// lib/models/diary_entry.dart

class DiaryEntry {
  final int? id;
  final String title;
  final String content;
  final String date;
  final String mood; // e.g., "happy", "sad", etc.
  final List<String> tags;
  final String? imagePath;

  DiaryEntry({
    this.id,
    required this.title,
    required this.content,
    required this.date,
    this.mood = '',
    this.tags = const [],
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date,
      'mood': mood,
      'tags': tags.join(','),
      'imagePath': imagePath,
    };
  }

  static DiaryEntry fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      date: map['date'],
      mood: map['mood'] ?? '',
      tags: map['tags'] != null && map['tags'] is String && (map['tags'] as String).isNotEmpty
          ? (map['tags'] as String).split(',')
          : <String>[],
      imagePath: map['imagePath'],
    );
  }
}
