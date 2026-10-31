begin;
select plan(16);
insert into auth.users(id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'p5-a@example.com', '', now(), now(), now()),
('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'p5-b@example.com', '', now(), now(), now());

-- Keep pre-existing local jobs out of this transaction's worker claim; all changes roll back.
update public.grading_jobs set next_attempt_at = now() + interval '1 day', lease_until = now() + interval '1 day';

create function pg_temp.input(k text default 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', s text default 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
returns jsonb language sql as $$select jsonb_build_object('idemKey', k, 'task', jsonb_build_object(
'id', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'part', 'A', 'title', 'Synthetic', 'prompt', 'Original directions',
'requirements', '[]'::jsonb, 'revision', 1, 'confirmed', true), 'submission', jsonb_build_object('id', s, 'originalText', 'I has a book.'))$$;
create function pg_temp.context() returns jsonb language sql as $$select jsonb_build_object(
'part', 'A', 'task', jsonb_build_object('prompt', 'Original directions', 'requirements', '[]'::jsonb, 'revision', 1, 'confirmed', true),
'originalText', 'I has a book.', 'wordCount', 4, 'contentHash', repeat('a',64), 'sentences', '[]'::jsonb,
'modelID', 'deepseek-flash', 'rubricVersion', 'KY_EN2_A_V1', 'promptVersion', 'TEST', 'mode', 'full')$$;

select lives_ok($$select public.enqueue_grading('11111111-1111-4111-8111-111111111111', pg_temp.input(), pg_temp.context())$$, 'atomic enqueue succeeds');
select lives_ok($$select public.enqueue_grading('11111111-1111-4111-8111-111111111111', pg_temp.input(), pg_temp.context())$$, 'same idempotency key is replayable');
select is((select count(*) from public.grading_jobs where user_id = '11111111-1111-4111-8111-111111111111'), 1::bigint, 'replay creates no duplicate paid task');
select throws_ok($$select public.enqueue_grading('11111111-1111-4111-8111-111111111111', pg_temp.input('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','dddddddd-dddd-4ddd-8ddd-dddddddddddd'), pg_temp.context())$$,
'P0001', 'IDEMPOTENCY_CONFLICT', 'a key cannot be reused for another submission');
select throws_ok($$select public.enqueue_grading('22222222-2222-4222-8222-222222222222', pg_temp.input('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','dddddddd-dddd-4ddd-8ddd-dddddddddddd'), pg_temp.context())$$,
'P0001', 'TASK_OWNER_MISMATCH', 'service RPC cannot take another users task');
select is((select count(*) from public.essay_submissions where user_id = '11111111-1111-4111-8111-111111111111'), 1::bigint, 'failed enqueue leaves no orphan submission');
update public.essay_tasks set directions = 'Later task edit', revision = 2 where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
select is((select context_json #>> '{task,prompt}' from public.grading_jobs where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 'Original directions', 'a queued job keeps its accepted task revision');
select throws_ok($$update public.grading_jobs set context_json = '{}'::jsonb where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'$$, 'P0001', 'IMMUTABLE_JOB_CONTEXT', 'accepted task context cannot be edited');

set local role authenticated;
select throws_ok($$select public.enqueue_grading('11111111-1111-4111-8111-111111111111', '{}'::jsonb, '{}'::jsonb)$$,
'42501', null, 'clients cannot call the privileged enqueue RPC');
reset role;
create temporary table lease as select * from public.claim_grading_job();
select ok((select lease_token is not null from lease), 'claim creates a fencing token');
select throws_ok($$select public.advance_grading_job('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','99999999-9999-4999-8999-999999999999','evaluate','{}','correct')$$,
'P0001', 'LEASE_LOST', 'a stale worker cannot advance state');
select lives_ok($$select public.advance_grading_job((select id from lease), (select lease_token from lease),'evaluate','{"validated":true}','correct')$$,
'current worker saves its stage');
select is((select stage from public.grading_jobs where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 'correct', 'stage progress is durable');
update public.grading_jobs set lease_until = now() - interval '1 second', max_attempts = attempts where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
select count(*) from public.claim_grading_job();
select is((select status from public.grading_jobs where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'), 'failed', 'an expired final lease becomes terminal instead of hanging');

select public.enqueue_grading('11111111-1111-4111-8111-111111111111',pg_temp.input('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','dddddddd-dddd-4ddd-8ddd-dddddddddddd'), pg_temp.context());
truncate lease;
insert into lease select * from public.claim_grading_job();
select lives_ok($$select public.finish_grading_job((select id from lease), (select lease_token from lease),
'{"part":"A","score":{"value":7,"max":10,"band":"良好"},"rubric_version":"TEST","prompt_version":"TEST","schema_version":"1.0.0","model_id":"deepseek-flash"}'::jsonb,'[]'::jsonb)$$,
'report and completed status commit together');
select ok((select j.status = 'completed' and r.job_id = j.id from public.grading_jobs j join public.grading_reports r on r.job_id = j.id where j.id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
'a completed task has exactly its owned report');
select * from finish();
rollback;
