import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/models.dart';
import '../../core/feedback.dart';
import '../../core/occurrence_options.dart';
import '../../services/school_repository.dart';
import '../students/student_search_page.dart';
import '../students/occurrence_student_picker.dart';

class OccurrenceForm extends StatefulWidget {
  const OccurrenceForm({super.key, required this.repository, this.existing});
  final SchoolRepository repository;
  final Occurrence? existing;
  @override
  State<OccurrenceForm> createState() => _OccurrenceFormState();
}

class _OccurrenceFormState extends State<OccurrenceForm> {
  final report = TextEditingController(),
      other = TextEditingController(),
      justification = TextEditingController();
  final id = const Uuid().v4();
  Student? student;
  bool newStudent = false;
  late DateTime date;
  Set<String> reasons = {}, actions = {};
  bool busy = false;
  Map<String, dynamic>? pending;
  String? error;
  bool get locked => busy || pending != null;
  @override
  void initState() {
    super.initState();
    final old = widget.existing;
    student = old?.student;
    date = old?.date ?? DateTime.now();
    report.text = old?.report ?? '';
    reasons = old?.reasons.toSet() ?? {};
    actions = old?.actions.toSet() ?? {};
  }

  @override
  void dispose() {
    report.dispose();
    other.dispose();
    justification.dispose();
    super.dispose();
  }

  Future<void> pickStudent() async {
    if (widget.existing == null) {
      final selection = await Navigator.push<OccurrenceStudentSelection>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OccurrenceStudentPicker(repository: widget.repository),
        ),
      );
      if (selection != null && mounted) {
        setState(() {
          student = selection.student;
          newStudent = selection.isNew;
        });
      }
      return;
    }
    final selected = await Navigator.push<Student>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSearchPage(
          repository: widget.repository,
          title: 'Selecionar aluno',
          onSelect: (context, s) => Navigator.pop(context, s),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => student = selected);
  }

  Future<void> save() async {
    if (busy) return;
    if (pending == null) {
      if (student == null ||
          reasons.isEmpty ||
          report.text.length > 400 ||
          (reasons.contains('Outro') && other.text.trim().isEmpty) ||
          (widget.existing != null && justification.text.trim().isEmpty)) {
        setState(
          () => error =
              'Selecione aluno e motivo, confira o limite do relato e preencha as descrições/justificativas necessárias.',
        );
        return;
      }
      pending = {
        'p_id': widget.existing?.id ?? id,
        'p_student_id': student!.id,
        if (newStudent) 'p_nome': student!.name,
        if (newStudent) 'p_turma': student!.group,
        'p_date': isoDate(date),
        'p_motivos': reasons
            .map(
              (r) => r == 'Outro' && other.text.trim().isNotEmpty
                  ? 'Outro: ${other.text.trim()}'
                  : r,
            )
            .toList(),
        'p_relato': report.text.trim(),
        'p_providencias': actions.toList(),
        if (widget.existing != null) 'p_version': widget.existing!.version,
        if (widget.existing != null) 'p_reason': justification.text.trim(),
      };
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.existing == null) {
        if (newStudent) {
          await widget.repository.createWithStudent(pending!);
        } else {
          await widget.repository.create(pending!);
        }
      } else {
        await widget.repository.correct(pending!);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              '${friendlyError(e)}\nOs dados foram mantidos. Repita a confirmação ou confira o histórico antes de criar outro registro.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.existing == null ? 'Nova ocorrência' : 'Corrigir ocorrência',
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: locked ? null : pickStudent,
              icon: const Icon(Icons.person_search),
              label: Text(student?.label ?? 'Selecionar aluno'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: locked
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100, 12, 31),
                      );
                      if (d != null && mounted) setState(() => date = d);
                    },
              icon: const Icon(Icons.calendar_today),
              label: Text('Data da ocorrência: ${formatDate(date)}'),
            ),
            const SizedBox(height: 24),
            Text('Motivos', style: Theme.of(context).textTheme.titleLarge),
            for (final r in {...occurrenceReasons, ...reasons})
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r),
                value: reasons.contains(r),
                onChanged: locked
                    ? null
                    : (v) => setState(
                        () => v == true ? reasons.add(r) : reasons.remove(r),
                      ),
              ),
            if (reasons.contains('Outro'))
              TextField(
                controller: other,
                enabled: !locked,
                maxLength: 450,
                decoration: const InputDecoration(
                  labelText: 'Descreva o outro motivo',
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: report,
              enabled: !locked,
              maxLines: 5,
              maxLength: 400,
              decoration: const InputDecoration(labelText: 'Relato'),
            ),
            const SizedBox(height: 16),
            Text('Providências', style: Theme.of(context).textTheme.titleLarge),
            for (final action in {...occurrenceActions, ...actions})
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(action),
                value: actions.contains(action),
                onChanged: locked
                    ? null
                    : (v) => setState(
                        () => v == true
                            ? actions.add(action)
                            : actions.remove(action),
                      ),
              ),
            if (widget.existing != null)
              TextField(
                controller: justification,
                enabled: !locked,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Justificativa da correção (obrigatória)',
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(error!),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(
                busy
                    ? 'Confirmando…'
                    : pending != null
                    ? 'Repetir confirmação'
                    : widget.existing == null
                    ? 'Registrar ocorrência'
                    : 'Salvar correção',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'O registro fica vinculado à conta que o criou. Correções são registradas no histórico de alterações.',
            ),
          ],
        ),
      ),
    ),
  );
}
