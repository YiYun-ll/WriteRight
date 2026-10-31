import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { randomUUID, randomBytes } from 'node:crypto';
const project=process.argv[process.argv.indexOf('--project-ref')+1];
if(!process.argv.includes('--live') || !/^[a-z]{20}$/.test(project??'') || readFileSync('supabase/.temp/project-ref','utf8').trim()!==project) throw new Error('Use --live --project-ref <reviewed-linked-development-project>. Uses paid AI and disposable test accounts.');
const keyResult=spawnSync('node_modules/.bin/supabase',['projects','api-keys','--project-ref',project,'--reveal','--output','json'],{encoding:'utf8',stdio:['ignore','pipe','pipe']});
if(keyResult.status!==0) throw new Error('Cloud test credentials unavailable');
const keys=JSON.parse(keyResult.stdout);
const anon=keys.find(k=>k.name==='anon')?.api_key;
const service=keys.find(k=>k.name==='service_role')?.api_key;
if(!anon || !service || !service.startsWith('ey')) throw new Error('Expected server-side legacy test credentials');
const base=`https://${project}.supabase.co`;
const users=[];const checks=[];
const folder='tests/private/cloud-acceptance';mkdirSync(folder,{recursive:true});
async function api(path,token,method='GET',body,admin=false) {
 const response=await fetch(base+path,{method,headers:{apikey:admin?service:anon,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(125000)});
 return {status:response.status,body:await response.json().catch(()=>null)};
}
function check(ok,name) {if(!ok)throw new Error(name);checks.push(name);console.log(JSON.stringify({check:name,status:'passed'}));}
async function createUser() {
 const email=`writeright-acceptance-${randomUUID()}@example.com`;const password=randomBytes(24).toString('base64url');
 const created=await api('/auth/v1/admin/users',service,'POST',{email,password,email_confirm:true},true);
 if(!created.body?.id)throw new Error(`Create synthetic user HTTP ${created.status}`);
 users.push(created.body.id);
 const signed=await api('/auth/v1/token?grant_type=password',anon,'POST',{email,password});
 if(!signed.body?.access_token)throw new Error(`Synthetic sign-in HTTP ${signed.status}`);
 return signed.body.access_token;
}
const inline=path=>'data:image/jpeg;base64,'+readFileSync(path).toString('base64');
try {
 const token=await createUser();
 const endpoint='/functions/v1/submit-photo-grading';
 const anonymous=await api(endpoint,anon,'POST',{});
 check(anonymous.status===401,'anonymous direct photo request rejected');
 const invalid=await api(endpoint,token,'POST',{part:'A',taskImages:[],essayImages:[]});
 check(invalid.status===400,'invalid direct photos rejected');
 const key=randomUUID();const submissionID=randomUUID();
 const request={idemKey:key,task:{id:randomUUID(),part:'A'},submission:{id:submissionID},taskImages:[inline(folder+'/task.jpg')],essayImages:[inline(folder+'/essay.jpg')]};
 const submitted=await api(endpoint,token,'POST',request);
 writeFileSync(folder+'/direct-submission.json',JSON.stringify(submitted.body,null,2));
 check(submitted.status===202 && submitted.body?.jobId===key,'photo-only durable job accepted');
 const duplicate=await api(endpoint,token,'POST',request);
 check(duplicate.status===202 && duplicate.body?.jobId===key,'photo-only idempotency');
 const conflict=await api(endpoint,token,'POST',{...request,task:{...request.task,part:'B'}});
 check(conflict.status===409,'same key with changed photo context conflicts');
 let status;
 for(let index=0;index<100;index++) {
  status=await api('/functions/v1/grading-status?jobId='+key,token);
  if(['completed','failed'].includes(status.body?.status)) break;
  await new Promise(resolve=>setTimeout(resolve,3000));
 }
 writeFileSync(folder+'/direct-report.json',JSON.stringify(status?.body,null,2));
 check(status?.body?.status==='completed','cloud cron completes direct photo grading');
 const report=status.body.report?.report_json;
 check(report?.schema_version==='2.0.0' && report?.score?.max===10 && typeof report?.score?.value==='number','direct photo report uses Part A rubric');
 check(report?.photo_review?.sources?.length===2 && status.body.report.source_sentences_json?.length===0 && report.corrections?.length===0,'original photos replace transcript and artificial sentence offsets');
 const source=report.photo_review.sources.find(s=>s.role==='essay');
 const photo=await fetch(base+'/storage/v1/object/authenticated/essay-images/'+source.path,{headers:{apikey:anon,Authorization:'Bearer '+token}});
 check(photo.status===200,'owner can revisit private report photo');
 await photo.arrayBuffer();
 const other=await createUser();
 const isolated=await api('/functions/v1/grading-status?jobId='+key,other);
 check(isolated.status===404,'other account cannot read direct photo report');
 const privatePhoto=await fetch(base+'/storage/v1/object/authenticated/essay-images/'+source.path,{headers:{apikey:anon,Authorization:'Bearer '+other}});
 check(privatePhoto.status!==200,'other account cannot read source photo');await privatePhoto.arrayBuffer();
 const original=await api('/rest/v1/essay_submissions?id=eq.'+submissionID+'&select=original_text,word_count',token);
 check(original.status===200 && original.body?.[0]?.original_text==='' && original.body?.[0]?.word_count===0,'submission never stores a generated transcript');
 const deleted=await api('/functions/v1/delete-account',token,'POST',{});
 check(deleted.status>=200 && deleted.status<300,'direct photo account deletion completes');
 const removed=await fetch(base+'/storage/v1/object/essay-images/'+source.path,{headers:{apikey:service,Authorization:'Bearer '+service}});
 check(removed.status!==200,'account deletion removes private source photos');await removed.arrayBuffer();
 mkdirSync('artifacts/cloud-direct-photos',{recursive:true});
 writeFileSync('artifacts/cloud-direct-photos/acceptance.json',JSON.stringify({project,checks,timestamp:new Date().toISOString(),mode:'real cloud DeepSeek; synthetic photos; cron only; no transcription step'},null,2));
} finally {
 for(const id of users) {
  const result=await api('/auth/v1/admin/users/'+id,service,'DELETE',undefined,true);
  if(![200,204,404].includes(result.status))console.error('Synthetic account cleanup needs attention');
 }
}
