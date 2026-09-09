import 'package:flutter/material.dart';
import '../../services/school_repository.dart';
import '../auth/auth_service.dart';
import '../accounts/accounts_page.dart';
import '../email/email_settings_page.dart';
import '../occurrences/occurrence_form.dart';
import '../occurrences/occurrence_list.dart';
import '../students/student_search_page.dart';
import '../history/history_page.dart';
import '../students/student_admin_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.auth,
    required this.user,
  });
  final SchoolRepository repository;
  final AuthService auth;
  final UserProfile user;
  void open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ocorrências Escolares'),
      actions: [
        IconButton(
          tooltip: 'Sair',
          onPressed: auth.signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Olá, ${user.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('E.E. João Paulo II'),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () =>
                  open(context, OccurrenceForm(repository: repository)),
              icon: const Icon(Icons.add),
              label: const Text('Nova ocorrência'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => open(
                context,
                OccurrenceList(repository: repository, user: user),
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Minhas ocorrências'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => open(
                context,
                StudentSearchPage(
                  repository: repository,
                  onSelect: (context, s) => open(
                    context,
                    HistoryPage(repository: repository, student: s, user: user),
                  ),
                ),
              ),
              icon: const Icon(Icons.person_search),
              label: const Text('Histórico por aluno'),
            ),
            if (user.isAdmin) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    open(context, EmailSettingsPage(repository: repository)),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Configurar e-mail'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    open(context, AccountsPage(repository: repository)),
                icon: const Icon(Icons.manage_accounts),
                label: const Text('Administrar contas'),
              ),
            ],
            if (user.isManager) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    open(context, StudentAdminPage(repository: repository)),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Cadastrar alunos'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => open(
                  context,
                  OccurrenceList(
                    repository: repository,
                    user: user,
                    mine: false,
                  ),
                ),
                icon: const Icon(Icons.list_alt),
                label: const Text('Todas as ocorrências'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
