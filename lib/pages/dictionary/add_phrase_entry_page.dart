// lib/pages/dictionary/add_phrase_entry_page.dart
//
// Create/Edit a phrase entry.
// - Fields: English, Target, Language Code (default 'zopau'), Category, Audio URL
// - If editing, pre-fills from the provided PhraseEntry.
// - Saves via DictionaryProvider.bulkUpsertPhrases([row]) and pops `true` on success.
// - Delete button shown when editing.
// - Mobile-only (non-web) optional recorder stub using `record` to capture audio
//   and store its local file path into the Audio URL field (gated behind kIsWeb).
//
// Requirements in pubspec:
//   record: ^5.x
//   permission_handler: ^11.x
//   path_provider: ^2.x
//
// NOTE: The recorder is intentionally minimal. For production, consider
//       error handling and displaying recording duration, playback, etc.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/phrase_entry.dart';
import '../../providers/dictionary_provider.dart';

class AddPhraseEntryPage extends StatefulWidget {
  const AddPhraseEntryPage({super.key, this.existing});

  final PhraseEntry? existing;

  @override
  State<AddPhraseEntryPage> createState() => _AddPhraseEntryPageState();
}

class _AddPhraseEntryPageState extends State<AddPhraseEntryPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _englishCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _langCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _audioUrlCtrl;

  bool _submitting = false;

  // Recorder state (mobile only)
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _englishCtrl = TextEditingController(text: widget.existing?.english ?? '');
    _targetCtrl = TextEditingController(text: widget.existing?.target ?? '');
    _langCtrl = TextEditingController(text: widget.existing?.languageCode ?? 'zopau');
    _categoryCtrl = TextEditingController(text: widget.existing?.category ?? '');
    _audioUrlCtrl = TextEditingController(text: widget.existing?.audioUrl ?? '');
  }

  @override
  void dispose() {
    _englishCtrl.dispose();
    _targetCtrl.dispose();
    _langCtrl.dispose();
    _categoryCtrl.dispose();
    _audioUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final row = <String, dynamic>{
      'id': widget.existing?.id, // optional; DB will generate if null
      'english': _englishCtrl.text.trim(),
      'target': _targetCtrl.text.trim(),
      'languageCode': _langCtrl.text.trim().isEmpty ? 'zopau' : _langCtrl.text.trim(),
      'category': _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      'audioUrl': _audioUrlCtrl.text.trim().isEmpty ? null : _audioUrlCtrl.text.trim(),
    };

    try {
      setState(() => _submitting = true);
      await context.read<DictionaryProvider>().bulkUpsertPhrases([row]);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final entry = widget.existing;
    if (entry == null) return;
    final ok = await showDialog<bool>(
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
    if (ok != true) return;

    try {
      await context.read<DictionaryProvider>().deletePhrase(entry.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  // ---------------------------
  // Mobile-only simple recorder
  // ---------------------------
  Future<void> _toggleRecord() async {
    if (kIsWeb) return; // defensive; button is hidden on web anyway

    // Lazy import/run to avoid static references on web
    // ignore: avoid_dynamic_calls
    final record = await _loadRecord();
    if (record == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording not available on this platform.')),
        );
      }
      return;
    }

    if (!_isRecording) {
      // Start recording
      final hasPerm = await record.hasPermission();
      if (!hasPerm) {
        final granted = await record.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission denied.')),
            );
          }
          return;
        }
      }

      final path = await _proposeAudioPath();
      await record.start(
        path: path, // e.g., .../phrase-<ts>.m4a
        encoder: _recordEncoderAacLc(),
        bitRate: 128000,
        samplingRate: 44100,
      );
      setState(() => _isRecording = true);
    } else {
      // Stop recording
      final filePath = await record.stop();
      setState(() => _isRecording = false);
      if (filePath != null && filePath.isNotEmpty) {
        _audioUrlCtrl.text = filePath; // store local file path
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved recording to $filePath')),
          );
        }
      }
    }
  }

  // Delay-loaded helpers for `record` to avoid web symbol resolution issues.
  Future<dynamic> _loadRecord() async {
    try {
      // ignore: avoid_dynamic_calls
      final rec = (await Future.microtask(() => _RecordProxy.create()));
      return rec;
    } catch (_) {
      return null;
    }
  }

  Future<String> _proposeAudioPath() async {
    try {
      // Use path_provider only on mobile/desktop
      // ignore: avoid_dynamic_calls
      final dir = await _PathProviderProxy.getAppDocsDir();
      final ts = DateTime.now().millisecondsSinceEpoch;
      return '${dir.path}/phrase-$ts.m4a';
    } catch (_) {
      // Fallback to relative filename
      final ts = DateTime.now().millisecondsSinceEpoch;
      return 'phrase-$ts.m4a';
    }
  }

  // Provide encoder enum in a way that avoids direct reference on web.
  dynamic _recordEncoderAacLc() => _RecordProxy.encoderAacLc();

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Phrase' : 'Add Phrase'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete),
              onPressed: _submitting ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _englishCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'English (required)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _targetCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Target Translation (required)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _langCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Language Code',
                            hintText: 'e.g., zopau',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _categoryCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Category (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _audioUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Audio URL or local path (optional)',
                      hintText: 'https://... or /path/to/file.m4a',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Recorder UI (mobile only)
                  if (!kIsWeb) _RecorderTile(
                    isRecording: _isRecording,
                    onToggle: _toggleRecord,
                  ) else
                    const _WebRecorderNotice(),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(_submitting ? 'Saving…' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------
// Lightweight recorder widgets
// -----------------------------

class _RecorderTile extends StatelessWidget {
  const _RecorderTile({required this.isRecording, required this.onToggle});

  final bool isRecording;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: ListTile(
        leading: Icon(isRecording ? Icons.stop_circle : Icons.mic),
        title: Text(isRecording ? 'Recording… Tap to stop' : 'Record pronunciation (mobile only)'),
        subtitle: const Text('Saves to local file and fills the Audio URL field'),
        onTap: onToggle,
      ),
    );
  }
}

class _WebRecorderNotice extends StatelessWidget {
  const _WebRecorderNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: const ListTile(
        leading: Icon(Icons.mic_off),
        title: Text('Recording unavailable on web'),
        subtitle: Text('Enter a hosted audio URL, or record on the mobile app.'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proxies to avoid static imports that would break web builds
// ---------------------------------------------------------------------------

class _RecordProxy {
  // Dynamically create a Record() instance
  static Future<dynamic> create() async {
    // Delay import so that tree-shaking and web builds don’t evaluate it.
    // ignore: avoid_dynamic_calls
    final rec = await Future.microtask(() => _createRecordImpl());
    return rec;
  }

  static dynamic encoderAacLc() => _encoderAacLcImpl();
}

// The following top-level functions are declared `dynamic` so they aren’t
// resolved by the web compiler when not used.

dynamic _createRecordImpl() {
  // These imports only execute at runtime on mobile/desktop due to call gating.
  // ignore: import_of_legacy_library_into_null_safe
  // ignore: unnecessary_import
  import 'package:record/record.dart' as rec;

  return rec.AudioRecorder();
}

dynamic _encoderAacLcImpl() {
  // ignore: import_of_legacy_library_into_null_safe
  import 'package:record/record.dart' as rec;
  return rec.AudioEncoder.aacLc;
}

class _PathProviderProxy {
  static Future<dynamic> getAppDocsDir() async {
    // ignore: import_of_legacy_library_into_null_safe
    import 'package:path_provider/path_provider.dart' as pp;
    return pp.getApplicationDocumentsDirectory();
  }
}
