import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/word.dart';
import '../widgets/card_actions_menu.dart';
import '../widgets/word_dialog.dart';

class LearnScreen extends StatefulWidget {
  final int folderId;

  const LearnScreen({super.key, required this.folderId});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<Word> _dueWords = [];
  int _totalWords = 0;
  bool _isLoading = true;
  bool _showAnswer = false;
  StudyDirection _direction = StudyDirection.plToEn;

  @override
  void initState() {
    super.initState();
    _loadDueWords();
  }

  Future<void> _loadDueWords() async {
    final due = await DatabaseHelper.instance.getDueWords(widget.folderId);
    final all = await DatabaseHelper.instance.getWordsForFolder(widget.folderId);
    if (!mounted) return;
    setState(() {
      _dueWords = due;
      _totalWords = all.length;
      _isLoading = false;
      _showAnswer = false;
    });
  }

  Future<void> _handleReview(bool isOk) async {
    if (_dueWords.isEmpty) return;
    final currentWord = _dueWords[0];
    if (currentWord.id == null) return;

    await DatabaseHelper.instance.reviewWord(
      currentWord.id!,
      currentWord.interval,
      isOk,
    );
    await _loadDueWords();
  }

  void _toggleDirection() {
    setState(() {
      _direction = _direction == StudyDirection.plToEn
          ? StudyDirection.enToPl
          : StudyDirection.plToEn;
      _showAnswer = false;
    });
  }

  Future<void> _addWord() async {
    final saved = await showWordEditorDialog(
      context,
      folderId: widget.folderId,
    );
    if (saved != null) await _loadDueWords();
  }

  Future<void> _editCurrentWord() async {
    if (_dueWords.isEmpty) return;
    final saved = await showWordEditorDialog(
      context,
      folderId: widget.folderId,
      word: _dueWords[0],
    );
    if (saved != null) await _loadDueWords();
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

    final done = _totalWords - _dueWords.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('$done/$_totalWords'),
        actions: [
          TextButton(
            onPressed: _toggleDirection,
            child: Text(_direction.shortLabel),
          ),
          CardActionsMenu(
            canEdit: _dueWords.isNotEmpty,
            onSelected: _onCardMenu,
          ),
        ],
      ),
      body: _dueWords.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 80),
                    const SizedBox(height: 24),
                    const Text(
                      'Nice work!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'All words in this folder are done for today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to menu'),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _showAnswer
                                ? _direction.answer(_dueWords[0])
                                : _direction.prompt(_dueWords[0]),
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
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 22,
                    child: Text(
                      _showAnswer
                          ? ''
                          : 'Tap the card to reveal the answer',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.thumb_down),
                        label: const Text(
                          'Forgot',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.red[600]!.withValues(alpha: 0.35),
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            _showAnswer ? () => _handleReview(false) : null,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.thumb_up),
                        label: const Text(
                          'Got it',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.green[600]!.withValues(alpha: 0.35),
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            _showAnswer ? () => _handleReview(true) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
