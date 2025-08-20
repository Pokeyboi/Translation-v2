import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';

class ClassesProvider extends ChangeNotifier {
  static const _key = 'students_v1';
  final _rand = Random();

  List<Student> _students = [];
  List<Student> get students => List.unmodifiable(_students);

  bool _loaded = false;

  Future<void> _ensureLoad() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _students = list.map((m) => Student.fromMap(m)).toList();
      } catch (_) {}
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_students.map((s) => s.toMap()).toList()));
  }

  Future<void> load() async => _ensureLoad();

  Future<void> addStudent({required String name, required String languageCode, String notes = ''}) async {
    await _ensureLoad();
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1<<32).toRadixString(36)}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final s = Student(id: id, name: name, languageCode: languageCode, notes: notes, createdAt: now, updatedAt: now);
    _students = [s, ..._students];
    await _save();
    notifyListeners();
  }

  Future<void> updateStudent(String id, {String? name, String? languageCode, String? notes}) async {
    await _ensureLoad();
    final now = DateTime.now().millisecondsSinceEpoch;
    _students = _students.map((s) => s.id == id ? Student(
      id: s.id,
      name: name ?? s.name,
      languageCode: languageCode ?? s.languageCode,
      notes: notes ?? s.notes,
      createdAt: s.createdAt,
      updatedAt: now,
    ) : s).toList();
    await _save();
    notifyListeners();
  }

  Future<void> removeStudent(String id) async {
    await _ensureLoad();
    _students.removeWhere((s) => s.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    await _ensureLoad();
    _students = [];
    await _save();
    notifyListeners();
  }
}
