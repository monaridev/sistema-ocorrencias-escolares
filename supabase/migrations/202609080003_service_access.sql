begin;
-- Operações de Auth das Edge Functions verificam o usuário antes de usar este papel.
grant usage on schema public to service_role;
grant select, update on public.profiles to service_role;
grant select on public.students,public.occurrences,public.occurrence_audit to service_role;
commit;
