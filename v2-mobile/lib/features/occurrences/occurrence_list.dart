import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/feedback.dart';
import '../../services/school_repository.dart';
import '../auth/auth_service.dart';
import 'occurrence_detail.dart';

class OccurrenceList extends StatefulWidget {
  const OccurrenceList({
    super.key,
    required this.repository,
    required this.user,
    this.mine = true,
  });
  final SchoolRepository repository;
  final UserProfile user;
  final bool mine;
  @override
  State<OccurrenceList> createState() => _OccurrenceListState();
}

class _OccurrenceListState extends State<OccurrenceList> {
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
      final data = await widget.repository.occurrences(
        mine: widget.mine,
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
    appBar: AppBar(
      title: Text(widget.mine ? 'Minhas ocorrências' : 'Todas as ocorrências'),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
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
              return ListTile(
                title: Text(o.student?.label ?? 'Aluno'),
                subtitle: Text(
                  '${formatDate(o.date)} · ${o.reasons.join(', ')}${o.cancelled ? '\nCancelada' : ''}',
                ),
                leading: Icon(
                  o.cancelled
                      ? Icons.cancel_outlined
                      : Icons.description_outlined,
                ),
                onTap: () async {
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
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
