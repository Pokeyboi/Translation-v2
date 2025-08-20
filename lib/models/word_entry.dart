// lib/models/word_entry.dart
//
// Simple model for a dictionary "word" row.
// Mirrors the schema used by AppDatabase (both mobile and web implementations).
//
// Fields:
//  - id            : String (primary key; generated if absent)
//  - english       : String (required)
//  - target        : String (required)
//  - languageCode  : String (required; e.g., 'zopau')
//  - category      : String? (optional)
//  - createdAt     : int (epoch ms)
//  - updatedAt     : int (epoch ms)

class WordEntry {
  final String id;
  final String english;
  final String target;
  final String languageCode;
  final String? category;
  final int createdAt;
  final int updatedAt;

  const WordEntry({
    required this.id,
    required this.english,
    required this.target,
    required this.languageCode,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  WordEntry copyWith({
    String? id,
    String? english,
    String? target,
    String? languageCode,
    String? category = _sentinelString,
    int? createdAt,
    int? updatedAt,
  }) {
    return WordEntry(
      id: id ?? this.id,
      english: english ?? this.english,
      target: target ?? this.target,
      languageCode: languageCode ?? this.languageCode,
      category: identical(category, _sentinelString) ? this.category : category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WordEntry.fromMap(Map<String, dynamic> map) {
    String s(dynamic v) => (v ?? '').toString();
    String? sOrNull(dynamic v) {
      final t = (v ?? '').toString().trim();
      return t.isEmpty ? null : t;
    }

    return WordEntry(
      id: s(map['id']),
      english: s(map['english']),
      target: s(map['target']),
      languageCode: s(map['languageCode']),
      category: sOrNull(map['category']),
      createdAt: _toInt(map['createdAt']),
      updatedAt: _toInt(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'english': english,
      'target': target,
      'languageCode': languageCode,
      'category': (category == null || category!.trim().isEmpty) ? null : category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = (v ?? '').toString();
    return int.tryParse(s) ?? 0;
  }

  @override
  String toString() =>
      'WordEntry(id: $id, "$english" → "$target", lang=$languageCode, cat=${category ?? '-'})';

  @override
  int get hashCode =>
      id.hashCode ^
      english.hashCode ^
      target.hashCode ^
      languageCode.hashCode ^
      (category ?? '').hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  bool operator ==(Object other) {
    return other is WordEntry &&
        other.id == id &&
        other.english == english &&
        other.target == target &&
        other.languageCode == languageCode &&
        other.category == category &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }
}

// Private sentinel used to distinguish "no change" vs. "set to null" in copyWith.
const _sentinelString = Object();
