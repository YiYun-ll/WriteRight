import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

const project = process.argv[process.argv.indexOf('--project-ref') + 1];
if (!process.argv.includes('--apply') || !/^[a-z]{20}$/.test(project ?? '') ||
    readFileSync('supabase/.temp/project-ref', 'utf8').trim() !== project) {
  throw new Error('Use --apply --project-ref <reviewed-linked-project>');
}
const version = '20261105200000';
const name = 'mixed_practice';
const source = readFileSync(`supabase/migrations/${version}_${name}.sql`, 'utf8');
const literal = value => "'" + value.replaceAll("'", "''") + "'";
const sql = `begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
do $migration$ begin
if exists(select 1 from supabase_migrations.schema_migrations where version=${literal(version)}) then
  if not exists(select 1 from supabase_migrations.schema_migrations where version=${literal(version)} and statements[1]=${literal(source)}) then
    raise exception 'MIGRATION_SOURCE_MISMATCH';
  end if;
else
  execute ${literal(source)};
  insert into supabase_migrations.schema_migrations(version,name,statements)
  values(${literal(version)},${literal(name)},array[${literal(source)}]);
end if;
end $migration$;
commit;`;
const result = spawnSync('node_modules/.bin/supabase', [
  'db', 'query', '--linked', '--file', '/dev/stdin', '--output', 'json',
], { input: sql, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 120000 });
if (result.status !== 0) { const reason = (result.stderr + result.stdout).match(/MIGRATION_SOURCE_MISMATCH|TransportError|syntax error|permission denied|Connection refused/)?.[0] ?? 'command failed'; throw new Error('Mixed practice migration failed: ' + reason); }
console.log('Mixed practice migration applied atomically with matching migration history.');
