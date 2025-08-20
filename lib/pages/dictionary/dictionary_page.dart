import 'package:flutter/material.dart';
import 'words_tab.dart';
import 'phrases_tab.dart';

class DictionaryPage extends StatelessWidget {
  const DictionaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: TabBar(tabs: [
          Tab(icon: Icon(Icons.text_fields), text: 'Words'),
          Tab(icon: Icon(Icons.textsms_outlined), text: 'Phrases'),
        ]),
        body: TabBarView(children: [
          WordsTab(),
          PhrasesTab(),
        ]),
      ),
    );
  }
}
