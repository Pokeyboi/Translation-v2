import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import '../../providers/practice_provider.dart';
import '../../models/practice_clip.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PracticeProvider>().load());
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _addClip() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3','m4a','wav','aac','ogg'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read file bytes.')));
      return;
    }
    final mime = _guessMime(file.extension ?? 'mp3');
    final translation = await _promptTranslation();
    if (translation == null || translation.isEmpty) return;
    final lang = await _promptLanguageCode();
    if (lang == null || lang.isEmpty) return;

    final url = await _uploadAudioToBlob(file.name, bytes, mime);
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload to cloud failed.')));
      return;
    }
    await context.read<PracticeProvider>().addClipFromBlob(
      name: file.name,
      languageCode: lang,
      translation: translation,
      mimeType: mime,
      blobUrl: url,
    );
  }

  String _guessMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'wav': return 'audio/wav';
      case 'm4a': return 'audio/mp4';
      case 'aac': return 'audio/aac';
      case 'ogg': return 'audio/ogg';
      default: return 'audio/mpeg';
    }
  }

  Future<String?> _promptTranslation() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('English translation (label)'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'e.g., “Please sign the form”')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<String?> _promptLanguageCode() async {
    final c = TextEditingController(text: 'zopau');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Language code'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'e.g., es, hmong, zopau')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<String?> _uploadAudioToBlob(String filename, List<int> bytes, String mimeType) async {
    try {
      final uri = Uri.parse('/api/upload_audio?filename=' + Uri.encodeComponent(filename));
      final resp = await http.post(uri, headers: {'content-type': mimeType}, body: bytes);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final url = (data['url'] ?? data['downloadUrl'] ?? '') as String;
        return url.isNotEmpty ? url : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _play(PracticeClip clip) async {
    final url = (clip.blobUrl != null && clip.blobUrl!.isNotEmpty)
        ? clip.blobUrl!
        : 'data:${clip.mimeType};base64,${clip.dataBase64}';
    if (_playingId == clip.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    await _player.stop();
    await _player.play(UrlSource(url));
    setState(() => _playingId = clip.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PracticeProvider>();
    final clips = provider.clips;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        actions: [
          IconButton(onPressed: _addClip, icon: const Icon(Icons.library_music), tooltip: 'Add clip'),
          if (clips.isNotEmpty) IconButton(onPressed: provider.clear, icon: const Icon(Icons.delete_sweep), tooltip: 'Clear all'),
        ],
      ),
      body: clips.isEmpty
        ? const Center(child: Text('No clips yet. Tap the music icon to add one.'))
        : ListView.separated(
            itemCount: clips.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final c = clips[i];
              final isPlaying = c.id == _playingId;
              return ListTile(
                leading: CircleAvatar(child: Text(c.languageCode.toUpperCase().substring(0,1))),
                title: Text(c.translation.isEmpty ? c.name : c.translation),
                subtitle: Text('${c.name} • ${c.languageCode}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow), onPressed: () => _play(c)),
                  IconButton(icon: const Icon(Icons.edit), onPressed: () async {
                    final newT = await _promptTranslation();
                    if (newT != null) await context.read<PracticeProvider>().updateTranslation(c.id, newT);
                  }),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => context.read<PracticeProvider>().remove(c.id)),
                ]),
              );
            },
          ),
    );
  }
}
