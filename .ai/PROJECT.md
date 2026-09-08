# Sistema de Ocorrências Escolares

V1 desktop preservada. V2: Flutter Android + Supabase Auth/PostgreSQL/RLS, sem FastAPI. MVP online. Documentação funcional em `v2-mobile/docs/` e decisões confirmadas em `.ai/DECISIONS/`.

Padrões compartilhados consultados: https://github.com/monaridev/monari-ai-brain (ENGINEERING, MOBILE_FLUTTER, DESIGN_SYSTEM, REPOSITORY_HYGIENE, workflows FEATURE/REVIEW/DEVICE_VALIDATION).

Manter implementação simples por feature, serviços fora de widgets, tema centralizado, commits pequenos, sem segredos ou artefatos gerados. Testar análise estática, regras de acesso, fluxos e Android real antes de declarar conclusão. Sem refatorações da V1.

O usuário autorizou implementação incremental e testes no Redmi 8. Em conflitos ou decisões importantes não definidas, parar e perguntar.
