import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/services.dart';
import 'models.dart';

// 타이머 상태 열거형
enum TimerState {
  inactive, // 비활성 상태
  focusMode, // 집중 모드
  restMode, // 휴식 모드
}

/// 타이머 모델 클래스
///
/// 집중 모드와 휴식 모드 타이머를 관리하는 모델
class TimerModel extends ChangeNotifier {
  // 타이머 상태
  TimerState _state = TimerState.inactive;
  TimerState get state => _state;

  // 타이머 설정 값 (초 단위)
  int _focusTime = 25 * 60; // 기본 25분
  int get focusTime => _focusTime;

  int _restTime = 5 * 60; // 기본 5분
  int get restTime => _restTime;

  // 경과 시간 (초 단위)
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  // 남은 시간 (초 단위)
  int _remainingSeconds = 0;
  int get remainingSeconds => _remainingSeconds;

  // 타이머 동작 상태
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // 타이머 객체
  Timer? _timer;

  // 알림 서비스
  final NotificationService _notificationService = NotificationService();

  // 통계 서비스
  final StatisticsService _statisticsService = StatisticsService();

  // 캐릭터 관련 콜백
  Function(String)? onEmotionChange;

  /// 타이머 시간 설정
  void setTimes({int? focusMinutes, int? restMinutes}) {
    if (focusMinutes != null) {
      _focusTime = focusMinutes * 60;
    }

    if (restMinutes != null) {
      _restTime = restMinutes * 60;
    }

    if (_state == TimerState.inactive) {
      _remainingSeconds = _focusTime;
    }

    notifyListeners();
  }

  /// 타이머 시작
  void startTimer({bool isFocusMode = true}) {
    if (_isRunning) return;

    if (_state == TimerState.inactive) {
      // 새로운 타이머 세션 시작
      _state = isFocusMode ? TimerState.focusMode : TimerState.restMode;
      _elapsedSeconds = 0;
      _remainingSeconds = isFocusMode ? _focusTime : _restTime;
    }

    _isRunning = true;
    _startTimerInternal();

    notifyListeners();
  }

  /// 타이머 일시 정지
  void pauseTimer() {
    if (!_isRunning) return;

    _isRunning = false;
    _timer?.cancel();
    _timer = null;

    notifyListeners();
  }

  /// 타이머 중지 (완전 종료)
  void stopTimer({bool completed = false}) {
    if (_state == TimerState.inactive) return;

    // 이전 상태 저장
    final wasRunning = _isRunning;
    final oldState = _state;
    final oldElapsed = _elapsedSeconds;

    // 타이머 종료
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _state = TimerState.inactive;

    // 통계 기록 (타이머가 실행 중이었던 경우에만)
    if (wasRunning) {
      if (oldState == TimerState.focusMode) {
        // 집중 세션 기록
        _statisticsService.recordFocusSession(oldElapsed, completed: completed);
      } else if (oldState == TimerState.restMode) {
        // 휴식 세션 기록
        _statisticsService.recordRestSession(oldElapsed, completed: completed);
      }
    }

    // 타이머 데이터 초기화
    _elapsedSeconds = 0;
    _remainingSeconds = _focusTime;
    // 알림 취소
    _notificationService.cancelAllNotifications();

    // 타이머 중지 시 캐릭터 감정 변경 (중간에 중지한 경우)
    if (!completed && wasRunning) {
      // 시간에 따라 다른 감정 표시
      if (oldState == TimerState.focusMode) {
        final targetTime = _focusTime;
        // 집중 모드 중간에 중지하면 진행 상황에 따라 감정 변화
        if (oldElapsed > (targetTime / 2)) {
          // 과반 이상 진행 후 중지 - 실망
          onEmotionChange?.call(Character.DISAPPOINTED);
        } else {
          // 초반에 중지 - 걱정
          onEmotionChange?.call(Character.WORRIED);
        }
      } else if (oldState == TimerState.restMode) {
        // 휴식 모드 중간에 중지해도 걱정 표시
        onEmotionChange?.call(Character.WORRIED);
      }
    }

    notifyListeners();
  }

  /// 내부 타이머 실행 로직
  void _startTimerInternal() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 타이머 업데이트
      _elapsedSeconds++;
      _remainingSeconds--;

      // 타이머 완료 체크
      if (_remainingSeconds <= 0) {
        _isRunning = false;
        _timer?.cancel();
        _timer = null;

        // 모드에 따른 처리
        if (_state == TimerState.focusMode) {
          // 집중 모드 완료 후 휴식 모드로 전환
          _statisticsService.recordFocusSession(
            _elapsedSeconds,
            completed: true,
          );

          // 알림 표시
          _notificationService.showTimerNotification(
            title: '집중 시간 완료!',
            body: '잘 하셨어요! 이제 휴식 시간이에요.',
          );

          // 다음 모드 준비
          _state = TimerState.restMode;
          _elapsedSeconds = 0;
          _remainingSeconds = _restTime;

          // 휴식 모드 바로 시작
          _startTimerInternal();

          // 캐릭터 감정 변경 - 완료했으므로 행복하거나 자랑스러움
          onEmotionChange?.call(Character.HAPPY);
        } else if (_state == TimerState.restMode) {
          // 휴식 모드 완료 후 비활성 상태로 전환
          _statisticsService.recordRestSession(
            _elapsedSeconds,
            completed: true,
          );

          // 알림 표시
          _notificationService.showTimerNotification(
            title: '휴식 시간 완료!',
            body: '충분히 쉬셨나요? 다시 집중할 준비가 되셨나요?',
          );

          // 초기 상태로 돌아가기
          _state = TimerState.inactive;
          _elapsedSeconds = 0;
          _remainingSeconds = _focusTime;

          // 캐릭터 감정 변경 - 보통 상태로
          onEmotionChange?.call(Character.NORMAL);
        }
      }

      notifyListeners();
    });
  }

  /// 리소스 해제
  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
