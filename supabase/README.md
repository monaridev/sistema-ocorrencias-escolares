# Backend da V2

Flutter usa Auth, Data API e RPCs com chave pública. Segredos privilegiados existem somente nas Edge Functions e na configuração local ignorada pelo Git. Não há servidor próprio.

## Banco

Aplicar `migrations/*.sql` na ordem em um projeto Supabase. Desabilitar cadastro público em Authentication. O trigger cria perfis inativos; ativar o primeiro admin por uma operação administrativa controlada após criar sua identidade no Auth. Demais contas são administradas no app.

O projeto atual recebeu as migrações pelo SQL Editor. Antes de usar `supabase db push`, conciliar o ledger da CLI com os arquivos aplicados, sem executar novamente as migrações de criação.

Testes em PostgreSQL local descartável: `python3 scripts/test_database.py`, com `psql` no PATH e PGHOST/PGPORT/PGUSER apontando ao ambiente local. `tests/bootstrap.sql` é somente um stub local de Auth; nunca executar no Supabase.

## Funções

Publicar `manage-users` e `send-occurrence` usando os respectivos `index.ts` e `config.toml`. `verify_jwt=false` desativa apenas o verificador legado: cada função valida o token através de `/auth/v1/user`. Administração exige perfil admin ativo; envio verifica acesso ao registro completo no banco.

`manage-users` cria contas sem e-mail automático; senha inicial é definida pelo admin. Alterações de Auth e perfil não são uma única transação: respostas parciais orientam a reabrir a conta. O banco impede remover o último admin ativo.

`send-occurrence` gera o PDF a partir dos dados canônicos do banco. Não aceita PDF nem destinatários enviados pelo cliente. O anexo usa Gmail API e MIME/base64url conforme [documentação oficial](https://developers.google.com/workspace/gmail/api/guides/sending). PDFs são temporários, sem Storage.

## Gmail

1. Na máquina administrativa, executar `python3 scripts/authorize_gmail.py` e autorizar a conta remetente no navegador. Exige `google-auth-oauthlib` e o cliente OAuth desktop já usado pela V1.
2. Guardar o conteúdo de `.local/gmail-oauth.json` no segredo `GMAIL_OAUTH` da Edge Function. Estrutura: `sender`, `client_id`, `client_secret`, `refresh_token`. Nunca colocar esses valores em Dart, Git ou APK.
3. No app, entrar como admin, abrir **Configurar e-mail**, conferir os destinatários de teste e habilitar o envio.
4. Registrar ocorrência de teste, abrir detalhes e enviar. Confirmar recebimento e testar repetição do botão: a mesma versão já enviada não gera outro e-mail.
5. Antes do uso escolar, trocar os destinatários no app; isso não exige recompilar o APK.

Uma tentativa confirmada `sent` não é repetida. Falha confirmada `failed` permite nova tentativa; `processing`/`unknown` bloqueiam repetição automática. Se houver interrupção após o Gmail aceitar a mensagem, conferir manualmente a caixa de enviados antes de qualquer intervenção administrativa no estado. Não marcar falha sem comprovar que não houve envio.

Os PDFs usam fontes padrão com suporte aos acentos portugueses. Símbolos fora desse conjunto devem ser verificados antes de distribuição; o envio falha antes de transmitir se não conseguir gerar o anexo.

## Testes

- `deno test --allow-env supabase/functions/manage-users/index_test.ts`
- `deno test --allow-env supabase/functions/send-occurrence/index_test.ts`
- `python3 scripts/test_supabase.py` e `python3 scripts/test_manage_users.py`: usam arquivos locais ignorados com as contas dedicadas de teste. Não enviam e-mails. As contas são desativadas ao terminar; registros auditáveis não são apagados.
