import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

Map<String, List<Map<String, dynamic>>> parseStudentFile(
  Map<String, dynamic> input,
) {
  final bytes = List<int>.from(input['bytes']);
  final extension = input['extension'] as String;
  if (bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Use arquivos de até 5 MB.');
  }
  if (extension == 'csv') {
    final content = utf8
        .decode(bytes)
        .replaceAll('\ufeff', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final first = content.split('\n').first;
    final separator =
        ';'.allMatches(first).length > ','.allMatches(first).length ? ';' : ',';
    final rows = CsvToListConverter(
      fieldDelimiter: separator,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);
    return {'CSV': _mapRows(rows)};
  }
  if (extension != 'xlsx') {
    throw const FormatException('Selecione CSV ou XLSX.');
  }
  final book = Excel.decodeBytes(bytes);
  final result = <String, List<Map<String, dynamic>>>{};
  for (final entry in book.tables.entries) {
    if (entry.value.maxRows == 0) continue;
    final rows = entry.value.rows
        .map(
          (row) => row.map((cell) {
            final value = cell?.value;
            if (value is FormulaCellValue) {
              throw const FormatException(
                'Substitua fórmulas por valores antes de importar.',
              );
            }
            return value?.toString() ?? '';
          }).toList(),
        )
        .toList();
    result[entry.key] = _mapRows(rows);
  }
  if (result.isEmpty) throw const FormatException('A planilha está vazia.');
  return result;
}

List<Map<String, dynamic>> _mapRows(List<List<dynamic>> rows) {
  final nonempty = rows
      .where((r) => r.any((c) => c.toString().trim().isNotEmpty))
      .toList();
  if (nonempty.isEmpty) throw const FormatException('Arquivo vazio.');
  final headers = nonempty.first
      .map((c) => c.toString().trim().toLowerCase())
      .toList();
  final name = headers.indexOf('nome'), group = headers.indexOf('turma');
  var ra = headers.indexOf('ra');
  if (ra < 0) ra = headers.indexOf('matrícula');
  if (ra < 0) ra = headers.indexOf('matricula');
  if (name < 0 || group < 0) {
    throw const FormatException(
      'A primeira linha deve conter as colunas nome e turma; ra é opcional.',
    );
  }
  if (headers.where((h) => h == 'nome').length != 1 ||
      headers.where((h) => h == 'turma').length != 1) {
    throw const FormatException('Há colunas obrigatórias repetidas.');
  }
  if (nonempty.length > 1001) {
    throw const FormatException('Importe até 1000 alunos por vez.');
  }
  String value(List row, int index) =>
      index < 0 || index >= row.length ? '' : row[index].toString().trim();
  return nonempty
      .skip(1)
      .map(
        (r) => {
          'nome': value(r, name),
          'turma': value(r, group),
          'ra': value(r, ra),
        },
      )
      .toList();
}
