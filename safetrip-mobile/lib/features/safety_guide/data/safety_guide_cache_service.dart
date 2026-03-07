import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 안전가이드 SQLite 로컬 캐시 서비스 (DOC-T3-SFG-021 §8)
/// S3: 오프라인 안정성 — 긴급연락처는 영구 저장, 나머지는 24h TTL
class SafetyGuideCacheService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'safety_guide_cache.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE guide_cache (
            country_code TEXT NOT NULL,
            data_type TEXT NOT NULL,
            content TEXT NOT NULL,
            fetched_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            PRIMARY KEY (country_code, data_type)
          )
        ''');
        await db.execute('''
          CREATE TABLE emergency_contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            country_code TEXT NOT NULL,
            contact_type TEXT NOT NULL,
            phone_number TEXT NOT NULL,
            description_ko TEXT,
            is_24h INTEGER NOT NULL DEFAULT 1
          )
        ''');
        // 시드: 영사콜센터 (§7.2 하드코딩 필수)
        await db.insert('emergency_contacts', {
          'country_code': 'ALL',
          'contact_type': 'consulate_call_center',
          'phone_number': '+82-2-3210-0404',
          'description_ko': '영사콜센터 (24시간)',
          'is_24h': 1,
        });
      },
    );
  }

  /// 캐시된 가이드 데이터 조회 (TTL 확인)
  Future<Map<String, dynamic>?> getCachedGuide(
      String countryCode, String dataType) async {
    try {
      final db = await database;
      final results = await db.query(
        'guide_cache',
        where: 'country_code = ? AND data_type = ?',
        whereArgs: [countryCode, dataType],
      );
      if (results.isEmpty) return null;

      final row = results.first;
      final expiresAt = DateTime.parse(row['expires_at'] as String);
      final content =
          jsonDecode(row['content'] as String) as Map<String, dynamic>;

      // TTL 만료 여부와 관계없이 반환 (stale 판단은 호출자가)
      return {
        'content': content,
        'fetched_at': row['fetched_at'],
        'expires_at': row['expires_at'],
        'is_expired': DateTime.now().isAfter(expiresAt),
      };
    } catch (e) {
      debugPrint('[SafetyGuideCacheService] getCachedGuide Error: $e');
      return null;
    }
  }

  /// 가이드 데이터 캐시 저장 (UPSERT)
  Future<void> cacheGuide(
    String countryCode,
    String dataType,
    Map<String, dynamic> content,
    DateTime expiresAt,
  ) async {
    try {
      final db = await database;
      await db.insert(
        'guide_cache',
        {
          'country_code': countryCode,
          'data_type': dataType,
          'content': jsonEncode(content),
          'fetched_at': DateTime.now().toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[SafetyGuideCacheService] cacheGuide Error: $e');
    }
  }

  /// 긴급연락처 조회 (country_code + 'ALL' 폴백)
  Future<List<Map<String, dynamic>>> getEmergencyContacts(
      String countryCode) async {
    try {
      final db = await database;
      final results = await db.query(
        'emergency_contacts',
        where: 'country_code = ? OR country_code = ?',
        whereArgs: [countryCode, 'ALL'],
        orderBy: 'country_code DESC', // country-specific first, then ALL
      );
      return results;
    } catch (e) {
      debugPrint(
          '[SafetyGuideCacheService] getEmergencyContacts Error: $e');
      return [];
    }
  }

  /// 긴급연락처 저장 (영구 — TTL 없음, §8.4 1순위)
  Future<void> saveEmergencyContacts(
      String countryCode, List<Map<String, dynamic>> contacts) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        // 해당 국가 기존 연락처 삭제 (ALL 제외)
        await txn.delete(
          'emergency_contacts',
          where: 'country_code = ? AND country_code != ?',
          whereArgs: [countryCode, 'ALL'],
        );
        // 새 연락처 삽입
        for (final contact in contacts) {
          await txn.insert('emergency_contacts', {
            'country_code': countryCode,
            'contact_type': contact['contact_type'] ?? '',
            'phone_number': contact['phone_number'] ?? '',
            'description_ko': contact['description_ko'],
            'is_24h': (contact['is_24h'] == true) ? 1 : 0,
          });
        }
      });
    } catch (e) {
      debugPrint(
          '[SafetyGuideCacheService] saveEmergencyContacts Error: $e');
    }
  }
}
