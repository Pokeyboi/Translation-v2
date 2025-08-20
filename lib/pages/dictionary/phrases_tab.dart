import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher_string.dart';

import 'csv_import_page.dart';
import 'add_phrase_entry_page.dart';
import '../../providers/dictionary_provider.dart';
import '../../models/phrase_entry.dart';

enum QuickFilter { all, favorites, recent }

class PhrasesTab extends StatefulWidget {
  const PhrasesTab({super.key});

  @override
  State<PhrasesTab> createState() => _PhrasesTabState();
}

class _PhrasesTabState extends State<PhrasesTab> {
  String _search = '';
  String _category = 'All';
  String _lang = 'All';
  QuickFilter _qf = QuickFilter.all;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      setState(() => _isLoading = true);
      await context.read<DictionaryProvider>().loadPhrases();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalize(String s) => s.toLowerCase();

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
      setState(() => _isLoading = true);
      await context.read<DictionaryProvider>().bulkUpsertPhrases(rows);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported ${rows.length} row(s).')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      await _refresh();
    }
  }

  Future<void> _addPhrase() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddPhraseEntryPage()),
    );
    if (created == true) await _refresh();
  }

  Future<void> _editPhrase(PhraseEntry entry) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddPhraseEntryPage(existing: entry)),
    );
    if (updated == true) await _refresh();
  }

  Future<void> _deletePhrase(PhraseEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete phrase'),
        content: Text('Delete “${entry.english} → ${entry.target}”?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await context.read<DictionaryProvider>().deletePhrase(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phrase deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _loadSamplePhrases() async {
    try {
      final csvStr = await rootBundle.loadString('assets/data/sample_phrases.csv');
      final parsed = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(csvStr);
      if (parsed.isEmpty) return;
      final header = parsed.first.map((e) => e.toString()).toList();
      final data = parsed.skip(1);
      final rows = <Map<String, dynamic>>[];
      for (final r in data) {
        if (!r.any((c) => (c?.toString().trim() ?? '').isNotEmpty)) continue;
        final m = <String, dynamic>{};
        for (var i = 0; i < header.length && i < r.length; i++) {
          m[header[i]] = r[i]?.toString().trim() ?? '';
        }
        rows.add({
          'english': m['english'] ?? '',
          'target': m['translation'] ?? m['target'] ?? '',
          'languageCode': m['languageCode'] ?? 'zopau',
          'category': (m['category'] ?? '').isEmpty ? null : m['category'],
          'audioUrl': (m['audioNativeUrl'] ?? m['audioUrl'] ?? '').isEmpty ? null : (m['audioNativeUrl'] ?? m['audioUrl']),
        });
      }
      if (rows.isNotEmpty) {
        await context.read<DictionaryProvider>().bulkUpsertPhrases(rows);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded ${rows.length} sample phrases.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load sample: $e')));
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final provider = context.read<DictionaryProvider>();
      final rows = provider.phrases.map((p) => [p.english, p.target, p.languageCode, p.category ?? '', p.audioUrl ?? '']).toList();
      final csv = const ListToCsvConverter().convert([['english','translation','languageCode','category','audioUrl'], ...rows]);
      final dataUrl = 'data:text/csv;charset=utf-8,' + Uri.encodeComponent(csv);
      await launchUrlString(dataUrl);
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DictionaryProvider>();
    final categories = provider.phraseCategories;
    final phrases = provider.phrases;
    final langs = provider.phraseLanguageCodes;

    final filtered = phrases.where((p) {
      final catOk = _category == 'All' || (p.category ?? '').toLowerCase().trim() == _category.toLowerCase().trim();
      final langOk = _lang == 'All' || p.languageCode.toLowerCase().trim() == _lang.toLowerCase().trim();
      final q = _search.trim();
      final qOk = q.isEmpty ? true : (
        p.english.toLowerCase().contains(q.toLowerCase()) ||
        p.target.toLowerCase().contains(q.toLowerCase()) ||
        (p.category ?? '').toLowerCase().contains(q.toLowerCase()) ||
        _similarity('${p.english} ${p.target}', q) >= 0.6
      );
      final favOk = _qf != QuickFilter.favorites || p.isFavorite;
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
        title: const Text('Phrases'),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Import CSV', onPressed: _isLoading ? null : _openImport),
          IconButton(icon: const Icon(Icons.download), tooltip: 'Load sample', onPressed: _loadSamplePhrases),
          IconButton(icon: const Icon(Icons.save_alt), tooltip: 'Export CSV', onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          _TopBar(
            categories: categories,
            langs: langs,
            selectedCategory: _category,
            selectedLang: _lang,
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
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: filtered.isEmpty
                  ? ListView(children: const [SizedBox(height: 48), Center(child: Text('No phrases yet.'))])
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final entry = filtered[i];
                        return ListTile(
                          leading: const Icon(Icons.textsms_outlined),
                          title: Text('${entry.english} → ${entry.target}'),
                          subtitle: Text([
                            if ((entry.category ?? '').isNotEmpty) 'Category: ${entry.category}',
                            'Lang: ${entry.languageCode}',
                          ].join(' • ')),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if ((entry.audioUrl ?? '').isNotEmpty)
                              IconButton(icon: const Icon(Icons.volume_up), tooltip: 'Play audio', onPressed: () { final url = entry.audioUrl!; launchUrlString(url); }),
                            IconButton(
                              icon: Icon(entry.isFavorite ? Icons.star : Icons.star_border),
                              tooltip: entry.isFavorite ? 'Unfavorite' : 'Favorite',
                              onPressed: () => context.read<DictionaryProvider>().toggleFavoritePhrase(entry.id, !entry.isFavorite),
                            ),
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _editPhrase(entry)),
                          ]),
                          onLongPress: () => _deletePhrase(entry),
                          onTap: () => _editPhrase(entry),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addPhrase, icon: const Icon(Icons.add), label: const Text('Add')),
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
                  hintText: 'Search phrases…',
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
