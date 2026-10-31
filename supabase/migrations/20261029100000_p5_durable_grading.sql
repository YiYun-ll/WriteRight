alter table public.grading_jobs
    add column stage_results jsonb not null default '{}'::jsonb check (jsonb_typeof(stage_results) = 'object'),
    add column next_attempt_at timestamptz not null default now(),
    add column max_attempts integer not null default 3 check (max_attempts between 1 and 10),
    add column completed_at timestamptz;

create index grading_jobs_ready_idx on public.grading_jobs(status, next_attempt_at, lease_until);

alter table public.grading_jobs
    add constraint grading_jobs_job_submission_user_unique unique (id, submission_id, user_id);

alter table public.grading_reports drop constraint grading_reports_job_id_user_id_fkey;
alter table public.grading_reports
    add constraint grading_reports_job_submission_user_fkey
    foreign key (job_id, submission_id, user_id)
    references public.grading_jobs(id, submission_id, user_id) on delete cascade;

create or replace function public.claim_grading_job()
returns setof public.grading_jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
    claimed_id uuid;
begin
    select id into claimed_id
    from public.grading_jobs
    where (
        (status = 'queued' and next_attempt_at <= now())
        or (status = 'running' and lease_until < now())
    ) and attempts < max_attempts
    order by created_at
    limit 1
    for update skip locked;

    if claimed_id is null then
        return;
    end if;

    return query
    update public.grading_jobs
    set status = 'running', attempts = attempts + 1,
        lease_until = now() + interval '2 minutes', heartbeat_at = now(), error_code = null
    where id = claimed_id
    returning *;
end;
$$;

revoke all on function public.claim_grading_job() from public, anon, authenticated;
grant execute on function public.claim_grading_job() to service_role;
