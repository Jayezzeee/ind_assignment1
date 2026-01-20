// lib/models/diary_entry.dart

class DiaryEntry {
  int? id;
  String? title;
  String? content;
  String date;
  String? mood;
  List<String>? tags;
  String? imagePath;

  DiaryEntry({
    this.id,
    this.title,
    this.content,
    required this.date,
    this.mood,
    this.tags,
    this.imagePath,
  });

  factory DiaryEntry.fromMap(Map<String, dynamic> m) {
    return DiaryEntry(
      id: m['id'] as int?,
      title: m['title'] as String?,
      content: m['content'] as String?,
      date: m['date'] as String,
      mood: m['mood'] as String?,
      tags: m['tags'] is String ? (m['tags'] as String).split(',') : (m['tags'] as List?)?.cast<String>(),
      imagePath: m['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'date': date,
      'mood': mood,
      'tags': tags?.join(','),
      'imagePath': imagePath,
    };
  }
}
