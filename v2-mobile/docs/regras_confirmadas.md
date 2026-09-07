# V2 — Regras confirmadas em 07/09/2026

Este complemento registra as decisões posteriores aos documentos de arquitetura e execução. Em caso de divergência, estas regras prevalecem.

## Contas

- Papéis: `professor`, `gestor` e `admin`.
- Não haverá cadastro público nem contas compartilhadas de professores.
- Somente admin cria, desativa e altera contas e papéis.
- Gestor consulta os dados da escola, mas não administra papéis.

## Ocorrências

- Professor cria registros vinculados à própria identidade autenticada e consulta suas ocorrências completas.
- Professores consultam o resumo das ocorrências de todos os professores por aluno: motivo, professor e data.
- Gestores consultam todas as ocorrências completas e podem corrigi-las.
- Correções de gestores registram autor e instante da alteração; registrar também o motivo é desejável.
- Não há exclusão permanente: registros incorretos são cancelados/invalidados, preservando o histórico.
- Após finalizar/enviar, professores não podem alterar silenciosamente o registro.

## Alunos e histórico

- Alunos não possuem login; cada aluno recebe ID interno único do banco.
- Nome e turma são obrigatórios; RA/matrícula, quando informado, deve ser único.
- Admin e gestor podem cadastrar alunos manualmente ou importar CSV/XLSX.
- A importação valida os dados e evita duplicação antes da gravação.
- Busca por nome mostra turma e total de ocorrências, calculado no PostgreSQL.
- O resumo inicial apresenta motivo, professor e data.

## Arquitetura e envio

- Flutter, Supabase Auth, PostgreSQL e RLS; sem FastAPI/servidor próprio obrigatório.
- MVP depende de internet. Histórico oficial no banco; PDF gerado sob demanda, sem arquivo permanente como histórico.
- Manter a conta remetente já configurada na V1; não versionar credenciais ou tokens.
- Os dois destinatários atuais da V1 são de teste.
- Destinatários da V2 serão configurados no Supabase, sem depender de recompilar o APK. A configuração de envio deve ter acesso administrativo restrito.
- Credenciais do remetente ficam fora do APK; operações privilegiadas de envio podem usar Edge Function.

## Detalhes a fechar na etapa correspondente

- Campos editáveis pelo gestor e obrigatoriedade do motivo da correção.
- Inclusão ou exclusão de registros cancelados no total exibido.
- Critério de correspondência na importação sem RA, incluindo homônimos.
- Destinatários oficiais e validação final com a escola.

## Sequência

Publicar os documentos, iniciar a base Flutter e validar cada etapa antes de ampliar o fluxo. Testar no Android antes da entrega do APK final assinado; trocar destinatários não exige recompilação, alterações no aplicativo podem exigir.
