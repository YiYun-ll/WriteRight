import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {randomUUID,randomBytes} from 'node:crypto';
const project=process.argv[process.argv.indexOf('--project-ref')+1];
if(!process.argv.includes('--live') || !/^[a-z]{20}$/.test(project??'') || readFileSync('supabase/.temp/project-ref','utf8').trim()!==project) throw new Error('Use --live --project-ref <reviewed-linked-project>; paid AI with synthetic accounts.');
const result=spawnSync('node_modules/.bin/supabase',['projects','api-keys','--project-ref',project,'--reveal','--output','json'],{encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:60000});
if(result.status!==0)throw new Error('Cloud test credentials unavailable');
const keys=JSON.parse(result.stdout),anon=keys.find(x=>x.name==='anon')?.api_key,service=keys.find(x=>x.name==='service_role')?.api_key;
if(!anon||!service)throw new Error('Missing test credentials');
const base=`https://${project}.supabase.co`,run=new Date().toISOString().replaceAll(/[:.]/g,'-');
const output=`artifacts/cloud-mixed/${run}`,privateOutput=`tests/private/cloud-mixed/${run}`;
mkdirSync(output,{recursive:true});mkdirSync(privateOutput,{recursive:true,mode:0o700});
const writing=JSON.parse(readFileSync('tests/fixtures/grading/mixed-live.json','utf8')).A;
const translation=JSON.parse(readFileSync('tests/fixtures/grading/translation-live.json','utf8'));
const fixtures={A:writing,T:{task:translation.english.join('\n'),essay:translation.student.join('\n'),reference:translation.reference.join('\n')}};
const users=[],checks=[],cases=[],summary={project,startedAt:new Date().toISOString(),mode:'real DeepSeek; mixed sources; synthetic fixtures; cron only',checks,cases};let failure;
function check(ok,name){if(!ok)throw new Error(name);checks.push(name);console.log(JSON.stringify({check:name,status:'passed'}));}
async function api(path,token,method='GET',body,admin=false){const response=await fetch(base+path,{method,headers:{apikey:admin?service:anon,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(125000)});return{status:response.status,body:await response.json().catch(()=>null)};}
async function account(){const email=`mixed-${randomUUID()}@example.com`,password=randomBytes(24).toString('base64url');const created=await api('/auth/v1/admin/users',service,'POST',{email,password,email_confirm:true},true);if(!created.body?.id)throw new Error('Synthetic account creation failed');const user={id:created.body.id,token:null,deleted:false};users.push(user);const signed=await api('/auth/v1/token?grant_type=password',anon,'POST',{email,password});if(!signed.body?.access_token)throw new Error('Synthetic sign-in failed');user.token=signed.body.access_token;return user;}
const inline=(part,role,page)=>'data:image/jpeg;base64,'+readFileSync(`tests/private/cloud-mixed/${part}-${role}-${page}.jpg`).toString('base64');
const save=()=>writeFileSync(output+'/acceptance.json',JSON.stringify(summary,null,2));
try{
 const owner=await account(),other=await account();const pending=[];
 for(const part of ['A','T'])for(const textRole of ['task','essay']){
  const name=`${part}-text-${textRole}`,data=fixtures[part],pages=part==='T'?[1,2]:[1];
  const input={idemKey:randomUUID(),task:{id:randomUUID(),part,...(data.reference?{referenceTranslation:data.reference}:{})},submission:{id:randomUUID()},taskImages:textRole==='task'?[]:pages.map(p=>inline(part,'source',p)),essayImages:textRole==='essay'?[]:pages.map(p=>inline(part,'answer',p)),textInputs:{task:textRole==='task'?data.task:'',essay:textRole==='essay'?data.essay:''}};
  const submitted=await api('/functions/v1/submit-photo-grading',owner.token,'POST',input);
  check(submitted.status===202&&submitted.body?.jobId===input.idemKey,`${name}: mixed submission accepted`);
  const duplicate=await api('/functions/v1/submit-photo-grading',owner.token,'POST',input);
  check(duplicate.status===202&&duplicate.body?.jobId===input.idemKey,`${name}: duplicate reuses snapshot`);
  const changed=structuredClone(input);changed.textInputs[textRole]+=' Changed';
  check((await api('/functions/v1/submit-photo-grading',owner.token,'POST',changed)).status===409,`${name}: changed text cannot reuse key`);
  const item={name,input,started:Date.now(),lastState:''};pending.push(item);cases.push({name,jobID:input.idemKey,submissionID:input.submission.id});
 }
 const deadline=Date.now()+720000;
 while(pending.some(x=>!x.result)&&Date.now()<deadline){
  for(const item of pending.filter(x=>!x.result)){
   const r=await api('/functions/v1/grading-status?jobId='+item.input.idemKey,owner.token);
   if(r.status!==200)throw new Error('Grading status unavailable');
   const state=r.body.status+':'+r.body.stage;
   if(state!==item.lastState){console.log(JSON.stringify({case:item.name,state}));item.lastState=state;}
   if(['completed','failed'].includes(r.body.status)){item.result=r.body;writeFileSync(`${privateOutput}/${item.name}.json`,JSON.stringify(r.body,null,2),{mode:0o600});Object.assign(cases.find(c=>c.name===item.name),{state:r.body.status,errorCode:r.body.errorCode,elapsedMs:Date.now()-item.started});save();}
  }
  if(pending.some(x=>!x.result))await new Promise(r=>setTimeout(r,3000));
 }
 for(const item of pending){
  check(item.result?.status==='completed',`${item.name}: cron completed real grading`);
  const r=item.result.report.report_json,isTranslation=item.input.task.part==='T';
  check(r.schema_version===(isTranslation?'3.1.0':'2.4.0')&&r.grading_mode==='full'&&typeof r.score.value==='number'&&r.score.max===(isTranslation?15:10),`${item.name}: correct mixed report and independent rubric`);
  check(JSON.stringify(r.photo_review.text_sources)===JSON.stringify(item.input.textInputs),`${item.name}: typed input preserved exactly`);
  check(r.photo_review.sources.length===item.input.taskImages.length+item.input.essayImages.length&&item.result.report.source_sentences_json.length===0,`${item.name}: only real photos, no artificial transcription spans`);
  if(isTranslation){
   check(r.translation_review.sentences.length===5&&r.translation_review.sentences.every(s=>s.analysis&&s.structure&&s.revised),`${item.name}: all five translations have explanations`);
   check(r.translation_review.sentences.every(s=>item.input.textInputs.task?s.source_page===null:s.answer_page===null),`${item.name}: text role has no fabricated page`);
  }else{
   check(r.sentence_reviews.items.length>0&&r.advanced_advice.length>=2&&r.model_essay&&r.rewrites.study,`${item.name}: sentence feedback and study materials`);
   if(item.input.textInputs.essay)check(r.sentence_reviews.items.every(s=>s.page===null&&s.sentence_id),`${item.name}: typed sentences have exact identifiers`);
  }
  check((await api('/functions/v1/grading-status?jobId='+item.input.idemKey,other.token)).status===404,`${item.name}: other account cannot read report`);
  Object.assign(cases.find(c=>c.name===item.name),{schema:r.schema_version,score:r.score.value,photoCount:r.photo_review.sources.length});
 }
 const ids=pending.map(x=>x.input.idemKey).join(',');
 const usages=await api('/rest/v1/grading_usage?job_id=in.('+ids+')&select=job_id,model_id,prompt_tokens,completion_tokens',service,'GET',undefined,true);
 check(usages.status===200&&pending.every(x=>usages.body.some(u=>u.job_id===x.input.idemKey&&u.prompt_tokens>0&&u.completion_tokens>0)),'provider usage recorded for all mixed jobs');summary.usage=usages.body;summary.status='passed';
}catch(error){failure=error;summary.status='failed';summary.failure=error instanceof Error?error.message:'unknown';console.error(JSON.stringify({status:'failed',reason:summary.failure}));}
finally{
 const cleanup=[];
 for(const user of users){
  if(user.token){const removed=await api('/functions/v1/delete-account',user.token,'POST',{}).catch(()=>({status:0}));user.deleted=removed.status>=200&&removed.status<300;}
  if(!user.deleted)await api('/auth/v1/admin/users/'+user.id,service,'DELETE',undefined,true).catch(()=>{});
  const gone=await api('/auth/v1/admin/users/'+user.id,service,'GET',undefined,true).catch(()=>({status:0}));cleanup.push({deleted:user.deleted,verifiedAbsent:gone.status===404});
 }
 summary.cleanup=cleanup;summary.finishedAt=new Date().toISOString();if(!cleanup.every(x=>x.deleted&&x.verifiedAbsent)){summary.status='failed';failure??=new Error('Synthetic cleanup needs attention');}save();console.log(JSON.stringify({status:summary.status,checks:checks.length,artifact:output+'/acceptance.json',cleanup}));
}
if(failure)process.exitCode=1;
