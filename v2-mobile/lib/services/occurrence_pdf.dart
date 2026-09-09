import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import '../core/models.dart';
import '../core/occurrence_options.dart';

/// Coordenadas e elementos de gerar_pdf da V1. Manter o par do servidor em sincronia.
Future<Uint8List> occurrencePdf(Occurrence o, {DateTime? generatedAt}) async {
  if (o.student == null || !o.data.containsKey('relato')) {
    throw StateError('O PDF exige acesso ao registro completo.');
  }
  final doc = PdfDocument();
  PdfInfo(
    doc,
    title: 'Ficha de ocorrência disciplinar',
    subject: 'Registro ${o.id} | Versão ${o.version}',
  );
  final font = PdfFont.helvetica(doc), bold = PdfFont.helveticaBold(doc);
  final bytes = await rootBundle.load('assets/pdf/logo-sp.png');
  final logo = PdfImage.file(
    doc,
    bytes: bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  const cm = 72 / 2.54, w = 21 * cm, h = 29.7 * cm, blue = '0A2C5E';
  PdfColor color(String hex) =>
      PdfColor.fromInt(0xff000000 | int.parse(hex, radix: 16));
  var page = PdfPage(doc, pageFormat: PdfPageFormat.a4);
  var g = page.getGraphics();
  // PdfFont usa bytes Latin-1 como códigos WinAnsi. Converter os caracteres
  // adicionais explicitamente para conservar os sinais do formulário original.
  String winAnsi(String value) {
    const extra = <int, int>{
      0x20ac: 0x80,
      0x201a: 0x82,
      0x0192: 0x83,
      0x201e: 0x84,
      0x2026: 0x85,
      0x2020: 0x86,
      0x2021: 0x87,
      0x02c6: 0x88,
      0x2030: 0x89,
      0x0160: 0x8a,
      0x2039: 0x8b,
      0x0152: 0x8c,
      0x017d: 0x8e,
      0x2018: 0x91,
      0x2019: 0x92,
      0x201c: 0x93,
      0x201d: 0x94,
      0x2022: 0x95,
      0x2013: 0x96,
      0x2014: 0x97,
      0x02dc: 0x98,
      0x2122: 0x99,
      0x0161: 0x9a,
      0x203a: 0x9b,
      0x0153: 0x9c,
      0x017e: 0x9e,
      0x0178: 0x9f,
    };
    return String.fromCharCodes(
      value.runes.map((rune) {
        if (rune <= 255) return rune;
        if (extra.containsKey(rune)) return extra[rune]!;
        throw StateError(
          'O PDF não suporta o caractere ${String.fromCharCode(rune)}.',
        );
      }),
    );
  }

  double width(String s, [double size = 9, bool strong = false]) =>
      (strong ? bold : font).stringMetrics(winAnsi(s)).advanceWidth * size;
  void text(
    String s,
    double x,
    double y, [
    double size = 9,
    bool strong = false,
    String ink = '000000',
    bool center = false,
  ]) {
    g.setFillColor(color(ink));
    g.drawString(
      strong ? bold : font,
      size,
      winAnsi(s),
      center ? x - width(s, size, strong) / 2 : x,
      y,
    );
  }

  void line(
    double y, [
    String ink = 'CCCCCC',
    double x = 1.5 * cm,
    double end = w - 1.5 * cm,
  ]) {
    g.setStrokeColor(color(ink));
    g.setLineWidth(1);
    g.drawLine(x, y, end, y);
    g.strokePath();
  }

  void rect(
    double x,
    double y,
    double rw,
    double rh,
    String fill, [
    String? border,
  ]) {
    g.setFillColor(color(fill));
    g.drawRect(x, y, rw, rh);
    g.fillPath();
    if (border != null) {
      g.setStrokeColor(color(border));
      g.setLineWidth(1);
      g.drawRect(x, y, rw, rh);
      g.strokePath();
    }
  }

  List<String> wrap(String s, double max, [double size = 9]) {
    final rows = <String>[];
    var row = '';
    for (final word
        in s.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty)) {
      final trial = row.isEmpty ? word : '$row $word';
      if (width(trial, size) <= max) {
        row = trial;
        continue;
      }
      if (row.isNotEmpty) {
        rows.add(row);
        row = '';
      }
      for (final rune in word.runes) {
        final char = String.fromCharCode(rune);
        if (width(row + char, size) > max) {
          rows.add(row);
          row = '';
        }
        row += char;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  final extra = <({String title, List<String> rows})>[];
  void fitted(
    String label,
    String value,
    double x,
    double y, [
    double size = 9,
  ]) {
    final rows = wrap(value, w - 1.5 * cm - x, size);
    if (rows.length > 1) {
      text('Ver continuação', x, y, size);
      extra.add((title: label, rows: wrap(value, w - 3 * cm)));
    } else {
      text(rows.isEmpty ? '' : rows.first, x, y, size);
    }
  }

  void header() {
    rect(0, h - 3.4 * cm, w, 3.4 * cm, 'FFFFFF');
    line(h - 3.3 * cm);
    const lh = 2.2 * cm;
    final lw = lh * logo.width / logo.height;
    g.drawImage(logo, 1.5 * cm, h - 3.1 * cm, lw, lh);
    final x = 1.5 * cm + lw + .4 * cm;
    text('SECRETARIA DE ESTADO DA EDUCAÇÃO', x, h - 1.1 * cm, 10, true);
    text('UNIDADE REGIONAL DE ENSINO DE MAUÁ', x, h - 1.65 * cm);
    text('ESCOLA ESTADUAL E.E. JOÃO PAULO II', x, h - 2.15 * cm);
    text(
      'Rua Barnabé Costa, 57 – Campo Verde – Mauá – SP – CEP 09320-015',
      x,
      h - 2.65 * cm,
      7.5,
      false,
      '555555',
    );
    text(
      'Fone: (11) 4514-7259  –  E-mail: e038453a@educacao.sp.gov.br',
      x,
      h - 3.1 * cm,
      7.5,
      false,
      '555555',
    );
    if (o.cancelled) {
      text('CANCELADA', w - 4 * cm, h - .55 * cm, 10, true, 'B00020');
    }
  }

  // Horário da escola (UTC-3), inclusive quando o aparelho estiver em outro fuso.
  final time = (generatedAt ?? DateTime.now()).toUtc().subtract(
    const Duration(hours: 3),
  );
  final timestamp =
      '${formatDate(time)} às ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  void footer() {
    rect(0, 0, w, .7 * cm, blue);
    text(
      'Documento gerado em $timestamp  |  e038453a@educacao.sp.gov.br',
      w / 2,
      .22 * cm,
      7,
      false,
      '90B0E0',
      true,
    );
  }

  header();
  var y = h - 4.2 * cm;
  rect(1.5 * cm, y - .5 * cm, w - 3 * cm, .85 * cm, 'FFFFFF', '1A1A1A');
  text(
    'FICHA DE OCORRÊNCIA DISCIPLINAR',
    w / 2,
    y - .2 * cm,
    12,
    true,
    '1A1A1A',
    true,
  );
  void section(String title) {
    text(title, 1.5 * cm, y, 9, true, blue);
    line(y - .15 * cm, blue);
  }

  y -= 1.3 * cm;
  section('IDENTIFICAÇÃO');
  y -= .7 * cm;
  for (final (label, value, x) in [
    ('Nome do Aluno: ', o.student!.name, 4.1),
    ('Série: ', o.student!.group, 2.5),
    ('Data: ', formatDate(o.date), 2.4),
    ('Relatado por: ', o.professor, 3.7),
  ]) {
    text(label, 1.5 * cm, y, 9, true);
    fitted(label, value, x * cm, y);
    y -= .52 * cm;
  }
  y += .52 * cm;
  y -= cm;
  section('OCORRÊNCIA');
  y -= .5 * cm;
  void checkbox(String label, bool checked) {
    rect(
      1.5 * cm,
      y - .06 * cm,
      .28 * cm,
      .28 * cm,
      checked ? blue : 'FFFFFF',
      blue,
    );
    if (checked) text('X', 1.53 * cm, y - .01 * cm, 7, true, 'FFFFFF');
    text(label, 1.93 * cm, y);
    y -= .52 * cm;
  }

  final other = o.reasons
      .where(
        (r) =>
            !occurrenceReasons.take(occurrenceReasons.length - 1).contains(r),
      )
      .toList();
  for (final reason in occurrenceReasons) {
    checkbox(
      reason,
      reason == 'Outro' ? other.isNotEmpty : o.reasons.contains(reason),
    );
  }
  final otherText = other
      .map((r) => r.replaceFirst(RegExp(r'^Outro\s*:?\s*'), ''))
      .where((s) => s.isNotEmpty)
      .join('; ');
  if (otherText.isNotEmpty) {
    final ax = 2.35 * cm, ay = y + .07 * cm;
    line(ay, '333333', ax, ax + .25 * cm);
    g.drawLine(ax + .25 * cm, ay, ax + .16 * cm, ay + .06 * cm);
    g.strokePath();
    g.drawLine(ax + .25 * cm, ay, ax + .16 * cm, ay - .06 * cm);
    g.strokePath();
    fitted('Outro motivo', otherText, 2.75 * cm, y, 8.5);
    y -= .52 * cm;
  }
  y -= .4 * cm;
  section('RELATO DA OCORRÊNCIA');
  y -= .5 * cm;
  final report = wrap(o.report, w - 3 * cm);
  final shown = report.length > 8
      ? ['Ver relato integral na continuação.']
      : [...report];
  if (report.length > 8) {
    extra.add((title: 'RELATO DA OCORRÊNCIA', rows: report));
  }
  while (shown.length < 4) {
    shown.add('');
  }
  for (final row in shown) {
    text(row, 1.5 * cm, y);
    line(y - .15 * cm);
    y -= .55 * cm;
  }
  y -= .5 * cm;
  section('PROVIDÊNCIA TOMADA PELA EQUIPE GESTORA');
  y -= .5 * cm;
  final unknownActions = o.actions
      .where((a) => !occurrenceActions.contains(a))
      .toList();
  for (final action in occurrenceActions) {
    checkbox(
      action,
      o.actions.contains(action) ||
          (action == 'Outra' && unknownActions.isNotEmpty),
    );
  }
  if (unknownActions.isNotEmpty) {
    extra.add((
      title: 'Outras providências',
      rows: wrap(unknownActions.join('; '), w - 3 * cm),
    ));
  }
  y -= .6 * cm;
  line(y + .3 * cm, blue);
  text(
    'Registro no Livro de Ata de Ocorrências — Página Nº: ',
    1.5 * cm,
    y,
    9,
    true,
  );
  y -= .6 * cm;
  text('Ocorrência Atendida por: ', 1.5 * cm, y, 9, true);
  y -= .6 * cm;
  text('Ciência do Responsável: ', 1.5 * cm, y, 9, true);
  y -= 1.4 * cm;
  line(y + .3 * cm);
  for (final (x, label) in [
    (1.5 * cm, 'Assinatura do Aluno'),
    (w / 2 - 3.5 * cm, 'Assinatura do Responsável'),
    (w - 7.5 * cm, 'Assinatura da Equipe Gestora'),
  ]) {
    line(y, '555555', x, x + 5.5 * cm);
    text(label, x, y - .4 * cm, 7.5, false, '555555');
  }
  footer();
  final cancellation = o.data['change_reason'] as String? ?? '';
  if (o.cancelled && cancellation.isNotEmpty) {
    extra.add((
      title: 'Justificativa do cancelamento',
      rows: wrap(cancellation, w - 3 * cm),
    ));
  }
  var number = 1;
  void continuation() {
    page = PdfPage(doc, pageFormat: PdfPageFormat.a4);
    g = page.getGraphics();
    header();
    footer();
    y = h - 4.2 * cm;
    section('FICHA DE OCORRÊNCIA DISCIPLINAR — CONTINUAÇÃO ${++number}');
    y -= .65 * cm;
    text('Registro ${o.id} | Versão ${o.version}', 1.5 * cm, y, 8);
    y -= .8 * cm;
  }

  for (final block in extra) {
    if (number == 1 || y < 3 * cm) continuation();
    section(block.title);
    y -= .55 * cm;
    for (final row in block.rows) {
      if (y < 1.6 * cm) continuation();
      text(row, 1.5 * cm, y);
      line(y - .15 * cm);
      y -= .55 * cm;
    }
    y -= .5 * cm;
  }
  return doc.save();
}
