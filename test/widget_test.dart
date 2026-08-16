import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memo_app/database_helper.dart';
import 'package:memo_app/main.dart';
import 'package:memo_app/models/word.dart';

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memo_hive_test_');
    DatabaseHelper.debugSeedCsv = '''
English;Polish
dog;pies
cat;kot
''';
    await DatabaseHelper.useTestDatabase(tempDir.path);
  });

  tearDown(() async {
    await DatabaseHelper.resetForTest();
    DatabaseHelper.debugSeedCsv = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('MemoApp shows folders screen with seed folder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MemoApp());

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text(DatabaseHelper.seededFolderName).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Vocamio'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text(DatabaseHelper.seededFolderName), findsOneWidget);
  });

  test('seeds English–Polish deck and enables cascade delete', () async {
    final folders = await DatabaseHelper.instance.getFolders();
    expect(folders, isNotEmpty);
    expect(folders.first.name, DatabaseHelper.seededFolderName);

    final words = await DatabaseHelper.instance.getWordsForFolder(
      folders.first.id,
    );
    expect(words.length, 2);
    expect(words.any((w) => w.en == 'dog' && w.pl == 'pies'), isTrue);

    await DatabaseHelper.instance.deleteFolder(folders.first.id);
    expect(await DatabaseHelper.instance.getFolders(), isEmpty);
    expect(
      await DatabaseHelper.instance.getWordsForFolder(folders.first.id),
      isEmpty,
    );
  });

  test('import skips duplicates', () async {
    final folders = await DatabaseHelper.instance.getFolders();
    final folderId = folders.first.id;

    final first = await DatabaseHelper.instance.importWords(folderId, [
      (pl: 'dom testowy', en: 'test house'),
      (pl: 'kot testowy', en: 'test cat'),
    ]);
    expect(first.imported, 2);
    expect(first.skipped, 0);

    final second = await DatabaseHelper.instance.importWords(folderId, [
      (pl: 'dom testowy', en: 'test house'),
      (pl: 'pies', en: 'dog'), // already seeded
      (pl: 'auto testowe', en: 'test car'),
    ]);
    expect(second.imported, 1);
    expect(second.skipped, 2);

    final words = await DatabaseHelper.instance.getWordsForFolder(folderId);
    expect(words.length, 5); // 2 seed + 3 new
  });

  test('bundled CSV asset parses to 500 English–Polish pairs', () async {
    await DatabaseHelper.resetForTest();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    tempDir = await Directory.systemTemp.createTemp('memo_hive_full_');
    DatabaseHelper.debugSeedCsv = null;
    await DatabaseHelper.useTestDatabase(tempDir.path);

    final csv = await rootBundle.loadString('assets/en_pl_500.csv');
    expect(csv.contains('English;Polish'), isTrue);

    final folders = await DatabaseHelper.instance.getFolders();
    final words = await DatabaseHelper.instance.getWordsForFolder(
      folders.first.id,
    );
    expect(words.length, 500);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('shufflePracticeOrder randomizes folder word order', () async {
    final folders = await DatabaseHelper.instance.getFolders();
    final folderId = folders.first.id;

    await DatabaseHelper.instance.importWords(folderId, [
      for (var i = 0; i < 20; i++) (pl: 'pl$i', en: 'en$i'),
    ]);

    final before = await DatabaseHelper.instance.getWordsForFolder(folderId);
    final beforeIds = before.map((w) => w.id).toList();

    var changed = false;
    for (var attempt = 0; attempt < 20; attempt++) {
      await DatabaseHelper.instance.shufflePracticeOrder(folderId);
      final after = await DatabaseHelper.instance.getWordsForFolder(folderId);
      final afterIds = after.map((w) => w.id).toList();
      if (!_listEquals(beforeIds, afterIds)) {
        changed = true;
        for (var i = 0; i < after.length; i++) {
          expect(after[i].practiceOrder, i);
        }
        break;
      }
    }
    expect(changed, isTrue);
  });

  test('StudyDirection flips prompt and answer', () {
    const word = Word(folderId: 1, pl: 'pies', en: 'dog');
    expect(StudyDirection.plToEn.prompt(word), 'pies');
    expect(StudyDirection.plToEn.answer(word), 'dog');
    expect(StudyDirection.enToPl.prompt(word), 'dog');
    expect(StudyDirection.enToPl.answer(word), 'pies');
  });
}
