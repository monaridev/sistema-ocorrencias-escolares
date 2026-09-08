"""Executa migrações e testes em um banco descartável PostgreSQL (não Supabase)."""
import os
from pathlib import Path
import subprocess
import uuid

root = Path(__file__).resolve().parents[1]
name = 'ocorrencias_test_' + uuid.uuid4().hex
# PGHOST/PGPORT/PGUSER podem apontar para um PostgreSQL local de desenvolvimento.
def run(*args):
    subprocess.run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', *args], check=True)

run('-d', 'postgres', '-c', f'CREATE DATABASE {name}')
try:
    # Os papéis são globais e podem já existir no servidor de desenvolvimento.
    bootstrap = (root / 'supabase/tests/bootstrap.sql').read_text()
    for role in ['anon', 'authenticated']:
        bootstrap = bootstrap.replace(f'create role {role} nologin;', f"DO $$ BEGIN CREATE ROLE {role} NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;")
    subprocess.run(['psql','-X','-v','ON_ERROR_STOP=1','-d',name], input=bootstrap, text=True, check=True)
    for migration in sorted((root / 'supabase/migrations').glob('*.sql')):
        run('-d',name,'-f',str(migration))
    for test in sorted((root / 'supabase/tests').glob('*.sql')):
        if test.name != 'bootstrap.sql': run('-d',name,'-f',str(test))
    print('Migrações e testes PostgreSQL: OK')
finally:
    run('-d','postgres','-c',f'DROP DATABASE {name}')
