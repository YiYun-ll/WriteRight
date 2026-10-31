import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const project = process.argv[process.argv.indexOf('--project-ref') + 1];
if (!process.argv.includes('--apply') || !/^[a-z]{20}$/.test(project ?? '') || readFileSync('supabase/.temp/project-ref','utf8').trim() !== project) throw new Error('Use --apply --project-ref <reviewed-linked-project>');
const version = '20261030150000';
const name = 'photo_grading';
const source = readFileSync(`supabase/migrations/${version}_${name}.sql`, 'utf8');
const literal = value => "'" + value.replaceAll("'", "''") + "'";
const sql = `begin; do $migration$ begin
if not exists(select 1 from supabase_migrations.schema_migrations where version=${literal(version)}) then
execute ${literal(source)};
insert into supabase_migrations.schema_migrations(version,name,statements) values(${literal(version)},${literal(name)},array[${literal(source)}]);
end if; end $migration$; commit;`;
const result = spawnSync('node_modules/.bin/supabase', ['db','query','--linked','--file','/dev/stdin','--output','json'], {input:sql,encoding:'utf8',stdio:['pipe','pipe','pipe']});
if(result.status!==0) throw new Error('Photo migration failed. Diagnostics suppressed; no credentials printed.');
console.log('Direct photo migration applied atomically with migration history.');
