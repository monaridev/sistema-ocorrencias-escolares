# Ocorrências Escolares — V2

Base Flutter para Android. Nesta primeira etapa há somente a tela inicial; login, Supabase, registros, PDF e envio serão implementados nas próximas etapas.

## Desenvolvimento

Ambiente inicial: Flutter 3.44.4 / Dart 3.12.2, JDK 17 e Android SDK 36.

Na pasta `v2-mobile`:

```bash
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d ID_DO_ANDROID
```

Para conectar o Android, habilite a depuração USB, conecte um cabo de dados e aceite a autorização no aparelho.

## APK de desenvolvimento

```bash
flutter build apk --debug
```

Saída: `build/app/outputs/flutter-apk/app-debug.apk`. Este APK é de desenvolvimento. A assinatura de distribuição ainda precisa ser configurada antes da entrega final; o template Android usa chave de debug também para release.

Não adicionar ao Git credenciais, tokens, chaves de assinatura ou configurações secretas. As credenciais Gmail da V1 não devem ser copiadas para o aplicativo.

## Documentação

- [Arquitetura](docs/v2-decisoes-arquitetura.md)
- [Plano de execução](docs/plano_execucao.md)
- [Regras confirmadas](docs/regras_confirmadas.md)
