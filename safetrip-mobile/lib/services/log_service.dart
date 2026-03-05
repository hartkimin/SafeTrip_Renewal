import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LogService {
  factory LogService() => _instance;
  LogService._internal();
  static final LogService _instance = LogService._internal();

  Database? _database;
  static const String _tableName = 'TB_APP_LOG';
  static const int _maxLogs = 10000; // 최대 보관 로그 수

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_logs.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            log_id INTEGER PRIMARY KEY AUTOINCREMENT,
            log_type TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s', 'now'))
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_log_type ON $_tableName(log_type, timestamp DESC)
        ''');
        await db.execute('''
          CREATE INDEX idx_timestamp ON $_tableName(timestamp DESC)
        ''');
      },
    );
  }

  /// 로그 추가
  Future<void> addLog(String logType, Map<String, dynamic> data) async {
    try {
      final db = await database;
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final dataJson = jsonEncode(data);

      await db.insert(_tableName, {
        'log_type': logType,
        'timestamp': timestamp,
        'data': dataJson,
      });

      // 최대 로그 수 초과 시 오래된 로그 삭제
      await _cleanupOldLogs();
    } catch (e) {
      debugPrint('[LogService] 로그 저장 실패: $e');
    }
  }

  /// 로그 조회
  Future<List<Map<String, dynamic>>> getLogs({
    String? logType,
    int? limit,
    DateTime? since,
  }) async {
    try {
      final db = await database;
      var query = 'SELECT * FROM $_tableName WHERE 1=1';
      final args = <dynamic>[];

      if (logType != null) {
        query += ' AND log_type = ?';
        args.add(logType);
      }

      if (since != null) {
        query += ' AND timestamp >= ?';
        args.add(since.toUtc().toIso8601String());
      }

      query += ' ORDER BY timestamp DESC';

      if (limit != null) {
        query += ' LIMIT ?';
        args.add(limit);
      }

      final results = await db.rawQuery(query, args);

      return results.map((row) {
        final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        return {
          'log_id': row['log_id'],
          'log_type': row['log_type'],
          'timestamp': DateTime.parse(row['timestamp'] as String),
          'data': data,
          'created_at': row['created_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[LogService] 로그 조회 실패: $e');
      return [];
    }
  }

  /// 로그 개수 조회
  Future<int> getLogCount({String? logType}) async {
    try {
      final db = await database;
      var query = 'SELECT COUNT(*) as count FROM $_tableName';
      final args = <dynamic>[];

      if (logType != null) {
        query += ' WHERE log_type = ?';
        args.add(logType);
      }

      final result = await db.rawQuery(query, args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('[LogService] 로그 개수 조회 실패: $e');
      return 0;
    }
  }

  /// 로그 삭제
  Future<void> clearLogs({String? logType, DateTime? before}) async {
    try {
      final db = await database;
      var query = 'DELETE FROM $_tableName WHERE 1=1';
      final args = <dynamic>[];

      if (logType != null) {
        query += ' AND log_type = ?';
        args.add(logType);
      }

      if (before != null) {
        query += ' AND timestamp < ?';
        args.add(before.toUtc().toIso8601String());
      }

      await db.rawDelete(query, args);
    } catch (e) {
      debugPrint('[LogService] 로그 삭제 실패: $e');
    }
  }

  /// 오래된 로그 정리 (최대 개수 초과 시)
  Future<void> _cleanupOldLogs() async {
    try {
      final count = await getLogCount();
      if (count > _maxLogs) {
        final db = await database;
        // 오래된 로그부터 삭제
        await db.rawDelete(
          '''
          DELETE FROM $_tableName 
          WHERE log_id IN (
            SELECT log_id FROM $_tableName 
            ORDER BY timestamp ASC 
            LIMIT ?
          )
        ''',
          [count - _maxLogs],
        );
      }
    } catch (e) {
      debugPrint('[LogService] 로그 정리 실패: $e');
    }
  }

  /// 7일 이상 된 로그 자동 삭제
  Future<void> cleanupOldLogsByDate() async {
    try {
      final sevenDaysAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 7),
      );
      await clearLogs(before: sevenDaysAgo);
    } catch (e) {
      debugPrint('[LogService] 날짜 기반 로그 정리 실패: $e');
    }
  }

  /// 데이터베이스 닫기
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
