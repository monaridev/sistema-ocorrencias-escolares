begin;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.profiles (
 id uuid primary key references auth.users(id) on delete restrict,
 nome text not null check (length(trim(nome)) between 1 and 150),
 role text not null default 'professor' check (role in ('professor','gestor','admin')),
 ativo boolean not null default false,
 created_at timestamptz not null default now()
);
create function private.create_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,nome) values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'nome'),''),'Usuário'));
 return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function private.create_profile();

create function private.active_role() returns text language sql stable security definer set search_path = '' as $$
 select role from public.profiles where id = (select auth.uid()) and ativo
$$;
revoke all on function private.active_role() from public;
grant execute on function private.active_role() to authenticated;

create table public.students (
 id uuid primary key default gen_random_uuid(),
 nome text not null check (length(trim(nome)) between 1 and 150),
 turma text not null check (length(trim(turma)) between 1 and 50),
 ra text unique check (ra is null or length(trim(ra)) between 1 and 50),
 ativo boolean not null default true,
 created_at timestamptz not null default now()
);
create index students_name_search on public.students(lower(nome));
create table public.occurrences (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.students(id) on delete restrict,
 created_by uuid not null references public.profiles(id) on delete restrict,
 occurrence_date date not null check (occurrence_date between date '2020-01-01' and date '2100-12-31'),
 motivos text[] not null check (cardinality(motivos) between 1 and 20),
 relato text not null default '' check (length(relato) <= 400),
 providencias text[] not null default '{}' check (cardinality(providencias) <= 20),
 status text not null default 'active' check (status in ('active','cancelled')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 version integer not null default 1,
 change_reason text
);
create index occurrences_student_date on public.occurrences(student_id,occurrence_date desc,created_at desc);
create index occurrences_author on public.occurrences(created_by,created_at desc);
create table public.occurrence_audit (
 id bigint generated always as identity primary key,
 occurrence_id uuid not null references public.occurrences(id) on delete restrict,
 changed_by uuid not null references public.profiles(id) on delete restrict,
 changed_at timestamptz not null default now(),
 reason text not null,
 old_values jsonb not null,
 new_values jsonb not null
);

create function private.audit_occurrence() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if TG_OP = 'DELETE' then raise exception 'Ocorrências não podem ser apagadas.'; end if;
 if private.active_role() is null or private.active_role() not in ('gestor','admin') then raise exception 'Sem permissão para corrigir ocorrências.'; end if;
 if new.id <> old.id or new.created_by <> old.created_by or new.created_at <> old.created_at then raise exception 'Autor, identificação e criação são imutáveis.'; end if;
 if nullif(trim(new.change_reason),'') is null then raise exception 'Justificativa obrigatória.'; end if;
 if old.status = 'cancelled' then raise exception 'Ocorrência já cancelada.'; end if;
 new.version := old.version + 1;
 new.updated_at := clock_timestamp();
 insert into public.occurrence_audit(occurrence_id,changed_by,reason,old_values,new_values)
 values(old.id,auth.uid(),trim(new.change_reason),to_jsonb(old),to_jsonb(new));
 return new;
end $$;
create trigger occurrence_changes before update or delete on public.occurrences for each row execute function private.audit_occurrence();

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.occurrences enable row level security;
alter table public.occurrence_audit enable row level security;
revoke all on public.profiles,public.students,public.occurrences,public.occurrence_audit from anon,authenticated;
grant select on public.profiles,public.students,public.occurrences,public.occurrence_audit to authenticated;
create policy profiles_read on public.profiles for select to authenticated using (id = (select auth.uid()) or (select private.active_role()) in ('gestor','admin'));
create policy students_read on public.students for select to authenticated using ((select private.active_role()) is not null);
create policy occurrences_read on public.occurrences for select to authenticated using ((select private.active_role()) in ('gestor','admin') or ((select private.active_role()) = 'professor' and created_by = (select auth.uid())));
create policy audit_read on public.occurrence_audit for select to authenticated using ((select private.active_role()) in ('gestor','admin'));

create function public.create_occurrence(p_id uuid,p_student_id uuid,p_date date,p_motivos text[],p_relato text,p_providencias text[]) returns uuid
language plpgsql security definer set search_path = '' as $$
declare existing public.occurrences;
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 if not exists(select 1 from public.students where id=p_student_id and ativo) then raise exception 'Aluno inválido ou inativo.'; end if;
 if exists(select 1 from unnest(p_motivos) m where m is null or trim(m)='' or length(m)>500)
 or exists(select 1 from unnest(p_providencias) p where p is null or trim(p)='' or length(p)>500) then raise exception 'Motivos ou providências inválidos.'; end if;
 insert into public.occurrences(id,student_id,created_by,occurrence_date,motivos,relato,providencias)
 values(p_id,p_student_id,auth.uid(),p_date,p_motivos,trim(p_relato),p_providencias)
 on conflict(id) do nothing;
 select * into existing from public.occurrences where id=p_id;
 if existing.created_by <> auth.uid() or existing.student_id <> p_student_id or existing.occurrence_date <> p_date
 or existing.motivos is distinct from p_motivos or existing.relato is distinct from trim(p_relato) or existing.providencias is distinct from p_providencias then
 raise exception 'Identificador já usado com outros dados. Atualize antes de tentar novamente.';
 end if;
 return p_id;
end $$;

create function public.correct_occurrence(p_id uuid,p_version integer,p_student_id uuid,p_date date,p_motivos text[],p_relato text,p_providencias text[],p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if private.active_role() is null or private.active_role() not in ('gestor','admin') then raise exception 'Sem permissão.'; end if;
 if not exists(select 1 from public.students where id=p_student_id and ativo) then raise exception 'Aluno inválido ou inativo.'; end if;
 if exists(select 1 from unnest(p_motivos) m where m is null or trim(m)='' or length(m)>500)
 or exists(select 1 from unnest(p_providencias) p where p is null or trim(p)='' or length(p)>500) then raise exception 'Motivos ou providências inválidos.'; end if;
 update public.occurrences set student_id=p_student_id,occurrence_date=p_date,motivos=p_motivos,relato=trim(p_relato),providencias=p_providencias,change_reason=p_reason where id=p_id and version=p_version;
 if not found then raise exception 'Registro alterado por outra pessoa. Atualize e tente novamente.'; end if;
end $$;
create function public.cancel_occurrence(p_id uuid,p_version integer,p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if private.active_role() is null or private.active_role() not in ('gestor','admin') then raise exception 'Sem permissão.'; end if;
 update public.occurrences set status='cancelled',change_reason=p_reason where id=p_id and version=p_version;
 if not found then raise exception 'Registro alterado por outra pessoa. Atualize e tente novamente.'; end if;
end $$;

create function public.search_students(p_query text,p_offset integer default 0)
returns table(id uuid,nome text,turma text,total bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 if length(trim(p_query)) < 2 then return; end if;
 return query select s.id,s.nome,s.turma,count(o.id) filter(where o.status='active') from public.students s
 left join public.occurrences o on o.student_id=s.id
 where s.ativo and position(lower(trim(p_query)) in lower(s.nome))>0
 group by s.id order by s.nome,s.turma,s.id limit 50 offset greatest(0,p_offset);
end $$;
create function public.student_history(p_student_id uuid,p_offset integer default 0)
returns table(id uuid,created_by uuid,professor text,motivos text[],occurrence_date date,status text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 return query select o.id,o.created_by,p.nome,o.motivos,o.occurrence_date,o.status from public.occurrences o join public.profiles p on p.id=o.created_by
 where o.student_id=p_student_id order by o.occurrence_date desc,o.created_at desc,o.id limit 50 offset greatest(0,p_offset);
end $$;

-- Revogar EXECUTE público também nas funções futuras desta migração.
revoke execute on function public.create_occurrence(uuid,uuid,date,text[],text,text[]),public.correct_occurrence(uuid,integer,uuid,date,text[],text,text[],text),public.cancel_occurrence(uuid,integer,text),public.search_students(text,integer),public.student_history(uuid,integer) from public,anon;
grant execute on function public.create_occurrence(uuid,uuid,date,text[],text,text[]),public.correct_occurrence(uuid,integer,uuid,date,text[],text,text[],text),public.cancel_occurrence(uuid,integer,text),public.search_students(text,integer),public.student_history(uuid,integer) to authenticated;
commit;
