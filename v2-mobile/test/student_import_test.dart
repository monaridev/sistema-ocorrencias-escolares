import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:ocorrencias_escolares/services/student_import.dart';

void main() {
  test('CSV preserva RA, acentos, delimitadores e campos entre aspas', () {
    final result = parseStudentFile({
      'extension': 'csv',
      'bytes': utf8.encode('nome;turma;ra\r\n"João; Silva";2B;00123\r\n'),
    });
    expect(result['CSV']!.single, {
      'nome': 'João; Silva',
      'turma': '2B',
      'ra': '00123',
    });
  });
  test('XLSX preserva valores de texto', () {
    final book = Excel.createExcel();
    final sheet = book['Sheet1'];
    sheet.appendRow([
      TextCellValue('nome'),
      TextCellValue('turma'),
      TextCellValue('ra'),
    ]);
    sheet.appendRow([
      TextCellValue('Érica'),
      TextCellValue('1A'),
      TextCellValue('00042'),
    ]);
    final result = parseStudentFile({
      'extension': 'xlsx',
      'bytes': book.encode()!,
    });
    expect(result['Sheet1']!.single['ra'], '00042');
    expect(result['Sheet1']!.single['nome'], 'Érica');
  });
  test('Arquivo sem cabeçalho obrigatório é rejeitado', () {
    expect(
      () => parseStudentFile({
        'extension': 'csv',
        'bytes': utf8.encode('aluno,sala\nJoão,2B'),
      }),
      throwsFormatException,
    );
  });
  test('Mais de 1000 alunos são rejeitados antes do envio', () {
    expect(
      () => parseStudentFile({
        'extension': 'csv',
        'bytes': utf8.encode(
          'nome,turma\n${List.filled(1001, 'Aluno,2B').join('\n')}',
        ),
      }),
      throwsFormatException,
    );
  });
}
