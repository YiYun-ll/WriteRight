create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    nickname text check (char_length(nickname) <= 80),
    settings_json jsonb not null default '{}'::jsonb check (jsonb_typeof(settings_json) = 'object'),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.essay_tasks (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    part text not null check (part in ('A', 'B')),
    title text not null default '',
    genre text,
    prompt_type text,
    directions text not null default '',
    parsed_json jsonb not null default '{}'::jsonb check (jsonb_typeof(parsed_json) = 'object'),
    confirmed_revision bigint,
    revision bigint not null default 1 check (revision >= 1),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    unique (id, user_id),
    check (confirmed_revision is null or confirmed_revision between 1 and revision)
);

create table public.task_assets (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    task_id uuid not null,
    page_index integer not null check (page_index >= 0),
    storage_path text not null,
    checksum text not null check (checksum ~ '^[0-9a-f]{64}$'),
    created_at timestamptz not null default now(),
    foreign key (task_id, user_id) references public.essay_tasks(id, user_id) on delete cascade,
    unique (task_id, page_index),
    unique (id, user_id),
    check (split_part(storage_path, '/', 1) = user_id::text),
    check (position('..' in storage_path) = 0)
);

create table public.essay_drafts (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    task_id uuid not null,
    body text not null default '',
    base_revision bigint not null default 1 check (base_revision >= 1),
    revision bigint not null default 1 check (revision >= 1),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    foreign key (task_id, user_id) references public.essay_tasks(id, user_id) on delete cascade,
    unique (id, user_id)
);

create table public.essay_submissions (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    task_id uuid not null,
    original_text text not null,
    word_count integer not null check (word_count >= 0),
    content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
    task_revision bigint not null check (task_revision >= 1),
    submitted_at timestamptz not null default now(),
    deleted_at timestamptz,
    foreign key (task_id, user_id) references public.essay_tasks(id, user_id) on delete cascade,
    unique (id, user_id)
);

create table public.submission_assets (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    submission_id uuid not null,
    page_index integer not null check (page_index >= 0),
    storage_path text not null,
    checksum text not null check (checksum ~ '^[0-9a-f]{64}$'),
    created_at timestamptz not null default now(),
    foreign key (submission_id, user_id) references public.essay_submissions(id, user_id) on delete cascade,
    unique (submission_id, page_index),
    unique (id, user_id),
    check (split_part(storage_path, '/', 1) = user_id::text),
    check (position('..' in storage_path) = 0)
);

create table public.grading_jobs (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    submission_id uuid not null,
    status text not null check (status in ('queued', 'running', 'completed', 'failed')),
    stage text not null check (stage in ('evaluate', 'correct', 'rewrite', 'validate', 'done')),
    attempts integer not null default 0 check (attempts >= 0),
    idem_key text not null check (char_length(idem_key) between 1 and 200),
    lease_until timestamptz,
    heartbeat_at timestamptz,
    error_code text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    foreign key (submission_id, user_id) references public.essay_submissions(id, user_id) on delete cascade,
    unique (user_id, idem_key),
    unique (id, user_id)
);

create table public.grading_reports (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    submission_id uuid not null,
    job_id uuid not null,
    part text not null check (part in ('A', 'B')),
    score numeric(4, 1),
    max_score numeric(4, 1),
    band text,
    report_json jsonb not null check (jsonb_typeof(report_json) = 'object'),
    rubric_version text not null,
    prompt_version text not null,
    schema_version text not null,
    model_id text not null,
    created_at timestamptz not null default now(),
    foreign key (submission_id, user_id) references public.essay_submissions(id, user_id) on delete cascade,
    foreign key (job_id, user_id) references public.grading_jobs(id, user_id) on delete cascade,
    unique (job_id),
    unique (id, user_id),
    check (
        (score is null and max_score is null and band is null)
        or (part = 'A' and max_score = 10 and score between 0 and 10 and band is not null)
        or (part = 'B' and max_score = 15 and score between 0 and 15 and band is not null)
    )
);

create table public.favorite_expressions (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    source_report_id uuid not null,
    expression text not null check (char_length(expression) between 1 and 1000),
    normalized_text text not null check (char_length(normalized_text) between 1 and 1000),
    meaning text not null default '',
    usage text not null default '',
    category text not null default '',
    original_sentence text not null default '',
    created_at timestamptz not null default now(),
    deleted_at timestamptz,
    foreign key (source_report_id, user_id) references public.grading_reports(id, user_id) on delete cascade,
    unique (user_id, normalized_text),
    unique (id, user_id)
);

create table public.sync_tombstones (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    entity_type text not null check (entity_type in ('task', 'draft', 'submission', 'favorite')),
    entity_id uuid not null,
    deleted_at timestamptz not null default now(),
    server_revision bigint not null check (server_revision >= 1),
    unique (user_id, entity_type, entity_id)
);

create table public.grading_usage (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    job_id uuid not null,
    model_id text not null,
    prompt_tokens integer not null check (prompt_tokens >= 0),
    completion_tokens integer not null check (completion_tokens >= 0),
    estimated_cost numeric(12, 6) check (estimated_cost >= 0),
    created_at timestamptz not null default now(),
    foreign key (job_id, user_id) references public.grading_jobs(id, user_id) on delete cascade
);

create index essay_tasks_user_time_idx on public.essay_tasks(user_id, updated_at desc);
create index essay_drafts_user_time_idx on public.essay_drafts(user_id, updated_at desc);
create index essay_submissions_user_time_idx on public.essay_submissions(user_id, submitted_at desc);
create index grading_jobs_status_lease_idx on public.grading_jobs(status, lease_until);
create index grading_reports_submission_time_idx on public.grading_reports(submission_id, created_at desc);
create index sync_tombstones_user_revision_idx on public.sync_tombstones(user_id, server_revision);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id) values (new.id);
    return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger essay_tasks_updated_at before update on public.essay_tasks
for each row execute function public.set_updated_at();
create trigger essay_drafts_updated_at before update on public.essay_drafts
for each row execute function public.set_updated_at();
create trigger grading_jobs_updated_at before update on public.grading_jobs
for each row execute function public.set_updated_at();

revoke all on public.profiles, public.essay_tasks, public.task_assets,
    public.essay_drafts, public.essay_submissions, public.submission_assets,
    public.grading_jobs, public.grading_reports, public.favorite_expressions,
    public.sync_tombstones, public.grading_usage from anon, authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.essay_tasks to authenticated;
grant select, insert, delete on public.task_assets to authenticated;
grant select, insert, update, delete on public.essay_drafts to authenticated;
grant select, insert on public.essay_submissions to authenticated;
grant select, insert, delete on public.submission_assets to authenticated;
grant select on public.grading_jobs, public.grading_reports, public.sync_tombstones,
    public.grading_usage to authenticated;
grant select, insert, update, delete on public.favorite_expressions to authenticated;

alter table public.profiles enable row level security;
alter table public.essay_tasks enable row level security;
alter table public.task_assets enable row level security;
alter table public.essay_drafts enable row level security;
alter table public.essay_submissions enable row level security;
alter table public.submission_assets enable row level security;
alter table public.grading_jobs enable row level security;
alter table public.grading_reports enable row level security;
alter table public.favorite_expressions enable row level security;
alter table public.sync_tombstones enable row level security;
alter table public.grading_usage enable row level security;

create policy "profiles_select_own" on public.profiles for select to authenticated
using ((select auth.uid()) = id);
create policy "profiles_insert_own" on public.profiles for insert to authenticated
with check ((select auth.uid()) = id);
create policy "profiles_update_own" on public.profiles for update to authenticated
using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "tasks_select_own" on public.essay_tasks for select to authenticated
using ((select auth.uid()) = user_id);
create policy "tasks_insert_own" on public.essay_tasks for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "tasks_update_own" on public.essay_tasks for update to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "tasks_delete_own" on public.essay_tasks for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "task_assets_select_own" on public.task_assets for select to authenticated
using ((select auth.uid()) = user_id);
create policy "task_assets_insert_own" on public.task_assets for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "task_assets_delete_own" on public.task_assets for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "drafts_select_own" on public.essay_drafts for select to authenticated
using ((select auth.uid()) = user_id);
create policy "drafts_insert_own" on public.essay_drafts for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "drafts_update_own" on public.essay_drafts for update to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "drafts_delete_own" on public.essay_drafts for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "submissions_select_own" on public.essay_submissions for select to authenticated
using ((select auth.uid()) = user_id);
create policy "submissions_insert_own" on public.essay_submissions for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "submission_assets_select_own" on public.submission_assets for select to authenticated
using ((select auth.uid()) = user_id);
create policy "submission_assets_insert_own" on public.submission_assets for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "submission_assets_delete_own" on public.submission_assets for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "jobs_select_own" on public.grading_jobs for select to authenticated
using ((select auth.uid()) = user_id);
create policy "reports_select_own" on public.grading_reports for select to authenticated
using ((select auth.uid()) = user_id);
create policy "favorites_select_own" on public.favorite_expressions for select to authenticated
using ((select auth.uid()) = user_id);
create policy "favorites_insert_own" on public.favorite_expressions for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "favorites_update_own" on public.favorite_expressions for update to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "favorites_delete_own" on public.favorite_expressions for delete to authenticated
using ((select auth.uid()) = user_id);
create policy "tombstones_select_own" on public.sync_tombstones for select to authenticated
using ((select auth.uid()) = user_id);
create policy "usage_select_own" on public.grading_usage for select to authenticated
using ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('essay-images', 'essay-images', false, 10485760, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do update set public = false, file_size_limit = 10485760,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "essay_images_select_own" on storage.objects for select to authenticated
using (bucket_id = 'essay-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "essay_images_insert_own" on storage.objects for insert to authenticated
with check (bucket_id = 'essay-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "essay_images_update_own" on storage.objects for update to authenticated
using (bucket_id = 'essay-images' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'essay-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "essay_images_delete_own" on storage.objects for delete to authenticated
using (bucket_id = 'essay-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
