import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/internship_profile.dart';
import '../models/time_log.dart';

class DtrDatabase {
  DtrDatabase._();

  static final DtrDatabase instance = DtrDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'mydtr.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profiles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            total_hours_required REAL NOT NULL,
            hours_per_day REAL NOT NULL,
            working_days TEXT NOT NULL,
            shift_type TEXT NOT NULL,
            avatar_path TEXT,
            created_at TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE time_logs (
            id TEXT PRIMARY KEY,
            profile_id TEXT NOT NULL,
            segment TEXT NOT NULL,
            direction TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            day_token TEXT NOT NULL,
            FOREIGN KEY(profile_id) REFERENCES profiles(id) ON DELETE CASCADE
          );
        ''');
        await db.execute(
          'CREATE INDEX idx_logs_profile ON time_logs(profile_id);',
        );
        await db.execute('CREATE INDEX idx_logs_day ON time_logs(day_token);');
      },
    );
    return _database!;
  }

  Future<List<InternshipProfile>> fetchProfiles() async {
    final db = await database;
    final result = await db.query('profiles', orderBy: 'created_at DESC');
    return result.map(InternshipProfile.fromMap).toList();
  }

  Future<InternshipProfile> insertProfile(InternshipProfile profile) async {
    final db = await database;
    await db.insert(
      'profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return profile;
  }

  Future<void> removeProfile(String profileId) async {
    final db = await database;
    await db.delete('profiles', where: 'id = ?', whereArgs: [profileId]);
  }

  Future<void> updateProfile(InternshipProfile profile) async {
    final db = await database;
    await db.update(
      'profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<List<TimeLog>> fetchLogs(String profileId) async {
    final db = await database;
    final result = await db.query(
      'time_logs',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'timestamp DESC',
    );
    return result.map(TimeLog.fromMap).toList();
  }

  Future<void> insertLog(TimeLog log) async {
    final db = await database;
    await db.insert(
      'time_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
