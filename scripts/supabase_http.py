"""Cliente HTTP usado somente por configuração/testes locais (não é backend)."""
import json
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.error import HTTPError
ROOT=Path(__file__).resolve().parents[1]
CFG=json.loads((ROOT/'.local/app-config.json').read_text())
URL=CFG['SUPABASE_URL']
KEY=CFG['SUPABASE_PUBLISHABLE_KEY']
def request(path,body=None,token=None,admin=False,method=None):
    key=(ROOT/'.local/supabase-admin-key').read_text().strip() if admin else KEY
    headers={'apikey':key,'Content-Type':'application/json'}
    if token or admin:headers['Authorization']='Bearer '+(token or key)
    req=Request(URL+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method)
    try:
        with urlopen(req,timeout=30) as r:
            raw=r.read();return r.status,json.loads(raw) if raw else None
    except HTTPError as e:
        raw=e.read()
        try:content=json.loads(raw)
        except ValueError:content={'message':'HTTP '+str(e.code)}
        return e.code,content

def login(account):
    status,data=request('/auth/v1/token?grant_type=password',{'email':account['email'],'password':account['password']})
    if status!=200:raise RuntimeError('Login de teste falhou: HTTP '+str(status))
    return data['access_token']
def rpc(name,data,token):return request('/rest/v1/rpc/'+name,data,token)
