import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocorrencias_escolares/main.dart';
import 'package:ocorrencias_escolares/features/auth/auth_service.dart';
import 'package:ocorrencias_escolares/core/config.dart';

class FakeAuth implements AuthService {
  final events = StreamController<void>.broadcast();
  @override
  String? userId;
  bool active = true, fail = false;
  int signIns = 0;
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<void> signIn(String email, String password) async {
    signIns++;
    if (fail) throw Exception('rede');
    userId = 'professor';
    events.add(null);
  }

  @override
  Future<void> signOut() async {
    userId = null;
    events.add(null);
  }

  @override
  Future<UserProfile> profile() async => UserProfile(
    id: 'professor',
    name: 'Professor de teste',
    role: 'professor',
    active: active,
  );
}

void main() {
  test('Configuração recusa segredos e URL sem HTTPS', () {
    expect(
      const AppConfig(
        'https://escola.supabase.co',
        'sb_secret_privada',
      ).isValid,
      isFalse,
    );
    expect(
      const AppConfig(
        'http://escola.supabase.co',
        'sb_publishable_publica',
      ).isValid,
      isFalse,
    );
    expect(
      const AppConfig(
        'https://escola.supabase.co',
        'sb_publishable_publica',
      ).isValid,
      isTrue,
    );
  });
  testWidgets('Login valida, autentica e logout remove área privada', (
    tester,
  ) async {
    final auth = FakeAuth();
    addTearDown(auth.events.close);
    await tester.pumpWidget(OcorrenciasApp(auth: auth));
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(auth.signIns, 0);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'professor@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-de-teste');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Professor de teste.'), findsOneWidget);
    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Olá, Professor de teste.'), findsNothing);
  });
  testWidgets('Conta desativada não abre área privada', (tester) async {
    final auth = FakeAuth()
      ..userId = 'professor'
      ..active = false;
    addTearDown(auth.events.close);
    await tester.pumpWidget(OcorrenciasApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sua conta está desativada'), findsOneWidget);
    expect(find.text('Olá, Professor de teste.'), findsNothing);
  });
  testWidgets('Falha permite nova tentativa e não revela erro interno', (
    tester,
  ) async {
    final auth = FakeAuth()..fail = true;
    addTearDown(auth.events.close);
    await tester.pumpWidget(OcorrenciasApp(auth: auth));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'teste@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-de-teste');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível entrar.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Entrar'))
          .onPressed,
      isNotNull,
    );
  });
}
