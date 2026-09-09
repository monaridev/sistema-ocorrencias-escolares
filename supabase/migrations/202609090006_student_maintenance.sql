begin;
alter table public.students add column version integer not null default 1;
alter table public.students add column merged_into uuid references public.students(id) on delete restrict;
alter table public.students add constraint students_not_self_merged check(merged_into is null or merged_into<>id);
create index students_merged_into_idx on public.students(merged_into);
create table public.student_audit (
 id uuid primary key default gen_random_uuid(),student_id uuid not null references public.students(id),
 changed_by uuid not null references public.profiles(id),changed_at timestamptz not null default now(),
 reason text not null,old_values jsonb not null,new_values jsonb not null
);
alter table public.student_audit enable row level security;
create policy student_audit_read on public.student_audit for select to authenticated using(private.active_role() in ('gestor','admin'));
grant select on public.student_audit to authenticated;
create function public.correct_student(p_id uuid,p_version integer,p_nome text,p_turma text,p_ra text,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare old public.students; updated public.students;
begin
 if private.active_role() is null or private.active_role() not in ('gestor','admin') then raise exception 'Somente gestão ou admin corrige alunos.'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Informe a justificativa.'; end if;
 perform pg_advisory_xact_lock(78265002);
 select * into old from public.students where id=p_id and version=p_version and ativo and merged_into is null for update;
 if not found then raise exception 'Cadastro alterado. Pesquise o aluno novamente.'; end if;
 update public.students set nome=trim(p_nome),turma=trim(p_turma),ra=nullif(trim(p_ra),''),version=version+1 where id=p_id returning * into updated;
 insert into public.student_audit(student_id,changed_by,reason,old_values,new_values) values(p_id,auth.uid(),trim(p_reason),to_jsonb(old),to_jsonb(updated));
end $$;

create function public.merge_students(p_source uuid,p_target uuid,p_source_version integer,p_target_version integer,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare src public.students; dst public.students; result public.students;
begin
 if private.active_role() is null or private.active_role() not in ('gestor','admin') then raise exception 'Somente gestão ou admin resolve duplicidades.'; end if;
 if p_source=p_target or nullif(trim(p_reason),'') is null then raise exception 'Selecione outro cadastro e justifique a união.'; end if;
 perform pg_advisory_xact_lock(78265002);
 select * into src from public.students where id=p_source and ativo and merged_into is null and version=p_source_version for update;
 if not found then raise exception 'Cadastro de origem alterado. Pesquise novamente.'; end if;
 select * into dst from public.students where id=p_target and ativo and merged_into is null and version=p_target_version for update;
 if not found then raise exception 'Cadastro de destino alterado. Pesquise novamente.'; end if;
 if src.ra is not null and dst.ra is not null and src.ra<>dst.ra then raise exception 'RAs diferentes. Confira e corrija os identificadores antes de unir.'; end if;
 update public.students set ativo=false,merged_into=p_target,ra=case when dst.ra is null then null else ra end,version=version+1 where id=p_source returning * into result;
 insert into public.student_audit(student_id,changed_by,reason,old_values,new_values) values(p_source,auth.uid(),trim(p_reason),to_jsonb(src),to_jsonb(result));
 update public.students set ra=coalesce(dst.ra,src.ra),version=version+1 where id=p_target returning * into result;
 insert into public.student_audit(student_id,changed_by,reason,old_values,new_values) values(p_target,auth.uid(),trim(p_reason),to_jsonb(dst),to_jsonb(result));
 -- As ocorrências mantêm IDs, autores, cancelamentos e auditorias originais.
 -- A consulta de histórico reúne todos os cadastros vinculados ao destino.
end $$;
create function private.student_family(p_root uuid) returns table(id uuid) language sql stable rows 10 security definer set search_path='' as $$
 with recursive family as (select p_root as id union all select s.id from public.students s join family f on s.merged_into=f.id) select id from family
$$;
revoke all on function private.student_family(uuid) from public,anon,authenticated;
create or replace function public.search_students(p_query text,p_offset integer default 0)
returns table(id uuid,nome text,turma text,total bigint) language plpgsql stable security definer set search_path='' as $$
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 if length(trim(p_query))<2 then return; end if;
 return query select s.id,s.nome,s.turma,(select count(*) from public.occurrences o where o.status='active' and o.student_id in (select f.id from private.student_family(s.id) f)) from public.students s
 where s.ativo and exists(select 1 from public.students alias where alias.id in(select f.id from private.student_family(s.id) f) and position(lower(trim(p_query)) in lower(alias.nome))>0)
 order by s.nome,s.turma,s.id limit 50 offset greatest(0,p_offset);
end $$;
create or replace function public.student_history(p_student_id uuid,p_offset integer default 0)
returns table(id uuid,created_by uuid,professor text,motivos text[],occurrence_date date,status text) language plpgsql stable security definer set search_path='' as $$
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 return query select o.id,o.created_by,p.nome,o.motivos,o.occurrence_date,o.status from public.occurrences o join public.profiles p on p.id=o.created_by
 where o.student_id in (select f.id from private.student_family(p_student_id) f) order by o.occurrence_date desc,o.created_at desc,o.id limit 50 offset greatest(0,p_offset);
end $$;
revoke all on function public.correct_student(uuid,integer,text,text,text,text),public.merge_students(uuid,uuid,integer,integer,text) from public,anon;
grant execute on function public.correct_student(uuid,integer,text,text,text,text),public.merge_students(uuid,uuid,integer,integer,text) to authenticated;
create or replace function public.find_student_matches(p_nome text,p_turma text)
returns table(id uuid,nome text,turma text,exact_match boolean)
language plpgsql stable security definer set search_path='' as $$
declare n text:=private.normalized_name(p_nome); t text:=private.normalized_name(p_turma);
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 if n is null or length(n)<2 or nullif(t,'') is null then raise exception 'Informe nome e turma para pesquisar.'; end if;
 return query select s.id,s.nome,s.turma,bool_or(private.normalized_name(a.nome)=n) from public.students s
 join lateral private.student_family(s.id) f on true join public.students a on a.id=f.id
 where s.ativo and private.normalized_name(a.turma)=t and (position(n in private.normalized_name(a.nome))>0 or position(private.normalized_name(a.nome) in n)>0 or split_part(private.normalized_name(a.nome),' ',1)=split_part(n,' ',1))
 group by s.id order by bool_or(private.normalized_name(a.nome)=n) desc,s.nome,s.id limit 50;
end $$;
commit;
