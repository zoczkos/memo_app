class Folder {
  final int id;
  final String name;

  const Folder({required this.id, required this.name});

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  Folder copyWith({int? id, String? name}) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
