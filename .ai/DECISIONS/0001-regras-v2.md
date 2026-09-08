# ADR 0001 — Regras confirmadas da V2

Status: aceito pelo usuário em 07/09/2026. Complementa os documentos enviados; não muda a arquitetura Flutter + Supabase.

## Contas e permissões
- Sem cadastro público. Contas individuais de professor, gestor e admin.
- Só admin cria, desativa e altera contas/papéis. Gestores não administram usuários.
- Professor registra com sua identidade e lê suas ocorrências completas. Não altera registros finalizados.
- Professores leem resumo compartilhado por aluno: motivo, professor, data e indicação de cancelamento.
- Gestores leem todas as ocorrências completas e corrigem aluno, data da ocorrência, motivos, relato e providências.
- Toda correção exige justificativa e auditoria com valores anteriores, autor e instante. `created_at` e `created_by` são imutáveis.
- Cancelamento preserva o registro e aparece como Cancelada no histórico; não entra no total. Não há exclusão física de ocorrências.

## Alunos
- Sem login, ID próprio, nome e turma obrigatórios; RA opcional e único quando informado.
- Admin e gestor cadastram manualmente e importam CSV/XLSX com validação anterior à gravação.
- Coincidência de nome + turma sem RA exige revisão; nunca mesclar homônimos automaticamente.

## PDF e e-mail
- Banco é o histórico oficial; PDF temporário sob demanda.
- Gmail da V1 continua como remetente. Credenciais ficam fora do APK/Git.
- Os dois destinatários da V1 são de teste. Destinatários configuráveis no Supabase, sem recompilar APK.

## Validação
Testar controles no banco, incluindo requisições que contornam a interface, contas desativadas, imutabilidade, cancelamento, auditoria, duplicação de envio/salvamento e importação transacional. Testes reais autorizados no Redmi 8 limitados a este aplicativo.
