// lib/providers/dictionary_provider.dart
//
// ChangeNotifier that mediates between UI and the AppDatabase.
// Works on mobile/desktop (sqflite) and on web (LocalStorage) via
// the conditional export in `services/database_universal.dart`.
//
// Exposes:
//   - loadWords(), loadPhrases()
//   - words, phrases (List<...> getters)
//   - wordCategories, phraseCategories (unique category lists)
//   - bulkUpsertWords(rows), bulkUpsertPhrases(rows)  // from CSV or programmatic
//   - bulkUpsert(rows) -> alias for bulkUpsertPhrases
//   - deleteWord(id), deletePhrase(id)
//
// Models are in lib/models/word_entry.dart and phrase_entry.dart.

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../services/database_universal.dart'; // exports the correct AppDatabase per platform
import '../models/word_entry.dart';
import '../models/phrase_entry.dart';

class DictionaryProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();

  List<WordEntry> _words = <WordEntry>[];
  List<PhraseEntry> _phrases = <PhraseEntry>[];

  bool _initialized = false;

  // ---------------- Public getters ----------------

  List<WordEntry> get words => List<WordEntry>.unmodifiable(_words);
  List<PhraseEntry> get phrases => List<PhraseEntry>.unmodifiable(_phrases);

  List<String> get wordCategories => _uniqueCategories(_words.map((w) => w.category));
  List<String> get phraseCategories => _uniqueCategories(_phrases.map((p) => p.category));

  // ---------------- Lifecycle ----------------

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _db.init();
    _initialized = true;
  }

  // ---------------- Loaders ----------------

  Future<void> loadWords() async {
    await _ensureInit();
    final maps = await _db.getWords();
    _words = maps.map((m) => WordEntry.fromMap(m)).toList(growable: false);
    notifyListeners();
  }

  Future<void> loadPhrases() async {
    await _ensureInit();
    final maps = await _db.getPhrases();
    _phrases = maps.map((m) => PhraseEntry.fromMap(m)).toList(growable: false);
    notifyListeners();
  }

  // ---------------- Bulk upserts (CSV/import) ----------------

  /// Upsert a batch of word rows in the format:
  /// { english, target, languageCode, category?, id?, createdAt?, updatedAt? }
  Future<void> bulkUpsertWords(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _ensureInit();
    await _db.bulkUpsertWords(rows);
    // Refresh local cache efficiently:
    await loadWords();
  }

  /// Upsert a batch of phrase rows in the format:
  /// { english, target, languageCode, category?, audioUrl?, id?, createdAt?, updatedAt? }
  Future<void> bulkUpsertPhrases(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _ensureInit();
    await _db.bulkUpsertPhrases(rows);
    await loadPhrases();
  }

  /// Back-compat alias used by some screens (treated as phrases import).
  Future<void> bulkUpsert(List<Map<String, dynamic>> rows) => bulkUpsertPhrases(rows);

  // ---------------- Deletion ----------------

  Future<void> deleteWord(String id) async {
    await _ensureInit();
    await _db.deleteWord(id);
    // Update local cache without a full reload:
    _words = _words.where((w) => w.id != id).toList(growable: false);
    notifyListeners();
  }

  Future<void> deletePhrase(String id) async {
    await _ensureInit();
    await _db.deletePhrase(id);
    _phrases = _phrases.where((p) => p.id != id).toList(growable: false);
    notifyListeners();
  }

  // ---------------- Helpers ----------------

  List<String> _uniqueCategories(Iterable<String?> cats) {
    final s = SplayTreeSet<String>((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final c in cats) {
      final t = (c ?? '').trim();
      if (t.isNotEmpty) s.add(t);
    }
    return ['All', ...s];
  }
}
