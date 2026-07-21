# Plano de execução — Sistema de Ocorrências (Desktop → Mobile + Backend)

> Este documento registra o plano de trabalho faseado para a refatoração do
> Sistema de Ocorrências da E.E. João Paulo II. O objetivo é conduzir a
> migração de forma incremental, com histórico de commits, PRs e testes que
> demonstrem o processo de desenvolvimento, não apenas o resultado final.

---

## 1. Visão geral

A refatoração segue a arquitetura definida em `arquitetura_sistema_ocorrencias.docx`
(v2, revisada com apoio do ChatGPT): backend em FastAPI como fonte da verdade,
autenticação JWT desde a primeira versão, PDF gerado no servidor via ReportLab,
histórico relacional em SQLite, e app mobile em Flutter consumindo uma API já
estável.

Este plano define **como** essa arquitetura será construída ao longo do tempo:
em fases pequenas, cada uma com sua branch, seu PR e seus testes mínimos.

---

## 2. Cronograma faseado

| Fase | Descrição | Branch | Testes mínimos da fase |
|---|---|---|---|
| 0 | Preparação: estrutura de pastas, ADRs iniciais, setup do Obsidian | `docs/setup-inicial` | — |
| 1 | Modelagem de dados (SQLModel): Ocorrencia, Usuario, Motivo, Providencia e tabelas de junção | `feature/modelagem-dados` | Modelo salva e recupera corretamente |
| 2 | Autenticação: tabela de usuários, login, JWT, papéis (professor/gestor/admin) | `feature/auth-jwt` | Login retorna JWT válido; rota protegida rejeita acesso sem token |
| 3 | Endpoint `POST /ocorrencia` (grava no banco, ainda sem PDF/e-mail) | `feature/endpoint-ocorrencia` | Professor autenticado cria ocorrência; usuário sem permissão não acessa histórico completo |
| 4 | Desacoplar `gerar_pdf()` do Tkinter no projeto atual; depois portar para `pdf_service.py` | `refactor/pdf-desacoplado` → `feature/pdf-service` | PDF é gerado corretamente a partir de dados de exemplo |
| 5 | Serviço de e-mail (background task), atualização de `email_status` | `feature/email-service` | Sucesso e falha no envio atualizam o status corretamente |
| 6 | Testes de integração de ponta a ponta + coleção Postman | `test/integracao-api` | Fluxo completo: login → criar ocorrência → PDF → e-mail |
| 7 | App Flutter — uma branch por tela | `feature/flutter-login`, `feature/flutter-formulario`, `feature/flutter-historico`, `feature/flutter-pdf-viewer` | Testes de widget básicos por tela |
| 8 | Polimento, revisão de segurança, deploy do backend, documentação final | `chore/deploy` | — |

Cada fase é fechada com um Pull Request, mesmo em desenvolvimento solo — a
auto-revisão antes do merge já documenta o raciocínio da mudança e cria
histórico de discussão real no repositório.

---

## 3. Estrutura de pastas do backend (referência da Fase 1 em diante)

```
backend/
├── routers/
│   ├── ocorrencias.py
│   └── auth.py
├── services/
│   ├── occurrence_service.py
│   ├── pdf_service.py
│   ├── email_service.py
│   └── storage_service.py
├── repositories/
│   └── occurrence_repository.py
├── models/
│   └── ... (entidades SQLModel)
├── tests/
│   └── ...
└── docs/
    └── adr/
```

`routers/` cuida apenas de HTTP (entrada/saída). `services/` concentra a regra
de negócio. `repositories/` isola o acesso ao banco. `storage_service.py`
abstrai onde os PDFs ficam salvos (filesystem local hoje; S3/Cloud Storage no
futuro, sem alterar a lógica de ocorrências).

---

## 4. Convenções de Git

### Commits (Conventional Commits)
- `feat:` — nova funcionalidade
- `fix:` — correção de bug
- `docs:` — apenas documentação
- `test:` — apenas testes
- `refactor:` — mudança de código sem alterar comportamento
- `chore:` — configuração, dependências, deploy

Exemplo: `feat: adiciona endpoint POST /ocorrencia`

### Branches
Prefixo por tipo, seguido de uma descrição curta:
`feature/`, `refactor/`, `test/`, `docs/`, `chore/`

Exemplo: `feature/auth-jwt`

### Template de PR
Todo PR deve conter:
1. **O que mudou** — resumo objetivo
2. **Como testar** — passos manuais ou comando de teste automatizado
3. **Checklist**:
   - [ ] Testes passando
   - [ ] Documentação (`.md`) atualizada
   - [ ] ADR criada/atualizada, se a mudança envolveu decisão de arquitetura

---

## 5. Testes mínimos da primeira versão

Lista base (expandir por fase, conforme a tabela da seção 2):
- Login retorna JWT válido
- Professor autenticado consegue criar ocorrência
- Usuário sem permissão não acessa histórico completo
- PDF é criado corretamente após uma ocorrência
- Falha no envio de e-mail atualiza `email_status` corretamente

---

## 6. Estrutura do vault Obsidian

```
00-Inbox/           → notas rápidas do dia a dia, organizadas depois
01-ADRs/            → uma nota por decisão de arquitetura, espelhando
                       /backend/docs/adr/ do repositório
                       Ex.: "0001 - Backend como fonte da verdade"
                            "0002 - JWT em vez de token fixo"
                            "0003 - Tabelas relacionadas em vez de JSON"
02-Sprints/         → uma nota por fase/semana: o que foi feito,
                       bloqueios, o que ficou pendente
03-Glossario/       → termos do domínio (ocorrência, providência,
                       ficha disciplinar)
04-Diagramas/       → export dos diagramas de arquitetura
```

As ADRs vivem nos dois lugares: rascunho e reflexão no Obsidian, versão final
commitada como `.md` no repositório em `/backend/docs/adr/`.

---

## 7. Princípio geral

O ritmo é deliberadamente incremental: cada fase deve resultar em um PR
pequeno, revisável, testável isoladamente — e não em um único commit grande
"reescreve o sistema inteiro". O histórico do repositório deve, por si só,
contar a história da migração.
