-- Photo snapshots use the existing durable queue and private Storage ownership rules.
-- No OCR/transcript is written; original_text is empty and source_sentences_json is [].
create or replace function public.enqueue_photo_grading(p_user_id uuid, p_input jsonb, p_context jsonb)
returns setof public.grading_jobs
language plpgsql security definer set search_path = '' as $$
declare j public.grading_jobs; item jsonb; v_task_id uuid;
begin
    if p_context->>'source' is distinct from 'photo_grading_v2'
       or p_context->>'originalText' is distinct from ''
       or jsonb_typeof(p_context->'images') is distinct from 'array'
       or jsonb_array_length(p_context->'images') not between 1 and 8 then
        raise exception 'INVALID_PHOTO_CONTEXT';
    end if;
    -- Validate the incoming snapshot before enqueue, including on idempotent retries.
    for item in select value from jsonb_array_elements(p_context->'images') loop
        if coalesce(item->>'role','') not in ('task','essay') or coalesce((item->>'page')::integer,0) not between 1 and 4
           or split_part(coalesce(item->>'path',''), '/',1) <> p_user_id::text
           or position('..' in item->>'path') > 0 or coalesce(item->>'checksum','') !~ '^[0-9a-f]{64}$' then
            raise exception 'INVALID_PHOTO_CONTEXT';
        end if;
    end loop;
    if not exists(select 1 from jsonb_array_elements(p_context->'images') x where x->>'role'='essay') then
        raise exception 'INVALID_PHOTO_CONTEXT';
    end if;
    select * into j from public.enqueue_grading(p_user_id, p_input, p_context);
    select task_id into v_task_id from public.essay_submissions where id=j.submission_id and user_id=p_user_id;
    for item in select value from jsonb_array_elements(j.context_json->'images') loop
        if item->>'role'='task' then
            insert into public.task_assets(id,user_id,task_id,page_index,storage_path,checksum)
            values(gen_random_uuid(),p_user_id,v_task_id,(item->>'page')::integer-1,item->>'path',item->>'checksum')
            on conflict(task_id,page_index) do nothing;
        else
            insert into public.submission_assets(id,user_id,submission_id,page_index,storage_path,checksum)
            values(gen_random_uuid(),p_user_id,j.submission_id,(item->>'page')::integer-1,item->>'path',item->>'checksum')
            on conflict(submission_id,page_index) do nothing;
        end if;
    end loop;
    return query select * from public.grading_jobs where id=j.id;
end;
$$;
revoke all on function public.enqueue_photo_grading(uuid,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.enqueue_photo_grading(uuid,jsonb,jsonb) to service_role;
