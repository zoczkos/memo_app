import '../models/word.dart';

/// Keeps the free-practice subset across screen opens until a new subset is chosen.
class FreePracticeSession {
  final int subsetIndex;
  final int currentIndex;
  final StudyDirection direction;

  const FreePracticeSession({
    required this.subsetIndex,
    required this.currentIndex,
    required this.direction,
  });

  FreePracticeSession copyWith({
    int? subsetIndex,
    int? currentIndex,
    StudyDirection? direction,
  }) {
    return FreePracticeSession(
      subsetIndex: subsetIndex ?? this.subsetIndex,
      currentIndex: currentIndex ?? this.currentIndex,
      direction: direction ?? this.direction,
    );
  }
}

class FreePracticeSessionStore {
  FreePracticeSessionStore._();

  static final Map<int, FreePracticeSession> _byFolder = {};

  static FreePracticeSession? get(int folderId) => _byFolder[folderId];

  static void save(int folderId, FreePracticeSession session) {
    _byFolder[folderId] = session;
  }

  static void clear(int folderId) {
    _byFolder.remove(folderId);
  }
}
