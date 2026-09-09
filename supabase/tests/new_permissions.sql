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

select public.create_occurrence_with_student('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','Ana Souza','1 A','2026-09-09',array['Atraso'],'Relato privado','{}');
select public.create_occurrence_with_student('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','Ana Souza','1 A','2026-09-09',array['Atraso'],'Relato privado','{}');
select pg_temp.assert_true((select count(*)=1 from public.students where nome='Ana Souza'),'repetição não duplica aluno');
select pg_temp.assert_true((select count(*)=1 from public.occurrences),'repetição não duplica ocorrência');
select pg_temp.assert_true(pg_temp.denied($q$select public.create_occurrence_with_student('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000003',' ana  souza ','1 a','2026-09-09',array['Atraso'],'','{}')$q$),'mesmo nome e turma bloqueado no banco');
select pg_temp.assert_true(pg_temp.denied($q$select public.create_occurrence_with_student('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000004','Falha','1 A','2026-09-09','{}','','{}')$q$),'ocorrência inválida falha');
select pg_temp.assert_true((select count(*)=0 from public.students where nome='Falha'),'aluno revertido junto com ocorrência');
select pg_temp.assert_true((select count(*)=1 from public.find_student_matches('Ana','1 A')),'busca parcial por nome e turma');
select pg_temp.assert_true((select count(*)=0 from public.find_student_matches('Ana','2 B')),'turma distinta não corresponde');
select pg_temp.assert_true(pg_temp.denied($q$select public.correct_student('20000000-0000-0000-0000-000000000002',1,'Ana','1 A','','Teste')$q$),'professor não corrige cadastro');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
select public.admin_update_profile('10000000-0000-0000-0000-000000000002','Professor B','gestor',true);
select public.admin_update_profile('10000000-0000-0000-0000-000000000002','Professor B','professor',false);
select pg_temp.assert_true(pg_temp.denied($q$select public.admin_update_profile('10000000-0000-0000-0000-000000000002','B','admin',true)$q$),'gestor não promove admin');
select pg_temp.assert_true(pg_temp.denied($q$select public.admin_update_profile('10000000-0000-0000-0000-000000000004','Admin','professor',false)$q$),'gestor não altera admin existente');
select pg_temp.assert_true(pg_temp.denied($q$select public.correct_student('20000000-0000-0000-0000-000000000002',1,'Ana','1 A','','')$q$),'justificativa de aluno obrigatória');
select public.correct_student('20000000-0000-0000-0000-000000000002',1,'Ana de Souza','1 A','123','Completar nome');
select pg_temp.assert_true((select old_values->>'nome'='Ana Souza' and new_values->>'nome'='Ana de Souza' from public.student_audit),'auditoria do aluno preservada');
select pg_temp.assert_true(pg_temp.denied($q$select public.correct_student('20000000-0000-0000-0000-000000000002',1,'Ana','1 A','','Desatualizado')$q$),'versão antiga rejeitada');
select public.create_occurrence('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','2026-09-09',array['Celular'],'Outro relato','{}');
select public.cancel_occurrence('30000000-0000-0000-0000-000000000004',1,'Teste cancelado');
select public.merge_students('20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001',2,1,'Cadastros do mesmo aluno');
select pg_temp.assert_true((select student_id='20000000-0000-0000-0000-000000000002' and created_by='10000000-0000-0000-0000-000000000001' from public.occurrences where id='30000000-0000-0000-0000-000000000001'),'união preserva origem e autor');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((select count(*)=2 from public.student_history('20000000-0000-0000-0000-000000000001')),'histórico reúne ativa e cancelada');
select pg_temp.assert_true((select total=1 from public.search_students('Aluno')),'contagem unificada exclui cancelada');
select pg_temp.assert_true((select count(*)=1 from public.find_student_matches('Ana de Souza','1 A')),'nome antigo encontra cadastro mantido');
select public.create_occurrence_with_student('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','Ana Souza','1 A','2026-09-09',array['Atraso'],'Relato privado','{}');
select pg_temp.assert_true((select ra='123' from public.students where id='20000000-0000-0000-0000-000000000001'),'RA preservado no destino');
select pg_temp.assert_true(pg_temp.denied($q$select public.merge_students('20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002',2,3,'Indevido')$q$),'professor não une cadastros');
rollback;
