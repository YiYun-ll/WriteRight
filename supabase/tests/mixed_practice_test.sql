begin;
select plan(6);
insert into auth.users(id,email) values ('65432109-1111-4111-8111-111111111111','mixed-synthetic@example.com');
create temporary table mixed_input as select
'{"idemKey":"65432109-2222-4222-8222-222222222222","task":{"id":"65432109-3333-4333-8333-333333333333","part":"T","title":"Synthetic mixed","prompt":"","requirements":[],"revision":1,"confirmed":true},"submission":{"id":"65432109-4444-4444-8444-444444444444","originalText":""}}'::jsonb as input,
jsonb_build_object('source','photo_grading_v2','part','T','originalText','','wordCount',0,'contentHash',repeat('c',64),'task',jsonb_build_object('fingerprint','source-hash'),'textInputs',jsonb_build_object('task','','essay','这是手动输入的译文。'),'images',jsonb_build_array(jsonb_build_object('role','task','page',1,'path','65432109-1111-4111-8111-111111111111/task.jpg','checksum',repeat('a',64)))) as context;
select lives_ok($$select public.enqueue_photo_grading('65432109-1111-4111-8111-111111111111',input,context) from mixed_input$$,'source photos plus typed answer enqueue');
select is((select original_text from essay_submissions where id='65432109-4444-4444-8444-444444444444'),'','no model transcription stored');
select is((select context_json #>> '{textInputs,essay}' from grading_jobs where id='65432109-2222-4222-8222-222222222222'),'这是手动输入的译文。','typed answer kept exactly in immutable context');
select is((select count(*)::integer from submission_assets where submission_id='65432109-4444-4444-8444-444444444444'),0,'typed answer has no artificial photo asset');
select throws_ok($$select public.enqueue_photo_grading('65432109-1111-4111-8111-111111111111',input,jsonb_set(context,'{textInputs,essay}','""'::jsonb)) from mixed_input$$,'P0001','INVALID_PHOTO_CONTEXT','empty typed answer without essay photos rejected');
select throws_ok($$select public.enqueue_photo_grading('65432109-1111-4111-8111-111111111111',input,jsonb_set(context,'{contentHash}',to_jsonb(repeat('d',64)))) from mixed_input$$,'P0001','IDEMPOTENCY_CONFLICT','different snapshot cannot reuse key');
select * from finish();
rollback;
