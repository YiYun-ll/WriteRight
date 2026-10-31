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
 if(process.argv.includes('--handwriting')) {
  const path='tests/private/handwriting-20261030/cloud-upload.jpg';
  const response=await api('/functions/v1/analyze-photos',token,'POST',{part:'B',taskImages:[],essayImages:[inline(path)]});
  writeFileSync('tests/private/handwriting-20261030/cloud-ai-photos.json',JSON.stringify(response.body,null,2));
  check(response.status===200,'real handwritten essay read by cloud AI');
  check(response.body?.task===null,'handwriting without question does not invent task');
  check(response.body?.essayPages?.length===1 && !('score' in response.body),'handwriting response requires review and has no task score');
  const text=response.body.essayPages[0].text;
  check(['2013','2015','4165','4692'].every(value=>text.includes(value)),'four manually checked year and museum-count anchors preserved');
  mkdirSync('artifacts/cloud-photos',{recursive:true});
  writeFileSync('artifacts/cloud-photos/handwriting-acceptance.json',JSON.stringify({checks,timestamp:new Date().toISOString(),note:'No original question; no grading call. Private result kept only in ignored tests/private.'},null,2));
 } else {
 const anonymous=await api('/functions/v1/analyze-photos',anon,'POST',{});
 check(anonymous.status===401,'anonymous photo request rejected');
 const invalid=await api('/functions/v1/analyze-photos',token,'POST',{part:'A',taskImages:[],essayImages:[]});
 check(invalid.status===400,'authenticated invalid images rejected without model call');
 const analyzed=await api('/functions/v1/analyze-photos',token,'POST',{part:'A',taskImages:[inline(folder+'/task.jpg')],essayImages:[inline(folder+'/essay.jpg')]});
 writeFileSync(folder+'/analysis.json',JSON.stringify(analyzed.body,null,2));
 check(analyzed.status===200,'real cloud AI reads task and essay photos');
 check(analyzed.body?.task?.parsed?.part==='A' && analyzed.body?.essayPages?.length===1,'separate task and essay result');
 const text=analyzed.body.essayPages[0].text;
 check(/I has/.test(text),'student grammar error preserved in AI transcription');
 const parsed=analyzed.body.task.parsed;
 const key=randomUUID();const submissionID=randomUUID();
 const request={idemKey:key,task:{id:randomUUID(),part:'A',title:'Cloud synthetic photo acceptance',prompt:analyzed.body.task.prompt,requirements:parsed.required_points.map(p=>({id:p.id,text:p.description})),revision:1,confirmed:true,chartFacts:parsed.chart_facts.map(f=>({...f,confirmed_by_user:true}))},submission:{id:submissionID,originalText:text}};
 const submitted=await api('/functions/v1/submit-grading',token,'POST',request);
 check(submitted.status===202 && submitted.body?.jobId===key,'cloud durable grading submission');
 const duplicate=await api('/functions/v1/submit-grading',token,'POST',request);
 check(duplicate.status===202 && duplicate.body?.jobId===key,'idempotent submission keeps same job');
 let status;
 for(let index=0;index<100;index++) {
  status=await api('/functions/v1/grading-status?jobId='+key,token);
  if(status.body?.status==='completed' || status.body?.status==='failed')break;
  await new Promise(resolve=>setTimeout(resolve,3000));
 }
 writeFileSync(folder+'/report.json',JSON.stringify(status?.body,null,2));
 check(status?.body?.status==='completed','cloud cron completes real model report without local worker');
 check(status.body.report?.report_json?.score?.max===10 && typeof status.body.report?.report_json?.score?.value==='number','Part A report uses independent 10-point rubric');
 const other=await createUser();
 const isolated=await api('/functions/v1/grading-status?jobId='+key,other);
 check(isolated.status===404,'another user cannot read the report');
 const deleted=await api('/functions/v1/delete-account',token,'POST',{});
 check(deleted.status>=200 && deleted.status<300,'cloud account deletion completes');
 mkdirSync('artifacts/cloud-photos',{recursive:true});
 writeFileSync('artifacts/cloud-photos/acceptance.json',JSON.stringify({project,checks,timestamp:new Date().toISOString(),mode:'real cloud DeepSeek; synthetic photos; cron only'},null,2));
 }
} finally {
 for(const id of users) {
  const result=await api('/auth/v1/admin/users/'+id,service,'DELETE',undefined,true);
  if(![200,204,404].includes(result.status))console.error('Synthetic account cleanup needs attention');
 }
}
