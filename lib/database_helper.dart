import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/folder.dart';
import 'models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static const seededFolderName = 'English–Polish 500';
  static const _seedAssetPath = 'assets/en_pl_500.csv';
  static const _foldersBoxName = 'folders';
  static const _wordsBoxName = 'words';
  static const _metaBoxName = 'meta';
  static const _seededMetaKey = 'seeded_en_pl_500';

  /// When set (tests), used instead of the bundled asset.
  static String? debugSeedCsv;

  /// When set (tests), Hive opens boxes under this path instead of Flutter path.
  static String? _testHivePath;

  Box? _foldersBox;
  Box? _wordsBox;
  Box? _metaBox;

  DatabaseHelper._init();

  /// Use an isolated Hive directory for tests.
  static Future<void> useTestDatabase(String hivePath) async {
    await resetForTest();
    _testHivePath = hivePath;
    await instance.initDB();
  }

  static Future<void> resetForTest() async {
    await instance._closeBoxes();
    if (_testHivePath != null) {
      await Hive.deleteFromDisk();
    }
    _testHivePath = null;
  }

  Future<void> _closeBoxes() async {
    await _foldersBox?.close();
    await _wordsBox?.close();
    await _metaBox?.close();
    _foldersBox = null;
    _wordsBox = null;
    _metaBox = null;
  }

  Future<void> initDB() async {
    if (_testHivePath != null) {
      Hive.init(_testHivePath!);
    } else {
      await Hive.initFlutter();
    }

    _foldersBox = await Hive.openBox(_foldersBoxName);
    _wordsBox = await Hive.openBox(_wordsBoxName);
    _metaBox = await Hive.openBox(_metaBoxName);

    await _migratePracticeOrdersIfNeeded();
    await _seedEnglishPolishDeckIfMissing();
  }

  /// Assigns [practice_order] to legacy words that predate the field.
  Future<void> _migratePracticeOrdersIfNeeded() async {
    final missingByFolder = <int, List<int>>{};
    for (final key in _wordsBox!.keys) {
      final data = Map<String, dynamic>.from(_wordsBox!.get(key) as Map);
      if (data.containsKey('practice_order')) continue;
      final folderId = data['folder_id'] as int;
      missingByFolder.putIfAbsent(folderId, () => []).add(key as int);
    }

    for (final entry in missingByFolder.entries) {
      final keys = entry.value..sort();
      for (var i = 0; i < keys.length; i++) {
        final data = Map<String, dynamic>.from(
          _wordsBox!.get(keys[i]) as Map,
        );
        data['practice_order'] = i;
        await _wordsBox!.put(keys[i], data);
      }
    }
  }

  Future<void> _seedEnglishPolishDeckIfMissing() async {
    final alreadySeeded = _metaBox!.get(_seededMetaKey) == true;
    final hasSeedFolder = _foldersBox!.values.any(
      (v) => Map<String, dynamic>.from(v)['name'] == seededFolderName,
    );
    if (alreadySeeded || hasSeedFolder) {
      if (!alreadySeeded && hasSeedFolder) {
        await _metaBox!.put(_seededMetaKey, true);
      }
      return;
    }
    await _seedEnglishPolishDeck();
  }

  Future<void> _seedEnglishPolishDeck() async {
    final folderId = await insertFolder(seededFolderName);
    final pairs = await _loadSeedPairs();
    for (var i = 0; i < pairs.length; i++) {
      final pair = pairs[i];
      await _wordsBox!.add({
        'folder_id': folderId,
        'pl': pair.pl,
        'en': pair.en,
        'interval': 0,
        'next_review': 0,
        'practice_order': i,
      });
    }
    await _metaBox!.put(_seededMetaKey, true);
  }

  /// Parses bundled `English;Polish` CSV into DB fields (`pl` / `en`).
  Future<List<({String pl, String en})>> _loadSeedPairs() async {
    var csv = debugSeedCsv ?? await rootBundle.loadString(_seedAssetPath);
    if (csv.startsWith('\uFEFF')) {
      csv = csv.substring(1);
    }

    final pairs = <({String pl, String en})>[];
    for (final rawLine in csv.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final parts = line.split(';');
      if (parts.length < 2) continue;

      final english = _cleanText(parts[0]);
      final polish = _cleanText(parts.sublist(1).join(';'));
      if (english.isEmpty || polish.isEmpty) continue;

      if (english.toLowerCase() == 'english' &&
          polish.toLowerCase() == 'polish') {
        continue;
      }

      pairs.add((pl: polish, en: english));
    }
    return pairs;
  }

  String _cleanText(String text) {
    var t = text.trim();
    if (t.startsWith('"') && t.endsWith('"') && t.length >= 2) {
      return t.substring(1, t.length - 1).trim();
    }
    return t;
  }

  Folder _folderFromKey(dynamic key, dynamic value) {
    final map = Map<String, dynamic>.from(value as Map);
    map['id'] = key as int;
    return Folder.fromMap(map);
  }

  Word _wordFromKey(dynamic key, dynamic value) {
    final map = Map<String, dynamic>.from(value as Map);
    map['id'] = key as int;
    return Word.fromMap(map);
  }

  Future<List<Folder>> getFolders() async {
    final folders = _foldersBox!.keys
        .map((key) => _folderFromKey(key, _foldersBox!.get(key)))
        .toList();
    folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return folders;
  }

  Future<int> insertFolder(String name) async {
    return await _foldersBox!.add({'name': name});
  }

  Future<void> updateFolder(Folder folder) async {
    await _foldersBox!.put(folder.id, {'name': folder.name});
  }

  Future<void> deleteFolder(int id) async {
    final wordKeys = _wordsBox!.keys.where((key) {
      final word = _wordsBox!.get(key);
      return word['folder_id'] == id;
    }).toList();
    for (final key in wordKeys) {
      await _wordsBox!.delete(key);
    }
    await _foldersBox!.delete(id);
  }

  Future<List<Word>> getWordsForFolder(int folderId) async {
    final words = _wordsBox!.keys
        .where((key) => _wordsBox!.get(key)['folder_id'] == folderId)
        .map((key) => _wordFromKey(key, _wordsBox!.get(key)))
        .toList();
    words.sort((a, b) {
      final byOrder = a.practiceOrder.compareTo(b.practiceOrder);
      if (byOrder != 0) return byOrder;
      return a.pl.toLowerCase().compareTo(b.pl.toLowerCase());
    });
    return words;
  }

  Future<int> _nextPracticeOrder(int folderId) async {
    var maxOrder = -1;
    for (final key in _wordsBox!.keys) {
      final word = _wordsBox!.get(key);
      if (word['folder_id'] != folderId) continue;
      final order = word['practice_order'] as int? ?? -1;
      if (order > maxOrder) maxOrder = order;
    }
    return maxOrder + 1;
  }

  /// Randomizes free-practice order for all words in [folderId].
  Future<void> shufflePracticeOrder(int folderId) async {
    final keys = _wordsBox!.keys
        .where((key) => _wordsBox!.get(key)['folder_id'] == folderId)
        .cast<int>()
        .toList()
      ..shuffle();

    for (var i = 0; i < keys.length; i++) {
      final data = Map<String, dynamic>.from(_wordsBox!.get(keys[i]) as Map);
      data['practice_order'] = i;
      await _wordsBox!.put(keys[i], data);
    }
  }

  Future<List<Word>> getDueWords(int folderId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _wordsBox!.keys
        .where((key) {
          final word = _wordsBox!.get(key);
          return word['folder_id'] == folderId && word['next_review'] <= now;
        })
        .map((key) => _wordFromKey(key, _wordsBox!.get(key)))
        .toList();
  }

  Future<Word> insertWord(Word word) async {
    final practiceOrder = await _nextPracticeOrder(word.folderId);
    final id = await _wordsBox!.add({
      'folder_id': word.folderId,
      'pl': word.pl,
      'en': word.en,
      'interval': 0,
      'next_review': 0,
      'practice_order': practiceOrder,
    });
    return word.copyWith(
      id: id,
      interval: 0,
      nextReview: 0,
      practiceOrder: practiceOrder,
    );
  }

  Future<void> updateWord(Word word) async {
    if (word.id == null) return;
    await _wordsBox!.put(word.id, {
      'folder_id': word.folderId,
      'pl': word.pl,
      'en': word.en,
      'interval': word.interval,
      'next_review': word.nextReview,
      'practice_order': word.practiceOrder,
    });
  }

  Future<void> deleteWord(int id) async {
    await _wordsBox!.delete(id);
  }

  /// Imports pairs, skipping duplicates (same pl+en in folder).
  Future<({int imported, int skipped})> importWords(
    int folderId,
    List<({String pl, String en})> pairs,
  ) async {
    var imported = 0;
    var skipped = 0;

    final existing = await getWordsForFolder(folderId);
    final seen = {for (final word in existing) '${word.pl}\u0000${word.en}'};
    var nextOrder = await _nextPracticeOrder(folderId);

    for (final pair in pairs) {
      final key = '${pair.pl}\u0000${pair.en}';
      if (seen.contains(key)) {
        skipped++;
        continue;
      }
      seen.add(key);
      await _wordsBox!.add({
        'folder_id': folderId,
        'pl': pair.pl,
        'en': pair.en,
        'interval': 0,
        'next_review': 0,
        'practice_order': nextOrder,
      });
      nextOrder++;
      imported++;
    }

    return (imported: imported, skipped: skipped);
  }

  Future<void> reviewWord(int wordId, int currentInterval, bool isOk) async {
    late final int newInterval;
    late final int nextReviewTime;

    if (!isOk) {
      newInterval = 0;
      nextReviewTime = 0;
    } else {
      newInterval = currentInterval == 0 ? 1 : currentInterval * 2;
      nextReviewTime =
          DateTime.now().millisecondsSinceEpoch +
          (newInterval * 24 * 60 * 60 * 1000);
    }

    final wordData = Map<String, dynamic>.from(_wordsBox!.get(wordId) as Map);
    wordData['interval'] = newInterval;
    wordData['next_review'] = nextReviewTime;
    await _wordsBox!.put(wordId, wordData);
  }
}
