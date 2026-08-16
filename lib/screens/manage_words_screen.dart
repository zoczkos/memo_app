import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/word.dart';
import '../utils/download_text_file.dart';
import '../widgets/word_dialog.dart';
import 'help_screen.dart';

class ManageWordsScreen extends StatefulWidget {
  final int folderId;

  const ManageWordsScreen({super.key, required this.folderId});

  @override
  State<ManageWordsScreen> createState() => _ManageWordsScreenState();
}

class _ManageWordsScreenState extends State<ManageWordsScreen> {
  List<Word> _words = [];
  bool _isLoading = true;
  String _filterQuery = '';
  final _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<Word> get _filteredWords {
    final q = _filterQuery.trim().toLowerCase();
    if (q.isEmpty) return _words;
    return _words.where((word) {
      return word.pl.toLowerCase().contains(q) ||
          word.en.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _loadWords() async {
    final data = await DatabaseHelper.instance.getWordsForFolder(
      widget.folderId,
    );
    if (!mounted) return;
    setState(() {
      _words = data;
      _isLoading = false;
    });
  }

  String _cleanText(String text) {
    var t = text.trim();
    if (t.startsWith('"') && t.endsWith('"') && t.length >= 2) {
      return t.substring(1, t.length - 1).trim();
    }
    return t;
  }

  String _escapeCsvField(String value) {
    if (value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _buildExportCsv() {
    final buffer = StringBuffer('Front;Back\n');
    for (final word in _words) {
      buffer.writeln(
        '${_escapeCsvField(word.pl)};${_escapeCsvField(word.en)}',
      );
    }
    return buffer.toString();
  }

  Future<String> _exportFileName() async {
    final folders = await DatabaseHelper.instance.getFolders();
    final folder = folders.where((f) => f.id == widget.folderId).firstOrNull;
    final raw = folder?.name ?? 'words';
    final safe = raw
        .replaceAll(RegExp(r'[^\w\- ]+'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return '${safe.isEmpty ? 'words' : safe}.csv';
  }

  Future<void> _exportCsv() async {
    if (_words.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words to export.')),
      );
      return;
    }

    try {
      final csv = _buildExportCsv();
      final filename = await _exportFileName();
      await downloadTextFile(filename, csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${_words.length} words to $filename')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export: $e')));
    }
  }

  List<({String pl, String en})> _parseImport(String csvData) {
    var data = csvData;
    if (data.startsWith('\uFEFF')) {
      data = data.substring(1);
    }

    final lines = data.split(RegExp(r'\r?\n'));
    var englishFirst = false;
    var startIndex = 0;

    if (lines.isNotEmpty) {
      final headerParts = lines.first.split(';');
      if (headerParts.length >= 2) {
        final left = _cleanText(headerParts[0]).toLowerCase();
        final right = _cleanText(headerParts[1]).toLowerCase();
        if (left == 'english' && right == 'polish') {
          englishFirst = true;
          startIndex = 1;
        } else if ((left == 'front' && right == 'back') ||
            (left == 'polish' && right == 'english')) {
          startIndex = 1;
        }
      }
    }

    final pairs = <({String pl, String en})>[];
    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(';');
      if (parts.length < 2) continue;
      final left = _cleanText(parts[0]);
      final right = _cleanText(parts.sublist(1).join(';'));
      if (left.isEmpty || right.isEmpty) continue;

      if (englishFirst) {
        pairs.add((pl: right, en: left));
      } else {
        pairs.add((pl: left, en: right));
      }
    }
    return pairs;
  }

  Future<void> _processImport(String csvData) async {
    final pairs = _parseImport(csvData);
    if (pairs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid rows found.')),
      );
      return;
    }

    final result = await DatabaseHelper.instance.importWords(
      widget.folderId,
      pairs,
    );
    await _loadWords();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${result.imported} words'
          '${result.skipped > 0 ? ', skipped ${result.skipped} duplicates' : ''}.',
        ),
      ),
    );
  }

  /// Web-safe: reads file bytes instead of dart:io paths.
  Future<void> _pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final csvData = utf8.decode(result.files.single.bytes!);
        await _processImport(csvData);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not read file: $e')));
    }
  }

  void _showPasteDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste import'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Separate front and back with a semicolon (;). '
                'Commas can appear inside words.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'to be, or not to be;być albo nie być\nHello, world!;Witaj, świecie!',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _processImport(controller.text);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showImportOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Import words',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Format: front;back — one card per line. '
                    'Use a semicolon as the separator so commas can appear in the text.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.file_open, color: Colors.blue),
                  title: const Text('Pick a file (.csv / .txt)'),
                  subtitle: const Text('Semicolon-separated lines'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndImportFile();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.paste, color: Colors.blue),
                  title: const Text('Paste text'),
                  subtitle: const Text('Same front;back format'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showPasteDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.blue),
                  title: const Text('Open import help'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWordDialog(Word? word) async {
    final saved = await showWordEditorDialog(
      context,
      folderId: widget.folderId,
      word: word,
    );
    if (saved != null) _loadWords();
  }

  Future<void> _confirmDeleteWord(Word word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete word'),
        content: Text('Delete “${word.pl} / ${word.en}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && word.id != null) {
      await DatabaseHelper.instance.deleteWord(word.id!);
      _loadWords();
    }
  }

  Future<void> _shufflePracticeOrder() async {
    if (_words.length < 2) return;

    await DatabaseHelper.instance.shufflePracticeOrder(widget.folderId);
    await _loadWords();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Practice order shuffled. Free practice subsets use this order.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredWords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word list'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Shuffle practice order',
            onPressed: _isLoading || _words.length < 2
                ? null
                : _shufflePracticeOrder,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: _isLoading || _words.isEmpty ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import words',
            onPressed: _showImportOptions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWordDialog(null),
        tooltip: 'Add word',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No words in this folder yet.\nUse the upload icon to import a file, or tap +.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    controller: _filterController,
                    onChanged: (value) => setState(() => _filterQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search front or back…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _filterQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear',
                              onPressed: () {
                                _filterController.clear();
                                setState(() => _filterQuery = '');
                              },
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (_filterQuery.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${filtered.length} of ${_words.length}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching words.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final word = filtered[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.blue.shade50,
                                  child: Text(
                                    '${word.practiceOrder + 1}',
                                    style: TextStyle(
                                      fontSize: word.practiceOrder + 1 >= 100
                                          ? 10
                                          : 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  word.en,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(word.pl),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmDeleteWord(word),
                                ),
                                onTap: () => _showWordDialog(word),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
