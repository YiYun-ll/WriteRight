-- Add opaque, account-scoped notebook records to the existing versioned sync stream.
alter table public.sync_log drop constraint sync_log_entity_type_check;
alter table public.sync_log add constraint sync_log_entity_type_check check (entity_type in ('draft', 'favorite', 'submission', 'report', 'record'));

create or replace function public.apply_sync_operation(op jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    uid uuid := auth.uid();
    v_type text := op->>'entity_type';
    v_id uuid := (op->>'entity_id')::uuid;
    v_operation text := op->>'operation';
    v_base bigint := coalesce((op->>'base_revision')::bigint, 0);
    v_payload text := coalesce(op->>'payload', '');
    current public.sync_heads%rowtype;
    v_revision bigint;
    v_log bigint;
begin
    if uid is null then raise exception 'AUTH_REQUIRED'; end if;
    if v_type not in ('draft', 'favorite', 'submission', 'report', 'record')
        or v_operation not in ('upsert', 'delete')
        or char_length(v_payload) > 200000 then
        raise exception 'INVALID_SYNC_OP';
    end if;
    select * into current from public.sync_heads
    where user_id = uid and entity_type = v_type and entity_id = v_id;
    if v_operation = 'delete' then
        if not found or current.deleted then
            return jsonb_build_object('status', 'deleted', 'server_revision', case when found then current.server_revision else 0 end);
        end if;
        if current.revision <> v_base then
            return jsonb_build_object('status', 'conflict', 'server', jsonb_build_object(
                'entity_type', current.entity_type, 'entity_id', current.entity_id, 'operation', 'upsert',
                'revision', current.revision, 'server_revision', current.server_revision, 'payload', current.payload));
        end if;
        v_revision := current.revision + 1;
        v_payload := current.payload;
    else
        if found and current.deleted then
            return jsonb_build_object('status', 'deleted', 'server_revision', current.server_revision);
        end if;
        if found and current.payload = v_payload then
            return jsonb_build_object('status', 'applied', 'revision', current.revision, 'server_revision', current.server_revision);
        end if;
        if v_type in ('submission', 'report') and found then
            return jsonb_build_object('status', 'applied', 'revision', current.revision, 'server_revision', current.server_revision);
        end if;
        if coalesce(current.revision, 0) <> v_base then
            return jsonb_build_object('status', 'conflict', 'server', jsonb_build_object(
                'entity_type', current.entity_type, 'entity_id', current.entity_id, 'operation', 'upsert',
                'revision', current.revision, 'server_revision', current.server_revision, 'payload', current.payload));
        end if;
        v_revision := coalesce(current.revision, 0) + 1;
    end if;
    insert into public.sync_log (user_id, entity_type, entity_id, operation, revision, payload)
    values (uid, v_type, v_id, v_operation, v_revision, v_payload)
    returning server_revision into v_log;
    insert into public.sync_heads (user_id, entity_type, entity_id, revision, deleted, payload, server_revision)
    values (uid, v_type, v_id, v_revision, v_operation = 'delete', v_payload, v_log)
    on conflict (user_id, entity_type, entity_id) do update
    set revision = excluded.revision, deleted = excluded.deleted, payload = excluded.payload, server_revision = excluded.server_revision;
    if v_operation = 'delete' and v_type in ('draft', 'favorite', 'submission') then
        insert into public.sync_tombstones (id, user_id, entity_type, entity_id, server_revision)
        values (gen_random_uuid(), uid, v_type, v_id, v_log)
        on conflict (user_id, entity_type, entity_id) do update
        set deleted_at = now(), server_revision = excluded.server_revision;
    end if;
    if v_operation = 'delete' then
        return jsonb_build_object('status', 'deleted', 'server_revision', v_log);
    end if;
    return jsonb_build_object('status', 'applied', 'revision', v_revision, 'server_revision', v_log);
end;
$$;

