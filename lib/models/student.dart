class Student {
  final String id;
  final String name;
  final String languageCode;
  final String notes;
  final int createdAt;
  final int updatedAt;

  const Student({
    required this.id,
    required this.name,
    required this.languageCode,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Student.fromMap(Map<String, dynamic> m) => Student(
    id: (m['id'] ?? '') as String,
    name: (m['name'] ?? '') as String,
    languageCode: (m['languageCode'] ?? 'zopau') as String,
    notes: (m['notes'] ?? '') as String,
    createdAt: (m['createdAt'] ?? 0) as int,
    updatedAt: (m['updatedAt'] ?? 0) as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'languageCode': languageCode,
    'notes': notes,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
