class PracticeClip {
  final String id;
  final String name;
  final String languageCode;
  final String translation;
  final String mimeType;
  final String? blobUrl; // preferred
  final String? dataBase64; // legacy
  final int addedAt;

  const PracticeClip({
    required this.id,
    required this.name,
    required this.languageCode,
    required this.translation,
    required this.mimeType,
    this.blobUrl,
    this.dataBase64,
    required this.addedAt,
  });

  factory PracticeClip.fromMap(Map<String, dynamic> m) => PracticeClip(
    id: (m['id'] ?? '') as String,
    name: (m['name'] ?? '') as String,
    languageCode: (m['languageCode'] ?? 'zopau') as String,
    translation: (m['translation'] ?? '') as String,
    mimeType: (m['mimeType'] ?? 'audio/mpeg') as String,
    blobUrl: (m['blobUrl'] ?? null) as String?,
    dataBase64: (m['dataBase64'] ?? null) as String?,
    addedAt: (m['addedAt'] ?? 0) as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'languageCode': languageCode,
    'translation': translation,
    'mimeType': mimeType,
    'blobUrl': blobUrl,
    'dataBase64': dataBase64,
    'addedAt': addedAt,
  };
}
