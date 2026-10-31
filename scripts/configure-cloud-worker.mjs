import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const project = process.argv[process.argv.indexOf('--project-ref') + 1];
if (!process.argv.includes('--apply') || !/^[a-z]{20}$/.test(project ?? '')) throw new Error('Use --apply --project-ref <linked-development-project>');
if (readFileSync('supabase/.temp/project-ref','utf8').trim() !== project) throw new Error('Project must match the reviewed linked development project.');
const values = Object.fromEntries(readFileSync('supabase/.env.cloud','utf8').split('\n').filter(v=>v && !v.startsWith('#')).map(v=>{const i=v.indexOf('=');return[v.slice(0,i),v.slice(i+1)];}));
const token = values.WRITERIGHT_WORKER_TOKEN;
if (!token || token.length < 32) throw new Error('Missing cloud worker token');
const literal = value => "'" + value.replaceAll("'","''") + "'";
const pairs = [['writeright_backend_url',`https://${project}.supabase.co`],['writeright_worker_token',token]];
const sql = 'begin;\n'+pairs.map(([name,value])=>`select vault.create_secret(${literal(value)},${literal(name)}) where not exists(select 1 from vault.secrets where name=${literal(name)});\nselect vault.update_secret(id,new_secret=>${literal(value)}) from vault.secrets where name=${literal(name)};`).join('\n')+'\ncommit;';
// Only stdin contains secret SQL. Never print SQL, token, or backend diagnostics.
const result = spawnSync('node_modules/.bin/supabase',['db','query','--linked','--file','/dev/stdin','--output','json'],{input:sql,encoding:'utf8',stdio:['pipe','pipe','pipe']});
if(result.status!==0) throw new Error('Cloud Vault configuration failed; private diagnostics suppressed.');
console.log('Cloud worker Vault settings configured; the existing database cron can process queued jobs.');
