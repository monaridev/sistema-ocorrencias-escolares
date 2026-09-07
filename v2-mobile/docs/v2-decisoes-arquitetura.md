# Sistema de Ocorrências Escolares — Decisões da V2

## 1. Objetivo

A V2 transforma o sistema desktop em um aplicativo mobile simples para uso por vários professores, mantendo os dados centralizados sem depender de um computador da escola ligado como servidor.

A solução atual foi simplificada para:

```text
Professor → Flutter → Supabase → PostgreSQL
```

O Supabase fornece autenticação, acesso ao PostgreSQL e regras de segurança. Não será mantido um FastAPI separado no MVP.

---

## 2. Tecnologias definidas

### Flutter / Dart

Responsável pelo aplicativo mobile:

- login;
- nova ocorrência;
- minhas ocorrências;
- pesquisa de aluno;
- histórico do aluno;
- geração de PDF quando necessário;
- feedback de sucesso ou erro.

### Supabase Auth

Responsável pela autenticação dos usuários.

Cada professor ou gestor terá uma conta própria. A identidade autenticada será usada para vincular cada ocorrência ao usuário que a criou.

### Supabase PostgreSQL

Será o banco central da V2 e armazenará os dados estruturados do sistema:

- perfis de usuários;
- professores e gestores;
- alunos;
- turmas;
- ocorrências;
- motivos;
- providências;
- datas e status necessários.

### Row Level Security (RLS)

As permissões não devem depender apenas da interface Flutter. O próprio banco deve aplicar regras de acesso.

Quando alguma consulta exigir uma visão resumida diferente do acesso detalhado, usar uma view segura ou RPC do PostgreSQL/Supabase em vez de liberar a tabela inteira.

---

## 3. Sem servidor próprio obrigatório

A V2 não terá como requisito um PC da escola funcionando como servidor local e não terá, no MVP, um FastAPI hospedado separadamente.

Na prática:

```text
Flutter
   ↓
Supabase Auth + PostgreSQL
```

Isso elimina a necessidade de manter uma máquina sempre ligada ou pagar, desde o início, por um servidor de aplicação separado.

O projeto começará usando o plano gratuito do Supabase enquanto ele for suficiente. Caso o uso ultrapasse os limites desse plano no futuro, a infraestrutura será reavaliada.

---

## 4. Perfis e permissões

### Professor

Um professor autenticado poderá:

- criar ocorrências;
- visualizar as ocorrências completas que ele próprio registrou;
- pesquisar alunos;
- visualizar o histórico resumido de um aluno, incluindo registros feitos por outros professores.

### Histórico resumido compartilhado

O histórico do aluno deve mostrar, para usuários autorizados:

- quantidade total de ocorrências;
- professor responsável por cada registro;
- motivo;
- data.

O objetivo do histórico é consulta rápida. Relato completo, observações internas e providências detalhadas não precisam ser expostos a todos os professores.

### Gestor / administrador

Gestores poderão ter acesso administrativo mais amplo, incluindo consulta completa e tarefas de gestão de usuários e dados. Os detalhes finais de edição e cadastro de contas devem ser confirmados antes da etapa de produção.

---

## 5. Fluxo de uma ocorrência

Fluxo principal:

1. O professor entra no app com sua conta.
2. Preenche a ocorrência.
3. O Flutter envia os dados ao Supabase.
4. O PostgreSQL registra a ocorrência vinculada ao ID do professor autenticado.
5. O app confirma o registro.
6. Quando necessário, o PDF é gerado para envio ou uso administrativo.

Fluxo resumido:

```text
Professor
   ↓
Flutter
   ↓
Supabase Auth
   ↓
PostgreSQL
```

Não haverá um FastAPI obrigatório entre o Flutter e o Supabase no MVP.

---

## 6. Histórico por aluno

O histórico será pesquisado pelo aluno, não carregado inteiro ao abrir a tela.

Exemplo de busca:

```text
Pesquisar: Pedro

Pedro Henrique — 2º B [3]
Pedro Henrique — 1º A [1]
```

O número entre colchetes é a quantidade total de ocorrências do aluno e deve ser calculado a partir dos registros do banco, sem manter um contador manual separado.

Cada aluno terá um ID próprio para evitar confusão entre nomes iguais ou semelhantes.

---

## 7. Visualização do histórico

Ao abrir um aluno, o app mostra uma lista resumida:

```text
Pedro Henrique — 2º B [3]

Motivo: Uso de celular
Professor: Fernando
Data: 25/08/2026

Motivo: Atraso
Professor: Wagner
Data: 14/08/2026

Motivo: Desrespeito
Professor: Érica
Data: 03/08/2026
```

Essa lista pode combinar ocorrências registradas por professores diferentes.

Para isso, a camada de dados deve disponibilizar uma consulta segura de histórico resumido. Se a tabela principal de ocorrências contiver campos que não devem ser vistos por todos, o resumo deve ser fornecido por uma view/RPC específica.

---

## 8. Estrutura inicial de dados

A modelagem exata será feita na implementação, mas o núcleo esperado é:

```text
profiles
- id (mesmo UUID do usuário autenticado)
- nome
- role

students
- id
- nome
- turma

occurrences
- id
- student_id
- created_by
- motivo
- relato
- providencias
- created_at
- email_status (se necessário)
```

Motivos e providências podem ser normalizados em tabelas próprias caso isso seja útil para filtros e manutenção.

---

## 9. PDF e histórico

O PDF não é o histórico oficial da V2.

Regra:

```text
PostgreSQL = histórico oficial
PDF = saída temporária para envio, impressão ou uso administrativo
```

Não será necessário salvar permanentemente cada PDF no banco ou no storage do Supabase.

A geração deve acontecer somente quando necessária.

---

## 10. E-mail

A V1 já migrou para Gmail API, e a V2 deve manter Gmail API como direção para envio por e-mail.

A integração mobile será implementada em uma fase própria, depois que autenticação, banco e registro de ocorrências estiverem funcionando.

Se for necessário executar alguma operação com credenciais que não devam permanecer no aplicativo, poderá ser usada uma Supabase Edge Function específica. Isso não significa adicionar um servidor FastAPI permanente.

---

## 11. Internet e funcionamento offline

Como Auth e PostgreSQL ficam no Supabase, o MVP depende de internet para autenticar, sincronizar registros e consultar o histórico central.

Não haverá dependência de um PC da escola, mas também não será implementada uma sincronização offline complexa na primeira versão.

Se necessário no futuro, o app poderá ganhar rascunhos locais e fila de sincronização.

---

## 12. Decisões atuais consolidadas

- Flutter/Dart será usado no aplicativo mobile.
- Supabase Auth será usado para autenticação.
- PostgreSQL do Supabase será o banco central.
- RLS será usada para segurança de acesso.
- Não haverá FastAPI hospedado separadamente no MVP.
- Não haverá dependência de um PC da escola como servidor.
- Cada ocorrência será vinculada ao professor autenticado que a criou.
- O professor terá uma visão de suas próprias ocorrências.
- O histórico do aluno reunirá ocorrências de vários professores.
- O histórico resumido mostrará quantidade, professor, motivo e data.
- Cada aluno terá ID próprio e a turma aparecerá junto ao nome.
- O contador de ocorrências será calculado a partir dos registros existentes.
- O histórico será carregado sob demanda, a partir da busca por aluno.
- PDFs não serão armazenados como histórico permanente.
- Gmail API continua como direção para envio de e-mail.
- O projeto começará no plano gratuito do Supabase enquanto ele for suficiente.

---

## 13. Pontos ainda a confirmar

Antes de colocar a V2 em produção, ainda precisam ser fechados:

- quem poderá criar e desativar contas de professores;
- quais campos completos um gestor poderá editar depois do registro;
- qual conta do Gmail fará os envios na V2;
- se haverá importação em massa de alunos e turmas;
- se será necessário algum suporte offline além de rascunhos locais.

Esses pontos não impedem o início da V2.
