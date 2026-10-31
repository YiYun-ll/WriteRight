-- The user ID comes from the verified Edge session; these RPCs are service-only.
alter table public.grading_jobs add column context_json jsonb not null default '{}'::jsonb;
alter table public.grading_jobs add column lease_token uuid;
alter table public.grading_usage add column attempt_key text;
create unique index grading_usage_attempt_idx on public.grading_usage(job_id, attempt_key);

update public.grading_jobs set status = 'failed', error_code = 'SNAPSHOT_MISSING'
where status in ('queued', 'running') and context_json = '{}'::jsonb;

create function public.enqueue_grading(p_user_id uuid, p_input jsonb, p_context jsonb)
returns setof public.grading_jobs language plpgsql security definer set search_path = '' as $$
declare
    task_id uuid := (p_input #>> '{task,id}')::uuid;
    v_submission_id uuid := (p_input #>> '{submission,id}')::uuid;
    idem text := p_input ->> 'idemKey';
    task_owner uuid;
    old_submission public.essay_submissions;
    old_job public.grading_jobs;
begin
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text || idem, 0));
    select * into old_job from public.grading_jobs j where j.user_id = p_user_id and j.idem_key = idem for update;
    if found then
        if old_job.submission_id <> v_submission_id
           or old_job.context_json ->> 'contentHash' <> p_context ->> 'contentHash'
           or old_job.context_json -> 'task' is distinct from p_context -> 'task'
           or old_job.context_json -> 'part' is distinct from p_context -> 'part' then
            raise exception 'IDEMPOTENCY_CONFLICT';
        end if;
        if old_job.status = 'failed' and old_job.error_code <> 'SNAPSHOT_MISSING' then
            update public.grading_jobs set status = 'queued', attempts = 0, error_code = null,
                next_attempt_at = now(), lease_until = null, lease_token = null
            where id = old_job.id;
        end if;
        return query select * from public.grading_jobs where id = old_job.id;
        return;
    end if;
    if (select count(*) from public.grading_jobs j where j.user_id = p_user_id and j.created_at > now() - interval '10 minutes') >= 10 then
        raise exception 'RATE_LIMITED';
    end if;
    insert into public.essay_tasks(id, user_id, part, title, directions, parsed_json, revision, confirmed_revision)
    values (task_id, p_user_id, p_input #>> '{task,part}', coalesce(p_input #>> '{task,title}', ''),
        p_input #>> '{task,prompt}', jsonb_build_object('requirements', p_input #> '{task,requirements}'),
        (p_input #>> '{task,revision}')::bigint,
        case when (p_input #>> '{task,confirmed}')::boolean then (p_input #>> '{task,revision}')::bigint else null end)
    on conflict (id) do nothing;
    select t.user_id into task_owner from public.essay_tasks t where t.id = task_id for update;
    if task_owner is distinct from p_user_id then raise exception 'TASK_OWNER_MISMATCH'; end if;
    -- Preserve the latest editable task. Every job keeps its own immutable task snapshot below.
    update public.essay_tasks set title = coalesce(p_input #>> '{task,title}', ''),
        directions = p_input #>> '{task,prompt}', part = p_input #>> '{task,part}',
        parsed_json = jsonb_build_object('requirements', p_input #> '{task,requirements}'),
        revision = (p_input #>> '{task,revision}')::bigint,
        confirmed_revision = case when (p_input #>> '{task,confirmed}')::boolean then (p_input #>> '{task,revision}')::bigint else null end
    where id = task_id and revision <= (p_input #>> '{task,revision}')::bigint;

    insert into public.essay_submissions(id, user_id, task_id, original_text, word_count, content_hash, task_revision)
    values (v_submission_id, p_user_id, task_id, p_context ->> 'originalText',
        (p_context ->> 'wordCount')::integer, p_context ->> 'contentHash', (p_input #>> '{task,revision}')::bigint)
    on conflict (id) do nothing;
    select * into old_submission from public.essay_submissions s where s.id = v_submission_id for update;
    if old_submission.user_id is distinct from p_user_id or old_submission.task_id <> task_id
       or old_submission.content_hash <> p_context ->> 'contentHash'
       or old_submission.task_revision <> (p_input #>> '{task,revision}')::bigint then
        raise exception 'SUBMISSION_CONFLICT';
    end if;
    if exists(select 1 from public.grading_jobs j where j.submission_id = v_submission_id) then
        raise exception 'SUBMISSION_CONFLICT';
    end if;
    return query insert into public.grading_jobs(id, user_id, submission_id, status, stage, idem_key, context_json)
    values (idem::uuid, p_user_id, v_submission_id, 'queued', 'evaluate', idem, p_context) returning *;
end;
$$;

create or replace function public.claim_grading_job()
returns setof public.grading_jobs language plpgsql security definer set search_path = '' as $$
declare claimed_id uuid;
begin
    update public.grading_jobs set status = 'failed', error_code = 'RETRY_EXHAUSTED', lease_until = null, lease_token = null
    where status = 'running' and lease_until < now() and attempts >= max_attempts;
    select id into claimed_id from public.grading_jobs
    where ((status = 'queued' and next_attempt_at <= now()) or (status = 'running' and lease_until < now()))
      and attempts < max_attempts
    order by created_at limit 1 for update skip locked;
    if claimed_id is null then return; end if;
    return query update public.grading_jobs set status = 'running', attempts = attempts + 1,
        lease_until = now() + interval '2 minutes', lease_token = gen_random_uuid(), heartbeat_at = now(), error_code = null
    where id = claimed_id returning *;
end;
$$;

create function public.advance_grading_job(p_job_id uuid, p_lease_token uuid, p_stage text, p_value jsonb, p_next text)
returns setof public.grading_jobs language plpgsql security definer set search_path = '' as $$
begin
    return query update public.grading_jobs set stage = p_next,
        stage_results = stage_results || jsonb_build_object(p_stage, p_value),
        heartbeat_at = now(), lease_until = now() + interval '2 minutes'
    where id = p_job_id and lease_token = p_lease_token and status = 'running' and lease_until > now()
    returning *;
    if not found then raise exception 'LEASE_LOST'; end if;
end;
$$;

create function public.finish_grading_job(p_job_id uuid, p_lease_token uuid, p_report jsonb, p_sentences jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare j public.grading_jobs;
begin
    select * into j from public.grading_jobs where id = p_job_id and lease_token = p_lease_token
        and status = 'running' and lease_until > now() for update;
    if not found then raise exception 'LEASE_LOST'; end if;
    insert into public.grading_reports(id, user_id, submission_id, job_id, part, score, max_score, band,
        report_json, source_sentences_json, rubric_version, prompt_version, schema_version, model_id)
    values (gen_random_uuid(), j.user_id, j.submission_id, j.id, p_report ->> 'part',
        (p_report #>> '{score,value}')::numeric,
        case when p_report #>> '{score,value}' is null then null else (p_report #>> '{score,max}')::numeric end,
        p_report #>> '{score,band}', p_report, p_sentences,
        p_report ->> 'rubric_version', p_report ->> 'prompt_version', p_report ->> 'schema_version', p_report ->> 'model_id')
    on conflict (job_id) do nothing;
    update public.grading_jobs set status = 'completed', stage = 'done', completed_at = now(),
        lease_until = null, lease_token = null, error_code = null where id = j.id;
end;
$$;

create function public.fail_grading_job(p_job_id uuid, p_lease_token uuid, p_code text, p_retryable boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
    update public.grading_jobs set status = case when p_retryable and attempts < max_attempts then 'queued' else 'failed' end,
        error_code = p_code, next_attempt_at = now() + make_interval(secs => least(60, power(2, attempts)::integer * 5)),
        lease_until = null, lease_token = null
    where id = p_job_id and lease_token = p_lease_token and status = 'running';
    if not found then raise exception 'LEASE_LOST'; end if;
end;
$$;

create function public.protect_grading_context() returns trigger language plpgsql set search_path = '' as $$
begin
    if old.user_id <> new.user_id or old.submission_id <> new.submission_id or old.idem_key <> new.idem_key
       or old.context_json <> new.context_json then raise exception 'IMMUTABLE_JOB_CONTEXT'; end if;
    return new;
end;
$$;
create trigger immutable_grading_context before update on public.grading_jobs for each row execute function public.protect_grading_context();

revoke all on function public.enqueue_grading(uuid, jsonb, jsonb), public.advance_grading_job(uuid, uuid, text, jsonb, text),
    public.finish_grading_job(uuid, uuid, jsonb, jsonb), public.fail_grading_job(uuid, uuid, text, boolean)
    from public, anon, authenticated;
grant execute on function public.enqueue_grading(uuid, jsonb, jsonb), public.advance_grading_job(uuid, uuid, text, jsonb, text),
    public.finish_grading_job(uuid, uuid, jsonb, jsonb), public.fail_grading_job(uuid, uuid, text, boolean) to service_role;
