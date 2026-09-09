# PDF da V2 deve preservar a ficha da V1

Confirmado pelo usuário em 09/09/2026.

- Aplicativo e anexo do e-mail reproduzem a função `gerar_pdf` da V1: A4, logo original, cabeçalho, Helvetica, coordenadas, opções com caixas de seleção, linhas do relato, campos finais, assinaturas e rodapé.
- Página do livro de atas, ocorrência atendida por e ciência do responsável permanecem em branco para preenchimento manual; não criar campos novos no aplicativo/banco.
- Quando algum texto ultrapassar o espaço disponível, indicar continuação e preservar o conteúdo completo em folha adicional com o mesmo cabeçalho e rodapé. Não truncar nem reduzir até ficar ilegível.
- Cancelamentos continuam claramente identificados; justificativa preservada na continuação. ID e versão ficam nos metadados do PDF e nas folhas adicionais.
- V1 e arquitetura Flutter + Supabase preservadas. PDF continua temporário; PostgreSQL continua sendo o histórico oficial.
