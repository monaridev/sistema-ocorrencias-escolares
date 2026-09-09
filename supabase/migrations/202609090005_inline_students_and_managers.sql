begin;
create or replace function public.admin_update_profile(p_id uuid,p_nome text,p_role text,p_ativo boolean) returns void language plpgsql security definer set search_path='' as $$
declare actor_role text;
begin
 perform pg_advisory_xact_lock(78265001);
 actor_role:=private.active_role();
 if actor_role is null or actor_role not in ('gestor','admin') then raise exception 'Somente gestão ou admin administra contas.'; end if;
 if actor_role='gestor' and (p_role='admin' or exists(select 1 from public.profiles where id=p_id and role='admin')) then raise exception 'Gestão não pode criar, promover ou alterar admin.'; end if;
 if exists(select 1 from public.profiles where id=p_id and role='admin' and ativo)
 and (p_role<>'admin' or not p_ativo)
 and (select count(*) from public.profiles where role='admin' and ativo)<2 then raise exception 'Mantenha ao menos um admin ativo.'; end if;
 update public.profiles set nome=trim(p_nome),role=p_role,ativo=p_ativo where id=p_id;
 if not found then raise exception 'Usuário não encontrado.'; end if;
end $$;

create function public.find_student_matches(p_nome text,p_turma text)
returns table(id uuid,nome text,turma text,exact_match boolean)
language plpgsql stable security definer set search_path='' as $$
declare n text:=private.normalized_name(p_nome); t text:=private.normalized_name(p_turma);
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 if n is null or length(n)<2 or nullif(t,'') is null then raise exception 'Informe nome e turma para pesquisar.'; end if;
 return query select s.id,s.nome,s.turma,private.normalized_name(s.nome)=n from public.students s
 where s.ativo and private.normalized_name(s.turma)=t and (
 position(n in private.normalized_name(s.nome))>0 or position(private.normalized_name(s.nome) in n)>0
 or split_part(private.normalized_name(s.nome),' ',1)=split_part(n,' ',1))
 order by (private.normalized_name(s.nome)=n) desc,s.nome,s.id limit 50;
end $$;

create function public.create_occurrence_with_student(p_id uuid,p_student_id uuid,p_nome text,p_turma text,p_date date,p_motivos text[],p_relato text,p_providencias text[]) returns uuid
language plpgsql security definer set search_path='' as $$
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 if nullif(trim(p_nome),'') is null or length(trim(p_nome))<2 or length(trim(p_nome))>150
 or nullif(trim(p_turma),'') is null or length(trim(p_turma))>50 then raise exception 'Confira nome e turma do aluno.'; end if;
 -- Mesmo bloqueio da importação: concorrência não cria um segundo aluno exato.
 perform pg_advisory_xact_lock(78265002);
 if exists(select 1 from public.occurrences where id=p_id) then
 return public.create_occurrence(p_id,p_student_id,p_date,p_motivos,p_relato,p_providencias);
 end if;
 if exists(select 1 from public.students where private.normalized_name(nome)=private.normalized_name(p_nome) and private.normalized_name(turma)=private.normalized_name(p_turma)) then
 raise exception 'Já existe aluno com esse nome e turma. Volte e selecione o cadastro existente; homônimos exatos precisam de revisão da gestão.';
 end if;
 insert into public.students(id,nome,turma) values(p_student_id,trim(p_nome),trim(p_turma));
 -- Se a ocorrência falhar, a inserção do aluno é revertida na mesma transação.
 return public.create_occurrence(p_id,p_student_id,p_date,p_motivos,p_relato,p_providencias);
end $$;
revoke all on function public.find_student_matches(text,text),public.create_occurrence_with_student(uuid,uuid,text,text,date,text[],text,text[]) from public,anon;
grant execute on function public.find_student_matches(text,text),public.create_occurrence_with_student(uuid,uuid,text,text,date,text[],text,text[]) to authenticated;
commit;
