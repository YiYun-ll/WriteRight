import { readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const project=process.argv[process.argv.indexOf('--project-ref')+1];
if(!/^[a-z]{20}$/.test(project??'') || readFileSync('supabase/.temp/project-ref','utf8').trim()!==project) throw new Error('Use reviewed linked --project-ref');
const result=spawnSync('node_modules/.bin/supabase',['projects','api-keys','--project-ref',project,'--output','json'],{encoding:'utf8',stdio:['ignore','pipe','pipe']});
if(result.status!==0) throw new Error('Could not retrieve client-public configuration.');
const keys=JSON.parse(result.stdout);
const item=keys.find(k=>k.type==='publishable' || k.api_key?.startsWith('sb_publishable_')) ?? keys.find(k=>k.name==='anon');
const key=item?.api_key;
if(!key || key.startsWith('sb_secret_')) throw new Error('No public client key returned');
if(!key.startsWith('sb_publishable_')) {
 const payload=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString());
 if(payload.role!=='anon') throw new Error('Only anon or publishable keys are allowed in iOS');
}
const path='ios/Config/Local.xcconfig';
let text=readFileSync(path,'utf8');
for(const [name,value] of [['SUPABASE_HOST',project+'.supabase.co'],['SUPABASE_PUBLISHABLE_KEY',key]]) {
 const pattern=new RegExp('^\\s*'+name+'\\s*=.*$','m');
 const setting=name+' = '+value;
 text=pattern.test(text)?text.replace(pattern,setting):text.trimEnd()+'\n'+setting+'\n';
}
writeFileSync(path,text);chmodSync(path,0o600);
console.log('Client-public cloud configuration saved in ignored Local.xcconfig; private signing settings preserved.');
