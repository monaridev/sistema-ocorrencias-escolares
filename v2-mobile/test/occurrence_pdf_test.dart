import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocorrencias_escolares/core/models.dart';
import 'package:ocorrencias_escolares/services/occurrence_pdf.dart';

void main() {
  test('PDF exige registro completo e identifica cancelamento', () async {
    final o = Occurrence({
      'id': '11111111-1111-1111-1111-111111111111',
      'created_by': 'author',
      'professor': 'Márcia de Oliveira',
      'students': {
        'id': 's',
        'nome': 'João Antônio de Souza',
        'turma': '2º B',
        'ra': '001234',
      },
      'occurrence_date': '2026-09-08',
      'motivos': ['Uso de celular', 'Outro: Conversas durante a atividade'],
      'providencias': ['Orientação ao aluno', 'Comunicação à família'],
      'relato':
          'O aluno recebeu orientação durante a atividade. A equipe gestora conversou com o responsável para acompanhar a situação.',
      'status': 'cancelled',
      'version': 2,
      'change_reason': 'Registro cancelado após revisão da equipe gestora.',
    });
    final bytes = await occurrencePdf(o);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
    if (Platform.environment['PDF_QA_OUTPUT'] case final String path) {
      await File(path).writeAsBytes(bytes);
    }
    await expectLater(
      occurrencePdf(Occurrence({'motivos': []})),
      throwsStateError,
    );
  });
}
