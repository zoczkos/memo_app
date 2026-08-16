import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/word.dart';

/// Shows the word editor used in dictionary management and study screens.
/// Returns the saved [Word] (with id) when created/updated, otherwise null.
Future<Word?> showWordEditorDialog(
  BuildContext context, {
  required int folderId,
  Word? word,
}) async {
  final plController = TextEditingController(text: word?.pl ?? '');
  final enController = TextEditingController(text: word?.en ?? '');

  final saved = await showDialog<Word>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(word == null ? 'New word' : 'Edit word'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: plController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Front'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: enController,
            decoration: const InputDecoration(labelText: 'Back'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final pl = plController.text.trim();
            final en = enController.text.trim();
            if (pl.isEmpty || en.isEmpty) return;

            if (word == null) {
              final created = await DatabaseHelper.instance.insertWord(
                Word(folderId: folderId, pl: pl, en: en),
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, created);
              }
            } else {
              final updated = word.copyWith(pl: pl, en: en);
              await DatabaseHelper.instance.updateWord(updated);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, updated);
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  plController.dispose();
  enController.dispose();
  return saved;
}
