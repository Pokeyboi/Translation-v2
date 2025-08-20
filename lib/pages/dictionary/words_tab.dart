import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher_string.dart';

import 'csv_import_page.dart';
import '../../providers/dictionary_provider.dart';
import '../../models/word_entry.dart';

enum QuickFilter { all, favorites, recent }

class WordsTab extends StatefulWidget {
  const WordsTab({super.key});

  @override
  State<WordsTab> createState() => _WordsTabState();
}

class _WordsTabState extends State<WordsTab> {
  String _search = '';
  String _category = 'All';
  String _lang = 'All';
  QuickFilter _qf = QuickFilter.all;
  bool _loadingImport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DictionaryProvider>().loadWords());
  }

  String _normalize(String s) {
    final lower = s.toLowerCase();
    const map = {
      'á':'a','à':'a','ä':'a','â':'a','ã':'a','å':'a',
      'é':'e','è':'e','ë':'e','ê':'e',
      'í':'i','ì':'i','ï':'i','î':'i',
      'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o',
      'ú':'u','ù':'u','ü':'u','û':'u',
      'ç':'c','ñ':'n'
    };
    final sb = StringBuffer();
    for (final code in lower.runes) {
      final ch = String.fromCharCode(code);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  double _similarity(String a, String b) {
    a = _normalize(a); b = _normalize(b);
    if (a.isEmpty || b.isEmpty) return 0;
    if (a.contains(b) || b.contains(a)) return 1.0;
    Set<String> bigrams(String s) {
      final out = <String>{};
      for (var i=0;i<s.length-1;i++) { out.add(s.substring(i,i+2)); }
      return out;
    }
    final aa = bigrams(a), bb = bigrams(b);
    final inter = aa.intersection(bb).length;
    return (2.0 * inter) / (aa.length + bb.length);
  }

  Future<void> _openImport() async {
    final rows = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(builder: (_) => const CsvImportPage()),
    );
    if (rows == null || rows.isEmpty) return;
    try {
      setState(() => _loadingImport = true);
      await context.read<DictionaryProvider>().bulkUpsertWords(rows);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported ${rows.length} row(s).')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally { if (mounted) setState(() => _loadingImport = false); }
  }

  Future<void> _loadSampleWords() async {
    try {
      setState(() => _loadingImport = true);
      final csvStr = await rootBundle.loadString('assets/data/sample_words.csv');
      final parsed = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(csvStr);
      if (parsed.isNotEmpty) {
        final header = parsed.first.map((e) => e.toString()).toList();
        final data = parsed.skip(1);
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (!r.any((c) => (c?.toString().trim() ?? '').isNotEmpty)) continue;
          final m = <String, dynamic>{};
          for (var i = 0; i < header.length && i < r.length; i++) { m[header[i]] = r[i]?.toString().trim() ?? ''; }
          rows.add({
            'english': m['english'] ?? '',
            'target': m['translation'] ?? m['target'] ?? '',
            'languageCode': m['languageCode'] ?? 'zopau',
            'category': (m['category'] ?? '').isEmpty ? null : m['category'],
          });
        }
        if (rows.isNotEmpty) {
          await context.read<DictionaryProvider>().bulkUpsertWords(rows);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded ${rows.length} sample words.')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load sample: $e')));
    } finally { if (mounted) setState(() => _loadingImport = false); }
  }

  Future<void> _exportCsv() async {
    try {
      final provider = context.read<DictionaryProvider>();
      final rows = provider.words.map((w) => [w.english, w.target, w.languageCode, w.category ?? '']).toList();
      final csv = const ListToCsvConverter().convert([['english','translation','languageCode','category'], ...rows]);
      final dataUrl = 'data:text/csv;charset=utf-8,' + Uri.encodeComponent(csv);
      await launchUrlString(dataUrl);
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DictionaryProvider>();
    final categories = provider.wordCategories;
    final langs = provider.wordLanguageCodes;
    final words = provider.words;

    final filtered = words.where((w) {
      final catOk = _category == 'All' || (w.category ?? '').toLowerCase().trim() == _category.toLowerCase().trim();
      final langOk = _lang == 'All' || w.languageCode.toLowerCase().trim() == _lang.toLowerCase().trim();
      final q = _search.trim();
      final qOk = q.isEmpty ? true : (
        w.english.toLowerCase().contains(q.toLowerCase()) ||
        w.target.toLowerCase().contains(q.toLowerCase()) ||
        (w.category ?? '').toLowerCase().contains(q.toLowerCase()) ||
        _similarity('${w.english} ${w.target}', q) >= 0.6
      );
      final favOk = _qf != QuickFilter.favorites || w.isFavorite;
      return catOk && langOk && qOk && favOk;
    }).toList()
      ..sort((a,b) {
        if (_qf == QuickFilter.recent) {
          final la = a.lastViewed ?? a.updatedAt; final lb = b.lastViewed ?? b.updatedAt;
          return lb.compareTo(la);
        }
        return a.english.toLowerCase().compareTo(b.english.toLowerCase());
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Words'),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Import CSV', onPressed: _openImport),
          IconButton(icon: const Icon(Icons.download), tooltip: 'Load sample', onPressed: _loadSampleWords),
          IconButton(icon: const Icon(Icons.save_alt), tooltip: 'Export CSV', onPressed: _exportCsv),
        ],
      ),
      body: Column(
        children: [
          _TopBar(
            categories: categories, langs: langs,
            selectedCategory: _category, selectedLang: _lang,
            onCategoryChanged: (v) => setState(() => _category = v),
            onLangChanged: (v) => setState(() => _lang = v),
            onSearchChanged: (v) => setState(() => _search = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('All'), selected: _qf == QuickFilter.all, onSelected: (_) => setState(() => _qf = QuickFilter.all)),
              ChoiceChip(label: const Text('Favorites'), selected: _qf == QuickFilter.favorites, onSelected: (_) => setState(() => _qf = QuickFilter.favorites)),
              ChoiceChip(label: const Text('Recent'), selected: _qf == QuickFilter.recent, onSelected: (_) => setState(() => _qf = QuickFilter.recent)),
            ]),
          ),
          if (_loadingImport) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<DictionaryProvider>().loadWords(),
              child: filtered.isEmpty
                ? ListView(children: const [SizedBox(height: 48), Center(child: Text('No words yet.'))])
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final entry = filtered[i];
                      return ListTile(
                        leading: const Icon(Icons.translate),
                        title: Text('${entry.english} → ${entry.target}'),
                        subtitle: Text([
                          if ((entry.category ?? '').isNotEmpty) 'Category: ${entry.category}',
                          'Lang: ${entry.languageCode}',
                        ].join(' • ')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: Icon(entry.isFavorite ? Icons.star : Icons.star_border),
                            tooltip: entry.isFavorite ? 'Unfavorite' : 'Favorite',
                            onPressed: () => context.read<DictionaryProvider>().toggleFavoriteWord(entry.id, !entry.isFavorite),
                          ),
                        ]),
                        onTap: () => context.read<DictionaryProvider>().touchWord(entry.id),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.categories,
    required this.langs,
    required this.selectedCategory,
    required this.selectedLang,
    required this.onCategoryChanged,
    required this.onLangChanged,
    required this.onSearchChanged,
  });

  final List<String> categories;
  final List<String> langs;
  final String selectedCategory;
  final String selectedLang;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onLangChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search words…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onSearchChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: categories.contains(selectedCategory) ? selectedCategory : categories.first,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { if (v != null) onCategoryChanged(v); },
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: langs.contains(selectedLang) ? selectedLang : langs.first,
                items: langs.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { if (v != null) onLangChanged(v); },
                decoration: const InputDecoration(labelText: 'Lang', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
