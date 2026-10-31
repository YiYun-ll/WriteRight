import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Development containers only. Never accepts a remote URL, connection or service key.
const root = fileURLToPath(new URL('..', import.meta.url));
const env = Object.fromEntries(readFileSync(new URL('../supabase/.env.local', import.meta.url), 'utf8')
  .split('\n').filter(line => line.includes('=') && !line.startsWith('#')).map(line => {
    const index = line.indexOf('=');
    return [line.slice(0, index), line.slice(index + 1).replace(/^"|"$/g, '')];
  }));
const key = env.WRITERIGHT_WORKER_TOKEN;
if (!key || key.length < 16) throw new Error('Set a local WRITERIGHT_WORKER_TOKEN with at least 16 characters first.');
const network = spawnSync('docker', ['network', 'inspect', 'essaypilot-local'], { cwd: root, encoding: 'utf8' });
if (network.status !== 0 || JSON.parse(network.stdout)[0]?.Options?.['com.docker.network.bridge.host_binding_ipv4'] !== '127.0.0.1') {
  throw new Error('Start the localhost-bound development backend first.');
}
const literal = value => "'" + value.replaceAll("'", "''") + "'";
const entries = [['writeright_backend_url', 'http://supabase_kong_EssayPilot:8000'], ['writeright_worker_token', key]];
const sql = 'begin;\n' + entries.map(([name, value]) =>
  `select vault.create_secret(${literal(value)}, ${literal(name)}) where not exists (select 1 from vault.secrets where name=${literal(name)});\n` +
  `select vault.update_secret(id, new_secret => ${literal(value)}) from vault.secrets where name=${literal(name)};`
).join('\n') + '\ncommit;';
// Values go via stdin, never argv, stdout, a temporary file, or a tracked migration.
const configured = spawnSync('docker', ['exec', '-i', 'supabase_db_EssayPilot', 'psql', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-q', '-o', '/dev/null'],
  { cwd: root, input: sql, encoding: 'utf8' });
if (configured.status !== 0) throw new Error('Local worker configuration failed; inspect the local database. Secret diagnostics were suppressed.');
console.log('Local Vault worker settings configured. Keep functions:serve running; the existing cron schedule invokes the worker each minute.');
