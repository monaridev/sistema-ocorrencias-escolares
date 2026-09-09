\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,description text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FALHOU: %',description; end if; end $$;
create function pg_temp.denied(statement text) returns boolean language plpgsql as $$
begin execute statement; return false; exception when others then return true; end $$;
insert into auth.users(id) values
 ('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002'),('10000000-0000-0000-0000-000000000003'),('10000000-0000-0000-0000-000000000004');
update public.profiles set ativo=true;
update public.profiles set role='gestor' where id='10000000-0000-0000-0000-000000000003';
update public.profiles set role='admin' where id='10000000-0000-0000-0000-000000000004';
insert into public.students(id,nome,turma) values('20000000-0000-0000-0000-000000000001','Aluno Teste','2º B');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select public.create_occurrence('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','2026-09-07',array['Celular'],'Relato privado',array['Advertência']);
select public.create_occurrence('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','2026-09-07',array['Celular'],'Relato privado',array['Advertência']);
select pg_temp.assert_true((select count(*)=1 from public.occurrences),'repetição não duplica');
select pg_temp.assert_true(pg_temp.denied($q$insert into public.occurrences(student_id,created_by,occurrence_date,motivos) values('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','2026-09-07',array['Falso'])$q$),'não forja autoria');
select pg_temp.assert_true(pg_temp.denied($q$update public.profiles set role='admin'$q$),'não eleva papel');
select pg_temp.assert_true(pg_temp.denied($q$select public.cancel_occurrence('30000000-0000-0000-0000-000000000001',1,'Teste')$q$),'professor não cancela');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true((select count(*)=0 from public.occurrences),'B não lê relato de A');
select pg_temp.assert_true((select count(*)=1 from public.student_history('20000000-0000-0000-0000-000000000001')),'B lê resumo de A');
select pg_temp.assert_true((select total=1 from public.search_students('Aluno')),'contagem compartilhada');
select pg_temp.assert_true(not exists(select 1 from jsonb_object_keys((select to_jsonb(h) from public.student_history('20000000-0000-0000-0000-000000000001') h)) k where k in ('relato','providencias','change_reason')),'resumo sem dados privados');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
select pg_temp.assert_true((select count(*)=1 from public.occurrences),'gestor lê completo');
select pg_temp.assert_true(pg_temp.denied($q$select public.correct_occurrence('30000000-0000-0000-0000-000000000001',1,'20000000-0000-0000-0000-000000000001','2026-09-06',array['Corrigido'],'Novo','{}','')$q$),'justificativa obrigatória');
select public.correct_occurrence('30000000-0000-0000-0000-000000000001',1,'20000000-0000-0000-0000-000000000001','2026-09-06',array['Corrigido'],'Novo','{}','Correção de data');
select pg_temp.assert_true((select old_values->>'relato'='Relato privado' and new_values->>'relato'='Novo' and old_values->>'created_at'=new_values->>'created_at' and old_values->>'created_by'=new_values->>'created_by' and changed_by=auth.uid() from public.occurrence_audit),'auditoria e imutabilidade');
select pg_temp.assert_true(pg_temp.denied($q$select public.correct_occurrence('30000000-0000-0000-0000-000000000001',1,'20000000-0000-0000-0000-000000000001','2026-09-06',array['Corrigido'],'Novo','{}','Versão antiga')$q$),'concorrência preserva edições');
select public.cancel_occurrence('30000000-0000-0000-0000-000000000001',2,'Registro indevido');
select pg_temp.assert_true((select total=0 from public.search_students('Aluno')),'cancelada não conta');
select pg_temp.assert_true((select status='cancelled' from public.student_history('20000000-0000-0000-0000-000000000001')),'cancelada visível');
select pg_temp.assert_true(pg_temp.denied('delete from public.occurrences'),'não apaga');
reset role;
update public.profiles set ativo=false where id='10000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((select count(*)=0 from public.occurrences),'desativado não lê ocorrências');
select pg_temp.assert_true(pg_temp.denied($q$select * from public.search_students('Aluno')$q$),'desativado não lê resumo');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.assert_true(pg_temp.denied($q$select * from public.search_students('Aluno')$q$),'sem identidade não lê resumo');
set local role anon;
select pg_temp.assert_true(pg_temp.denied('select * from public.occurrences'),'anônimo não lê tabela');
select pg_temp.assert_true(pg_temp.denied($q$select * from public.search_students('Aluno')$q$),'anônimo não chama RPC');
rollback;
