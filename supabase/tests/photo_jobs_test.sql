begin;
select plan(7);
select ok(not has_function_privilege('authenticated','public.enqueue_photo_grading(uuid,jsonb,jsonb)','execute'), 'photo enqueue is not callable by authenticated clients');
select ok(has_function_privilege('service_role','public.enqueue_photo_grading(uuid,jsonb,jsonb)','execute'), 'photo enqueue is service only');
insert into auth.users(id,email) values ('22222222-2222-4222-8222-222222222222','photo-test@example.com');
create temporary table photo_input as select
'{"idemKey":"33333333-3333-4333-8333-333333333333","task":{"id":"44444444-4444-4444-8444-444444444444","part":"A","title":"Photo","prompt":"","requirements":[],"revision":1,"confirmed":true},"submission":{"id":"55555555-5555-4555-8555-555555555555","originalText":""}}'::jsonb as input,
jsonb_build_object('source','photo_grading_v2','part','A','originalText','','wordCount',0,'contentHash',repeat('c',64),'task',jsonb_build_object('fingerprint','task-hash'), 'images', jsonb_build_array(jsonb_build_object('role','task','page',1,'path','22222222-2222-4222-8222-222222222222/task.jpg','checksum',repeat('a',64)),jsonb_build_object('role','essay','page',1,'path','22222222-2222-4222-8222-222222222222/essay.jpg','checksum',repeat('b',64)))) as context;
select lives_ok($$select public.enqueue_photo_grading('22222222-2222-4222-8222-222222222222', input, context) from photo_input$$,'photo job enqueues atomically');
select is((select original_text from public.essay_submissions where id='55555555-5555-4555-8555-555555555555'), '', 'no transcript stored');
select is((select count(*)::integer from public.submission_assets where submission_id='55555555-5555-4555-8555-555555555555'),1,'essay source registered');
select lives_ok($$select public.enqueue_photo_grading('22222222-2222-4222-8222-222222222222', input, context) from photo_input$$,'duplicate request stays idempotent');
select throws_ok($$select public.enqueue_photo_grading('22222222-2222-4222-8222-222222222222', input, jsonb_set(context,'{images,0,path}','"another-user/task.jpg"'::jsonb)) from photo_input$$,'P0001','INVALID_PHOTO_CONTEXT','cross-user photo path rejected');
select * from finish();
rollback;
