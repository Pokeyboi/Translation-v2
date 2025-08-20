import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dictionary/csv_import_page.dart';
import '../../providers/dictionary_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dict = context.watch<DictionaryProvider>();
    final wordsCount = dict.words.length;
    final phrasesCount = dict.phrases.length;

    final wordEnglish = TextEditingController();
    final wordTarget = TextEditingController();
    final wordLang = TextEditingController(text: 'zopau');
    final wordCat = TextEditingController();

    final phraseEnglish = TextEditingController();
    final phraseTarget = TextEditingController();
    final phraseLang = TextEditingController(text: 'zopau');
    final phraseCat = TextEditingController();
    final phraseAudio = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dictionary management', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add a word', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  SizedBox(width: 260, child: TextField(controller: wordEnglish, decoration: const InputDecoration(labelText: 'English', border: OutlineInputBorder()))),
                  SizedBox(width: 260, child: TextField(controller: wordTarget, decoration: const InputDecoration(labelText: 'Target', border: OutlineInputBorder()))),
                  SizedBox(width: 160, child: TextField(controller: wordLang, decoration: const InputDecoration(labelText: 'Lang code', border: OutlineInputBorder()))),
                  SizedBox(width: 200, child: TextField(controller: wordCat, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()))),
                  FilledButton(onPressed: () async {
                    await context.read<DictionaryProvider>().bulkUpsertWords([{
                      'english': wordEnglish.text.trim(),
                      'target': wordTarget.text.trim(),
                      'languageCode': wordLang.text.trim().isEmpty ? 'zopau' : wordLang.text.trim(),
                      'category': wordCat.text.trim().isEmpty ? null : wordCat.text.trim(),
                    }]);
                    wordEnglish.clear(); wordTarget.clear(); wordCat.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Word added')));
                  }, child: const Text('Add')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add a phrase', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  SizedBox(width: 260, child: TextField(controller: phraseEnglish, decoration: const InputDecoration(labelText: 'English', border: OutlineInputBorder()))),
                  SizedBox(width: 260, child: TextField(controller: phraseTarget, decoration: const InputDecoration(labelText: 'Target', border: OutlineInputBorder()))),
                  SizedBox(width: 160, child: TextField(controller: phraseLang, decoration: const InputDecoration(labelText: 'Lang code', border: OutlineInputBorder()))),
                  SizedBox(width: 200, child: TextField(controller: phraseCat, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()))),
                  SizedBox(width: 260, child: TextField(controller: phraseAudio, decoration: const InputDecoration(labelText: 'Audio URL (optional)', border: OutlineInputBorder()))),
                  FilledButton(onPressed: () async {
                    await context.read<DictionaryProvider>().bulkUpsertPhrases([{
                      'english': phraseEnglish.text.trim(),
                      'target': phraseTarget.text.trim(),
                      'languageCode': phraseLang.text.trim().isEmpty ? 'zopau' : phraseLang.text.trim(),
                      'category': phraseCat.text.trim().isEmpty ? null : phraseCat.text.trim(),
                      'audioUrl': phraseAudio.text.trim().isEmpty ? null : phraseAudio.text.trim(),
                    }]);
                    phraseEnglish.clear(); phraseTarget.clear(); phraseCat.clear(); phraseAudio.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phrase added')));
                  }, child: const Text('Add')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bulk operations', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(onPressed: () async {
                    final rows = await Navigator.of(context).push<List<Map<String, dynamic>>>(MaterialPageRoute(builder: (_) => const CsvImportPage()));
                    if (rows != null && rows.isNotEmpty) { await context.read<DictionaryProvider>().bulkUpsertWords(rows); }
                  }, icon: const Icon(Icons.upload_file), label: const Text('Import Words CSV')),
                  FilledButton.icon(onPressed: () async {
                    final rows = await Navigator.of(context).push<List<Map<String, dynamic>>>(MaterialPageRoute(builder: (_) => const CsvImportPage()));
                    if (rows != null && rows.isNotEmpty) { await context.read<DictionaryProvider>().bulkUpsertPhrases(rows); }
                  }, icon: const Icon(Icons.upload_file), label: const Text('Import Phrases CSV')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.25),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Danger zone', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(onPressed: () async { await context.read<DictionaryProvider>().clearWords(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared all words'))); }, icon: const Icon(Icons.delete), label: Text('Clear words (${wordsCount})')),
                  OutlinedButton.icon(onPressed: () async { await context.read<DictionaryProvider>().clearPhrases(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared all phrases'))); }, icon: const Icon(Icons.delete), label: Text('Clear phrases (${phrasesCount})')),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
