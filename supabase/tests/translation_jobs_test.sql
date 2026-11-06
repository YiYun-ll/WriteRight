begin;
select plan(9);
insert into auth.users(id,email) values ('76543210-1111-4111-8111-111111111111','translation-synthetic@example.com');
create temporary table translation_input as select
'{"idemKey":"76543210-2222-4222-8222-222222222222","task":{"id":"76543210-3333-4333-8333-333333333333","part":"T","title":"Synthetic translation","prompt":"Reading opens doors.","requirements":[],"revision":1,"confirmed":true},"submission":{"id":"76543210-4444-4444-8444-444444444444","originalText":"阅读打开大们。"}}'::jsonb as input,
jsonb_build_object('part','T','originalText','阅读打开大们。','wordCount',0,'contentHash',repeat('a',64),'task',jsonb_build_object('referenceTranslation','阅读带来机会。')) as context;
select lives_ok($$select public.enqueue_grading('76543210-1111-4111-8111-111111111111', input, context) from translation_input$$,'translation enqueues through durable job API');
select is((select part from public.essay_tasks where id='76543210-3333-4333-8333-333333333333'),'T','translation task keeps independent type');
select is((select context_json #>> '{task,referenceTranslation}' from public.grading_jobs where id='76543210-2222-4222-8222-222222222222'),'阅读带来机会。','reference stays in immutable snapshot');
update public.grading_jobs set status='running',stage='validate',lease_token='76543210-5555-4555-8555-555555555555',lease_until=now()+interval '5 minutes' where id='76543210-2222-4222-8222-222222222222';
select lives_ok($$select public.finish_grading_job('76543210-2222-4222-8222-222222222222','76543210-5555-4555-8555-555555555555','{"part":"T","score":{"value":14.75,"max":15,"band":"13–15 分档"},"rubric_version":"KY_EN2_TRANSLATION_V1","prompt_version":"WRITERIGHT_TRANSLATION_V1","schema_version":"3.0.0","model_id":"synthetic"}'::jsonb,'[]'::jsonb)$$,'translation finishes through existing lease-protected report API');
select is((select score from public.grading_reports where job_id='76543210-2222-4222-8222-222222222222'),14.75::numeric,'quarter-point score survives database precision');
select is((select max_score from public.grading_reports where job_id='76543210-2222-4222-8222-222222222222'),15::numeric,'translation maximum stays 15');
select throws_ok($$update public.grading_reports set score=15.25 where job_id='76543210-2222-4222-8222-222222222222'$$,'23514',null,'translation over maximum rejected');
select throws_ok($$update public.grading_reports set part='A' where job_id='76543210-2222-4222-8222-222222222222'$$,'23514',null,'Part A cannot inherit translation maximum');
select lives_ok($$update public.grading_reports set score=null,max_score=null,band=null where job_id='76543210-2222-4222-8222-222222222222'$$,'insufficient evidence report may omit score');
select * from finish();
rollback;
