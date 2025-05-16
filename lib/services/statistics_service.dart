import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 통계 서비스
///
/// 사용자의 타이머 사용 통계를 기록하고 관리하는 서비스
class StatisticsService {
  // 싱글톤 인스턴스
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  StatisticsService._internal();

  // SharedPreferences 키
  static const String _keyDailyStats = 'daily_stats';
  static const String _keyWeeklyStats = 'weekly_stats';

  /// 집중 세션 기록
  Future<void> recordFocusSession(int seconds, {bool completed = false}) async {
    if (seconds <= 0) return;

    try {
      // 오늘 날짜
      final today = _getDateString(DateTime.now());

      // 기존 데이터 로드
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString(_keyDailyStats) ?? '{}';
      final stats = jsonDecode(statsString) as Map<String, dynamic>;

      // 오늘 데이터가 없으면 생성
      if (!stats.containsKey(today)) {
        stats[today] = {
          'focusedTime': 0,
          'restTime': 0,
          'focusCount': 0,
          'completedFocusCount': 0,
          'restCount': 0,
          'completedRestCount': 0,
        };
      }

      // 시간(초) 추가
      final todayStats = stats[today] as Map<String, dynamic>;
      final focusedTime = (todayStats['focusedTime'] as int) + seconds;
      todayStats['focusedTime'] = focusedTime;

      // 세션 카운트 증가
      todayStats['focusCount'] = (todayStats['focusCount'] as int) + 1;

      // 완료된 세션인 경우 카운트 증가
      if (completed) {
        todayStats['completedFocusCount'] =
            (todayStats['completedFocusCount'] as int) + 1;
      }

      // 통계 저장
      await prefs.setString(_keyDailyStats, jsonEncode(stats));

      // 주간 통계 업데이트
      await _updateWeeklyStats();

      debugPrint('StatisticsService: 집중 세션 기록 완료 ($seconds초)');
    } catch (e) {
      debugPrint('StatisticsService: 집중 세션 기록 오류 $e');
    }
  }

  /// 휴식 세션 기록
  Future<void> recordRestSession(int seconds, {bool completed = false}) async {
    if (seconds <= 0) return;

    try {
      // 오늘 날짜
      final today = _getDateString(DateTime.now());

      // 기존 데이터 로드
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString(_keyDailyStats) ?? '{}';
      final stats = jsonDecode(statsString) as Map<String, dynamic>;

      // 오늘 데이터가 없으면 생성
      if (!stats.containsKey(today)) {
        stats[today] = {
          'focusedTime': 0,
          'restTime': 0,
          'focusCount': 0,
          'completedFocusCount': 0,
          'restCount': 0,
          'completedRestCount': 0,
        };
      }

      // 시간(초) 추가
      final todayStats = stats[today] as Map<String, dynamic>;
      final restTime = (todayStats['restTime'] as int) + seconds;
      todayStats['restTime'] = restTime;

      // 세션 카운트 증가
      todayStats['restCount'] = (todayStats['restCount'] as int) + 1;

      // 완료된 세션인 경우 카운트 증가
      if (completed) {
        todayStats['completedRestCount'] =
            (todayStats['completedRestCount'] as int) + 1;
      }

      // 통계 저장
      await prefs.setString(_keyDailyStats, jsonEncode(stats));

      // 주간 통계 업데이트
      await _updateWeeklyStats();

      debugPrint('StatisticsService: 휴식 세션 기록 완료 ($seconds초)');
    } catch (e) {
      debugPrint('StatisticsService: 휴식 세션 기록 오류 $e');
    }
  }

  /// 집중 시간 추가 (보상 등)
  Future<void> addFocusedTime(String userId, int minutes) async {
    if (minutes <= 0) return;

    try {
      // 오늘 날짜
      final today = _getDateString(DateTime.now());

      // 기존 데이터 로드
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString(_keyDailyStats) ?? '{}';
      final stats = jsonDecode(statsString) as Map<String, dynamic>;

      // 오늘 데이터가 없으면 생성
      if (!stats.containsKey(today)) {
        stats[today] = {
          'focusedTime': 0,
          'restTime': 0,
          'focusCount': 0,
          'completedFocusCount': 0,
          'restCount': 0,
          'completedRestCount': 0,
        };
      }

      // 시간(초) 추가
      final todayStats = stats[today] as Map<String, dynamic>;
      final focusedTime = (todayStats['focusedTime'] as int) + (minutes * 60);
      todayStats['focusedTime'] = focusedTime;

      // 통계 저장
      await prefs.setString(_keyDailyStats, jsonEncode(stats));

      // 주간 통계 업데이트
      await _updateWeeklyStats();

      debugPrint('StatisticsService: 집중 시간 추가 완료 ($minutes분)');
    } catch (e) {
      debugPrint('StatisticsService: 집중 시간 추가 오류 $e');
    }
  }

  /// 오늘의 통계 가져오기
  Future<Map<String, dynamic>?> getTodayLog(String userId) async {
    try {
      // 오늘 날짜
      final today = _getDateString(DateTime.now());

      // 기존 데이터 로드
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString(_keyDailyStats) ?? '{}';
      final stats = jsonDecode(statsString) as Map<String, dynamic>;

      // 오늘 데이터가 없으면 기본값 반환
      if (!stats.containsKey(today)) {
        return {
          'focusedTime': 0,
          'restTime': 0,
          'focusCount': 0,
          'completedFocusCount': 0,
          'restCount': 0,
          'completedRestCount': 0,
          'adherenceRate': 0.0,
        };
      }

      // 통계 반환
      final todayStats = stats[today] as Map<String, dynamic>;

      // 준수율 계산 (완료된 세션 / 총 세션)
      final totalSessions =
          (todayStats['focusCount'] as int) + (todayStats['restCount'] as int);
      final completedSessions =
          (todayStats['completedFocusCount'] as int) +
          (todayStats['completedRestCount'] as int);

      double adherenceRate = 0.0;
      if (totalSessions > 0) {
        adherenceRate = (completedSessions / totalSessions) * 100;
      }

      // 분 단위로 변환
      final focusedTime = (todayStats['focusedTime'] as int) ~/ 60;
      final restTime = (todayStats['restTime'] as int) ~/ 60;

      return {
        'focusedTime': focusedTime,
        'restTime': restTime,
        'focusCount': todayStats['focusCount'],
        'completedFocusCount': todayStats['completedFocusCount'],
        'restCount': todayStats['restCount'],
        'completedRestCount': todayStats['completedRestCount'],
        'adherenceRate': adherenceRate,
      };
    } catch (e) {
      debugPrint('StatisticsService: 오늘 통계 로드 오류 $e');
      return null;
    }
  }

  /// 주간 통계 업데이트
  Future<void> _updateWeeklyStats() async {
    try {
      // 기존 데이터 로드
      final prefs = await SharedPreferences.getInstance();
      final dailyStatsString = prefs.getString(_keyDailyStats) ?? '{}';
      final dailyStats = jsonDecode(dailyStatsString) as Map<String, dynamic>;

      // 주간 통계 초기화
      final weeklyStats = <String, dynamic>{};

      // 현재 날짜
      final now = DateTime.now();

      // 최근 7일간의 데이터 집계
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateString = _getDateString(date);

        if (dailyStats.containsKey(dateString)) {
          weeklyStats[dateString] = dailyStats[dateString];
        }
      }

      // 주간 통계 저장
      await prefs.setString(_keyWeeklyStats, jsonEncode(weeklyStats));
    } catch (e) {
      debugPrint('StatisticsService: 주간 통계 업데이트 오류 $e');
    }
  }

  /// 날짜를 문자열로 변환 (yyyy-MM-dd 형식)
  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
