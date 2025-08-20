import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'providers/dictionary_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/classes_provider.dart';

import 'pages/dictionary/dictionary_page.dart';
import 'pages/practice/practice_page.dart';
import 'pages/classes/classes_page.dart';
import 'pages/settings/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TeacherTranslatorApp());
}

class TeacherTranslatorApp extends StatelessWidget {
  const TeacherTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DictionaryProvider()),
        ChangeNotifierProvider(create: (_) => PracticeProvider()),
        ChangeNotifierProvider(create: (_) => ClassesProvider()),
      ],
      child: MaterialApp(
        title: 'Teacher Translator',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Home(),
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _index = 0;

  final _pages = const [
    DictionaryPage(),
    PracticePage(),
    ClassesPage(),
    SettingsPage(),
  ];

  final _titles = const ['Dictionary', 'Practice', 'Classes', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Dictionary'),
          NavigationDestination(icon: Icon(Icons.library_music), label: 'Practice'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Classes'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
