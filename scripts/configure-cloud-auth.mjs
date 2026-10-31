import { mkdtempSync, mkdirSync, existsSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
const project = process.argv[process.argv.indexOf('--project-ref')+1];
if (!/^[a-z]{20}$/.test(project??'') || readFileSync('supabase/.temp/project-ref','utf8').trim()!==project) throw new Error('Use the reviewed linked --project-ref');
const values = existsSync('supabase/.env.smtp') ? Object.fromEntries(readFileSync('supabase/.env.smtp','utf8').split('\n').filter(line=>line.includes('=')&&!line.startsWith('#')).map(line=>{const i=line.indexOf('=');return[line.slice(0,i).trim(),line.slice(i+1).trim().replace(/^['"]|['"]$/g,'')];})) : {};
const hasSMTP = Boolean(values.SMTP_USER && values.SMTP_PASS);
if (process.argv.includes('--apply') && !hasSMTP) throw new Error('Fill SMTP_USER and SMTP_PASS in ignored supabase/.env.smtp first.');
if (hasSMTP && (values.SMTP_HOST!=='smtp.qq.com' || ![465,587].includes(Number(values.SMTP_PORT)) || !/^[^\s@]+@(qq|foxmail)\.com$/i.test(values.SMTP_USER))) throw new Error('Check the QQ SMTP host, port, and complete sender email.');
const childEnv = {...process.env,WRITERIGHT_SMTP_USER:values.SMTP_USER??'',WRITERIGHT_SMTP_PASS:values.SMTP_PASS??'',WRITERIGHT_SMTP_SENDER:values.SMTP_SENDER_EMAIL||values.SMTP_USER||''};
function scrub(value) {
  let result=value.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi,'[email]');
  if(values.SMTP_PASS)result=result.replaceAll(values.SMTP_PASS,'[redacted]');
  return result;
}
const work = mkdtempSync(join(tmpdir(),'writeright-cloud-auth-'));
try {
  mkdirSync(join(work,'supabase'));
  writeFileSync(join(work,'supabase/magic_link.html'),readFileSync('supabase/templates/magic_link.html'));
  let config='project_id = "writeright-cloud-auth"\n[auth.email]\notp_length = 6\nenable_confirmations = true\n';
  if(!process.argv.includes('--smtp-only')) config+=['confirmation','magic_link','email_change'].map(name=>`[auth.email.template.${name}]\nsubject = "${name==='email_change'?'WriteRight 邮箱变更验证码':'WriteRight 登录验证码'}"\ncontent_path = "./supabase/magic_link.html"\n`).join('\n');
  if(hasSMTP) config+=`\n[auth.email.smtp]\nenabled = true\nhost = "smtp.qq.com"\nport = ${Number(values.SMTP_PORT)}\nuser = "env(WRITERIGHT_SMTP_USER)"\npass = "env(WRITERIGHT_SMTP_PASS)"\nadmin_email = "env(WRITERIGHT_SMTP_SENDER)"\nsender_name = "WriteRight"\n`;
  writeFileSync(join(work,'supabase/config.toml'),config);
  const tool=resolve('node_modules/.bin/supabase');
  const options={encoding:'utf8',env:childEnv,stdio:['ignore','pipe','pipe']};
  const inspect=spawnSync(tool,['config','diff','--project-ref',project,'--workdir',work,'--output-format','json'],options);
  if(inspect.status!==0) throw new Error('Could not review cloud email plan: '+scrub(inspect.stderr.slice(-400)));
  const plan=JSON.parse(inspect.stdout);
  const changes=plan.changes?.filter(change=>change.declared)??[];
  if(changes.some(change=>change.path[0]!=='auth' || change.path[1]!=='email' || !['otp_length','enable_confirmations','template','smtp'].includes(change.path[2]) || (change.path[2]==='enable_confirmations' && change.local!==true))) throw new Error('Unexpected cloud configuration change; no changes applied.');
  if(process.argv.includes('--apply')) {
    const applied=spawnSync(tool,['config','push','--project-ref',project,'--workdir',work,'--yes'],options);
    if(applied.status!==0) throw new Error('Cloud email configuration failed: '+scrub((applied.stderr+'\n'+applied.stdout).slice(-2400)));
    console.log('Configured QQ SMTP and six-digit OTP templates; email confirmation remains enabled.');
  } else console.log(JSON.stringify({smtpReady:hasSMTP,changes:changes.map(change=>({path:change.path,class:change.class})),counts:plan.counts},null,2));
} finally { rmSync(work,{recursive:true,force:true}); }
