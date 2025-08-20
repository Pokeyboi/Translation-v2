import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/practice_clip.dart';

class PracticeProvider extends ChangeNotifier {
  static const _key = 'practice_clips_v2';
  final _rand = Random();

  List<PracticeClip> _clips = [];
  List<PracticeClip> get clips => List.unmodifiable(_clips);

  bool _loaded = false;

  Future<void> _ensureLoad() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _clips = list.map((m) => PracticeClip.fromMap(m)).toList();
      } catch (_) {}
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_clips.map((c) => c.toMap()).toList()));
  }

  Future<void> load() async => _ensureLoad();

  Future<void> addClipFromBlob({
    required String name,
    required String languageCode,
    required String translation,
    required String mimeType,
    required String blobUrl,
  }) async {
    await _ensureLoad();
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1<<32).toRadixString(36)}';
    final clip = PracticeClip(
      id: id,
      name: name,
      languageCode: languageCode,
      translation: translation,
      mimeType: mimeType,
      blobUrl: blobUrl,
      dataBase64: null,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _clips = [clip, ..._clips];
    await _save();
    notifyListeners();
  }

  Future<void> addClip({
    required String name,
    required String languageCode,
    required String translation,
    required String mimeType,
    required String dataBase64,
  }) async {
    await _ensureLoad();
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1<<32).toRadixString(36)}';
    final clip = PracticeClip(
      id: id,
      name: name,
      languageCode: languageCode,
      translation: translation,
      mimeType: mimeType,
      dataBase64: dataBase64,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _clips = [clip, ..._clips];
    await _save();
    notifyListeners();
  }

  Future<void> updateTranslation(String id, String translation) async {
    await _ensureLoad();
    _clips = _clips.map((c) => c.id == id ? PracticeClip(
      id: c.id,
      name: c.name,
      languageCode: c.languageCode,
      translation: translation,
      mimeType: c.mimeType,
      blobUrl: c.blobUrl,
      dataBase64: c.dataBase64,
      addedAt: c.addedAt,
    ) : c).toList();
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _ensureLoad();
    _clips.removeWhere((c) => c.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    await _ensureLoad();
    _clips = [];
    await _save();
    notifyListeners();
  }
}
