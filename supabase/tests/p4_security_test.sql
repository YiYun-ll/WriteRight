begin;
select plan(25);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
    ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'p4-a@example.com', '', now(), now(), now()),
    ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'p4-b@example.com', '', now(), now(), now());

select is(
    (select count(*) from public.profiles where id in (
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222'
    )),
    2::bigint,
    'creating auth users creates their profiles'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
    'sub', '11111111-1111-4111-8111-111111111111', 'role', 'authenticated'
)::text, true);

select lives_ok(
    $$insert into public.essay_tasks (id, user_id, part, title, directions)
      values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'A', 'A task', 'Directions')$$,
    'a user can create an owned task'
);
select throws_ok(
    $$insert into public.essay_tasks (id, user_id, part)
      values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222', 'B')$$,
    '42501',
    null,
    'a user cannot create a task for another user'
);
select is((select count(*) from public.essay_tasks), 1::bigint, 'a user can read an owned task');

select set_config('request.jwt.claims', json_build_object(
    'sub', '22222222-2222-4222-8222-222222222222', 'role', 'authenticated'
)::text, true);
select is((select count(*) from public.essay_tasks), 0::bigint, 'another user cannot read the task');
select throws_ok(
    $$insert into public.essay_drafts (id, user_id, task_id, body)
      values ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'cross user')$$,
    '23503',
    null,
    'a user cannot reference another users task'
);

select set_config('request.jwt.claims', json_build_object(
    'sub', '11111111-1111-4111-8111-111111111111', 'role', 'authenticated'
)::text, true);
select lives_ok(
    $$insert into public.essay_drafts (id, user_id, task_id, body)
      values ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Draft')$$,
    'a user can create a draft for an owned task'
);
select lives_ok(
    $$insert into public.essay_submissions (id, user_id, task_id, original_text, word_count, content_hash, task_revision)
      values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Original text', 2, repeat('a', 64), 1)$$,
    'a user can submit an immutable snapshot'
);
select throws_ok(
    $$update public.essay_submissions set original_text = 'Changed' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'$$,
    '42501',
    null,
    'a client cannot mutate submitted original text'
);
select throws_ok(
    $$insert into public.grading_jobs (id, user_id, submission_id, status, stage, idem_key)
      values ('99999999-9999-4999-8999-999999999999', '11111111-1111-4111-8111-111111111111', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'completed', 'done', 'client-forged')$$,
    '42501',
    null,
    'a client cannot forge grading job state'
);

select set_config('request.jwt.claims', json_build_object(
    'sub', '22222222-2222-4222-8222-222222222222', 'role', 'authenticated'
)::text, true);
select is((select count(*) from public.essay_submissions), 0::bigint, 'another user cannot read a submission');
select lives_ok(
    $$update public.essay_tasks set title = 'Stolen' where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'$$,
    'cross-user update is blocked by RLS'
);

select set_config('request.jwt.claims', json_build_object(
    'sub', '11111111-1111-4111-8111-111111111111', 'role', 'authenticated'
)::text, true);
select is((select title from public.essay_tasks where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 'A task', 'cross-user update did not modify the task');
select lives_ok(
    $$insert into public.task_assets (id, user_id, task_id, page_index, storage_path, checksum)
      values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', '11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 0, '11111111-1111-4111-8111-111111111111/task.png', repeat('b', 64))$$,
    'an owned task asset can reference the users private path'
);

select set_config('request.jwt.claims', json_build_object(
    'sub', '22222222-2222-4222-8222-222222222222', 'role', 'authenticated'
)::text, true);
select throws_ok(
    $$insert into public.task_assets (id, user_id, task_id, page_index, storage_path, checksum)
      values ('ffffffff-ffff-4fff-8fff-ffffffffffff', '22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 1, '22222222-2222-4222-8222-222222222222/task.png', repeat('b', 64))$$,
    '23503',
    null,
    'an asset cannot reference another users task'
);

reset role;
select lives_ok(
    $$insert into public.grading_jobs (id, user_id, submission_id, status, stage, idem_key)
      values ('99999999-9999-4999-8999-999999999999', '11111111-1111-4111-8111-111111111111', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'completed', 'done', 'server-job');
      insert into public.grading_reports (id, user_id, submission_id, job_id, part, score, max_score, band, report_json, rubric_version, prompt_version, schema_version, model_id)
      values ('88888888-8888-4888-8888-888888888888', '11111111-1111-4111-8111-111111111111', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', '99999999-9999-4999-8999-999999999999', 'A', 8, 10, 'good', '{}', 'rubric-v1', 'prompt-v1', 'schema-v1', 'deepseek-flash')$$,
    'the trusted server can persist a completed report'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
    'sub', '11111111-1111-4111-8111-111111111111', 'role', 'authenticated'
)::text, true);
select is((select count(*) from public.grading_reports), 1::bigint, 'the owner can read a report');
select throws_ok(
    $$insert into public.grading_reports (id, user_id, submission_id, job_id, part, score, max_score, band, report_json, rubric_version, prompt_version, schema_version, model_id)
      values ('77777777-7777-4777-8777-777777777777', '11111111-1111-4111-8111-111111111111', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', '99999999-9999-4999-8999-999999999999', 'A', 10, 10, 'forged', '{}', 'rubric-v1', 'prompt-v1', 'schema-v1', 'deepseek-flash')$$,
    '42501',
    null,
    'a client cannot forge a score'
);
select lives_ok(
    $$insert into storage.objects (id, bucket_id, name, owner_id)
      values ('66666666-6666-4666-8666-666666666666', 'essay-images', '11111111-1111-4111-8111-111111111111/page.png', '11111111-1111-4111-8111-111111111111')$$,
    'a user can add an image under the owned prefix'
);
select is((select count(*) from storage.objects), 1::bigint, 'the owner can read private image metadata');

select set_config('request.jwt.claims', json_build_object(
    'sub', '22222222-2222-4222-8222-222222222222', 'role', 'authenticated'
)::text, true);
select is((select count(*) from public.grading_reports), 0::bigint, 'another user cannot read the report');
select is((select count(*) from storage.objects), 0::bigint, 'another user cannot read private image metadata');
select throws_ok(
    $$insert into storage.objects (id, bucket_id, name, owner_id)
      values ('55555555-5555-4555-8555-555555555555', 'essay-images', '11111111-1111-4111-8111-111111111111/stolen.png', '22222222-2222-4222-8222-222222222222')$$,
    '42501',
    null,
    'a user cannot write into another users image prefix'
);

reset role;
select is((select public from storage.buckets where id = 'essay-images'), false, 'the essay image bucket is private');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok(
    'select * from public.essay_tasks',
    '42501',
    null,
    'anonymous clients cannot access user tasks'
);

select * from finish();
rollback;
