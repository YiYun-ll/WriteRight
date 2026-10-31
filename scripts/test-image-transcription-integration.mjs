import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
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
  const imagePath = process.argv[process.argv.indexOf('--image') + 1];
  if (!process.argv.includes('--image') || !imagePath?.startsWith('tests/private/')) throw new Error('Use --image tests/private/your-image.jpg');
  const image = 'data:image/jpeg;base64,' + readFileSync(imagePath).toString('base64');
  const response = await api('/functions/v1/transcribe-image', token, 'POST', { image });
  check(response.status === 200, 'authenticated image transcription');
  check(typeof response.body?.text === 'string' && response.body.text.length > 0, 'nonempty transcription');
  check(Array.isArray(response.body?.uncertain) && !('score' in response.body), 'uncertainties without an invented score');
  const outputPath = imagePath + '.transcription.json';
  writeFileSync(outputPath, JSON.stringify(response.body, null, 2));
  const unauth = await api('/functions/v1/transcribe-image', settings.ANON_KEY, 'POST', { image });
  check(unauth.status === 401, 'anonymous image transcription rejected');
  console.log('Private result written beside the private input.');
} finally {
  for (const id of users) await api('/auth/v1/admin/users/' + id, settings.SERVICE_ROLE_KEY, 'DELETE', undefined, { apikey: settings.SERVICE_ROLE_KEY });
}
