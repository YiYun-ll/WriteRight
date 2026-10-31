begin;
select plan(5);
insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('55555555-5555-4555-8555-555555555555','authenticated','authenticated','notebook-a@example.com','',now(),now(),now()),
('66666666-6666-4666-8666-666666666666','authenticated','authenticated','notebook-b@example.com','',now(),now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated"}',true);
select is(public.apply_sync_operation('{"entity_type":"record","entity_id":"77777777-7777-4777-8777-777777777777","operation":"upsert","base_revision":0,"payload":"{\"title\":\"A small note\"}"}')->>'status','applied','records can be synced');
select is(jsonb_array_length(public.sync_changes(0)),1,'record returns to its owner');
select set_config('request.jwt.claims','{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated"}',true);
select is(public.sync_changes(0),'[]'::jsonb,'records are isolated between accounts');
select set_config('request.jwt.claims','{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated"}',true);
select is(public.apply_sync_operation('{"entity_type":"record","entity_id":"77777777-7777-4777-8777-777777777777","operation":"delete","base_revision":1}')->>'status','deleted','record deletion is versioned');
select is(public.apply_sync_operation('{"entity_type":"record","entity_id":"77777777-7777-4777-8777-777777777777","operation":"upsert","base_revision":1,"payload":"stale"}')->>'status','deleted','old records cannot resurrect');
select * from finish();
rollback;
