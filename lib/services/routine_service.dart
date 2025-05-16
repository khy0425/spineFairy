import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:collection';

import '../models/models.dart';

/// 루틴 서비스
///
/// 사용자의 루틴 기록을 관리하고 저장하는 서비스
class RoutineService {
  static final RoutineService _instance = RoutineService._internal();
  factory RoutineService() => _instance;

  RoutineService._internal();

  // 데이터베이스 인스턴스
  Database? _database;

  // 웹일 경우 인메모리 저장소
  final Map<String, List<RoutineLog>> _inMemoryLogs =
      HashMap<String, List<RoutineLog>>();

  // 날짜 포매터
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // 초기화 완료 여부
  bool _initialized = false;

  // 데이터베이스 초기화
  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      // 웹에서는 인메모리로 동작
      _initialized = true;
      return;
    }

    try {
      // 모바일에서는 SQLite 사용
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'routine_database.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE routine_logs(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              date TEXT NOT NULL,
              focused_time INTEGER NOT NULL,
              rest_time INTEGER NOT NULL,
              feedback_message TEXT
            )
          ''');
        },
      );

      _initialized = true;
    } catch (e) {
      debugPrint('데이터베이스 초기화 오류: $e');
      // 오류 발생 시에도 인메모리로 대체
      _initialized = true;
    }
  }

  // 오늘의 루틴 로그 가져오기
  Future<RoutineLog?> getTodayLog(String userId) async {
    await initialize();

    final today = DateTime.now();
    return getLogByDate(userId, today);
  }

  // 특정 날짜의 루틴 로그 가져오기
  Future<RoutineLog?> getLogByDate(String userId, DateTime date) async {
    await initialize();

    final dateStr = _dateFormat.format(date);

    if (kIsWeb || _database == null) {
      // 웹에서는 인메모리에서 조회
      final userLogs = _inMemoryLogs[userId] ?? [];
      return userLogs.firstWhere(
        (log) => _dateFormat.format(log.date) == dateStr,
        orElse:
            () => RoutineLog(
              userId: userId,
              date: date,
              focusedTime: 0,
              restTime: 0,
            ),
      );
    }

    // 모바일에서는 SQLite 조회
    final logs = await _database!.query(
      'routine_logs',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, dateStr],
    );

    if (logs.isEmpty) return null;

    return RoutineLog.fromMap(logs.first);
  }

  // 날짜 범위의 루틴 로그 가져오기
  Future<List<RoutineLog>> getLogsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await initialize();

    final startDateStr = _dateFormat.format(startDate);
    final endDateStr = _dateFormat.format(endDate);

    if (kIsWeb || _database == null) {
      // 웹에서는 인메모리에서 조회
      final userLogs = _inMemoryLogs[userId] ?? [];
      return userLogs.where((log) {
        final logDateStr = _dateFormat.format(log.date);
        return logDateStr.compareTo(startDateStr) >= 0 &&
            logDateStr.compareTo(endDateStr) <= 0;
      }).toList();
    }

    // 모바일에서는 SQLite 조회
    final logs = await _database!.query(
      'routine_logs',
      where: 'user_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [userId, startDateStr, endDateStr],
      orderBy: 'date ASC',
    );

    return logs.map((log) => RoutineLog.fromMap(log)).toList();
  }

  // 루틴 로그 저장
  Future<int> saveRoutineLog(RoutineLog log) async {
    await initialize();

    if (kIsWeb || _database == null) {
      // 웹에서는 인메모리에 저장
      final userLogs = _inMemoryLogs[log.userId] ?? [];

      // 기존 로그 찾기
      final dateStr = _dateFormat.format(log.date);
      final existingLogIndex = userLogs.indexWhere(
        (l) => _dateFormat.format(l.date) == dateStr,
      );

      if (existingLogIndex >= 0) {
        // 기존 로그 업데이트
        userLogs[existingLogIndex] = log;
      } else {
        // 새 로그 추가
        userLogs.add(log);
      }

      _inMemoryLogs[log.userId] = userLogs;
      return 1; // 성공 반환
    }

    // 모바일에서는 SQLite에 저장
    final existingLog = await getLogByDate(log.userId, log.date);

    if (existingLog != null) {
      // 기존 로그 업데이트
      return await _database!.update(
        'routine_logs',
        log.toMap(),
        where: 'id = ?',
        whereArgs: [existingLog.id],
      );
    } else {
      // 새 로그 추가
      return await _database!.insert('routine_logs', log.toMap());
    }
  }

  // 휴식 시간 추가
  Future<void> addRestTime(String userId, int minutes) async {
    await initialize();

    final today = DateTime.now();
    var log = await getLogByDate(userId, today);

    if (log == null) {
      // 새 로그 생성
      log = RoutineLog(
        userId: userId,
        date: today,
        focusedTime: 0,
        restTime: minutes,
      );
    } else {
      // 기존 로그 업데이트
      log = log.copyWith(restTime: log.restTime + minutes);
    }

    await saveRoutineLog(log);
  }

  // 집중 시간 추가
  Future<void> addFocusedTime(String userId, int minutes) async {
    await initialize();

    final today = DateTime.now();
    var log = await getLogByDate(userId, today);

    if (log == null) {
      // 새 로그 생성
      log = RoutineLog(
        userId: userId,
        date: today,
        focusedTime: minutes,
        restTime: 0,
      );
    } else {
      // 기존 로그 업데이트
      log = log.copyWith(focusedTime: log.focusedTime + minutes);
    }

    await saveRoutineLog(log);
  }

  // 피드백 메시지 업데이트
  Future<void> updateFeedbackMessage(String userId, String message) async {
    await initialize();

    final today = DateTime.now();
    var log = await getLogByDate(userId, today);

    if (log == null) {
      // 새 로그 생성
      log = RoutineLog(
        userId: userId,
        date: today,
        focusedTime: 0,
        restTime: 0,
        feedbackMessage: message,
      );
    } else {
      // 기존 로그 업데이트
      log = log.copyWith(feedbackMessage: message);
    }

    await saveRoutineLog(log);
  }

  // 주간 통계 계산
  Future<Map<String, dynamic>> getWeeklyStats(String userId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final logs = await getLogsByDateRange(userId, startOfWeek, endOfWeek);

    int totalFocusedTime = 0;
    int totalRestTime = 0;
    double averageAdherenceRate = 0;

    if (logs.isNotEmpty) {
      for (final log in logs) {
        totalFocusedTime += log.focusedTime;
        totalRestTime += log.restTime;
        averageAdherenceRate += log.adherenceRate;
      }

      averageAdherenceRate = averageAdherenceRate / logs.length;
    }

    return {
      'totalFocusedTime': totalFocusedTime,
      'totalRestTime': totalRestTime,
      'averageAdherenceRate': averageAdherenceRate,
      'daysCounted': logs.length,
    };
  }

  // 데이터베이스 닫기
  Future<void> close() async {
    if (!kIsWeb && _database != null) {
      await _database!.close();
      _database = null;
    }

    _initialized = false;
  }
}
