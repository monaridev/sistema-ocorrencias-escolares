begin;
create function public.admin_update_profile(p_id uuid,p_nome text,p_role text,p_ativo boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 -- Serializar mudanças de papel para preservar pelo menos um administrador ativo.
 perform pg_advisory_xact_lock(78265001);
 if private.active_role() is distinct from 'admin' then raise exception 'Somente admin administra contas.'; end if;
 if exists(select 1 from public.profiles where id=p_id and role='admin' and ativo)
 and (p_role<>'admin' or not p_ativo)
 and (select count(*) from public.profiles where role='admin' and ativo)<2 then raise exception 'Mantenha ao menos um admin ativo.'; end if;
 update public.profiles set nome=trim(p_nome),role=p_role,ativo=p_ativo where id=p_id;
 if not found then raise exception 'Usuário não encontrado.'; end if;
end $$;

create function private.normalized_name(value text) returns text language sql immutable set search_path='' as $$
 select lower(regexp_replace(trim(value),'\s+',' ','g'))
$$;
create function public.preview_students(p_rows jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare item jsonb; results jsonb='[]'; row_number integer=0; state text; candidate uuid; normalized text; seen_names text[]='{}'; seen_ra text[]='{}'; ra_value text;
begin
 if private.active_role() is null or private.active_role() not in ('gestor','admin') then raise exception 'Sem permissão para cadastrar alunos.'; end if;
 if jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'Lista inválida.'; end if;
 if jsonb_array_length(p_rows)>1000 then raise exception 'Importe até 1000 alunos por vez.'; end if;
 for item in select value from jsonb_array_elements(p_rows) loop
 row_number:=row_number+1; candidate:=null; state:='ready';
 ra_value:=nullif(trim(item->>'ra'),'');
 normalized:=private.normalized_name(item->>'nome')||'|'||private.normalized_name(item->>'turma');
 if nullif(trim(item->>'nome'),'') is null or nullif(trim(item->>'turma'),'') is null
 or length(trim(item->>'nome'))>150 or length(trim(item->>'turma'))>50 or length(ra_value)>50 then state:='invalid';
 elsif ra_value is not null and ra_value=any(seen_ra) then state:='duplicate_ra';
 elsif ra_value is not null and exists(select 1 from public.students where ra=ra_value) then
 state:='existing_ra'; select id into candidate from public.students where ra=ra_value;
 elsif normalized=any(seen_names) or exists(select 1 from public.students where private.normalized_name(nome)||'|'||private.normalized_name(turma)=normalized) then state:='review';
 end if;
 seen_names:=array_append(seen_names,normalized); if ra_value is not null then seen_ra:=array_append(seen_ra,ra_value); end if;
 results:=results||jsonb_build_array(jsonb_build_object('row',row_number,'nome',trim(item->>'nome'),'turma',trim(item->>'turma'),'ra',ra_value,'state',state,'existing_id',candidate));
 end loop;
 return results;
end $$;

create function public.import_students(p_rows jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare preview jsonb; item jsonb; checked jsonb; inserted_count integer=0; skipped_count integer=0; n integer=0;
begin
 -- Validação e gravação na mesma transação; segunda importação espera a primeira.
 perform pg_advisory_xact_lock(78265002);
 preview:=public.preview_students(p_rows);
 for item in select value from jsonb_array_elements(p_rows) loop
 checked:=preview->n; n:=n+1;
 if item->>'decision'='skip' then skipped_count:=skipped_count+1; continue; end if;
 if checked->>'state' in ('invalid','duplicate_ra','existing_ra') then raise exception 'Revise a linha %: %',n,checked->>'state'; end if;
 if checked->>'state'='review' and item->>'decision' is distinct from 'new' then raise exception 'Possível duplicidade na linha %. Confirme ou ignore antes de importar.',n; end if;
 insert into public.students(nome,turma,ra) values(checked->>'nome',checked->>'turma',checked->>'ra');
 inserted_count:=inserted_count+1;
 end loop;
 return jsonb_build_object('inserted',inserted_count,'skipped',skipped_count);
end $$;
revoke all on function private.normalized_name(text) from public;
revoke all on function public.admin_update_profile(uuid,text,text,boolean),public.preview_students(jsonb),public.import_students(jsonb) from public,anon;
grant execute on function public.admin_update_profile(uuid,text,text,boolean),public.preview_students(jsonb),public.import_students(jsonb) to authenticated;
commit;
