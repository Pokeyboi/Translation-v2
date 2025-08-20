// lib/services/database_service.dart
//
// Mobile/Desktop database implementation using sqflite.
// Exposes a unified API (`AppDatabase`) that is also implemented by
// `database_service_web.dart` for the Web build via conditional export.
//
// Tables:
//  - words   : id TEXT PK, english TEXT, target TEXT, languageCode TEXT, category TEXT,
//              createdAt INT, updatedAt INT,
//              UNIQUE(english, target, languageCode) ON CONFLICT REPLACE
//  - phrases : id TEXT PK, english TEXT, target TEXT, languageCode TEXT, category TEXT,
//              audioUrl TEXT, createdAt INT, updatedAt INT,
//              UNIQUE(english, target, languageCode) ON CONFLICT REPLACE
//
// Notes:
//  - `bulkUpsertWords` / `bulkUpsertPhrases` accept rows in the shape produced by
//    CsvImportPage: { english, target, languageCode, category, audioUrl? }.
//  - IDs are auto-generated if not provided.
//  - All getters return *all* rows; higher layers (provider/UI) can filter/search.

import 'dart:async';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  // --- Singleton ---
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _db;
  final _rand = Random();

  Future<void> init() async {
    if (_db != null) return;

    // Get an OS-specific writable directory
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/teacher_translate.db';

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE words(
            id TEXT PRIMARY KEY,
            english TEXT NOT NULL,
            target TEXT NOT NULL,
            languageCode TEXT NOT NULL,
            category TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(english, target, languageCode) ON CONFLICT REPLACE
          )
        ''');
        await db.execute('''
          CREATE TABLE phrases(
            id TEXT PRIMARY KEY,
            english TEXT NOT NULL,
            target TEXT NOT NULL,
            languageCode TEXT NOT NULL,
            category TEXT,
            audioUrl TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(english, target, languageCode) ON CONFLICT REPLACE
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  // ---------------------------------------------------------------------------
  // WORDS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getWords() async {
    final db = await _ensureDb();
    final rows = await db.query(
      'words',
      orderBy: 'english COLLATE NOCASE ASC',
    );
    return rows;
  }

  Future<void> bulkUpsertWords(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await _ensureDb();
    final batch = db.batch();
    final now = _now();

    for (final r in rows) {
      final english = _s(r['english']);
      final target = _s(r['target']);
      final languageCode = _s(r['languageCode'], fallback: 'zopau');
      final category = _s(r['category']);

      if (english.isEmpty || target.isEmpty) continue;

      final id = _s(r['id'], fallback: _genId());
      batch.insert(
        'words',
        {
          'id': id,
          'english': english,
          'target': target,
          'languageCode': languageCode,
          'category': category.isEmpty ? null : category,
          'createdAt': now,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteWord(String id) async {
    final db = await _ensureDb();
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // PHRASES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getPhrases() async {
    final db = await _ensureDb();
    final rows = await db.query(
      'phrases',
      orderBy: 'english COLLATE NOCASE ASC',
    );
    return rows;
  }

  Future<void> bulkUpsertPhrases(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await _ensureDb();
    final batch = db.batch();
    final now = _now();

    for (final r in rows) {
      final english = _s(r['english']);
      final target = _s(r['target']);
      final languageCode = _s(r['languageCode'], fallback: 'zopau');
      final category = _s(r['category']);
      final audioUrl = _s(r['audioUrl']);

      if (english.isEmpty || target.isEmpty) continue;

      final id = _s(r['id'], fallback: _genId());
      batch.insert(
        'phrases',
        {
          'id': id,
          'english': english,
          'target': target,
          'languageCode': languageCode,
          'category': category.isEmpty ? null : category,
          'audioUrl': audioUrl.isEmpty ? null : audioUrl,
          'createdAt': now,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deletePhrase(String id) async {
    final db = await _ensureDb();
    await db.delete('phrases', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Database> _ensureDb() async {
    if (_db == null) {
      await init();
    }
    return _db!;
  }

  String _s(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
    }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  String _genId() {
    // pseudo-unique: timestamp + random suffix
    final ts = DateTime.now().microsecondsSinceEpoch;
    final suffix = _rand.nextInt(1 << 32).toRadixString(36);
    return '$ts$suffix';
  }
}
