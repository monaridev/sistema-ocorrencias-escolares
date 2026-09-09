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

select pg_temp.assert_true(pg_temp.denied($q$select public.configure_email(array['test@example.com'],true)$q$),'professor não configura envio');
select pg_temp.assert_true(pg_temp.denied($q$select public.claim_occurrence_email('30000000-0000-0000-0000-000000000001',1,'10000000-0000-0000-0000-000000000001')$q$),'cliente não reserva envio diretamente');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
select public.configure_email(array['test@example.com'],true);
select pg_temp.assert_true(pg_temp.denied($q$select public.configure_email(array[E'test@example.com\nBcc: injected@example.com'],true)$q$),'sem injeção de cabeçalhos');
set local role service_role;
select pg_temp.assert_true(pg_temp.denied($q$select public.claim_occurrence_email('30000000-0000-0000-0000-000000000001',1,'10000000-0000-0000-0000-000000000002')$q$),'professor não envia ocorrência de outro');
select pg_temp.assert_true((public.claim_occurrence_email('30000000-0000-0000-0000-000000000001',1,'10000000-0000-0000-0000-000000000001')->>'send')::boolean,'primeira tentativa reservada');
select pg_temp.assert_true(not (public.claim_occurrence_email('30000000-0000-0000-0000-000000000001',1,'10000000-0000-0000-0000-000000000001')->>'send')::boolean,'tentativa pendente não duplica');
update public.email_deliveries set status='failed';
select pg_temp.assert_true((public.claim_occurrence_email('30000000-0000-0000-0000-000000000001',1,'10000000-0000-0000-0000-000000000001')->>'send')::boolean,'rejeição confirmada permite repetir');
update public.email_deliveries set status='unknown';
select pg_temp.assert_true(not (public.claim_occurrence_email('30000000-0000-0000-0000-000000000001',1,'10000000-0000-0000-0000-000000000001')->>'send')::boolean,'resultado incerto bloqueia repetição');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true((select count(*)=0 from public.email_deliveries),'outro professor não lê envios privados');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((select count(*)=1 from public.email_deliveries),'autor consulta envio');
select pg_temp.assert_true(pg_temp.denied($q$update public.email_deliveries set status='sent'$q$),'cliente não falsifica sucesso');
rollback;
