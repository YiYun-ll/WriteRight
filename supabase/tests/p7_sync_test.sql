begin;
select plan(7);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
    ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'p7-a@example.com', '', now(), now(), now()),
    ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'p7-b@example.com', '', now(), now(), now());

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-4111-8111-111111111111', 'role', 'authenticated')::text, true);

select is(
    (select public.apply_sync_operation(jsonb_build_object(
        'entity_type', 'draft', 'entity_id', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'operation', 'upsert', 'base_revision', 0, 'payload', '{"body":"one"}'
    ))->>'status'),
    'applied',
    'the owner can upload a new draft'
);
select is(
    (select public.apply_sync_operation(jsonb_build_object(
        'entity_type', 'draft', 'entity_id', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'operation', 'upsert', 'base_revision', 0, 'payload', '{"body":"two"}'
    ))->>'status'),
    'conflict',
    'a stale base revision does not overwrite'
);
select is(
    (select public.apply_sync_operation(jsonb_build_object(
        'entity_type', 'draft', 'entity_id', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'operation', 'delete', 'base_revision', 1, 'payload', ''
    ))->>'status'),
    'deleted',
    'delete writes a tombstone for the accepted revision'
);
select is(
    (select public.apply_sync_operation(jsonb_build_object(
        'entity_type', 'draft', 'entity_id', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'operation', 'upsert', 'base_revision', 1, 'payload', '{"body":"back"}'
    ))->>'status'),
    'deleted',
    'a later upsert cannot resurrect the deleted draft'
);

select set_config('request.jwt.claims', json_build_object('sub', '22222222-2222-4222-8222-222222222222', 'role', 'authenticated')::text, true);
select is((select count(*) from public.sync_heads), 0::bigint, 'another user cannot read the first head');
select is((select public.sync_changes(0)), '[]'::jsonb, 'another user does not receive the first log');

select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-4111-8111-111111111111', 'role', 'authenticated')::text, true);
select is(jsonb_array_length(public.sync_changes(0)), 2, 'the owner can pull the upsert and the delete');

select * from finish();
rollback;
