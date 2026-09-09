# Sistema de Ocorrências Escolares

Sistema desenvolvido para a **E.E. João Paulo II, em Mauá/SP**, para registrar ocorrências disciplinares, acompanhar o histórico dos alunos e produzir a ficha utilizada pela escola.

O projeto começou como um aplicativo desktop em Python, já utilizado e testado na escola. A V2 leva esse fluxo para Android e centraliza os registros no Supabase, com contas individuais e permissões para professores e equipe gestora. Este repositório reúne as duas versões, o banco de dados e as decisões que orientam essa evolução.

## Da ficha ao histórico do aluno

Na V1, o trabalho gira em torno do documento: preencher a ocorrência no computador, gerar a ficha em PDF e enviá-la por e-mail. Na V2, cada ocorrência passa a integrar o histórico do aluno, acessível conforme o papel de quem está usando o aplicativo.

O professor procura o aluno por nome e turma antes de registrar uma ocorrência. Se o aluno ainda não estiver cadastrado, pode confirmar seus dados dentro desse mesmo fluxo: o cadastro e a primeira ocorrência são salvos juntos. Possíveis correspondências aparecem antes da criação para evitar duplicatas.

A gestão acompanha os registros da escola, corrige informações com justificativa e resolve eventuais duplicidades de alunos. Correções preservam os valores anteriores, o responsável pela alteração e a data. Uma ocorrência cancelada permanece identificada no histórico, mas deixa de entrar na contagem do aluno.

**O histórico oficial da V2 fica no PostgreSQL.** O PDF é uma saída para envio, impressão ou uso administrativo. Seu formato preserva a ficha original da V1: logo, cabeçalho, caixas de seleção, linhas do relato, campos administrativos e assinaturas.

## Quem pode fazer o quê

Não há cadastro público. Cada profissional utiliza sua própria conta.

| Papel | Acesso e responsabilidades |
| --- | --- |
| **Professor** | Registra ocorrências e consulta integralmente as que criou. No histórico do aluno, vê o resumo das ocorrências de outros professores: motivo, autor e data. Pode cadastrar um aluno durante a primeira ocorrência, após pesquisar correspondências. |
| **Gestor** | Consulta todas as ocorrências completas, realiza correções auditadas, cancela registros e administra alunos, incluindo importação e resolução de duplicidades. Cria contas de professor/gestor e altera nome, papel e situação desses perfis, sem modificar contas admin. |
| **Admin** | Mantém o acesso administrativo completo, incluindo contas admin, alterações de login de contas existentes e configuração dos destinatários de e-mail. |

Alunos não possuem login. Seu cadastro utiliza um identificador interno único, nome e turma, com RA/matrícula opcional. A importação por CSV ou XLSX permite cadastrar turmas em lote, com validação e revisão de possíveis duplicidades.

## As duas versões

| | V1 — Desktop | V2 — Android |
| --- | --- | --- |
| **Uso** | Preenchimento e emissão da ficha no computador da escola | Registro e consulta por profissionais autenticados no aplicativo |
| **Tecnologias** | Python, CustomTkinter e ReportLab | Flutter/Dart e Supabase |
| **Registros** | Fichas salvas localmente em PDF | Dados centralizados no PostgreSQL, com histórico e auditoria |
| **E-mail** | Gmail API com OAuth | Gmail API por uma Edge Function do Supabase |
| **Situação** | Versão já testada na escola, preservada no repositório | Implementada e em validação final no aparelho e nas integrações |

## Como a V2 está organizada

O **Flutter** fornece a interface Android. O **Supabase Auth** autentica os profissionais, e o **PostgreSQL** guarda perfis, alunos, ocorrências e auditorias. As permissões são aplicadas no banco por **RLS** e operações protegidas, além dos controles apresentados na interface.

As **Edge Functions** executam a administração protegida de contas e o envio por Gmail. No envio, o servidor consulta o registro autorizado e gera o anexo a partir desses dados. Credenciais de e-mail e chaves privilegiadas ficam fora do aplicativo.

A V2 inicial funciona **online**, sem depender de um computador da escola como servidor ou de um backend FastAPI separado. Os destinatários de e-mail são configurados no sistema, sem precisar gerar outro APK para trocá-los.

## Estado atual

**Atualizado em 09/09/2026.** A V2 já inclui login, permissões por papel, registro e histórico de ocorrências, correções auditadas, cancelamento, cadastro de alunos no fluxo do professor, importação em lote, gestão de contas e geração de PDF no modelo da V1. O backend está implantado no Supabase, e há APK de desenvolvimento compilado.

As verificações realizadas incluem testes do banco e das permissões, testes de interface e serviços, chamadas ao Supabase e comparação dos PDFs com o gerador original. A atualização do PDF passou por 22 testes Flutter e 11 testes da função de PDF/e-mail, além da conferência visual.

Ainda faltam a validação do **APK mais recente no celular**, a **autorização e o teste real de envio pelo Gmail** e a **impressão em A4 na escola**. A assinatura Android para distribuição também precisa ser preparada. O APK atual é de desenvolvimento; a V2 ainda não está apresentada como uma entrega final de produção.

## Onde encontrar cada parte

| Pasta | Conteúdo |
| --- | --- |
| [`v1-desktop/`](v1-desktop/) | Aplicativo original em Python e suas instruções de uso |
| [`v2-mobile/`](v2-mobile/) | Aplicativo Flutter, testes e documentação funcional da V2 |
| [`supabase/`](supabase/) | Migrações do banco, regras de acesso, Edge Functions e testes |
| [`scripts/`](scripts/) | Ferramentas de validação e apoio à configuração; não são um servidor da aplicação |
| [`docs/`](docs/) | Página pública e política de privacidade relacionadas ao OAuth |
| [`.ai/DECISIONS/`](.ai/DECISIONS/) | Decisões confirmadas e ajustes posteriores ao planejamento inicial |

## Documentação

- **Para desenvolver:** [aplicativo Android](v2-mobile/README.md) e [backend Supabase](supabase/README.md).
- **Para entender o planejamento:** [arquitetura da V2](v2-mobile/docs/v2-decisoes-arquitetura.md) e [plano de execução](v2-mobile/docs/plano_execucao.md).
- **Para acompanhar as regras atuais:** [regras iniciais](.ai/DECISIONS/0001-regras-v2.md), [cadastro no fluxo e permissões da gestão](.ai/DECISIONS/0002-cadastro-no-fluxo-e-gestao.md) e [preservação do PDF da V1](.ai/DECISIONS/0003-pdf-modelo-v1.md). Essas decisões registram as atualizações ao plano original.
- **Para conferir os testes:** [validação da V2](v2-mobile/docs/validacao-v2.md).
