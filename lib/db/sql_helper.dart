import '../models/diary_entry.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../services/encryption_service.dart';

class SQLHelper {
  static Database? _db;
  static final List<DiaryEntry> _webEntries = [
    DiaryEntry(id: 1, title: 'Welcome', content: 'This is a web mock entry.', date: '2025-07-02'),
  ];

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'diary.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE diaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            date TEXT,
            mood TEXT,
            tags TEXT,
            imagePath TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE diaries ADD COLUMN mood TEXT;');
          await db.execute('ALTER TABLE diaries ADD COLUMN tags TEXT;');
          await db.execute('ALTER TABLE diaries ADD COLUMN imagePath TEXT;');
        }
      },
    );
  }

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<List<DiaryEntry>> getDiaries() async {
    if (kIsWeb) {
      return List<DiaryEntry>.from(_webEntries);
    } else {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('diaries', orderBy: "id DESC");
      final entries = <DiaryEntry>[];
      for (final map in maps) {
        final entry = DiaryEntry.fromMap(map);
        if (entry.content != null) {
          try {
            entry.content = await EncryptionService().decryptData(entry.content!);
          } catch (e) {
            // Keep original content if decryption fails
          }
        }
        entries.add(entry);
      }
      return entries;
    }
  }

  static Future<int> createDiary(DiaryEntry entry) async {
    if (kIsWeb) {
      final newId = (_webEntries.isNotEmpty ? _webEntries.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) : 0) + 1;
      _webEntries.insert(0, DiaryEntry(
        id: newId,
        title: entry.title,
        content: entry.content,
        date: entry.date,
        mood: entry.mood,
        tags: entry.tags,
        imagePath: entry.imagePath,
      ));
      return newId;
    } else {
      final db = await database;
      final encryptedEntry = DiaryEntry(
        title: entry.title,
        content: entry.content != null ? await EncryptionService().encryptData(entry.content!) : null,
        date: entry.date,
        mood: entry.mood,
        tags: entry.tags,
        imagePath: entry.imagePath,
      );
      return await db.insert('diaries', encryptedEntry.toMap());
    }
  }

  static Future<int> updateDiary(DiaryEntry entry) async {
    if (kIsWeb) {
      final idx = _webEntries.indexWhere((e) => e.id == entry.id);
      if (idx != -1) {
        _webEntries[idx] = entry;
        return 1;
      }
      return 0;
    } else {
      final db = await database;
      final encryptedEntry = DiaryEntry(
        id: entry.id,
        title: entry.title,
        content: entry.content != null ? await EncryptionService().encryptData(entry.content!) : null,
        date: entry.date,
        mood: entry.mood,
        tags: entry.tags,
        imagePath: entry.imagePath,
      );
      return await db.update('diaries', encryptedEntry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
    }
  }

  static Future<void> deleteDiary(int id) async {
    if (kIsWeb) {
      _webEntries.removeWhere((e) => e.id == id);
    } else {
      final db = await database;
      await db.delete('diaries', where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<List<DiaryEntry>> getFlashbackEntries(String currentDate) async {
    // currentDate in 'YYYY-MM-DD' format
    final parts = currentDate.split('-');
    if (parts.length != 3) return [];
    final currentYear = int.parse(parts[0]);
    final monthDay = '${parts[1]}-${parts[2]}'; // MM-DD

    if (kIsWeb) {
      return _webEntries.where((e) {
        final eParts = e.date.split('-');
        if (eParts.length != 3) return false;
        final eYear = int.parse(eParts[0]);
        final eMonthDay = '${eParts[1]}-${eParts[2]}';
        return eMonthDay == monthDay && eYear < currentYear;
      }).toList();
    } else {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'diaries',
        where: "substr(date, 6) = ? AND substr(date, 1, 4) < ?",
        whereArgs: [monthDay, currentYear.toString()],
        orderBy: "date DESC",
      );
      final entries = <DiaryEntry>[];
      for (final map in maps) {
        final entry = DiaryEntry.fromMap(map);
        if (entry.content != null) {
          try {
            entry.content = await EncryptionService().decryptData(entry.content!);
          } catch (e) {
            // Keep original content if decryption fails
          }
        }
        entries.add(entry);
      }
      return entries;
    }
  }
}
