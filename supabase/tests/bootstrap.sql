-- Somente banco LOCAL descartável. Não executar em um projeto Supabase.
create role anon nologin;
create role service_role nologin bypassrls;
create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key,raw_user_meta_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to authenticated,anon;
grant execute on function auth.uid() to authenticated,anon;
