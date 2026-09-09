"""Teste real de Auth/Data API. Usa contas próprias de teste e cancela a ocorrência criada."""
import json,secrets,uuid
from supabase_http import *
admin=json.loads((ROOT/'.local/admin-login.json').read_text())
at=login(admin)
accounts_path=ROOT/'.local/test-accounts.json'
accounts=json.loads(accounts_path.read_text()) if accounts_path.exists() else {}
for role in ['professor_a','professor_b','gestor']:
    if role not in accounts:
        item={'email':f'ocorrencias.{role}.{uuid.uuid4().hex[:10]}@example.com','password':secrets.token_urlsafe(24)}
        code,user=request('/auth/v1/admin/users',{**item,'email_confirm':True,'user_metadata':{'nome':'[TESTE] '+role,'role':'admin'}},admin=True)
        assert code in (200,201),('criar conta',code)
        item['id']=user['id'];accounts[role]=item
        accounts_path.write_text(json.dumps(accounts));accounts_path.chmod(0o600)
    item=accounts[role]
    code,_=request('/auth/v1/admin/users/'+item['id'],{'ban_duration':'none'},admin=True,method='PUT')
    assert code==200,('desbloquear teste',code)
    code,data=rpc('admin_update_profile',{'p_id':item['id'],'p_nome':'[TESTE] '+role,'p_role':'gestor' if role=='gestor' else 'professor','p_ativo':True},at)
    assert code in (200,204),('ativar teste',code,data)
a=login(accounts['professor_a']);b=login(accounts['professor_b']);g=login(accounts['gestor'])
label='[TESTE] Aluno '+uuid.uuid4().hex[:8]
code,data=rpc('import_students',{'p_rows':[{'nome':label,'turma':'TESTE'}]},at);assert code==200,(code,data)
code,students=rpc('search_students',{'p_query':label},a);assert code==200 and len(students)==1
student=students[0]['id'];oid=str(uuid.uuid4());created=False
try:
    payload={'p_id':oid,'p_student_id':student,'p_date':'2026-09-07','p_motivos':['Teste de acesso'],'p_relato':'Relato privado de teste','p_providencias':['Teste']}
    code,data=rpc('create_occurrence',payload,a);assert code==200,(code,data);created=True
    code,data=rpc('create_occurrence',payload,a);assert code==200
    code,data=request('/rest/v1/occurrences?id=eq.'+oid,token=b);assert code==200 and data==[],('sigilo',code)
    code,data=rpc('student_history',{'p_student_id':student},b);assert code==200 and len(data)==1 and 'relato' not in data[0]
    code,data=request('/rest/v1/profiles?id=eq.'+accounts['professor_a']['id'],{'role':'admin'},token=a,method='PATCH');assert code in (401,403)
    code,data=rpc('correct_occurrence',{'p_id':oid,'p_version':1,'p_student_id':student,'p_date':'2026-09-06','p_motivos':['Teste corrigido'],'p_relato':'Corrigido','p_providencias':[],'p_reason':'Teste automatizado de auditoria'},g);assert code==204 or code==200,(code,data)
    code,data=request('/rest/v1/occurrence_audit?occurrence_id=eq.'+oid,token=g);assert code==200 and data[0]['old_values']['relato']=='Relato privado de teste'
    code,data=rpc('cancel_occurrence',{'p_id':oid,'p_version':2,'p_reason':'Encerramento do teste automatizado'},g);assert code in (200,204)
    code,data=rpc('search_students',{'p_query':label},b);assert code==200 and data[0]['total']==0
    code,data=rpc('student_history',{'p_student_id':student},b);assert code==200 and data[0]['status']=='cancelled'
    code,data=request('/rest/v1/occurrences?id=eq.'+oid,token=g,method='DELETE');assert code in (401,403)
    code,data=rpc('admin_update_profile',{'p_id':accounts['professor_a']['id'],'p_nome':'[TESTE] professor_a','p_role':'professor','p_ativo':False},at);assert code in (200,204)
    code,data=rpc('search_students',{'p_query':label},a);assert code>=400,('sessão desativada',code)
    code,data=request('/auth/v1/settings');assert code==200 and data['disable_signup'] is True
    print('Supabase real: login, sigilo, auditoria, concorrência de salvamento, cancelamento e desativação OK.')
finally:
    for role,item in accounts.items():
        rpc('admin_update_profile',{'p_id':item['id'],'p_nome':'[TESTE] '+role,'p_role':'gestor' if role=='gestor' else 'professor','p_ativo':False},at)
    print('Contas de teste desativadas. Registros de teste preservados com identificação [TESTE].')
