import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/models.dart';

/// Saída temporária: não grava PDF no banco ou no armazenamento local.
Future<Uint8List> occurrencePdf(Occurrence occurrence) async {
  if (occurrence.student == null || !occurrence.data.containsKey('relato')) {
    throw StateError('O PDF exige acesso ao registro completo.');
  }
  final doc = pw.Document(
    title: 'Ocorrência escolar',
    author: 'E.E. João Paulo II',
  );
  const blue = PdfColor.fromInt(0xff0a2c5e);
  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: blue,
      ),
    ),
  );
  final o = occurrence;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'E.E. JOÃO PAULO II',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: blue,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Ficha de ocorrência escolar',
            style: const pw.TextStyle(fontSize: 13),
          ),
          pw.Divider(color: blue),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Registro ${o.id} | Versão ${o.version}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'Cópia para consulta. Histórico oficial no sistema. | ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (_) => [
        if (o.cancelled)
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 12),
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.red50,
            child: pw.Text(
              'CANCELADA',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red900,
              ),
            ),
          ),
        heading('Identificação'),
        pw.Text('Aluno: ${o.student!.name}'),
        pw.SizedBox(height: 4),
        pw.Text('Turma: ${o.student!.group}'),
        if (o.student!.ra != null) pw.Text('RA/matrícula: ${o.student!.ra}'),
        pw.SizedBox(height: 4),
        pw.Text('Professor: ${o.professor}'),
        pw.Text('Data da ocorrência: ${formatDate(o.date)}'),
        heading('Motivos'),
        for (final reason in o.reasons)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('- $reason'),
          ),
        heading('Relato'),
        pw.Text(o.report.isEmpty ? 'Não informado' : o.report),
        heading('Providências'),
        if (o.actions.isEmpty) pw.Text('Não informadas'),
        for (final action in o.actions)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('- $action'),
          ),
        if (o.cancelled) ...[
          heading('Justificativa do cancelamento'),
          pw.Text(o.data['change_reason'] ?? ''),
        ],
        pw.SizedBox(height: 42),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            for (final label in ['Aluno', 'Responsável', 'Equipe gestora'])
              pw.SizedBox(
                width: 145,
                child: pw.Column(
                  children: [
                    pw.Divider(),
                    pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
