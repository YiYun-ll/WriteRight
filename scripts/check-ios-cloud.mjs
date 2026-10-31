import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const app=process.argv[2]??'DerivedData/Build/Products/Debug-iphoneos/EssayPilot.app';
const result=spawnSync('/usr/bin/plutil',['-convert','json','-o','-',app+'/Info.plist'],{encoding:'utf8',stdio:['ignore','pipe','pipe']});
if(result.status!==0)throw new Error('Build the iPhone app before checking cloud configuration.');
const info=JSON.parse(result.stdout);
const project=readFileSync('supabase/.temp/project-ref','utf8').trim();
const url=new URL(info.SUPABASE_URL);
if(url.protocol!=='https:' || url.hostname!==project+'.supabase.co' || url.username || url.password)throw new Error('Built App does not target the reviewed cloud project.');
const key=info.SUPABASE_PUBLISHABLE_KEY;
if(typeof key!=='string' || !key)throw new Error('Missing public client key.');
if(!key.startsWith('sb_publishable_')) {
 const claims=JSON.parse(Buffer.from(key.split('.')[1]??'','base64url').toString());
 if(claims.role!=='anon')throw new Error('Only publishable/anon keys are allowed in the App.');
}
for(const name of ['DEEPSEEK_API_KEY','SUPABASE_SERVICE_ROLE_KEY','SUPABASE_SECRET_KEY','SMTP_PASS','WRITERIGHT_WORKER_TOKEN'])if(info[name])throw new Error('Server-only configuration detected in the App.');
console.log('Built App has the reviewed HTTPS cloud host and a client-public key; no server-only plist credentials.');
