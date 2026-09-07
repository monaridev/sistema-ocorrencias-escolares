# Sistema de Ocorrências Escolares

Histórico de evolução do sistema de registro de ocorrências disciplinares da E.E. João Paulo II.

## Versões

- [`v1-desktop`](./v1-desktop) — versão original em Python desktop. Continua como registro da primeira solução e recebeu a migração de SMTP para Gmail API.
- [`v2-mobile`](./v2-mobile) — nova versão mobile em Flutter, com autenticação e dados centralizados no Supabase (Auth + PostgreSQL + RLS).

## Arquitetura atual da V2

```text
Flutter
  ↓
Supabase
  ├─ Auth
  ├─ PostgreSQL
  └─ RLS / views ou RPCs seguras
```

A V2 não depende de um PC da escola funcionando como servidor e não exige um backend FastAPI hospedado separadamente. Enquanto o projeto permanecer dentro dos limites do plano gratuito do Supabase, não há necessidade de contratar um servidor próprio.

O histórico oficial é formado pelos dados estruturados do PostgreSQL. PDFs são gerados apenas quando necessários para envio ou uso administrativo e não fazem parte do histórico permanente.

Consulte [`v2-mobile/docs/v2-decisoes-arquitetura.md`](./v2-mobile/docs/v2-decisoes-arquitetura.md) para as decisões atuais e [`v2-mobile/docs/plano_execucao.md`](./v2-mobile/docs/plano_execucao.md) para o plano de implementação.

As [regras confirmadas](./v2-mobile/docs/regras_confirmadas.md) complementam esses documentos com permissões, auditoria, importação de alunos e configuração de destinatários de teste.
