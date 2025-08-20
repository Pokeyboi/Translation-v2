import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/classes_provider.dart';
import '../../models/student.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ClassesProvider>().load());
  }

  Future<void> _add() async {
    final name = await _prompt('Student name');
    if (name == null) return;
    final lang = await _prompt('Language code', initial: 'zopau');
    if (lang == null) return;
    final notes = await _prompt('Notes (optional)', multiline: true) ?? '';
    await context.read<ClassesProvider>().addStudent(name: name, languageCode: lang, notes: notes);
  }

  Future<void> _edit(Student s) async {
    final name = await _prompt('Student name', initial: s.name);
    if (name == null) return;
    final lang = await _prompt('Language code', initial: s.languageCode);
    if (lang == null) return;
    final notes = await _prompt('Notes (optional)', initial: s.notes, multiline: true) ?? '';
    await context.read<ClassesProvider>().updateStudent(s.id, name: name, languageCode: lang, notes: notes);
  }

  Future<String?> _prompt(String label, {String initial = '', bool multiline = false}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: c, minLines: multiline ? 3 : 1, maxLines: multiline ? 5 : 1),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassesProvider>();
    final students = provider.students;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        actions: [
          if (students.isNotEmpty) IconButton(onPressed: provider.clear, icon: const Icon(Icons.delete_sweep), tooltip: 'Clear all'),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.person_add), label: const Text('Student')),
      body: students.isEmpty
        ? const Center(child: Text('No students yet. Tap “Student” to add one.'))
        : ListView.separated(
            itemCount: students.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final s = students[i];
              return ListTile(
                leading: CircleAvatar(child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?')),
                title: Text(s.name),
                subtitle: Text('Lang: ${s.languageCode}${s.notes.isNotEmpty ? " • ${s.notes}" : ""}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(s)),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => provider.removeStudent(s.id)),
                ]),
              );
            },
          ),
    );
  }
}
