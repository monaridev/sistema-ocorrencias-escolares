# Estado da V2

Atualizado em 09/09/2026. Branch `codex/v2-supabase`. V1 preservada.

Implementado: Flutter Android com login e bloqueio de contas inativas; ocorrências próprias/completas conforme papel; histórico resumido; correção auditada e cancelamento sem exclusão; cadastro manual e revisão de CSV/XLSX; administração de contas exclusiva do admin; PDF temporário; configuração de destinatários e envio via Gmail em Edge Function.

Supabase `ocorrencias-v2` (`gndthsbyfyzmowavkhfl`): migrations 001–007 aplicadas via SQL Editor; primeiro admin ativo; signup público desabilitado; funções `manage-users` e `send-occurrence` implantadas. Ambas verificam identidade no Auth; verificador JWT legado desligado conforme config.toml. Migrações executadas pelo editor ainda não constam no ledger da CLI: não executar db push sem conciliar o histórico.

Validação: testes PostgreSQL reais locais (RLS, auditoria, importação, papéis, e-mail/deduplicação), Auth/Data API remotos, administração remota, 17 testes Flutter e 5 testes Deno de contas aprovados (6 testes Gmail previamente aprovados); análise Flutter sem problemas. PDF local e anexo do servidor renderizados e conferidos visualmente. Build APK debug concluído; não é distribuição de produção assinada.

Gmail: OAuth antigo retornou invalid_grant em 08/09. Usuário informou em 09/09 que colocou a configuração em produção; nova autorização e teste de envio ficam para amanhã, por decisão dele. Dois destinatários de teste configurados; envio desabilitado e segredo GMAIL_OAUTH ainda ausente. Nenhum e-mail real enviado. Script scripts/authorize_gmail.py preparado para a reconexão, não executado.

Dispositivo: Moto G30 recebeu o APK anterior. O APK com as regras da ADR 0002 foi compilado, mas o celular desconectou antes da atualização. Instalação dessa versão e teste completo no aparelho continuam pendentes.

Próximos passos: autorização Gmail, gravar segredo exclusivamente na Edge Function, habilitar destinatários de teste e validar envio real com autorização do usuário; validar fluxos no aparelho; definir/guardar assinatura Android de distribuição; trocar destinatários para os definitivos antes de uso escolar. Contas e registros automatizados possuem identificação [TESTE]; contas ficam inativas e ocorrências canceladas são preservadas.

ADR 0002 implementada: cadastro atômico do aluno junto da primeira ocorrência, busca nome/turma, gestão de contas professor/gestor sem atingir admin, correção auditada de alunos e união explícita de históricos. Testes reais de API confirmaram criação/repetição, bloqueio de duplicidade e união/cancelamento. Gmail continua desabilitado conforme adiamento do usuário.

## PDF alinhado à V1 (09/09/2026)

Renderers Flutter e Edge Function `send-occurrence` agora reproduzem o formulário V1 (logo original, coordenadas/fontes, caixas de seleção, relato pautado, campos finais, assinaturas e rodapé). Decisões complementares em `DECISIONS/0003-pdf-modelo-v1.md`. Modelo normal comparado diretamente com o gerador original, e cinco cenários conferidos entre Flutter/servidor, incluindo textos longos e cancelamento. 22 testes Flutter, análise sem problemas e 11 testes Deno de PDF/e-mail passaram. Edge Function atualizada e HTTP 401 sem autenticação verificado. APK debug reconstruído com sucesso; aparelho ausente no ADB, sem instalação nesta etapa. Envio real de Gmail continua pendente da autorização combinada com o usuário.
