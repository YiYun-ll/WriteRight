create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Deployment supplies these two values through Vault, never through a client or Git.
create function private.invoke_grading_worker() returns bigint
language plpgsql security definer set search_path = '' as $$
declare base_url text; worker_key text;
begin
    select decrypted_secret into base_url from vault.decrypted_secrets where name = 'writeright_backend_url' limit 1;
    select decrypted_secret into worker_key from vault.decrypted_secrets where name = 'writeright_worker_token' limit 1;
    if base_url is null or worker_key is null then return null; end if;
    return net.http_post(url := rtrim(base_url, '/') || '/functions/v1/grading-worker',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-worker-key', worker_key),
        body := '{}'::jsonb, timeout_milliseconds := 120000);
end;
$$;
revoke all on function private.invoke_grading_worker() from public, anon, authenticated;
select cron.schedule('writeright-grading-worker', '* * * * *', 'select private.invoke_grading_worker();');
