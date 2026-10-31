import { execFileSync } from 'node:child_process';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { randomUUID, randomBytes } from 'node:crypto';

if (!process.argv.includes('--live')) throw new Error('Pass --live: this integration uses paid model calls on synthetic data.');
function env(text) {
  return Object.fromEntries(text.split('\n').filter(line => line.includes('=') && !line.startsWith('#')).map(line => {
    const index = line.indexOf('='); return [line.slice(0,index), line.slice(index+1).replace(/^"|"$/g,'')];
  }));
}
const settings = process.argv.includes('--cloud') ? env(readFileSync('.setup/cloud-test.env','utf8')) : env(execFileSync('node_modules/.bin/supabase',['status','-o','env'],{encoding:'utf8',stdio:['ignore','pipe','ignore']}));
const secrets = env(readFileSync('supabase/.env.local','utf8'));
const base = settings.API_URL;
if (!base || !settings.ANON_KEY || !settings.SERVICE_ROLE_KEY) throw new Error('Missing integration configuration');
const workerKey = process.env.WRITERIGHT_WORKER_TOKEN || secrets.WRITERIGHT_WORKER_TOKEN;
const workerURL = process.env.WRITERIGHT_WORKER_URL || base + '/functions/v1/grading-worker';
const users = [];
const checks = [];
async function api(path, token, method='GET', body, extra={}) {
  const response = await fetch(base+path,{method,headers:{apikey:settings.ANON_KEY,Authorization:`Bearer ${token}`,'Content-Type':'application/json',...extra},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(125000)});
  return {status:response.status,body:await response.json().catch(()=>null)};
}
function check(ok, name) { if(!ok) throw new Error(name); checks.push(name); console.log(JSON.stringify({check:name,status:'passed'})); }
async function user() {
  const email = `writeright-integration-${randomUUID()}@example.com`; const password=randomBytes(24).toString('base64url');
  const created=await api('/auth/v1/admin/users',settings.SERVICE_ROLE_KEY,'POST',{email,password,email_confirm:true},{apikey:settings.SERVICE_ROLE_KEY});
  if (!created.body?.id) throw new Error(`Create test user ${created.status}`);
  users.push(created.body.id);
  const signed=await api('/auth/v1/token?grant_type=password',settings.ANON_KEY,'POST',{email,password});
  if (!signed.body?.access_token) throw new Error(`Sign in ${signed.status}`);
  return signed.body.access_token;
}
try {
  const [tokenA,tokenB]=await Promise.all([user(),user()]);
  const input={idemKey:randomUUID(),task:{id:randomUUID(),part:'A',title:'Reading club',prompt:'Write an email inviting Alex to a book club. Give a time and place, describe the activity, and ask for a reply. Sign Li Ming.',requirements:[{id:'p1',text:'Invite Alex and give the meeting time and place'},{id:'p2',text:'Describe the activity and ask for a reply'}],revision:1,confirmed:true},submission:{id:randomUUID(),originalText:'Dear Alex,\nI am writing to invite you to our reading club this Saturday at the library. We will discuss a short story and share the books we enjoy. I has prepared a few questions for our discussion. You can bring a friend if you like. Please let me know by Friday whether you can come. I hope to see you there.\nYours,\nLi Ming'}};
  const first=await api('/functions/v1/submit-grading',tokenA,'POST',input);
  check(first.status===202 && first.body?.jobId===input.idemKey,'authenticated durable submission');
  const duplicate=await api('/functions/v1/submit-grading',tokenA,'POST',input);
  check(duplicate.body?.jobId===first.body.jobId,'duplicate submission reuses job');
  const cross=await api('/functions/v1/grading-status?jobId='+input.idemKey,tokenB);
  check(cross.status===404,'cross-user job lookup rejected');
  const unauth=await api('/functions/v1/submit-grading',settings.ANON_KEY,'POST',input);
  check(unauth.status===401,'anonymous grading rejected');
  let result;
  for (let attempt=0;attempt<6;attempt++) {
    const workerResponse = await fetch(workerURL,{method:'POST',headers:{'x-worker-key':workerKey},signal:AbortSignal.timeout(125000)});
    check(workerResponse.status===200,'protected worker invocation');
    result=await api('/functions/v1/grading-status?jobId='+input.idemKey,tokenA);
    if (result.body?.status==='completed' || result.body?.status==='failed') break;
    await new Promise(resolve=>setTimeout(resolve,15000));
  }
  check(result?.body?.status==='completed' && result.body.report?.report_json,'real model worker and persisted report');
  const report=result.body.report;
  check(report.report_json.score.max===10 && Number.isInteger(report.report_json.score.value),'A score contract');
  check(report.source_sentences_json?.every(s=>input.submission.originalText.slice(s.startUTF16,s.startUTF16+s.lengthUTF16)===s.original),'server source spans match original');
  mkdirSync('artifacts',{recursive:true});
  writeFileSync('artifacts/p5-live-integration.json',JSON.stringify({generatedAt:new Date().toISOString(),dataset:'Synthetic integration fixture, no human grading labels',checks,report},null,2));
} finally {
  for(const id of users) await api('/auth/v1/admin/users/'+id,settings.SERVICE_ROLE_KEY,'DELETE',undefined,{apikey:settings.SERVICE_ROLE_KEY});
}
