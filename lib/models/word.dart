class Word {
  final int? id;
  final int folderId;
  final String pl;
  final String en;
  final int interval;
  final int nextReview;
  final int practiceOrder;

  const Word({
    this.id,
    required this.folderId,
    required this.pl,
    required this.en,
    this.interval = 0,
    this.nextReview = 0,
    this.practiceOrder = 0,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      folderId: map['folder_id'] as int,
      pl: map['pl'] as String,
      en: map['en'] as String,
      interval: map['interval'] as int? ?? 0,
      nextReview: map['next_review'] as int? ?? 0,
      practiceOrder: map['practice_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'folder_id': folderId,
      'pl': pl,
      'en': en,
      'interval': interval,
      'next_review': nextReview,
      'practice_order': practiceOrder,
    };
  }

  Word copyWith({
    int? id,
    int? folderId,
    String? pl,
    String? en,
    int? interval,
    int? nextReview,
    int? practiceOrder,
  }) {
    return Word(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      pl: pl ?? this.pl,
      en: en ?? this.en,
      interval: interval ?? this.interval,
      nextReview: nextReview ?? this.nextReview,
      practiceOrder: practiceOrder ?? this.practiceOrder,
    );
  }
}

enum StudyDirection { plToEn, enToPl }

extension StudyDirectionX on StudyDirection {
  String get label => switch (this) {
    StudyDirection.plToEn => 'Front → Back',
    StudyDirection.enToPl => 'Back → Front',
  };

  String get shortLabel => switch (this) {
    StudyDirection.plToEn => 'F→B',
    StudyDirection.enToPl => 'B→F',
  };

  String prompt(Word word) => switch (this) {
    StudyDirection.plToEn => word.pl,
    StudyDirection.enToPl => word.en,
  };

  String answer(Word word) => switch (this) {
    StudyDirection.plToEn => word.en,
    StudyDirection.enToPl => word.pl,
  };
}
