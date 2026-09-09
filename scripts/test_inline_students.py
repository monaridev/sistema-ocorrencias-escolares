"""Testa nova ocorrência/aluno e união no Supabase usando só dados marcados [TESTE]."""
import json,uuid
from supabase_http import ROOT,request,login,rpc
admin=json.loads((ROOT/'.local/admin-login.json').read_text())
accounts=json.loads((ROOT/'.local/test-accounts.json').read_text())
at=login(admin);teacher=accounts['professor_a'];manager=accounts['gestor']
for label,item,role in [('professor_a',teacher,'professor'),('gestor',manager,'gestor')]:
    code,_=request('/auth/v1/admin/users/'+item['id'],{'ban_duration':'none'},admin=True,method='PUT');assert code==200
    code,_=rpc('admin_update_profile',{'p_id':item['id'],'p_nome':'[TESTE] '+label,'p_role':role,'p_ativo':True},at);assert code in (200,204)
oid=None;mt=None
try:
    tt=login(teacher);mt=login(manager)
    suffix=uuid.uuid4().hex[:8];name='[TESTE] Cadastro no fluxo '+suffix;sid=str(uuid.uuid4());oid=str(uuid.uuid4())
    payload={'p_id':oid,'p_student_id':sid,'p_nome':name,'p_turma':'TESTE','p_date':'2026-09-09','p_motivos':['Teste nova regra'],'p_relato':'Relato privado de teste','p_providencias':[]}
    for _ in range(2):
        code,result=rpc('create_occurrence_with_student',payload,tt);assert code==200,(code,result)
    code,matches=rpc('find_student_matches',{'p_nome':name,'p_turma':'TESTE'},tt);assert code==200 and len([m for m in matches if m['exact_match'] and m['id']==sid])==1,(code,matches)
    code,_=rpc('create_occurrence_with_student',{**payload,'p_id':str(uuid.uuid4()),'p_student_id':str(uuid.uuid4())},tt);assert code>=400
    code,_=rpc('correct_student',{'p_id':sid,'p_version':1,'p_nome':name,'p_turma':'TESTE','p_ra':'','p_reason':'Teste'},tt);assert code>=400
    target_name='[TESTE] Destino unificado '+suffix
    code,result=rpc('import_students',{'p_rows':[{'nome':target_name,'turma':'TESTE'}]},mt);assert code==200,(code,result)
    code,rows=rpc('search_students',{'p_query':target_name},mt);assert code==200 and len(rows)==1
    target=rows[0]['id']
    code,result=rpc('merge_students',{'p_source':sid,'p_target':target,'p_source_version':1,'p_target_version':1,'p_reason':'Teste automatizado de união sem apagar registros'},mt);assert code in (200,204),(code,result)
    code,history=rpc('student_history',{'p_student_id':target},tt);assert code==200 and len(history)==1 and history[0]['id']==oid and 'relato' not in history[0]
    code,result=rpc('cancel_occurrence',{'p_id':oid,'p_version':1,'p_reason':'Encerramento de teste'},mt);assert code in (200,204),(code,result)
    code,rows=rpc('search_students',{'p_query':target_name},tt);assert code==200 and rows[0]['total']==0
    print('Supabase: cadastro junto à ocorrência, repetição, duplicidade, permissões e união de histórico OK.')
finally:
    if oid and mt:
        code,records=request('/rest/v1/occurrences?id=eq.'+oid+'&select=id,status,version',token=mt)
        if code==200 and records and records[0]['status']=='active':
            rpc('cancel_occurrence',{'p_id':oid,'p_version':records[0]['version'],'p_reason':'Encerramento do teste automatizado, inclusive em falha'},mt)
    for label,item,role in [('professor_a',teacher,'professor'),('gestor',manager,'gestor')]:
        rpc('admin_update_profile',{'p_id':item['id'],'p_nome':'[TESTE] '+label,'p_role':role,'p_ativo':False},at)
    print('Contas de teste desativadas; dados [TESTE] preservados.')
