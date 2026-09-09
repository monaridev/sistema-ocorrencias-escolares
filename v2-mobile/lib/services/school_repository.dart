import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models.dart';

class SchoolRepository {
  SchoolRepository(this.client);
  final SupabaseClient client;
  Future<List<Student>> search(String query, {int offset = 0}) async {
    final rows = await client.rpc(
      'search_students',
      params: {'p_query': query, 'p_offset': offset},
    );
    return (rows as List)
        .map((row) => Student.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Occurrence>> history(String studentId, {int offset = 0}) async {
    final rows = await client.rpc(
      'student_history',
      params: {'p_student_id': studentId, 'p_offset': offset},
    );
    return (rows as List)
        .map((row) => Occurrence(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Occurrence>> occurrences({
    required bool mine,
    int offset = 0,
  }) async {
    var q = client
        .from('occurrences')
        .select('*,students(*),profiles!created_by(nome)');
    if (mine) q = q.eq('created_by', client.auth.currentUser!.id);
    final rows = await q
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + 49);
    return rows.map(Occurrence.new).toList();
  }

  Future<Occurrence> occurrence(String id) async => Occurrence(
    await client
        .from('occurrences')
        .select('*,students(*),profiles!created_by(nome)')
        .eq('id', id)
        .single(),
  );
  Future<void> create(Map<String, dynamic> payload) async {
    await client.rpc('create_occurrence', params: payload);
  }

  Future<void> correct(Map<String, dynamic> payload) async {
    await client.rpc('correct_occurrence', params: payload);
  }

  Future<void> cancel(Occurrence occurrence, String reason) async {
    await client.rpc(
      'cancel_occurrence',
      params: {
        'p_id': occurrence.id,
        'p_version': occurrence.version,
        'p_reason': reason,
      },
    );
  }

  Future<List<Map<String, dynamic>>> audit(String id) async => await client
      .from('occurrence_audit')
      .select('*,profiles!changed_by(nome)')
      .eq('occurrence_id', id)
      .order('changed_at', ascending: false);
  Future<List<Map<String, dynamic>>> preview(
    List<Map<String, dynamic>> rows,
  ) async => List<Map<String, dynamic>>.from(
    await client.rpc('preview_students', params: {'p_rows': rows}),
  );
  Future<Map<String, dynamic>> importStudents(
    List<Map<String, dynamic>> rows,
  ) async => Map<String, dynamic>.from(
    await client.rpc('import_students', params: {'p_rows': rows}),
  );
  Future<Map<String, dynamic>> manageUsers(Map<String, dynamic> body) async {
    final response = await client.functions.invoke('manage-users', body: body);
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> emailSettings() async =>
      await client.from('email_settings').select().eq('id', true).single();
  Future<void> configureEmail(List<String> recipients, bool enabled) async {
    await client.rpc(
      'configure_email',
      params: {'p_recipients': recipients, 'p_enabled': enabled},
    );
  }

  Future<Map<String, dynamic>> sendEmail(Occurrence o) async {
    final response = await client.functions.invoke(
      'send-occurrence',
      body: {'id': o.id, 'version': o.version},
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> emailDeliveries(String id) async =>
      await client
          .from('email_deliveries')
          .select()
          .eq('occurrence_id', id)
          .order('created_at', ascending: false);
}
