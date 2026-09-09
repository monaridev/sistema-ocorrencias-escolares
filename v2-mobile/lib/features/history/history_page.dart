import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/feedback.dart';
import '../../services/school_repository.dart';
import '../auth/auth_service.dart';
import '../occurrences/occurrence_detail.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.repository,
    required this.student,
    required this.user,
  });
  final SchoolRepository repository;
  final Student student;
  final UserProfile user;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Occurrence> records = [];
  bool busy = false, more = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.repository.history(
        widget.student.id,
        offset: append ? records.length : 0,
      );
      if (mounted) {
        setState(() {
          records = append ? [...records, ...data] : data;
          more = data.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histórico do aluno')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.student.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          TextButton(onPressed: load, child: Text('$error Tentar novamente')),
        if (!busy && records.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhuma ocorrência registrada.'),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: records.length + (more ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == records.length) {
                return TextButton(
                  onPressed: busy ? null : () => load(append: true),
                  child: const Text('Carregar mais'),
                );
              }
              final o = records[i];
              final canOpen =
                  widget.user.isManager || o.author == widget.user.id;
              return ListTile(
                title: Text(o.reasons.join(', ')),
                subtitle: Text(
                  '${o.professor} · ${formatDate(o.date)}${o.cancelled ? '\nCancelada' : ''}',
                ),
                leading: Icon(
                  o.cancelled
                      ? Icons.cancel_outlined
                      : Icons.description_outlined,
                ),
                trailing: canOpen ? const Icon(Icons.chevron_right) : null,
                onTap: canOpen
                    ? () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OccurrenceDetail(
                              repository: widget.repository,
                              id: o.id,
                              user: widget.user,
                            ),
                          ),
                        );
                        if (mounted) load();
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    ),
  );
}
