-- The desk cat's growth follows the account. Clients never write the row directly: merge_companion
-- unions day lists, keeps the larger per-device counter and the newest rename, so retries and
-- concurrent devices can only add growth, never remove it.
create table public.companion_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    growth jsonb not null,
    updated_at timestamptz not null default now()
);

alter table public.companion_profiles enable row level security;
revoke all on public.companion_profiles from anon, authenticated;
grant select on public.companion_profiles to authenticated;
create policy "companion_profiles_select_own" on public.companion_profiles for select to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.companion_days(a jsonb, b jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
    select coalesce(jsonb_agg(day order by day), '[]'::jsonb)
    from (
        select jsonb_array_elements_text(coalesce(a, '[]'::jsonb)) as day
        union
        select jsonb_array_elements_text(coalesce(b, '[]'::jsonb))
    ) days;
$$;

create or replace function public.companion_counts(a jsonb, b jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
    select coalesce(jsonb_object_agg(key, largest), '{}'::jsonb)
    from (
        select key, max(value::bigint) as largest
        from (
            select key, value from jsonb_each_text(coalesce(a, '{}'::jsonb))
            union all
            select key, value from jsonb_each_text(coalesce(b, '{}'::jsonb))
        ) counts
        group by key
    ) merged;
$$;

create or replace function public.merge_companion(incoming jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    uid uuid := auth.uid();
    existing jsonb;
    merged jsonb;
    field text;
    incoming_renamed numeric;
    existing_renamed numeric;
begin
    if uid is null then raise exception 'AUTH_REQUIRED'; end if;
    if incoming is null or jsonb_typeof(incoming) <> 'object' or octet_length(incoming::text) > 65536
        or jsonb_typeof(incoming->'metAt') is distinct from 'number'
        or jsonb_typeof(incoming->'name') is distinct from 'string'
        -- The app keeps 8 visible characters; emoji can take several code points each.
        or char_length(incoming->>'name') not between 1 and 32
        or (incoming ? 'nameUpdatedAt' and jsonb_typeof(incoming->'nameUpdatedAt') not in ('number', 'null'))
        or (incoming ? 'celebratedStage' and (jsonb_typeof(incoming->'celebratedStage') <> 'number'
            or (incoming->>'celebratedStage')::numeric not in (0, 1, 2, 3, 4, 5))) then
        raise exception 'INVALID_COMPANION';
    end if;
    foreach field in array array['visitDays', 'patDays', 'treatDays'] loop
        if jsonb_typeof(coalesce(incoming->field, '[]'::jsonb)) <> 'array'
            or jsonb_array_length(coalesce(incoming->field, '[]'::jsonb)) > 3000
            or exists (
                select 1 from jsonb_array_elements(coalesce(incoming->field, '[]'::jsonb)) as day
                where jsonb_typeof(day) <> 'string' or day #>> '{}' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            ) then
            raise exception 'INVALID_COMPANION';
        end if;
    end loop;
    foreach field in array array['focusMinutes', 'focusSessions'] loop
        if jsonb_typeof(coalesce(incoming->field, '{}'::jsonb)) <> 'object'
            or (select count(*) from jsonb_object_keys(coalesce(incoming->field, '{}'::jsonb))) > 64
            or exists (
                select 1 from jsonb_each(coalesce(incoming->field, '{}'::jsonb)) as entry
                where char_length(entry.key) not between 1 and 64
                    or jsonb_typeof(entry.value) <> 'number'
                    or (entry.value #>> '{}')::numeric not between 0 and 10000000
                    or (entry.value #>> '{}')::numeric <> trunc((entry.value #>> '{}')::numeric)
            ) then
            raise exception 'INVALID_COMPANION';
        end if;
    end loop;

    insert into public.companion_profiles (user_id, growth) values (uid, incoming)
    on conflict (user_id) do nothing;
    select growth into existing from public.companion_profiles where user_id = uid for update;

    incoming_renamed := coalesce((incoming->>'nameUpdatedAt')::numeric, -1e18);
    existing_renamed := coalesce((existing->>'nameUpdatedAt')::numeric, -1e18);
    merged := jsonb_strip_nulls(jsonb_build_object(
        'name', case when incoming_renamed > existing_renamed
            or (incoming_renamed = existing_renamed and incoming->>'name' > existing->>'name')
            then incoming->>'name' else existing->>'name' end,
        'nameUpdatedAt', nullif(greatest(incoming_renamed, existing_renamed), -1e18),
        'metAt', least((incoming->>'metAt')::numeric, (existing->>'metAt')::numeric),
        'celebratedStage', greatest(coalesce((incoming->>'celebratedStage')::integer, 0), coalesce((existing->>'celebratedStage')::integer, 0)),
        'visitDays', public.companion_days(incoming->'visitDays', existing->'visitDays'),
        'patDays', public.companion_days(incoming->'patDays', existing->'patDays'),
        'treatDays', public.companion_days(incoming->'treatDays', existing->'treatDays'),
        'focusMinutes', public.companion_counts(incoming->'focusMinutes', existing->'focusMinutes'),
        'focusSessions', public.companion_counts(incoming->'focusSessions', existing->'focusSessions')
    ));
    update public.companion_profiles set growth = merged, updated_at = now() where user_id = uid;
    return merged;
end;
$$;

revoke all on function public.companion_days(jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.companion_counts(jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.merge_companion(jsonb) from public, anon;
grant execute on function public.merge_companion(jsonb) to authenticated;
