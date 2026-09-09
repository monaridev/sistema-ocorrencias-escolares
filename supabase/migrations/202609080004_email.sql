begin;
create table public.email_settings (
 id boolean primary key default true check(id),
 recipients text[] not null default '{}',
 enabled boolean not null default false,
 updated_at timestamptz not null default now()
);
insert into public.email_settings(id) values(true);
alter table public.email_settings enable row level security;
create policy email_settings_read on public.email_settings for select to authenticated using(private.active_role() is not null);
grant select on public.email_settings to authenticated,service_role;
create function public.configure_email(p_recipients text[],p_enabled boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if private.active_role() is distinct from 'admin' then raise exception 'Somente admin configura o envio.'; end if;
 if p_enabled is null or p_recipients is null or cardinality(p_recipients)>20 or (p_enabled and cardinality(p_recipients)=0)
 or exists(select 1 from unnest(p_recipients) e where e is null or e !~ '^[^[:space:]@,<>]+@[^[:space:]@,<>]+\.[^[:space:]@,<>]+$' or length(e)>254)
 then raise exception 'Informe destinatários válidos (até 20).'; end if;
 update public.email_settings set recipients=p_recipients,enabled=p_enabled,updated_at=now() where id;
end $$;
revoke all on function public.configure_email(text[],boolean) from public,anon;
grant execute on function public.configure_email(text[],boolean) to authenticated;
create table public.email_deliveries (
 id uuid primary key default gen_random_uuid(),
 occurrence_id uuid not null references public.occurrences(id) on delete restrict,
 occurrence_version integer not null,
 requested_by uuid not null references public.profiles(id) on delete restrict,
 recipients text[] not null,
 status text not null default 'processing' check(status in ('processing','sent','failed','unknown')),
 message_id text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(occurrence_id,occurrence_version)
);
alter table public.email_deliveries enable row level security;
create policy email_deliveries_read on public.email_deliveries for select to authenticated using (
 private.active_role() in ('gestor','admin') or
 (private.active_role()='professor' and exists(select 1 from public.occurrences o where o.id=occurrence_id and o.created_by=auth.uid()))
);
grant select on public.email_deliveries to authenticated;
grant select,update on public.email_deliveries to service_role;
-- Exclusiva da Edge Function: devolve o registro canônico e reserva a tentativa em uma transação.
create function public.claim_occurrence_email(p_id uuid,p_version integer,p_actor uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.occurrences; p public.profiles; settings public.email_settings; delivery public.email_deliveries; snapshot jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,42));
 select * into p from public.profiles where id=p_actor and ativo;
 if not found then raise exception 'Conta inativa.'; end if;
 select * into o from public.occurrences where id=p_id for share;
 if not found or (p.role='professor' and o.created_by<>p_actor) then raise exception 'Sem acesso à ocorrência completa.'; end if;
 if o.version<>p_version then raise exception 'A ocorrência mudou. Atualize antes de enviar.'; end if;
 select * into settings from public.email_settings where id;
 if not settings.enabled or cardinality(settings.recipients)=0 then raise exception 'Envio de e-mail ainda não configurado.'; end if;
 select * into delivery from public.email_deliveries where occurrence_id=p_id and occurrence_version=p_version for update;
 if found and delivery.status<>'failed' then
 return jsonb_build_object('send',false,'delivery',to_jsonb(delivery));
 end if;
 if delivery.id is null then
 insert into public.email_deliveries(occurrence_id,occurrence_version,requested_by,recipients) values(p_id,p_version,p_actor,settings.recipients) returning * into delivery;
 else
 update public.email_deliveries set status='processing',requested_by=p_actor,recipients=settings.recipients,updated_at=now() where id=delivery.id returning * into delivery;
 end if;
 snapshot:=to_jsonb(o)||jsonb_build_object('students',(select to_jsonb(s) from public.students s where s.id=o.student_id),'professor',(select nome from public.profiles where id=o.created_by));
 return jsonb_build_object('send',true,'delivery',to_jsonb(delivery),'occurrence',snapshot);
end $$;
revoke all on function public.claim_occurrence_email(uuid,integer,uuid) from public,anon,authenticated;
grant execute on function public.claim_occurrence_email(uuid,integer,uuid) to service_role;
commit;
