import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/feedback.dart';
import '../../services/school_repository.dart';

class StudentSearchPage extends StatefulWidget {
  const StudentSearchPage({
    super.key,
    required this.repository,
    required this.onSelect,
    this.title = 'Histórico por aluno',
  });
  final SchoolRepository repository;
  final void Function(BuildContext, Student) onSelect;
  final String title;
  @override
  State<StudentSearchPage> createState() => _StudentSearchPageState();
}

class _StudentSearchPageState extends State<StudentSearchPage> {
  final query = TextEditingController();
  List<Student> students = [];
  bool busy = false, more = false, searched = false;
  String? error;
  String activeQuery = '';
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search({bool append = false}) async {
    if (busy) return;
    if (!append) {
      activeQuery = query.text.trim();
      if (activeQuery.length < 2) {
        setState(() => error = 'Digite pelo menos 2 letras.');
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.search(
        activeQuery,
        offset: append ? students.length : 0,
      );
      if (mounted) {
        setState(() {
          students = append ? [...students, ...result] : result;
          more = result.length == 50;
          searched = true;
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
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: query,
                    enabled: !busy,
                    onSubmitted: (_) => search(),
                    decoration: const InputDecoration(
                      labelText: 'Nome do aluno',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Pesquisar',
                  onPressed: busy ? null : search,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
          if (searched && students.isEmpty && !busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nenhum aluno encontrado.'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: students.length + (more ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == students.length) {
                  return TextButton(
                    onPressed: busy ? null : () => search(append: true),
                    child: const Text('Carregar mais'),
                  );
                }
                final s = students[index];
                return ListTile(
                  title: Text('${s.label} [${s.total}]'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onSelect(context, s),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
