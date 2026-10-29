import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const network = 'essaypilot-local';
function run(command, args, options = {}) {
  return spawnSync(command, args, { cwd: root, stdio: 'inherit', ...options });
}

if (run('docker', ['info'], { stdio: 'ignore' }).status !== 0) {
  console.error('Start OrbStack or Docker Desktop before running the local backend.');
  process.exit(1);
}
const inspection = run('docker', ['network', 'inspect', network], { encoding: 'utf8', stdio: 'pipe' });
if (inspection.status !== 0) {
  const created = run('docker', ['network', 'create', '--opt',
    'com.docker.network.bridge.host_binding_ipv4=127.0.0.1', network]);
  if (created.status !== 0) process.exit(created.status ?? 1);
} else {
  const [details] = JSON.parse(inspection.stdout);
  if (details.Options?.['com.docker.network.bridge.host_binding_ipv4'] !== '127.0.0.1') {
    console.error('Existing essaypilot-local network is not bound to localhost; inspect it before use.');
    process.exit(1);
  }
}
const result = run(resolve(root, 'node_modules/.bin/supabase'),
  ['start', '--network-id', network, '--output', 'json'],
  { stdio: ['inherit', 'pipe', 'inherit'], encoding: 'utf8' });
if (result.status === 0 && result.stdout.trim()) {
  try {
    const services = JSON.parse(result.stdout);
    for (const key of ['API_URL', 'STUDIO_URL', 'MAILPIT_URL', 'FUNCTIONS_URL']) {
      if (services[key]) console.log(`${key}: ${services[key]}`);
    }
  } catch {
    console.log('Backend started. Use Supabase Studio to inspect local services.');
  }
}
process.exit(result.status ?? 1);
