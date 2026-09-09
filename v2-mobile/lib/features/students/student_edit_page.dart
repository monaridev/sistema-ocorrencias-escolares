import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/feedback.dart';
import '../../services/school_repository.dart';
import 'student_search_page.dart';

class StudentEditPage extends StatefulWidget {
  const StudentEditPage({
    super.key,
    required this.repository,
    required this.id,
  });
  final SchoolRepository repository;
  final String id;
  @override
  State<StudentEditPage> createState() => _StudentEditPageState();
}

class _StudentEditPageState extends State<StudentEditPage> {
  final name = TextEditingController(),
      group = TextEditingController(),
      ra = TextEditingController();
  Map<String, dynamic>? original;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    group.dispose();
    ra.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final s = await widget.repository.studentRecord(widget.id);
      if (mounted) {
        setState(() {
          original = s;
          name.text = s['nome'];
          group.text = s['turma'];
          ra.text = s['ra'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    if (busy || original == null) return;
    if (name.text.trim().isEmpty || group.text.trim().isEmpty) {
      setState(() => error = 'Informe nome e turma.');
      return;
    }
    final reason = await askReason(context, 'Justificar correção do aluno');
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repository.correctStudent({
        'p_id': widget.id,
        'p_version': original!['version'],
        'p_nome': name.text.trim(),
        'p_turma': group.text.trim(),
        'p_ra': ra.text.trim(),
        'p_reason': reason,
      });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> merge() async {
    if (busy || original == null) return;
    final target = await Navigator.push<Student>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSearchPage(
          repository: widget.repository,
          title: 'Escolher cadastro que será mantido',
          onSelect: (context, s) => Navigator.pop(context, s),
        ),
      ),
    );
    if (target == null || !mounted) return;
    if (target.id == widget.id) {
      setState(() => error = 'Escolha outro cadastro.');
      return;
    }
    setState(() => busy = true);
    try {
      final destination = await widget.repository.studentRecord(target.id);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Unir cadastros do mesmo aluno?'),
          content: Text(
            'Cadastro duplicado: ${original!['nome']} — ${original!['turma']}\n\nManter: ${target.label}\n\nO histórico será reunido sem apagar ocorrências.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('É o mesmo aluno'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final reason = await askReason(context, 'Justificar união de cadastros');
      if (reason == null || !mounted) return;
      await widget.repository.mergeStudents({
        'p_source': widget.id,
        'p_target': target.id,
        'p_source_version': original!['version'],
        'p_target_version': destination['version'],
        'p_reason': reason,
      });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Corrigir aluno')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: name,
          enabled: !busy,
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        TextField(
          controller: group,
          enabled: !busy,
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'Turma'),
        ),
        TextField(
          controller: ra,
          enabled: !busy,
          maxLength: 50,
          decoration: const InputDecoration(
            labelText: 'RA/matrícula (opcional)',
          ),
        ),
        if (error != null) Text(error!),
        if (busy) const LinearProgressIndicator(),
        FilledButton(
          onPressed: busy || original == null ? null : save,
          child: const Text('Salvar correção'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Se este cadastro pertence ao mesmo aluno de outro cadastro, una os históricos. Os dados do cadastro escolhido serão mantidos. RAs diferentes exigem revisão prévia.',
        ),
        OutlinedButton(
          onPressed: busy || original == null ? null : merge,
          child: const Text('Resolver duplicidade / unir históricos'),
        ),
      ],
    ),
  );
}
