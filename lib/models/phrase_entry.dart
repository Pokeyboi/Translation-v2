// lib/models/phrase_entry.dart
//
// Model for a dictionary "phrase" row.
// Mirrors the schema used by AppDatabase (both mobile and web implementations).
//
// Fields:
//  - id            : String (primary key; generated if absent)
//  - english       : String (required)
//  - target        : String (required)
//  - languageCode  : String (required; e.g., 'zopau')
//  - category      : String? (optional)
//  - audioUrl      : String? (optional; remote URL to audio pronunciation)
//  - createdAt     : int (epoch ms)
//  - updatedAt     : int (epoch ms)

class PhraseEntry {
  final String id;
  final String english;
  final String target;
  final String languageCode;
  final String? category;
  final String? audioUrl;
  final int createdAt;
  final int updatedAt;

  const PhraseEntry({
    required this.id,
    required this.english,
    required this.target,
    required this.languageCode,
    this.category,
    this.audioUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  PhraseEntry copyWith({
    String? id,
    String? english,
    String? target,
    String? languageCode,
    String? category = _sentinelString,
    String? audioUrl = _sentinelString,
    int? createdAt,
    int? updatedAt,
  }) {
    return PhraseEntry(
      id: id ?? this.id,
      english: english ?? this.english,
      target: target ?? this.target,
      languageCode: languageCode ?? this.languageCode,
      category: identical(category, _sentinelString) ? this.category : category,
      audioUrl: identical(audioUrl, _sentinelString) ? this.audioUrl : audioUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PhraseEntry.fromMap(Map<String, dynamic> map) {
    String s(dynamic v) => (v ?? '').toString();
    String? sOrNull(dynamic v) {
      final t = (v ?? '').toString().trim();
      return t.isEmpty ? null : t;
    }

    return PhraseEntry(
      id: s(map['id']),
      english: s(map['english']),
      target: s(map['target']),
      languageCode: s(map['languageCode']),
      category: sOrNull(map['category']),
      audioUrl: sOrNull(map['audioUrl']),
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
      'audioUrl': (audioUrl == null || audioUrl!.trim().isEmpty) ? null : audioUrl,
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
      'PhraseEntry(id: $id, "$english" → "$target", lang=$languageCode, cat=${category ?? '-'}, audio=${audioUrl ?? '-'})';

  @override
  int get hashCode =>
      id.hashCode ^
      english.hashCode ^
      target.hashCode ^
      languageCode.hashCode ^
      (category ?? '').hashCode ^
      (audioUrl ?? '').hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  bool operator ==(Object other) {
    return other is PhraseEntry &&
        other.id == id &&
        other.english == english &&
        other.target == target &&
        other.languageCode == languageCode &&
        other.category == category &&
        other.audioUrl == audioUrl &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }
}

// Private sentinel used to distinguish "no change" vs. "set to null" in copyWith.
const _sentinelString = Object();
