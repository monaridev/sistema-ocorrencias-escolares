# Estado da V2

Atualizado em 09/09/2026. Branch `codex/v2-supabase`. V1 preservada.

Implementado: Flutter Android com login e bloqueio de contas inativas; ocorrências próprias/completas conforme papel; histórico resumido; correção auditada e cancelamento sem exclusão; cadastro manual e revisão de CSV/XLSX; administração de contas exclusiva do admin; PDF temporário; configuração de destinatários e envio via Gmail em Edge Function.

Supabase `ocorrencias-v2` (`gndthsbyfyzmowavkhfl`): migrations 001–004 aplicadas via SQL Editor; primeiro admin ativo; signup público desabilitado; funções `manage-users` e `send-occurrence` implantadas. Ambas verificam identidade no Auth; verificador JWT legado desligado conforme config.toml. Migrações executadas pelo editor ainda não constam no ledger da CLI: não executar db push sem conciliar o histórico.

Validação: testes PostgreSQL reais locais (RLS, auditoria, importação, papéis, e-mail/deduplicação), Auth/Data API remotos, administração remota, 15 testes Flutter e 10 testes Deno aprovados; análise Flutter sem problemas. PDF local e anexo do servidor renderizados e conferidos visualmente. Build APK debug concluído; não é distribuição de produção assinada.

Gmail: OAuth antigo retornou invalid_grant em 08/09. Usuário informou em 09/09 que colocou a configuração em produção; nova autorização e teste de envio ficam para amanhã, por decisão dele. Dois destinatários de teste configurados; envio desabilitado e segredo GMAIL_OAUTH ainda ausente. Nenhum e-mail real enviado. Script scripts/authorize_gmail.py preparado para a reconexão, não executado.

Dispositivo: Redmi 8 bloqueou instalação; Moto G30 recebeu uma versão inicial. Usuário retirou o celular e autorizou continuidade sem aparelho. Teste completo da versão atual no Android real continua pendente.

Próximos passos: autorização Gmail, gravar segredo exclusivamente na Edge Function, habilitar destinatários de teste e validar envio real com autorização do usuário; validar fluxos no aparelho; definir/guardar assinatura Android de distribuição; trocar destinatários para os definitivos antes de uso escolar. Contas e registros automatizados possuem identificação [TESTE]; contas ficam inativas e ocorrências canceladas são preservadas.
