"""Reconecta o Gmail da escola para a V2. Guarda segredo somente em .local, sem imprimir tokens."""
import json
import os
import sys
from pathlib import Path
from google_auth_oauthlib.flow import InstalledAppFlow
ROOT=Path(__file__).resolve().parents[1]
os.umask(0o077)
sender=os.getenv("GMAIL_SENDER", "").strip()
if not sender:
    print("Defina GMAIL_SENDER com o Gmail remetente da escola antes de executar.", file=sys.stderr)
    raise SystemExit(1)
local=ROOT/'.local';local.mkdir(exist_ok=True)
flow=InstalledAppFlow.from_client_secrets_file(str(ROOT/'v1-desktop/credentials.json'),['https://www.googleapis.com/auth/gmail.send'])
# A biblioteca valida state e usa o redirecionamento loopback oficial para clientes desktop.
credentials=flow.run_local_server(host='localhost',port=0,open_browser=False,timeout_seconds=900,authorization_prompt_message='Abra esta URL para reconectar o Gmail da escola:\n{url}',success_message='Gmail autorizado. Pode fechar esta aba.',access_type='offline',prompt='consent',login_hint=sender)
if not credentials.refresh_token:raise RuntimeError('O Google não devolveu autorização offline. Repita o consentimento.')
data={k:getattr(credentials,k) for k in ['client_id','client_secret','refresh_token']}
data['sender']=sender
path=local/'gmail-oauth.json';path.write_text(json.dumps(data));path.chmod(0o600)
print('Autorização salva localmente. Nenhum e-mail foi enviado.')
