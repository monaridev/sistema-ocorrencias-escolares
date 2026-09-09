# ADR 0002 — Aluno na primeira ocorrência e contas pela gestão

Status: autorizado pelo usuário em 09/09/2026. Atualiza as restrições correspondentes da ADR 0001; a arquitetura Flutter + Supabase permanece.

- Professor pesquisa por nome completo e turma dentro de Nova ocorrência. Possíveis correspondências são apresentadas antes de oferecer novo cadastro.
- Havendo correspondência exata, selecionar o cadastro existente. Homônimos exatos precisam da revisão de gestor/admin, que já podem cadastrar alunos distintos após revisão.
- Sem correspondência, professor confirma nome/turma. Aluno e primeira ocorrência são gravados atomicamente; desistir do formulário não cria aluno e uma falha reverte ambos.
- IDs permanecem fixos ao repetir a confirmação. A validação no banco serializa criação/importação para impedir concorrência de duplicatas exatas.
- Professor não recebe tela geral de administração de alunos. Gestor/admin corrigem cadastros com justificativa e valores anteriores auditados.
- União de cadastros é explícita, justificada e preserva registros de origem; o cadastro duplicado fica vinculado ao escolhido. Histórico e contagem reúnem os cadastros vinculados, excluindo canceladas da contagem. Autoria e auditoria das ocorrências permanecem intactas. RAs conflitantes exigem correção prévia.
- Gestor cria contas professor/gestor e altera nome, papel e situação desses perfis. Não cria admin, não promove a admin e não modifica perfil ou login de admin.
- Na edição de contas existentes pelo gestor, o servidor altera somente o perfil. E-mail/senha existentes continuam restritos ao admin; isso evita que alterações de login atinjam uma conta promovida a admin durante uma operação concorrente.
- Admin mantém seus poderes anteriores. Nenhuma conta admin existente foi modificada para implementar essa mudança.
