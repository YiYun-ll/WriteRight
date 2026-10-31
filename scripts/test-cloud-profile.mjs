import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { randomUUID, randomBytes } from 'node:crypto';
const project=process.argv[process.argv.indexOf('--project-ref')+1];
if(!process.argv.includes('--live') || !/^[a-z]{20}$/.test(project??'') || readFileSync('supabase/.temp/project-ref','utf8').trim()!==project) throw new Error('Use --live --project-ref <reviewed-linked-development-project>. Uses disposable test accounts; no AI call.');
const keyResult=spawnSync('node_modules/.bin/supabase',['projects','api-keys','--project-ref',project,'--reveal','--output','json'],{encoding:'utf8',stdio:['ignore','pipe','pipe']});
if(keyResult.status!==0) throw new Error('Cloud test credentials unavailable');
const keys=JSON.parse(keyResult.stdout);
const anon=keys.find(k=>k.name==='anon')?.api_key;
const service=keys.find(k=>k.name==='service_role')?.api_key;
if(!anon || !service || !service.startsWith('ey')) throw new Error('Expected server-side legacy test credentials');
const base=`https://${project}.supabase.co`;
const users=[];const tokens=new Map();const checks=[];
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
 tokens.set(created.body.id,signed.body.access_token);
 return signed.body.access_token;
}
try {
 const token=await createUser();
 const self=await api('/auth/v1/user',token);const id=self.body.id;
 const path='/rest/v1/profiles?id=eq.'+id;
 const saved=await api(path,token,'PATCH',{nickname:'晨光'});
 check([200,204].includes(saved.status),'owner can save a nickname');
 const reopened=await api(path+'&select=nickname',token);
 check(reopened.body?.[0]?.nickname==='晨光','nickname persists across separate cloud reads');
 const other=await createUser();
 const hidden=await api(path+'&select=nickname',other);
 check(hidden.status===200 && hidden.body?.length===0,'other account cannot read the nickname');
 await api(path,other,'PATCH',{nickname:'forged'});
 const unchanged=await api(path+'&select=nickname',token);
 check(unchanged.body?.[0]?.nickname==='晨光','other account cannot overwrite the nickname');
 const reset=await api(path,token,'PATCH',{nickname:''});
 const empty=await api(path+'&select=nickname',token);
 check([200,204].includes(reset.status) && empty.body?.[0]?.nickname==='','nickname can be reset to the default display');
 mkdirSync('artifacts/cloud-profile',{recursive:true});
 writeFileSync('artifacts/cloud-profile/acceptance.json',JSON.stringify({project,checks,timestamp:new Date().toISOString(),mode:'real cloud profiles RLS; disposable synthetic accounts; no model call'},null,2));
} finally {
 for(const id of users) {
  if(tokens.has(id)) await api('/functions/v1/delete-account',tokens.get(id),'POST',{});
  const result=await api('/auth/v1/admin/users/'+id,service,'DELETE',undefined,true);
  if(![200,204,404].includes(result.status))console.error('Synthetic account cleanup needs attention');
 }
}
