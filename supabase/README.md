# Banco da V2

Migrações versionadas para Supabase PostgreSQL. Auth permanece no Supabase; não existe backend FastAPI.

## Testes locais

Com PostgreSQL 16+ e `psql` disponíveis, configure PGHOST/PGPORT/PGUSER para uma instância local de desenvolvimento e execute `python3 scripts/test_database.py` na raiz. O script cria e remove somente um banco descartável com nome aleatório.

O bootstrap de testes reproduz apenas `auth.users` e `auth.uid()` para testar SQL, grants e RLS com papéis reais do PostgreSQL. Não substitui testes de integração do Supabase Auth/Data API. Nunca executar `tests/bootstrap.sql` num projeto Supabase.

## Implantação

Aplicar migrações em ordem em projeto exclusivo da V2, com cadastro público desabilitado no Supabase Auth. Habilitar Data API, mantendo grants explícitos e RLS. O primeiro admin deve ser provisionado por operação administrativa; novos perfis começam inativos, sem aceitar papéis enviados em metadados pelo cliente.

Nenhuma chave privilegiada do Supabase nem credencial Gmail pode ser incluída no APK. O aplicativo usa apenas URL e chave pública do projeto; operações administrativas de Auth e envio ficam em Edge Functions autenticadas.
