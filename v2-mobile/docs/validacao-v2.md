# Validação e execução da V2

A arquitetura funcional continua definida nos documentos originais e nas decisões confirmadas em `.ai/DECISIONS/0001-regras-v2.md`.

## Executar

Copiar `config.example.json` para um arquivo local ignorado pelo Git, preencher URL e chave pública do Supabase e executar dentro de `v2-mobile`:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=../.local/app-config.json
flutter build apk --debug --dart-define-from-file=../.local/app-config.json
```

O APK debug é de validação. Assinatura definitiva de distribuição ainda deve ser configurada e guardada pelo responsável; não distribuir o build debug como versão final.

## Fluxos para conferir no aparelho

1. Admin/gestor cria professor individual ou gestor; professor não vê administração. Gestor não vê nem altera contas admin.
2. Admin desativa conta; nova consulta e retomada do app negam acesso.
3. Professor pesquisa nome/turma na nova ocorrência e confirma um aluno novo somente quando não houver correspondência. Sair antes de registrar não cria cadastro. Gestor/admin também cadastra aluno e importa CSV/XLSX: colunas nome, turma, ra opcional; homônimo exige revisão; RA duplicado não é mesclado.
4. Professor registra ocorrência. Outro professor vê apenas motivo, autor e data no histórico do aluno.
5. Gestor corrige com justificativa; auditoria preserva antes/depois. Cancelamento continua visível e sai da contagem.
6. Simular conexão interrompida ao registrar e repetir confirmação: mesmo ID, sem duplicação.
7. Gerar e imprimir PDF. Testar nomes acentuados, relato longo e ocorrência cancelada.
8. Autorizar Gmail, habilitar destinatários de teste e conferir envio real. Destinatários definitivos são configuração remota, sem recompilar.

Última situação: aparelho indisponível por decisão do usuário; autorização e envio real do Gmail adiados. Testes automatizados e build não substituem essa validação no aparelho.

Regras atualizadas: `.ai/DECISIONS/0002-cadastro-no-fluxo-e-gestao.md`. Em Administrar alunos, gestor/admin podem corrigir cadastro e unir históricos duplicados, sempre com justificativa. Na união, conferir canceladas visíveis e excluídas da contagem. O APK dessa mudança ainda precisa ser instalado no Moto G30, que desconectou durante a atualização.
