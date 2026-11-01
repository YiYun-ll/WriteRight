begin;
select plan(13);
insert into auth.users(id,email) values('55555555-5555-4555-8555-555555555555','companion-a@example.com'),('66666666-6666-4666-8666-666666666666','companion-b@example.com');

select throws_ok($$select public.merge_companion('{"name":"团团","metAt":100}'::jsonb)$$,'P0001','AUTH_REQUIRED','anonymous merge rejected');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated"}',true);
select is(
    public.merge_companion('{"name":"团团","metAt":200,"visitDays":["2026-11-01"],"patDays":["2026-11-01"],"focusMinutes":{"phone":10},"focusSessions":{"phone":1}}'::jsonb),
    '{"name":"团团","metAt":200,"celebratedStage":0,"visitDays":["2026-11-01"],"patDays":["2026-11-01"],"treatDays":[],"focusMinutes":{"phone":10},"focusSessions":{"phone":1}}'::jsonb,
    'first device stores its growth');
select is(
    public.merge_companion('{"name":"Mochi","nameUpdatedAt":500,"metAt":150,"celebratedStage":1,"visitDays":["2026-11-01","2026-11-02"],"treatDays":["2026-11-02"],"focusMinutes":{"pad":25,"phone":4},"focusSessions":{"pad":1}}'::jsonb),
    '{"name":"Mochi","nameUpdatedAt":500,"metAt":150,"celebratedStage":1,"visitDays":["2026-11-01","2026-11-02"],"patDays":["2026-11-01"],"treatDays":["2026-11-02"],"focusMinutes":{"pad":25,"phone":10},"focusSessions":{"pad":1,"phone":1}}'::jsonb,
    'second device unions days, keeps larger per-device counts, earliest meeting and newest name');
select is(
    public.merge_companion('{"name":"旧名字","nameUpdatedAt":300,"metAt":400}'::jsonb)->>'name',
    'Mochi', 'an older rename does not win');
select is(
    public.merge_companion('{"name":"旧名字","nameUpdatedAt":300,"metAt":400}'::jsonb),
    '{"name":"Mochi","nameUpdatedAt":500,"metAt":150,"celebratedStage":1,"visitDays":["2026-11-01","2026-11-02"],"patDays":["2026-11-01"],"treatDays":["2026-11-02"],"focusMinutes":{"pad":25,"phone":10},"focusSessions":{"pad":1,"phone":1}}'::jsonb,
    'a stale device adds nothing and removes nothing');
select is((select jsonb_array_length(growth->'visitDays') from public.companion_profiles where user_id='55555555-5555-4555-8555-555555555555'), 2, 'owner reads the stored growth');

select throws_ok($$update public.companion_profiles set growth='{}'::jsonb$$,'42501',null,'clients cannot write the row directly');
select throws_ok($$insert into public.companion_profiles(user_id,growth) values('55555555-5555-4555-8555-555555555555','{}')$$,'42501',null,'clients cannot insert directly');
select throws_ok($$select public.merge_companion('{"name":"团团","metAt":1,"visitDays":["yesterday"]}'::jsonb)$$,'P0001','INVALID_COMPANION','malformed day rejected');
select throws_ok($$select public.merge_companion('{"name":"团团","metAt":1,"focusMinutes":{"phone":-3}}'::jsonb)$$,'P0001','INVALID_COMPANION','negative minutes rejected');
select throws_ok($$select public.merge_companion('{"name":"","metAt":1}'::jsonb)$$,'P0001','INVALID_COMPANION','empty name rejected');

select set_config('request.jwt.claims','{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated"}',true);
select is((select count(*)::integer from public.companion_profiles),0,'other account cannot read the cat');
select is(public.merge_companion('{"name":"团团","metAt":900}'::jsonb)->>'metAt','900','other account gets its own cat');
select * from finish();
rollback;
