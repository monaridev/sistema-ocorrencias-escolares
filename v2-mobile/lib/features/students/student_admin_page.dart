import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/feedback.dart';
import '../../services/school_repository.dart';
import '../../services/student_import.dart';

class StudentAdminPage extends StatefulWidget {
  const StudentAdminPage({super.key, required this.repository});
  final SchoolRepository repository;
  @override
  State<StudentAdminPage> createState() => _StudentAdminPageState();
}

class _StudentAdminPageState extends State<StudentAdminPage> {
  final name = TextEditingController(),
      group = TextEditingController(),
      ra = TextEditingController();
  bool busy = false;
  String? message;
  @override
  void dispose() {
    name.dispose();
    group.dispose();
    ra.dispose();
    super.dispose();
  }

  Future<void> review(List<Map<String, dynamic>> rows) async {
    final preview = await widget.repository.preview(rows);
    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImportReviewPage(repository: widget.repository, rows: preview),
      ),
    );
    if (result != null && mounted) {
      setState(
        () => message =
            '${result['inserted']} aluno(s) cadastrado(s); ${result['skipped']} ignorado(s).',
      );
    }
  }

  Future<void> manual() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await review([
        {
          'nome': name.text.trim(),
          'turma': group.text.trim(),
          'ra': ra.text.trim(),
        },
      ]);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> file() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );
      if (picked == null) return;
      final selected = picked;
      if (await selected.length() > 5 * 1024 * 1024) {
        throw const FormatException('Use arquivos de até 5 MB.');
      }
      final bytes = await selected.readAsBytes();
      final sheets = await compute(parseStudentFile, {
        'bytes': bytes,
        'extension': selected.extension?.toLowerCase(),
      });
      if (!mounted) return;
      String? sheet = sheets.keys.first;
      if (sheets.length > 1) {
        sheet = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Escolha a aba'),
            children: sheets.keys
                .map(
                  (key) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, key),
                    child: Text(key),
                  ),
                )
                .toList(),
          ),
        );
      }
      if (sheet != null) await review(sheets[sheet]!);
    } catch (e) {
      if (mounted) {
        if (e is FormatException) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message.toString())));
        } else {
          showError(context, e);
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cadastrar alunos')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: name,
              enabled: !busy,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: group,
              enabled: !busy,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'Turma'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ra,
              enabled: !busy,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'RA/matrícula (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : manual,
              child: const Text('Revisar cadastro'),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: busy ? null : file,
              icon: const Icon(Icons.upload_file),
              label: const Text('Importar CSV ou XLSX'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Colunas: nome, turma e ra (opcional). Use RA como texto para preservar zeros à esquerda. Até 1000 alunos e 5 MB por arquivo. Nenhum aluno será gravado antes da revisão.',
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (message != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(message!)),
          ],
        ),
      ),
    ),
  );
}

class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({
    super.key,
    required this.repository,
    required this.rows,
  });
  final SchoolRepository repository;
  final List<Map<String, dynamic>> rows;
  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  late List<Map<String, dynamic>> rows;
  bool busy = false;
  String? error;
  bool needsReview = false;
  @override
  void initState() {
    super.initState();
    rows = widget.rows
        .map((r) => {...r, 'decision': r['state'] == 'ready' ? 'import' : null})
        .toList();
  }

  Future<void> submit() async {
    if (busy || needsReview) return;
    if (rows.any((r) => r['decision'] == null)) {
      setState(
        () => error = 'Revise todas as linhas pendentes antes de importar.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.importStudents(rows);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      needsReview = true;
      if (mounted) {
        setState(
          () => error =
              '${friendlyError(e)}\nAntes de repetir, volte e revise o arquivo novamente para conferir possíveis registros já importados.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Revisar ${rows.length} aluno(s)')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Homônimos não serão mesclados. Revise cada possível duplicidade.',
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                final state = row['state'];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${row['nome']} — ${row['turma']}'),
                        Text(
                          {
                                'ready': 'Pronto para importar',
                                'review':
                                    'Possível duplicidade: revisão obrigatória',
                                'invalid': 'Nome/turma ausente ou inválido',
                                'existing_ra':
                                    'RA já cadastrado: não será mesclado',
                                'duplicate_ra': 'RA repetido no arquivo',
                              }[state] ??
                              'Revisar',
                        ),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: row['decision'],
                          hint: const Text('Escolha uma ação'),
                          items: [
                            const DropdownMenuItem(
                              value: 'skip',
                              child: Text('Ignorar esta linha'),
                            ),
                            if (state == 'ready')
                              const DropdownMenuItem(
                                value: 'import',
                                child: Text('Importar'),
                              ),
                            if (state == 'review')
                              const DropdownMenuItem(
                                value: 'new',
                                child: Text('Confirmei: é outro aluno'),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) =>
                                    setState(() => row['decision'] = value),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: busy || needsReview ? null : submit,
              child: Text(busy ? 'Importando…' : 'Confirmar importação'),
            ),
          ),
        ],
      ),
    ),
  );
}
