// lib/services/database_service_web.dart
//
// Web database implementation using browser LocalStorage.
// Exposes the same `AppDatabase` API as the sqflite version so the rest
// of the app can be platform-agnostic via `database_universal.dart`.
//
// Storage layout (LocalStorage keys):
//  - 'db_words_v1'   : JSON-encoded List<Map<String, dynamic>>
//  - 'db_phrases_v1' : JSON-encoded List<Map<String, dynamic>>
//
// Notes:
//  - Enforces uniqueness on (english, target, languageCode) by REPLACE.
//  - Generates `id` if missing.
//  - `createdAt`/`updatedAt` are epoch ms integers.

import 'dart:convert';
import 'dart:math';
import 'dart:html' as html;

class AppDatabase {
  // --- Singleton ---
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static const _wordsKey = 'db_words_v1';
  static const _phrasesKey = 'db_phrases_v1';

  final _rand = Random();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // Ensure keys exist
    html.window.localStorage.putIfAbsent(_wordsKey, () => jsonEncode(<Map<String, dynamic>>[]));
    html.window.localStorage.putIfAbsent(_phrasesKey, () => jsonEncode(<Map<String, dynamic>>[]));
    _initialized = true;
  }

  Future<void> close() async {
    // Nothing to close for LocalStorage.
  }

  // ---------------------------------------------------------------------------
  // WORDS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getWords() async {
    await init();
    final list = _readList(_wordsKey);
    // Sort by english (case-insensitive)
    list.sort((a, b) => (a['english'] ?? '').toString().toLowerCase().compareTo(
          (b['english'] ?? '').toString().toLowerCase(),
        ));
    return list;
  }

  Future<void> bulkUpsertWords(List<Map<String, dynamic>> rows) async {
    await init();
    if (rows.isEmpty) return;

    final now = _now();
    final list = _readList(_wordsKey);

    // Build an index on unique key: english|target|languageCode
    final index = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      final k = _uKey(list[i]['english'], list[i]['target'], list[i]['languageCode']);
      index[k] = i;
    }

    for (final r in rows) {
      final english = _s(r['english']);
      final target = _s(r['target']);
      final languageCode = _s(r['languageCode'], fallback: 'zopau');
      if (english.isEmpty || target.isEmpty) continue;

      final category = _s(r['category']);
      final id = _s(r['id'], fallback: _genId());

      final data = {
        'id': id,
        'english': english,
        'target': target,
        'languageCode': languageCode,
        'category': category.isEmpty ? null : category,
        'createdAt': now,
        'updatedAt': now,
      };

      final key = _uKey(english, target, languageCode);
      if (index.containsKey(key)) {
        // replace existing
        final i = index[key]!;
        list[i] = { ...list[i], ...data, 'updatedAt': now };
      } else {
        index[key] = list.length;
        list.add(data);
      }
    }

    _writeList(_wordsKey, list);
  }

  Future<void> deleteWord(String id) async {
    await init();
    final list = _readList(_wordsKey)..removeWhere((e) => _s(e['id']) == id);
    _writeList(_wordsKey, list);
  }

  // ---------------------------------------------------------------------------
  // PHRASES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getPhrases() async {
    await init();
    final list = _readList(_phrasesKey);
    list.sort((a, b) => (a['english'] ?? '').toString().toLowerCase().compareTo(
          (b['english'] ?? '').toString().toLowerCase(),
        ));
    return list;
  }

  Future<void> bulkUpsertPhrases(List<Map<String, dynamic>> rows) async {
    await init();
    if (rows.isEmpty) return;

    final now = _now();
    final list = _readList(_phrasesKey);

    // Build index
    final index = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      final k = _uKey(list[i]['english'], list[i]['target'], list[i]['languageCode']);
      index[k] = i;
    }

    for (final r in rows) {
      final english = _s(r['english']);
      final target = _s(r['target']);
      final languageCode = _s(r['languageCode'], fallback: 'zopau');
      if (english.isEmpty || target.isEmpty) continue;

      final category = _s(r['category']);
      final audioUrl = _s(r['audioUrl']);
      final id = _s(r['id'], fallback: _genId());

      final data = {
        'id': id,
        'english': english,
        'target': target,
        'languageCode': languageCode,
        'category': category.isEmpty ? null : category,
        'audioUrl': audioUrl.isEmpty ? null : audioUrl,
        'createdAt': now,
        'updatedAt': now,
      };

      final key = _uKey(english, target, languageCode);
      if (index.containsKey(key)) {
        final i = index[key]!;
        list[i] = { ...list[i], ...data, 'updatedAt': now };
      } else {
        index[key] = list.length;
        list.add(data);
      }
    }

    _writeList(_phrasesKey, list);
  }

  Future<void> deletePhrase(String id) async {
    await init();
    final list = _readList(_phrasesKey)..removeWhere((e) => _s(e['id']) == id);
    _writeList(_phrasesKey, list);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _readList(String key) {
    final raw = html.window.localStorage[key];
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  void _writeList(String key, List<Map<String, dynamic>> list) {
    html.window.localStorage[key] = jsonEncode(list);
  }

  String _s(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  String _genId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _rand.nextInt(1 << 32).toRadixString(36);
    return '$ts$r';
  }

  String _uKey(dynamic english, dynamic target, dynamic languageCode) =>
      '${_s(english).toLowerCase()}|${_s(target).toLowerCase()}|${_s(languageCode).toLowerCase()}';
}
