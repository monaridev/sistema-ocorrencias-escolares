# Plano de execução — Sistema de Ocorrências V2

## 1. Objetivo

Construir a V2 mobile de forma incremental, preservando histórico de commits, branches, PRs e testes pequenos.

A arquitetura atual é:

```text
Flutter/Dart → Supabase Auth + PostgreSQL + RLS
```

Não haverá FastAPI separado no MVP e não haverá dependência de um PC da escola funcionando como servidor.

O histórico oficial será o PostgreSQL. PDFs serão gerados apenas quando necessários e não serão armazenados permanentemente como histórico.

---

## 2. Regras funcionais que guiam a implementação

1. Cada professor terá uma conta própria.
2. Cada ocorrência será vinculada ao professor autenticado que a criou.
3. O professor poderá consultar suas próprias ocorrências completas.
4. O histórico de um aluno reunirá ocorrências registradas por professores diferentes.
5. O histórico resumido mostrará quantidade total, professor, motivo e data.
6. Cada aluno terá ID próprio e turma associada.
7. A quantidade de ocorrências será calculada diretamente dos registros do banco.
8. O histórico será carregado sob demanda após pesquisa do aluno.
9. RLS e consultas seguras devem proteger dados que não precisam ser visíveis a todos.
10. PDF não será usado como banco de histórico.

---

## 3. Cronograma faseado

| Fase | Descrição | Branch sugerida | Resultado mínimo |
|---|---|---|---|
| 0 | Atualizar documentação e preparar estrutura Flutter | `docs/arquitetura-v2-supabase` | Documentação consistente e projeto Flutter inicial executando |
| 1 | Criar projeto Supabase e modelar tabelas principais | `feature/supabase-schema` | `profiles`, `students` e `occurrences` criadas com relacionamentos básicos |
| 2 | Integrar Supabase Auth ao Flutter | `feature/auth-supabase` | Login funciona e o app conhece o usuário autenticado |
| 3 | Implementar roles, RLS e acesso seguro ao histórico resumido | `feature/rls-permissoes` | Professor não consegue burlar permissões; consulta resumida funciona |
| 4 | Implementar tela e fluxo de nova ocorrência | `feature/nova-ocorrencia` | Professor autenticado registra ocorrência vinculada ao próprio ID |
| 5 | Implementar “Minhas ocorrências” | `feature/minhas-ocorrencias` | Professor consulta registros completos criados por ele |
| 6 | Implementar pesquisa e histórico por aluno | `feature/historico-aluno` | Busca mostra aluno + turma + total; detalhe mostra professor, motivo e data |
| 7 | Gerar PDF localmente a partir de uma ocorrência | `feature/pdf-mobile` | PDF é gerado sob demanda sem ser salvo como histórico permanente |
| 8 | Integrar Gmail API para envio | `feature/gmail-api-mobile` | PDF pode ser enviado e o app informa sucesso/falha corretamente |
| 9 | Testes de integração, segurança e UX | `test/integracao-v2` | Fluxos principais testados em Android e regras de acesso revisadas |
| 10 | Empacotamento e validação na escola | `chore/release-v2` | APK de teste validado com usuários reais e documentação final atualizada |

Não avançar várias fases de uma vez. Cada fase deve ser revisável e testável isoladamente.

---

## 4. Modelagem inicial sugerida

A Fase 1 deve começar simples.

### `profiles`

```text
id          uuid  → auth.users.id
nome        text
role        text  → professor | gestor | admin
ativo       bool
created_at  timestamp
```

### `students`

```text
id          uuid ou bigint
nome        text
turma       text
ativo       bool
created_at  timestamp
```

### `occurrences`

```text
id           uuid ou bigint
student_id   FK → students.id
created_by   FK → profiles.id
motivo       text
relato       text
providencias text
created_at   timestamp
email_status text opcional
```

Motivos e providências podem virar tabelas relacionadas depois, se isso trouxer benefício real. Não normalizar por complexidade sem necessidade.

---

## 5. Segurança e permissões

A interface não é a camada de segurança.

O Supabase deve aplicar RLS desde cedo.

### Regra mínima esperada

- usuário autenticado pode inserir ocorrência apenas com `created_by = auth.uid()`;
- professor pode ler os registros completos que ele criou;
- gestor/admin pode receber permissões mais amplas;
- histórico resumido entre professores deve expor apenas os campos necessários.

Como RLS é orientada a linhas e o histórico compartilhado pode precisar esconder colunas como relato e providências, preferir uma view segura ou RPC específica para o resumo do aluno.

Exemplo de saída dessa consulta:

```text
student_id
professor_nome
motivo
data
```

O total deve ser calculado com `COUNT(*)` sobre as ocorrências do aluno.

---

## 6. Estrutura Flutter sugerida

```text
v2-mobile/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── supabase/
│   │   └── config/
│   ├── features/
│   │   ├── auth/
│   │   ├── occurrences/
│   │   └── history/
│   └── services/
│       ├── pdf_service.dart
│       └── email_service.dart
├── test/
└── docs/
```

Evitar criar camadas e abstrações sem uso. A estrutura pode crescer conforme o projeto realmente precisar.

---

## 7. Fluxos mínimos de teste

### Autenticação

- login válido entra no app;
- login inválido falha com mensagem adequada;
- logout encerra a sessão.

### Nova ocorrência

- professor autenticado consegue salvar;
- `created_by` corresponde ao usuário autenticado;
- usuário não consegue registrar ocorrência fingindo ser outro professor.

### Minhas ocorrências

- professor A vê seus registros completos;
- professor A não recebe detalhes completos privados de professor B sem permissão apropriada.

### Histórico do aluno

- pesquisa retorna aluno e turma;
- quantidade total corresponde aos registros reais;
- registros de professores diferentes aparecem no resumo;
- resumo mostra professor, motivo e data;
- nenhum PDF é necessário para consultar histórico.

### PDF e e-mail

- PDF é criado sob demanda;
- PDF não é persistido como histórico;
- sucesso e falha no envio são informados corretamente.

---

## 8. Convenções de Git

### Commits

- `feat:` nova funcionalidade
- `fix:` correção
- `docs:` documentação
- `test:` testes
- `refactor:` mudança sem alterar comportamento
- `chore:` configuração e manutenção

### Pull Requests

Cada PR deve responder:

1. O que mudou?
2. Como testar?
3. Houve mudança de arquitetura ou permissão?
4. A documentação precisa ser atualizada?

Evitar um único PR que implemente a V2 inteira.

---

## 9. O que foi removido do plano antigo

As seguintes decisões antigas não fazem mais parte da arquitetura atual do MVP:

- FastAPI como backend obrigatório;
- JWT próprio emitido pelo FastAPI;
- SQLModel como camada de persistência principal;
- SQLite como banco da V2;
- diretório `backend/` obrigatório;
- deploy separado de um servidor FastAPI;
- PDF gerado obrigatoriamente no servidor.

Foram substituídas por Supabase Auth, PostgreSQL, RLS e integração direta do Flutter com o Supabase.

---

## 10. Próximo passo imediato

Depois de atualizar estes documentos no GitHub:

1. criar/inicializar o projeto Flutter dentro de `v2-mobile`;
2. criar o projeto Supabase;
3. modelar apenas as tabelas essenciais;
4. configurar autenticação;
5. implementar e testar RLS antes de construir o fluxo completo de ocorrências.

A prioridade da primeira etapa da V2 é provar este caminho mínimo:

```text
login → usuário autenticado → salvar ocorrência → recuperar registro com permissão correta
```

Somente depois disso avançar para histórico, PDF e Gmail API.
