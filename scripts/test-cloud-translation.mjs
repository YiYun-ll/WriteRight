import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { randomBytes, randomUUID } from 'node:crypto';

const project = process.argv[process.argv.indexOf('--project-ref') + 1];
if (!process.argv.includes('--live') || !/^[a-z]{20}$/.test(project ?? '') ||
    readFileSync('supabase/.temp/project-ref', 'utf8').trim() !== project) {
  throw new Error('Use --live --project-ref <reviewed-linked-project>; uses paid AI and disposable accounts.');
}
const keyResult = spawnSync('node_modules/.bin/supabase', [
  'projects', 'api-keys', '--project-ref', project, '--reveal', '--output', 'json',
], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000 });
if (keyResult.status !== 0) throw new Error('Cloud test credentials unavailable');
const keys = JSON.parse(keyResult.stdout);
const anon = keys.find(k => k.name === 'anon')?.api_key;
const service = keys.find(k => k.name === 'service_role')?.api_key;
if (!anon || !service) throw new Error('Expected test credentials');
const base = `https://${project}.supabase.co`;
const fixture = JSON.parse(readFileSync('tests/fixtures/grading/translation-live.json', 'utf8'));
const runID = new Date().toISOString().replaceAll(/[:.]/g, '-');
const output = `artifacts/cloud-translation-20261105/${runID}`;
const privateOutput = `tests/private/cloud-translation/${runID}`;
mkdirSync(output, { recursive: true }); mkdirSync(privateOutput, { recursive: true, mode: 0o700 });
const users = []; const checks = []; const cases = []; let failure;
const summary = { project, startedAt: new Date().toISOString(), mode: 'real cloud DeepSeek; synthetic data; cron worker only', checks, cases };
const savePrivate = (name, value) => writeFileSync(`${privateOutput}/${name}.json`, JSON.stringify(value, null, 2), { mode: 0o600 });
const saveSummary = () => writeFileSync(`${output}/acceptance.json`, JSON.stringify(summary, null, 2));
function check(ok, name) {
  if (!ok) throw new Error(name);
  checks.push(name); console.log(JSON.stringify({ check: name, status: 'passed' }));
}
async function api(path, token, method = 'GET', body, admin = false) {
  const response = await fetch(base + path, { method,
    headers: { apikey: admin ? service : anon, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(125000) });
  return { status: response.status, body: await response.json().catch(() => null) };
}
async function createUser() {
  const email = `writeright-translation-${randomUUID()}@example.com`;
  const password = randomBytes(24).toString('base64url');
  const created = await api('/auth/v1/admin/users', service, 'POST', { email, password, email_confirm: true }, true);
  if (!created.body?.id) throw new Error(`Synthetic user create HTTP ${created.status}`);
  const user = { id: created.body.id, token: null, deleted: false }; users.push(user);
  const signed = await api('/auth/v1/token?grant_type=password', anon, 'POST', { email, password });
  if (!signed.body?.access_token) throw new Error(`Synthetic sign-in HTTP ${signed.status}`);
  user.token = signed.body.access_token; return user;
}
function typedRequest(confirmed = true) {
  return { idemKey: randomUUID(), task: { id: randomUUID(), part: 'T', title: 'Synthetic translation acceptance', prompt: confirmed ? fixture.english.join('\n') : '', requirements: confirmed ? [{ id: 'p1', text: '5句专项，每句3分，按原文顺序批改。' }] : [], revision: 1, confirmed, referenceTranslation: confirmed ? fixture.reference.join('\n') : '' }, submission: { id: randomUUID(), originalText: fixture.student.join('\n') } };
}
const inline = (role, page) => 'data:image/jpeg;base64,' + readFileSync(`tests/private/cloud-translation/${role}-${page}.jpg`).toString('base64');
async function enqueue(name, endpoint, input, token) {
  const startedAt = Date.now();
  const response = await api('/functions/v1/' + endpoint, token, 'POST', input);
  savePrivate(name + '-submission', response);
  check(response.status === 202 && response.body?.jobId === input.idemKey, `${name}: durable submission accepted`);
  const item = { name, input, token, jobID: input.idemKey, startedAt, lastState: '' };
  cases.push({ name, jobID: item.jobID, submissionID: input.submission.id, endpoint }); return item;
}
async function waitAll(items) {
  const deadline = Date.now() + 600000;
  const pending = new Set(items);
  while (pending.size && Date.now() < deadline) {
    for (const item of [...pending]) {
      const response = await api('/functions/v1/grading-status?jobId=' + item.jobID, item.token);
      if (response.status !== 200) throw new Error(`${item.name}: status HTTP ${response.status}`);
      const state = `${response.body.status}:${response.body.stage}`;
      if (state !== item.lastState) {
        console.log(JSON.stringify({ case: item.name, state })); item.lastState = state;
      }
      if (['completed', 'failed'].includes(response.body.status)) {
        savePrivate(item.name + '-report', response.body); item.result = response.body;
        const record = cases.find(c => c.name === item.name);
        Object.assign(record, { state: response.body.status, errorCode: response.body.errorCode, elapsedMs: Date.now() - item.startedAt });
        saveSummary(); pending.delete(item);
      }
    }
    if (pending.size) await new Promise(resolve => setTimeout(resolve, 3000));
  }
  for (const item of items) check(item.result?.status === 'completed', `${item.name}: cloud cron completed real grading`);
}
function validate(item, full) {
  const r = item.result.report.report_json; const t = r.translation_review;
  check(r.schema_version === '3.0.0' && r.part === 'T' && r.model_id === 'deepseek-flash' && r.score.max === 15 && r.prompt_version === 'WRITERIGHT_TRANSLATION_V1' && r.rubric_version === 'KY_EN2_TRANSLATION_V1', `${item.name}: independent translation contract and selected model`);
  check(t && t.overall_comment && t.accuracy && t.completeness && t.fluency && t.practice_advice, `${item.name}: detailed analysis returned`);
  if (full) {
    const earned = t.sentences.reduce((sum, s) => sum + s.points.reduce((n, p) => n + p.earned, 0), 0);
    const max = t.sentences.reduce((sum, s) => sum + s.points.reduce((n, p) => n + p.max, 0), 0);
    const typos = Math.floor(t.typos.length / 3) * .5 + (t.typos.length % 3 ? .25 : 0);
    check(r.grading_mode === 'full' && t.coverage === 'complete' && max === 15 && r.score.value === Math.max(0, earned - typos), `${item.name}: score equals point sum minus typo convention`);
    check(t.sentences.length === 5 && t.sentences.every(s => s.analysis && s.structure && s.revised && s.points.every(p => p.meaning && p.explanation)), `${item.name}: all five sentences have explanations and revisions`);
    check(t.revised_translation && t.changes.every(c => t.revised_translation.includes(c.text)) && t.expressions.length >= 3 && t.expressions.length <= 5, `${item.name}: full revision, anchored changes and useful expressions`);
    const fourth = t.sentences[3];
    check(fourth.points.reduce((n, p) => n + p.earned, 0) < fourth.points.reduce((n, p) => n + p.max, 0) && /不|并非|未必|并不是/.test(fourth.revised), `${item.name}: missing negation identified and corrected`);
    const last = t.sentences[4];
    check(last.student.includes('答按') && last.revised.includes('答案'), `${item.name}: original typo preserved and revised`);
    Object.assign(cases.find(c => c.name === item.name), { schema: r.schema_version, score: r.score.value, pointsSubtotal: earned, typoCount: t.typos.length, typoDeduction: typos, sentenceCount: t.sentences.length, expressionCount: t.expressions.length, coverage: t.coverage });
  } else {
    check(r.score.value === null && r.score.range === null && r.grading_mode === 'language_only' && t.source_status === 'missing', `${item.name}: missing original cannot be reconstructed from translation`);
    check(t.notice_zh && t.revised_translation === '' && t.typos.length === 0 && t.changes.length === 0, `${item.name}: explicit request for source, no guessed full revision or typo charge`);
  }
  return r;
}
try {
  const owner = await createUser(); const other = await createUser();
  const noAuth = await api('/functions/v1/submit-grading', anon, 'POST', typedRequest());
  check(noAuth.status === 401, 'anonymous translation submission rejected');
  const typed = await enqueue('typed-five-sentences', 'submit-grading', typedRequest(), owner.token);
  const duplicate = await api('/functions/v1/submit-grading', owner.token, 'POST', typed.input);
  check(duplicate.status === 202 && duplicate.body?.jobId === typed.jobID, 'typed duplicate reuses job');
  const changed = structuredClone(typed.input); changed.task.referenceTranslation += '补充对照';
  check((await api('/functions/v1/submit-grading', owner.token, 'POST', changed)).status === 409, 'typed reference change conflicts with same idempotency key');
  const photoInput = { idemKey: randomUUID(), task: { id: randomUUID(), part: 'T', referenceTranslation: fixture.reference.join('\n') }, submission: { id: randomUUID() }, taskImages: [inline('source', 1), inline('source', 2)], essayImages: [inline('answer', 1), inline('answer', 2)] };
  const photos = await enqueue('photos-two-plus-two', 'submit-photo-grading', photoInput, owner.token);
  const photoDuplicate = await api('/functions/v1/submit-photo-grading', owner.token, 'POST', photoInput);
  check(photoDuplicate.status === 202 && photoDuplicate.body?.jobId === photos.jobID, 'photo duplicate reuses job');
  const changedPhoto = structuredClone(photoInput); changedPhoto.task.referenceTranslation += '补充对照';
  check((await api('/functions/v1/submit-photo-grading', owner.token, 'POST', changedPhoto)).status === 409, 'photo reference change conflicts with same idempotency key');
  const missing = await enqueue('missing-original', 'submit-grading', typedRequest(false), owner.token);
  await waitAll([typed, photos, missing]);
  const typedReport = validate(typed, true); const photoReport = validate(photos, true); validate(missing, false);
  check(typedReport.translation_review.sentences.every(s => s.points.length >= 3 && s.points.length <= 4 && s.points.reduce((n, p) => n + p.max, 0) === 3), 'five-sentence exercise allocates three points each');
  check(photoReport.photo_review.sources.length === 4 && photos.result.report.source_sentences_json.length === 0 && photoReport.corrections.length === 0, 'multi-page photo report preserves images without transcript offsets');
  check(photoReport.translation_review.sentences.every((s, i) => s.source_page === (i < 3 ? 1 : 2) && s.answer_page === (i < 3 ? 1 : 2)), 'source and translation page references match two-page fixture');
  for (const item of [typed, photos]) {
    const stored = await api('/rest/v1/grading_reports?job_id=eq.' + item.jobID + '&select=score,max_score,report_json', owner.token);
    check(stored.status === 200 && Number(stored.body[0]?.score) === item.result.report.report_json.score.value && Number(stored.body[0]?.max_score) === 15, `${item.name}: database preserves exact score`);
  }
  check((await api('/functions/v1/grading-status?jobId=' + typed.jobID, other.token)).status === 404, 'other account cannot read translation report');
  const source = photoReport.photo_review.sources.find(s => s.role === 'essay');
  for (const [user, allowed] of [[owner, true], [other, false]]) {
    const response = await fetch(base + '/storage/v1/object/authenticated/essay-images/' + source.path, { headers: { apikey: anon, Authorization: 'Bearer ' + user.token }, signal: AbortSignal.timeout(30000) });
    check(allowed ? response.status === 200 : response.status !== 200, allowed ? 'owner can view original translation photo' : 'other account cannot view private translation photo'); await response.arrayBuffer();
  }
  const submission = await api('/rest/v1/essay_submissions?id=eq.' + photos.input.submission.id + '&select=original_text,word_count', owner.token);
  check(submission.body?.[0]?.original_text === '' && submission.body?.[0]?.word_count === 0, 'photo submission never stores generated full transcription');
  const usages = await api('/rest/v1/grading_usage?job_id=in.(' + [typed.jobID, photos.jobID, missing.jobID].join(',') + ')&select=job_id,model_id,prompt_tokens,completion_tokens', service, 'GET', undefined, true);
  check(usages.status === 200 && [typed, photos, missing].every(i => usages.body.some(u => u.job_id === i.jobID && u.prompt_tokens > 0 && u.completion_tokens > 0)), 'real provider usage recorded for all three jobs');
  summary.usage = usages.body;
  const deletion = await api('/functions/v1/delete-account', owner.token, 'POST', {});
  check(deletion.status >= 200 && deletion.status < 300, 'test account deletion completes'); owner.deleted = true;
  const removed = await fetch(base + '/storage/v1/object/essay-images/' + source.path, { headers: { apikey: service, Authorization: 'Bearer ' + service }, signal: AbortSignal.timeout(30000) });
  check(removed.status !== 200, 'test account deletion removes private translation photos'); await removed.arrayBuffer();
  summary.status = 'passed';
} catch (error) {
  failure = error; summary.status = 'failed'; summary.failure = error instanceof Error ? error.message : 'unknown failure';
  console.error(JSON.stringify({ status: 'failed', reason: summary.failure }));
} finally {
  const cleanup = [];
  for (const user of users) {
    if (!user.deleted && user.token) {
      const deleted = await api('/functions/v1/delete-account', user.token, 'POST', {}).catch(() => ({ status: 0 }));
      user.deleted = deleted.status >= 200 && deleted.status < 300;
    }
    const removed = await api('/auth/v1/admin/users/' + user.id, service, 'DELETE', undefined, true).catch(() => ({ status: 0 }));
    const gone = await api('/auth/v1/admin/users/' + user.id, service, 'GET', undefined, true).catch(() => ({ status: 0 }));
    cleanup.push({ deleted: user.deleted || [200, 204, 404].includes(removed.status), verifiedAbsent: gone.status === 404 });
  }
  summary.cleanup = cleanup; summary.finishedAt = new Date().toISOString();
  if (!cleanup.every(c => c.deleted && c.verifiedAbsent)) { summary.status = 'failed'; failure ??= new Error('Synthetic cleanup needs attention'); }
  saveSummary();
  console.log(JSON.stringify({ status: summary.status, checks: checks.length, artifact: `${output}/acceptance.json`, cleanup }));
}
if (failure) process.exitCode = 1;
