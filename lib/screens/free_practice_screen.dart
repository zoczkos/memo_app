import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../free_practice_session.dart';
import '../models/word.dart';
import '../widgets/card_actions_menu.dart';
import '../widgets/word_dialog.dart';

class FreePracticeScreen extends StatefulWidget {
  final int folderId;

  const FreePracticeScreen({super.key, required this.folderId});

  @override
  State<FreePracticeScreen> createState() => _FreePracticeScreenState();
}

class _FreePracticeScreenState extends State<FreePracticeScreen> {
  static const _batchSize = 20;

  List<Word> _allWords = [];
  List<Word> _batch = [];
  int _subsetIndex = 0;
  int _subsetCount = 0;
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _showAnswer = false;
  StudyDirection _direction = StudyDirection.plToEn;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  int _computeSubsetCount(int wordCount) {
    if (wordCount <= 0) return 0;
    return (wordCount + _batchSize - 1) ~/ _batchSize;
  }

  List<Word> _subsetAt(List<Word> words, int index) {
    if (words.isEmpty || index < 0) return [];
    final start = index * _batchSize;
    if (start >= words.length) return [];
    final end = (start + _batchSize).clamp(0, words.length);
    return words.sublist(start, end);
  }

  String _subsetLabel(int index, int wordCount) {
    final start = index * _batchSize + 1;
    final end = ((index + 1) * _batchSize).clamp(0, wordCount);
    return '$start–$end';
  }

  void _persistSession() {
    FreePracticeSessionStore.save(
      widget.folderId,
      FreePracticeSession(
        subsetIndex: _subsetIndex,
        currentIndex: _currentIndex,
        direction: _direction,
      ),
    );
  }

  void _applySubset(
    int subsetIndex, {
    int currentIndex = 0,
    bool resetAnswer = true,
  }) {
    final count = _computeSubsetCount(_allWords.length);
    if (count == 0) {
      _subsetCount = 0;
      _subsetIndex = 0;
      _batch = [];
      _currentIndex = 0;
      _showAnswer = false;
      FreePracticeSessionStore.clear(widget.folderId);
      return;
    }

    final clamped = subsetIndex.clamp(0, count - 1);
    final batch = _subsetAt(_allWords, clamped);
    _subsetCount = count;
    _subsetIndex = clamped;
    _batch = batch;
    _currentIndex = batch.isEmpty
        ? 0
        : currentIndex.clamp(0, batch.length - 1);
    if (resetAnswer) _showAnswer = false;
    _persistSession();
  }

  Future<void> _loadWords() async {
    final data = await DatabaseHelper.instance.getWordsForFolder(
      widget.folderId,
    );
    if (!mounted) return;

    final saved = FreePracticeSessionStore.get(widget.folderId);
    final subsetIndex = saved?.subsetIndex ?? 0;
    final index = saved?.currentIndex ?? 0;
    final direction = saved?.direction ?? StudyDirection.plToEn;

    setState(() {
      _allWords = data;
      _isLoading = false;
      _direction = direction;
      _applySubset(subsetIndex, currentIndex: index);
    });
  }

  void _selectSubset(int? subsetIndex) {
    if (subsetIndex == null || subsetIndex == _subsetIndex) return;
    setState(() {
      _applySubset(subsetIndex);
    });
  }

  void _nextCard() {
    if (_batch.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _batch.length;
      _showAnswer = false;
    });
    _persistSession();
  }

  void _toggleDirection() {
    setState(() {
      _direction = _direction == StudyDirection.plToEn
          ? StudyDirection.enToPl
          : StudyDirection.plToEn;
      _showAnswer = false;
    });
    _persistSession();
  }

  Future<void> _addWord() async {
    final saved = await showWordEditorDialog(
      context,
      folderId: widget.folderId,
    );
    if (saved == null || !mounted) return;

    setState(() {
      _allWords = [..._allWords, saved]
        ..sort((a, b) {
          final byOrder = a.practiceOrder.compareTo(b.practiceOrder);
          if (byOrder != 0) return byOrder;
          return a.pl.toLowerCase().compareTo(b.pl.toLowerCase());
        });
      _applySubset(_subsetIndex, currentIndex: _currentIndex);
    });
  }

  Future<void> _editCurrentWord() async {
    if (_batch.isEmpty) return;
    final current = _batch[_currentIndex];
    final saved = await showWordEditorDialog(
      context,
      folderId: widget.folderId,
      word: current,
    );
    if (saved == null || !mounted) return;

    setState(() {
      final i = _allWords.indexWhere((w) => w.id == saved.id);
      if (i >= 0) _allWords[i] = saved;
      _allWords.sort((a, b) {
        final byOrder = a.practiceOrder.compareTo(b.practiceOrder);
        if (byOrder != 0) return byOrder;
        return a.pl.toLowerCase().compareTo(b.pl.toLowerCase());
      });
      _applySubset(_subsetIndex, currentIndex: _currentIndex);
    });
  }

  void _onCardMenu(CardMenuAction action) {
    switch (action) {
      case CardMenuAction.add:
        _addWord();
      case CardMenuAction.edit:
        _editCurrentWord();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _batch.isEmpty ? '0/0' : '${_currentIndex + 1}/${_batch.length}',
        ),
        backgroundColor: Colors.orange[50],
        foregroundColor: Colors.orange[900],
        actions: [
          TextButton(
            onPressed: _toggleDirection,
            child: Text(
              _direction.shortLabel,
              style: TextStyle(color: Colors.orange[900]),
            ),
          ),
          CardActionsMenu(
            canEdit: _batch.isNotEmpty,
            iconColor: Colors.orange[900],
            onSelected: _onCardMenu,
          ),
        ],
      ),
      body: _allWords.isEmpty
          ? const Center(child: Text('This folder is empty.'))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_subsetCount > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('$_subsetCount-$_subsetIndex'),
                          initialValue: _subsetIndex,
                          decoration: InputDecoration(
                            labelText: 'Words',
                            labelStyle: TextStyle(color: Colors.orange[900]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade600,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            for (var i = 0; i < _subsetCount; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  _subsetLabel(i, _allWords.length),
                                ),
                              ),
                          ],
                          onChanged: _selectSubset,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAnswer = !_showAnswer;
                      });
                    },
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        width: 320,
                        height: 220,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _showAnswer
                              ? Colors.orange[100]
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _showAnswer
                                ? _direction.answer(_batch[_currentIndex])
                                : _direction.prompt(_batch[_currentIndex]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _showAnswer ? _nextCard : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.orange[600]!.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Next card',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
