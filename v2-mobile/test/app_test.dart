import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocorrencias_escolares/main.dart';

void main() {
  testWidgets('Tela inicial cabe em celular pequeno com texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const OcorrenciasApp());
    expect(find.text('E.E. João Paulo II'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
