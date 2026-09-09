import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/models.dart';
import '../../core/feedback.dart';
import '../../services/school_repository.dart';

class OccurrenceStudentSelection {
  const OccurrenceStudentSelection(this.student, {this.isNew = false});
  final Student student;
  final bool isNew;
}

class OccurrenceStudentPicker extends StatefulWidget {
  const OccurrenceStudentPicker({super.key, required this.repository});
  final SchoolRepository repository;
  @override
  State<OccurrenceStudentPicker> createState() =>
      _OccurrenceStudentPickerState();
}

class _OccurrenceStudentPickerState extends State<OccurrenceStudentPicker> {
  final name = TextEditingController(), group = TextEditingController();
  List<Map<String, dynamic>>? matches;
  bool busy = false;
  String? error;
  String searchedName = '', searchedGroup = '';
  @override
  void dispose() {
    name.dispose();
    group.dispose();
    super.dispose();
  }

  void changed(String _) {
    setState(() {
      matches = null;
      error = null;
    });
  }

  Future<void> search() async {
    if (busy) return;
    final n = name.text.trim(), t = group.text.trim();
    if (n.length < 2 || t.isEmpty) {
      setState(() => error = 'Informe o nome completo e a turma.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      matches = null;
    });
    try {
      final result = await widget.repository.studentMatches(n, t);
      if (mounted) {
        setState(() {
          matches = result;
          searchedName = n;
          searchedGroup = t;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmNew() async {
    if (matches == null ||
        busy ||
        matches!.any((m) => m['exact_match'] == true)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar novo aluno'),
        content: Text(
          '$searchedName — $searchedGroup\n\nConfirme que não é nenhum dos alunos apresentados. O cadastro só será criado quando você registrar a primeira ocorrência.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar dados'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(
        context,
        OccurrenceStudentSelection(
          Student(
            id: const Uuid().v4(),
            name: searchedName,
            group: searchedGroup,
          ),
          isNew: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aluno da ocorrência')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: name,
          enabled: !busy,
          maxLength: 150,
          onChanged: changed,
          decoration: const InputDecoration(
            labelText: 'Nome completo do aluno',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: group,
          enabled: !busy,
          maxLength: 50,
          onChanged: changed,
          decoration: const InputDecoration(labelText: 'Turma'),
        ),
        FilledButton(
          onPressed: busy ? null : search,
          child: const Text('Pesquisar aluno'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (matches != null) ...[
          const SizedBox(height: 20),
          Text(
            matches!.isEmpty
                ? 'Nenhum aluno correspondente encontrado.'
                : 'Confira os possíveis alunos correspondentes:',
          ),
          for (final m in matches!)
            ListTile(
              title: Text('${m['nome']} — ${m['turma']}'),
              subtitle: Text(
                m['exact_match'] == true
                    ? 'Mesmo nome e turma'
                    : 'Possível correspondência',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(
                context,
                OccurrenceStudentSelection(Student.fromJson(m)),
              ),
            ),
          if (matches!.any((m) => m['exact_match'] == true))
            const Text(
              'Selecione o cadastro existente. Se for outro aluno com nome e turma idênticos, peça à gestão para revisar.',
            )
          else
            OutlinedButton(
              onPressed: confirmNew,
              child: const Text('Não é nenhum desses: usar novo aluno'),
            ),
        ],
      ],
    ),
  );
}
