-- Uma união não invalida a confirmação repetida da ocorrência já salva.
begin;
create or replace function public.create_occurrence(p_id uuid,p_student_id uuid,p_date date,p_motivos text[],p_relato text,p_providencias text[]) returns uuid
language plpgsql security definer set search_path = '' as $$
declare existing public.occurrences;
begin
 if private.active_role() is null then raise exception 'Conta sem acesso.'; end if;
 if not exists(select 1 from public.occurrences where id=p_id) and not exists(select 1 from public.students where id=p_student_id and ativo) then raise exception 'Aluno inválido ou inativo.'; end if;
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

commit;
