import 'dart:async';
import 'package:ocorrencias_escolares/features/students/occurrence_student_picker.dart';
import 'package:ocorrencias_escolares/features/occurrences/occurrence_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ocorrencias_escolares/core/models.dart';
import 'package:ocorrencias_escolares/features/auth/auth_service.dart';
import 'package:ocorrencias_escolares/features/history/history_page.dart';
import 'package:ocorrencias_escolares/features/students/student_admin_page.dart';
import 'package:ocorrencias_escolares/features/accounts/accounts_page.dart';
import 'package:ocorrencias_escolares/services/school_repository.dart';

class TestRepository extends SchoolRepository {
  TestRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'public-test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int imports = 0, accountWrites = 0;
  bool failImport = false;
  final saves = <Map<String, dynamic>>[];
  bool existingMatch = true;
  @override
  Future<List<Map<String, dynamic>>> studentMatches(
    String name,
    String group,
  ) async => existingMatch
      ? [
          {'id': 's', 'nome': 'Ana', 'turma': '2 B', 'exact_match': true},
        ]
      : [];
  @override
  Future<void> createWithStudent(Map<String, dynamic> payload) =>
      create(payload);

  @override
  Future<List<Student>> search(String query, {int offset = 0}) async => [
    const Student(id: 's', name: 'Ana', group: '2 B'),
  ];
  @override
  Future<void> create(Map<String, dynamic> payload) async {
    saves.add(Map.of(payload));
    if (saves.length == 1) throw TimeoutException('Resposta perdida');
  }

  Map<String, dynamic>? account;
  @override
  Future<Map<String, dynamic>> importStudents(
    List<Map<String, dynamic>> rows,
  ) async {
    imports++;
    if (failImport) throw TimeoutException('Resposta perdida');
    return {'inserted': rows.length, 'skipped': 0};
  }

  @override
  Future<List<Occurrence>> history(String studentId, {int offset = 0}) async =>
      [
        Occurrence({
          'id': 'other',
          'created_by': 'another-teacher',
          'professor': 'Outro professor',
          'motivos': ['Atraso'],
          'occurrence_date': '2026-09-08',
          'status': 'cancelled',
        }),
      ];
  @override
  Future<Map<String, dynamic>> manageUsers(Map<String, dynamic> body) async {
    accountWrites++;
    account = body;
    return {'success': true};
  }
}

void main() {
  testWidgets(
    'Novo aluno só é gravado junto com a ocorrência e reutiliza IDs',
    (tester) async {
      final repo = TestRepository()..existingMatch = false;
      await tester.pumpWidget(
        MaterialApp(home: OccurrenceForm(repository: repo)),
      );
      await tester.tap(find.text('Selecionar aluno'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Nova Aluna');
      await tester.enterText(find.byType(TextField).at(1), '3 B');
      expect(find.text('Não é nenhum desses: usar novo aluno'), findsNothing);
      await tester.tap(find.text('Pesquisar aluno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Não é nenhum desses: usar novo aluno'));
      await tester.pumpAndSettle();
      expect(repo.saves, isEmpty);
      await tester.tap(find.text('Confirmar dados'));
      await tester.pumpAndSettle();
      expect(repo.saves, isEmpty);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Registrar ocorrência'));
      await tester.tap(find.text('Registrar ocorrência'));
      await tester.pumpAndSettle();
      expect(repo.saves.single['p_nome'], 'Nova Aluna');
      expect(repo.saves.single['p_turma'], '3 B');
      await tester.ensureVisible(find.text('Repetir confirmação'));
      await tester.tap(find.text('Repetir confirmação'));
      await tester.pumpAndSettle();
      expect(repo.saves[0], repo.saves[1]);
    },
  );
  testWidgets(
    'Correspondência exata impede novo cadastro e mudanças exigem nova busca',
    (tester) async {
      final repo = TestRepository();
      await tester.pumpWidget(
        MaterialApp(home: OccurrenceStudentPicker(repository: repo)),
      );
      await tester.enterText(find.byType(TextField).at(0), 'Ana');
      await tester.enterText(find.byType(TextField).at(1), '2 B');
      await tester.tap(find.text('Pesquisar aluno'));
      await tester.pumpAndSettle();
      expect(find.text('Mesmo nome e turma'), findsOneWidget);
      expect(find.text('Não é nenhum desses: usar novo aluno'), findsNothing);
      await tester.enterText(find.byType(TextField).at(1), '3 A');
      await tester.pumpAndSettle();
      expect(find.text('Mesmo nome e turma'), findsNothing);
      expect(repo.saves, isEmpty);
    },
  );

  testWidgets(
    'Repetir salvamento preserva ID e conteúdo após resposta perdida',
    (tester) async {
      final repo = TestRepository();
      await tester.pumpWidget(
        MaterialApp(home: OccurrenceForm(repository: repo)),
      );
      await tester.tap(find.text('Selecionar aluno'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Ana');
      await tester.enterText(find.byType(TextField).at(1), '2 B');
      await tester.tap(find.text('Pesquisar aluno'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Ana').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Registrar ocorrência'));
      await tester.tap(find.text('Registrar ocorrência'));
      await tester.pumpAndSettle();
      expect(repo.saves.length, 1);
      await tester.ensureVisible(find.text('Repetir confirmação'));
      await tester.tap(find.text('Repetir confirmação'));
      await tester.pumpAndSettle();
      expect(repo.saves.length, 2);
      expect(repo.saves[0], repo.saves[1]);
      expect(repo.saves[0].containsKey('created_by'), false);
    },
  );

  testWidgets('Homônimo exige revisão explícita antes da importação', (
    tester,
  ) async {
    final repo = TestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ImportReviewPage(
          repository: repo,
          rows: [
            {'nome': 'Ana', 'turma': '2 B', 'state': 'review'},
          ],
        ),
      ),
    );
    await tester.tap(find.text('Confirmar importação'));
    await tester.pump();
    expect(repo.imports, 0);
    expect(
      find.text('Revise todas as linhas pendentes antes de importar.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmei: é outro aluno').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar importação'));
    await tester.pumpAndSettle();
    expect(repo.imports, 1);
  });
  testWidgets('Timeout não permite repetir importação sem nova revisão', (
    tester,
  ) async {
    final repo = TestRepository()..failImport = true;
    await tester.pumpWidget(
      MaterialApp(
        home: ImportReviewPage(
          repository: repo,
          rows: [
            {'nome': 'Ana', 'turma': '2 B', 'state': 'ready'},
          ],
        ),
      ),
    );
    await tester.tap(find.text('Confirmar importação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar importação'));
    await tester.pumpAndSettle();
    expect(repo.imports, 1);
  });
  testWidgets('Professor vê cancelada de outro autor apenas como resumo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          repository: TestRepository(),
          student: const Student(id: 's', name: 'Ana', group: '2 B'),
          user: const UserProfile(
            id: 'teacher',
            name: 'Professor',
            role: 'professor',
            active: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Cancelada'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
    expect(find.text('Relato'), findsNothing);
  });
  testWidgets(
    'Conta exige nome e-mail e senha e envia papel padrão professor',
    (tester) async {
      final repo = TestRepository();
      await tester.pumpWidget(MaterialApp(home: AccountForm(repository: repo)));
      await tester.tap(find.text('Salvar conta'));
      await tester.pump();
      expect(repo.accountWrites, 0);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Professor de teste');
      await tester.enterText(fields.at(1), 'professor@example.com');
      await tester.enterText(fields.at(2), 'SenhaApenasDeTeste123');
      await tester.ensureVisible(find.text('Salvar conta'));
      await tester.tap(find.text('Salvar conta'));
      await tester.pumpAndSettle();
      expect(repo.accountWrites, 1);
      expect(repo.account!['role'], 'professor');
    },
  );
}
