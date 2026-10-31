import { execFileSync } from 'node:child_process';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { randomUUID, randomBytes } from 'node:crypto';

if (!process.argv.includes('--live')) throw new Error('Pass --live: this integration uses paid model calls on synthetic data.');
function env(text) {
  return Object.fromEntries(text.split('\n').filter(line => line.includes('=') && !line.startsWith('#')).map(line => {
    const index = line.indexOf('='); return [line.slice(0,index), line.slice(index+1).replace(/^"|"$/g,'')];
  }));
}
if (process.argv.includes('--cloud')) throw new Error('This acceptance script is local only.');
const settings = env(execFileSync('node_modules/.bin/supabase',['status','-o','env'],{encoding:'utf8',stdio:['ignore','pipe','ignore']}));
const base = settings.API_URL;
if (!base || !settings.ANON_KEY || !settings.SERVICE_ROLE_KEY) throw new Error('Missing integration configuration');
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
  const token = await user();
  const jobID = randomUUID();
  const submitted = await api('/functions/v1/submit-grading', token, 'POST', {
    idemKey: jobID,
    task: { id: randomUUID(), part: 'A', title: 'Scheduled local invitation',
      prompt: 'Invite Alex to a book club on Saturday at the library. Describe the activity and ask for a reply. Sign Li Ming.',
      requirements: [{ id: 'p1', text: 'Give time and place, describe the activity and request a reply.' }], revision: 1, confirmed: true },
    submission: { id: randomUUID(), originalText: 'Dear Alex, I am writing to invite you to our book club this Saturday at the library. We will discuss a short story and share our favorite books. I has prepared some questions for everyone. Please let me know by Friday if you can join us. Yours sincerely, Li Ming' }
  });
  check(submitted.status === 202 && submitted.body?.jobId === jobID, 'scheduled test job accepted');
  let result;
  // No grading-worker request here: only the database's existing cron may process it.
  const deadline = Date.now() + 240_000;
  while (Date.now() < deadline) {
    result = await api('/functions/v1/grading-status?jobId=' + jobID, token);
    if (result.body?.status === 'completed' || result.body?.status === 'failed') break;
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
  check(result?.body?.status === 'completed', 'database schedule completed a real model job without manual invocation');
  check(result.body.report?.report_json?.prompt_version === 'WRITERIGHT_GRADING_V1_2', 'scheduled report uses current source context');
  mkdirSync('artifacts', { recursive: true });
  writeFileSync('artifacts/local-worker-schedule.json', JSON.stringify({ checks, at: new Date().toISOString() }, null, 2));
} finally {
  for (const id of users) await api('/auth/v1/admin/users/' + id, settings.SERVICE_ROLE_KEY, 'DELETE', undefined, { apikey: settings.SERVICE_ROLE_KEY });
}
