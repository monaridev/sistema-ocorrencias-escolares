# Ocorrências Escolares — V2

Aplicativo Android da V2, com login Supabase, ocorrências, histórico de alunos, administração por papéis e PDF no modelo da V1. Para a visão geral, funcionalidades e estado da entrega, consulte o [README do repositório](../README.md). Este documento reúne as instruções de desenvolvimento.

## Desenvolvimento

Ambiente inicial: Flutter 3.44.4 / Dart 3.12.2, JDK 17 e Android SDK 36.

Configure o backend conforme o [guia do Supabase](../supabase/README.md). Crie `../.local/app-config.json` seguindo `config.example.json`, com a URL do seu projeto e sua chave pública. A pasta `.local` é ignorada pelo Git.

Na pasta `v2-mobile`:

```bash
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d ID_DO_ANDROID --dart-define-from-file=../.local/app-config.json
```

Para conectar o Android, habilite a depuração USB, conecte um cabo de dados e aceite a autorização no aparelho.

## APK de desenvolvimento

```bash
flutter build apk --debug --dart-define-from-file=../.local/app-config.json
```

Saída: `build/app/outputs/flutter-apk/app-debug.apk`. Este APK é de desenvolvimento. A assinatura de distribuição ainda precisa ser configurada antes da entrega final; o template Android usa chave de debug também para release.

Não adicionar ao Git credenciais, tokens, chaves de assinatura ou configurações secretas. As credenciais Gmail da V1 não devem ser copiadas para o aplicativo.

## Documentação

- [Arquitetura](docs/v2-decisoes-arquitetura.md)
- [Plano de execução](docs/plano_execucao.md)
- [Decisões confirmadas e suas atualizações](../.ai/DECISIONS/)
