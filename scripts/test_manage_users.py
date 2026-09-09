"""Exercita a função publicada usando somente contas marcadas de teste."""
import json
from supabase_http import ROOT,login,request
admin=json.loads((ROOT/'.local/admin-login.json').read_text())
accounts=json.loads((ROOT/'.local/test-accounts.json').read_text())
token=login(admin)
def manage(body,auth=token):
    return request('/functions/v1/manage-users',body,auth)
assert manage({'action':'list'},None)[0]==401
code,result=manage({'action':'list'})
assert code==200 and all('password' not in row for row in result['users'])
for label in ('professor_b','gestor'):
    account=accounts[label]
    fields={'id':account['id'],'nome':'[TESTE] '+label,'email':account['email'],'role':'gestor' if label=='gestor' else 'professor','ativo':True}
    try:
        code,result=manage({'action':'update',**fields})
        assert code==200,('ativação',code,result)
        restricted=login(account)
        status,listing=manage({'action':'list'},restricted)
        assert status==(200 if label=='gestor' else 403)
        if label=='gestor':
            assert all(u['role']!='admin' for u in listing['users'])
            assert manage({'action':'update',**fields},restricted)[0]==200
        assert manage({'action':'update',**fields,'role':'admin'},restricted)[0]==403
    finally:
        code,result=manage({'action':'update',**fields,'ativo':False})
        assert code==200,('desativação',code,result)
    assert manage({'action':'list'},restricted)[0] in (401,403)
print('Edge Function real: admin e gestor autorizados; promoção a admin, professor, conta inativa e anônimo bloqueados. Contas de teste desativadas.')
