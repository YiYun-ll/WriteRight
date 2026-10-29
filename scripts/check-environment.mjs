import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const run = (command, args = []) => spawnSync(command, args, {
  cwd: root,
  encoding: 'utf8',
  timeout: 15000,
  env: process.env,
});
let missing = 0;
function check(name, command, args) {
  const result = run(command, args);
  const ok = result.status === 0;
  console.log(`${ok ? 'OK' : 'MISSING'} ${name}${ok ? `: ${result.stdout.trim().split('\n')[0]}` : ''}`);
  if (!ok) missing++;
}

console.log('EssayPilot environment check (no secret values are printed)');
check('Git', 'git', ['--version']);
check('Node.js', 'node', ['--version']);
check('Codex CLI', 'codex', ['--version']);
check('Cursor CLI', 'cursor', ['--version']);
check('Kimi Code CLI', 'kimi', ['--version']);
check('Deno', 'deno', ['--version']);
check('Supabase CLI', resolve(root, 'node_modules/.bin/supabase'), ['--version']);
check('Full Xcode', 'xcodebuild', ['-version']);
check('iOS simulator SDK', 'xcrun', ['--sdk', 'iphonesimulator', '--show-sdk-version']);
const simulator = run('xcrun', ['simctl', 'list', 'runtimes', '--json']);
let hasRuntime = false;
try {
  hasRuntime = JSON.parse(simulator.stdout).runtimes.some(runtime =>
    runtime.isAvailable && runtime.identifier.startsWith('com.apple.CoreSimulator.SimRuntime.iOS-'));
} catch { /* Missing or unfinished Xcode installation. */ }
console.log(`${hasRuntime ? 'OK' : 'MISSING'} iOS simulator runtime`);
if (!hasRuntime) missing++;
check('Docker runtime', 'docker', ['info', '--format', '{{.ServerVersion}}']);
const generator = existsSync(resolve(root, '.tools/bin/xcodegen'))
  ? resolve(root, '.tools/bin/xcodegen') : 'xcodegen';
check('XcodeGen', generator, ['--version']);
check('GitHub CLI login', 'gh', ['api', 'user', '--jq', '.login']);
console.log(`\n${missing === 0 ? 'All toolchain checks passed.' : `${missing} prerequisite(s) still need attention.`}`);
console.log('Cloud projects, API access, Apple signing and device tests are verified separately.');
process.exitCode = missing === 0 ? 0 : 1;
