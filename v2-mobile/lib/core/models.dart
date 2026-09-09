class Student {
  const Student({
    required this.id,
    required this.name,
    required this.group,
    this.total = 0,
    this.ra,
  });
  final String id, name, group;
  final int total;
  final String? ra;
  factory Student.fromJson(Map<String, dynamic> row) => Student(
    id: row['id'],
    name: row['nome'],
    group: row['turma'],
    total: (row['total'] as num?)?.toInt() ?? 0,
    ra: row['ra'],
  );
  String get label => '$name — $group';
}

class Occurrence {
  Occurrence(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'];
  String get author => data['created_by'];
  String get professor => data['professor'] ?? data['profiles']?['nome'] ?? '';
  int get version => data['version'] ?? 1;
  bool get cancelled => data['status'] == 'cancelled';
  List<String> get reasons => List<String>.from(data['motivos']);
  List<String> get actions => List<String>.from(data['providencias'] ?? []);
  String get report => data['relato'] ?? '';
  DateTime get date => DateTime.parse(data['occurrence_date']);
  Student? get student => data['students'] == null
      ? null
      : Student.fromJson(Map<String, dynamic>.from(data['students']));
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
