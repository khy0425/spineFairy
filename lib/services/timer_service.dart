import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import '../generated/app_localizations.dart';

import 'music_service.dart';
import 'ad_service.dart';
import 'notification_service.dart';

/// 타이머 상태
enum TimerState {
  inactive, // 비활성
  focusMode, // 집중 모드
  restMode, // 휴식 모드
}

/// 타이머 완료 콜백 타입
typedef TimerCompletionCallback = void Function(bool wasFocusMode);

/// 타이머 서비스
///
/// 백그라운드에서 타이머를 관리하고 알림을 보내는 서비스
class TimerService extends ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;

  TimerService._internal();

  // 컨텍스트를 저장하기 위한 필드
  BuildContext? _currentContext;

  // 컨텍스트 설정 메소드
  void setContext(BuildContext context) {
    _currentContext = context;
  }

  // isolate 통신을 위한 리시버 포트
  ReceivePort? _receivePort;
  // isolate 참조
  Isolate? _isolate;
  // 알림 관리자
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  // 타이머 활성화 상태
  bool _isActive = false;
  // 타이머 시작 시간
  DateTime? _startTime;
  // 포커스 모드 상태 (true: 집중 중, false: 휴식 중)
  bool _isFocusMode = true;
  // 현재 타이머 상태
  TimerState currentState = TimerState.inactive;

  // 집중 타임 (분)
  int _focusTime = 50;
  // 휴식 타임 (분)
  int _restTime = 10;

  // 초기화 완료 여부
  bool _isInitialized = false;

  // 타이머 인스턴스
  Timer? _timer;

  // 경과 시간 (초)
  int _elapsed = 0;

  // 집중 시간 (초)
  int _focusDuration = 50 * 60; // 50분 (기본값)

  // 휴식 시간 (초)
  int _restDuration = 10 * 60; // 10분 (기본값)

  // 세션 목표 (초)
  final int _sessionGoal = 25 * 60; // 기본 25분

  // 타이머 완료 콜백
  TimerCompletionCallback? _onTimerCompleted;

  // 음악 서비스
  final MusicService _musicService = MusicService();

  // 알림 서비스
  final NotificationService _notificationService = NotificationService();

  // Getters
  bool get isActive => _isActive;
  bool get isFocusMode => _isFocusMode;
  DateTime? get startTime => _startTime;
  int get focusTime => _focusTime;
  int get restTime => _restTime;
  int get elapsed => _elapsed;
  bool get isRestMode => currentState == TimerState.restMode;
  Duration get focusDuration => Duration(seconds: _focusDuration);
  Duration get restDuration => Duration(seconds: _restDuration);
  Duration get elapsedDuration => Duration(seconds: _elapsed);
  int get remaining {
    final target =
        currentState == TimerState.focusMode ? _focusDuration : _restDuration;
    final remainingTime = target - _elapsed;
    // 음수가 되지 않도록 보장
    return remainingTime > 0 ? remainingTime : 0;
  }

  Duration get remainingDuration => Duration(seconds: remaining);

  // 타이머 완료 메시지
  String? _completionMessage;
  String? get completionMessage => _completionMessage;

  // 타이머 완료 메시지 설정
  void clearCompletionMessage() {
    _completionMessage = null;
    notifyListeners();
  }

  // 타이머 완료 콜백 설정
  void setOnTimerCompleted(TimerCompletionCallback callback) {
    _onTimerCompleted = callback;
  }

  // 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 타임존 초기화
    tz_data.initializeTimeZones();

    // 사용자 설정 로드
    await _loadSettings();

    // 웹이 아닌 경우에만 알림 초기화
    if (!kIsWeb) {
      // 알림 초기화
      final initializationSettingsAndroid =
          const AndroidInitializationSettings('ic_notification');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      final initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _onSelectNotification(response.payload);
        },
      );
    }

    _isInitialized = true;
  }

  /// 알림 탭 처리
  void _onSelectNotification(String? payload) {
    // 알림 탭 처리 로직
    debugPrint('TimerService: 알림 탭됨 - payload: $payload');
  }

  // 설정 로드
  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _focusTime = prefs.getInt('focus_time') ?? 50;
    _restTime = prefs.getInt('rest_time') ?? 10;

    // 설정 로드 후 바로 초 단위 값도 업데이트
    _focusDuration = _focusTime * 60;
    _restDuration = _restTime * 60;
  }

  // 설정 저장
  Future<void> _saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('focus_time', _focusTime);
    await prefs.setInt('rest_time', _restTime);
  }

  // 타이머 설정 업데이트
  Future<void> updateTimerSettings({int? focusTime, int? restTime}) async {
    bool updated = false;

    if (focusTime != null && _focusTime != focusTime) {
      _focusTime = focusTime;
      _focusDuration = focusTime * 60; // 초 단위 즉시 업데이트
      updated = true;
    }

    if (restTime != null && _restTime != restTime) {
      _restTime = restTime;
      _restDuration = restTime * 60; // 초 단위 즉시 업데이트
      updated = true;
    }

    if (updated) {
      await _saveSettings();

      // 현재 타이머가 실행 중이면 업데이트된 값으로 재설정
      if (_isActive) {
        _updateActiveDuration();
      }

      debugPrint(
          '타이머 설정 업데이트: 집중=$_focusTime분($_focusDuration초), 휴식=$_restTime분($_restDuration초)');
      notifyListeners();
    }
  }

  // 활성 상태에서 타이머 시간 업데이트
  void _updateActiveDuration() {
    if (!_isActive) return;

    // 모드에 따라 타이머 업데이트 (이미 updateTimerSettings에서 설정했으므로 여기서는 필요 없음)
    // 그래도 혹시 모르니 다시 한번 값 확인
    if (_isFocusMode) {
      if (_focusDuration != _focusTime * 60) {
        _focusDuration = _focusTime * 60;
      }
    } else {
      if (_restDuration != _restTime * 60) {
        _restDuration = _restTime * 60;
      }
    }

    debugPrint(
        '활성 타이머 업데이트: 현재 ${_isFocusMode ? "집중" : "휴식"} 모드, 남은 시간=${remaining}초');

    // 웹에서 타이머가 실행 중이면 업데이트
    if (kIsWeb && _timer != null) {
      // 기존 타이머 취소하고 새로 시작
      _timer?.cancel();
      _startWebTimer();
    }
    // 모바일에서는 알림만 업데이트
    else if (!kIsWeb && _isolate != null) {
      _scheduleNotification();
    }
  }

  // 타이머 시작
  Future<void> startTimer() async {
    if (_isActive) return;

    await initialize();

    _isActive = true;
    _startTime = DateTime.now();
    _isFocusMode = true;
    _elapsed = 0; // 경과 시간 초기화
    currentState = TimerState.focusMode;

    // 설정된 값으로 duration 업데이트
    // 항상 값을 새로 계산하여 최신 설정값 반영
    _focusDuration = _focusTime * 60;
    _restDuration = _restTime * 60;

    debugPrint(
        '타이머 시작: 집중 시간($_focusTime분, $_focusDuration초), 휴식 시간($_restTime분, $_restDuration초)');

    // 음악 서비스에 모드 변경 알림
    _musicService.handleTimerModeChange(_isFocusMode);

    // 타이머 시작 알림 표시
    await _notificationService.showTimerStartNotification(
      isFocusMode: _isFocusMode,
      minutes: _isFocusMode ? _focusTime : _restTime,
    );

    if (kIsWeb) {
      // 웹에서는 일반 타이머 사용
      _startWebTimer();
    } else {
      // 웹이 아닌 경우 백그라운드 타이머 시작
      _startBackgroundTimer();
    }

    notifyListeners();
  }

  // 웹용 타이머 시작
  void _startWebTimer() {
    // 기존 타이머가 있으면 취소
    _timer?.cancel();

    // 1초마다 타이머 업데이트
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimer();
    });
  }

  // 타이머 업데이트 (웹용)
  void _updateTimer() {
    _elapsed++;

    int targetDuration = _isFocusMode
        ? _focusDuration // 이미 초 단위로 변환된 집중 시간 사용
        : _restDuration; // 이미 초 단위로 변환된 휴식 시간 사용

    // 타이머 완료 체크
    if (_elapsed >= targetDuration) {
      // 타이머 완료 시 현재 모드 저장
      bool wasFocusMode = _isFocusMode;
      final completedMinutes = wasFocusMode ? _focusTime : _restTime;

      // 휴식 모드가 끝났을 때 데스크톱 특화 알림 표시 (집중 모드에서 휴식 모드로 전환될 때는 일반 알림 유지)
      if (!wasFocusMode && !kIsWeb) {
        // 휴식 모드가 끝났고 웹이 아닌 경우 데스크톱 특화 알림 표시
        _notificationService.showDesktopRestCompleteNotification(
            minutes: completedMinutes);
      } else {
        // 그 외 경우는 일반 알림 표시 (집중 모드 종료 또는 웹 환경)
        _notificationService.showTimerCompleteNotification(
          isFocusMode: wasFocusMode,
          minutes: completedMinutes,
        );
      }

      // 데스크톱 환경을 위한 완료 메시지 설정
      final context = _currentContext;
      if (context != null) {
        final loc = AppLocalizations.of(context)!;
        _completionMessage = wasFocusMode
            ? loc.focusCompleteMessage(_focusTime)
            : loc.restCompleteMessage(_restTime);
      } else {
        // 컨텍스트가 없는 경우 대체 메시지 사용
        _completionMessage = wasFocusMode
            ? '집중 시간 ${_focusTime}분이 완료되었습니다. 휴식할 시간입니다!'
            : '휴식 시간 ${_restTime}분이 완료되었습니다. 다시 집중할 시간입니다!';
      }

      // 완료 콜백 호출
      if (_onTimerCompleted != null) {
        _onTimerCompleted!(wasFocusMode);
      }

      // 기존 타이머 취소
      _timer?.cancel();

      // 모드 전환 전에 경과 시간 초기화
      _elapsed = 0;

      // 모드 전환
      toggleMode();

      // 타이머를 다시 시작하기 전에 현재 모드에 맞는 duration 설정 확인
      _focusDuration = _focusTime * 60;
      _restDuration = _restTime * 60;

      // 타이머 재시작 전 설정값 디버그 출력
      debugPrint(
          '타이머 재시작 전 설정값: 집중=${_focusTime}분(${_focusDuration}초), 휴식=${_restTime}분(${_restDuration}초)');

      // 새 타이머 시작
      _startWebTimer();

      // 여기서 함수 종료 (더 이상 진행하지 않음)
      return;
    }

    notifyListeners();
  }

  // 타이머 중지
  Future<void> stopTimer() async {
    if (!_isActive) return;

    // 타이머 중지 알림 표시
    _notificationService.showTimerStoppedNotification(
      isFocusMode: _isFocusMode,
      elapsedMinutes: (_elapsed / 60).floor(),
      targetMinutes: _isFocusMode ? _focusTime : _restTime,
    );

    _isActive = false;
    currentState = TimerState.inactive;

    // 백그라운드 타이머 중지
    if (_isolate != null) {
      _isolate!.kill();
      _isolate = null;
    }

    if (_receivePort != null) {
      _receivePort!.close();
      _receivePort = null;
    }

    // 웹 타이머 중지
    _timer?.cancel();
    _timer = null;

    // 음악 서비스에 모드 변경 알림 - 집중 모드로 설정하여 음악 중지
    _musicService.handleTimerModeChange(true);

    notifyListeners();
  }

  // 모드 전환
  void toggleMode() {
    bool wasRestMode = !_isFocusMode; // 이전에 휴식 모드였는지 저장
    _isFocusMode = !_isFocusMode;
    _elapsed = 0; // 경과 시간 초기화
    _startTime = DateTime.now(); // 시작 시간 재설정

    // 모드 전환 시 상태 업데이트
    currentState = _isFocusMode ? TimerState.focusMode : TimerState.restMode;

    // 모드 전환 시 해당 모드의 시간 값으로 재설정 (최신 설정값 사용)
    _focusDuration = _focusTime * 60;
    _restDuration = _restTime * 60;

    // 현재 활성화된 모드의 남은 시간 디버그 출력
    debugPrint(
        '모드 전환 시 타이머 값: 집중=${_focusDuration}초, 휴식=${_restDuration}초, 현재 모드=${_isFocusMode ? "집중" : "휴식"}');

    // 타이머 시작 알림 표시 - 현재 설정된 시간 사용
    _notificationService.showTimerStartNotification(
      isFocusMode: _isFocusMode,
      minutes: _isFocusMode ? _focusTime : _restTime,
    );

    // 휴식 모드에서 집중 모드로 변경 시 (휴식 시간 종료) 광고 서비스에 알림
    if (wasRestMode && _isFocusMode) {
      try {
        // AdService 인스턴스 가져와서 휴식 완료 설정
        final adService = AdService();
        adService.setRestCompleted(true);
        debugPrint('휴식 시간 종료, 광고 서비스에 알림');
      } catch (e) {
        debugPrint('광고 서비스 알림 오류: $e');
      }
    }

    // 모드 전환 시 진동 시뮬레이션 (실제 진동은 없음)
    _vibrateSimulation();

    // 음악 서비스에 모드 변경 알림
    _musicService.handleTimerModeChange(_isFocusMode);

    // 웹인 경우 타이머 즉시 재시작
    if (kIsWeb && _isActive) {
      _timer?.cancel(); // 기존 타이머 취소
      _startWebTimer(); // 새 타이머 시작
    }
    // 웹이 아닌 경우 백그라운드 타이머 재시작
    else if (!kIsWeb && _isActive) {
      // 기존 isolate 종료
      if (_isolate != null) {
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
      }

      if (_receivePort != null) {
        _receivePort!.close();
        _receivePort = null;
      }

      // 약간의 지연 후 새 백그라운드 타이머 시작 (타이밍 이슈 해결)
      Future.delayed(const Duration(milliseconds: 100), () {
        _startBackgroundTimer();
      });
    }

    // 디버그 로그 추가
    debugPrint(
        '타이머 모드 전환 완료: ${_isFocusMode ? "집중" : "휴식"} 모드, 남은 시간: ${_isFocusMode ? _focusTime : _restTime}분 (${_isFocusMode ? _focusDuration : _restDuration}초)');

    // 상태 변경 알림
    notifyListeners();
  }

  /// 진동 시뮬레이션 (실제 진동은 없음)
  void _vibrateSimulation() {
    debugPrint('진동 시뮬레이션: 타이머 모드 변경됨 - ${_isFocusMode ? "집중" : "휴식"} 모드');
    // 실제 진동은 없지만 콘솔에 메시지 출력
  }

  /// 집중 시간 설정 (분 단위)
  void setFocusTime(int minutes) {
    if (minutes <= 0) return;
    _focusTime = minutes;
    _focusDuration = minutes * 60; // 초 단위로 변환
    debugPrint('집중 시간이 $minutes분으로 설정되었습니다.');
  }

  /// 휴식 시간 설정 (분 단위)
  void setRestTime(int minutes) {
    if (minutes <= 0) return;
    _restTime = minutes;
    _restDuration = minutes * 60; // 초 단위로 변환
    debugPrint('휴식 시간이 $minutes분으로 설정되었습니다.');
  }

  // 백그라운드 타이머 시작
  void _startBackgroundTimer() {
    // uc774ubbf8 uc2e4ud589 uc911uc778 isolateuac00 uc788ub2e4uba74 uc885ub8cc
    if (_isolate != null) {
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }

    if (_receivePort != null) {
      _receivePort!.close();
    }

    // uc0c8 ud3ecud2b8 uc0dduc131
    _receivePort = ReceivePort();

    // ub514ubc84uadf8ub97c uc704ud55c ub85cuadf8 ucd94uac00
    debugPrint(
        'ubc31uadf8ub77cuc6b4ub4dc ud0c0uc774uba38 uc2dcuc791: ubaa8ub4dc=${_isFocusMode ? "uc9d1uc911" : "ud734uc2dd"}, uc2dcuac04=${_isFocusMode ? _focusTime : _restTime}ubd84');

    // 설정된 시간 값으로 업데이트된 타이머 정보 전달
    _focusDuration = _focusTime * 60;
    _restDuration = _restTime * 60;

    // isolate uc0dduc131 ubc0f ud0c0uc774uba38 uc2dcuc791
    Isolate.spawn<TimerData>(
      _runTimerIsolate,
      TimerData(
        sendPort: _receivePort!.sendPort,
        focusTime: _focusTime,
        restTime: _restTime,
        isFocusMode: _isFocusMode,
      ),
    ).then((isolate) {
      _isolate = isolate;

      // uba54uc2dcuc9c0 uc218uc2e0 ucc98ub9ac
      _receivePort!.listen((message) {
        if (message is String && message == 'toggle') {
          debugPrint(
              'ubc31uadf8ub77cuc6b4ub4dc ud0c0uc774uba38 uc644ub8cc: uba54uc2dcuc9c0 uc218uc2e0 $message');

          // 현재 모드 저장 (변경 전)
          bool wasFocusMode = _isFocusMode;
          final completedMinutes = wasFocusMode ? _focusTime : _restTime;

          // 휴식 모드가 끝났을 때 데스크톱 특화 알림 표시
          if (!wasFocusMode && !kIsWeb) {
            // 휴식 모드가 끝났고 웹이 아닌 경우 데스크톱 특화 알림 표시
            _notificationService.showDesktopRestCompleteNotification(
                minutes: completedMinutes);
          } else {
            // 그 외 경우는 일반 알림 표시 (집중 모드 종료 또는 웹 환경)
            _notificationService.showTimerCompleteNotification(
              isFocusMode: wasFocusMode,
              minutes: completedMinutes,
            );
          }

          // ub370uc2a4ud06cud1b1 ud658uacbduc744 uc704ud55c uc644ub8cc uba54uc2dcuc9c0 uc124uc815
          final context = _currentContext;
          if (context != null) {
            final loc = AppLocalizations.of(context)!;
            _completionMessage = wasFocusMode
                ? loc.focusCompleteMessage(_focusTime)
                : loc.restCompleteMessage(_restTime);
          } else {
            // ucee8ud14duc2a4ud2b8uac00 uc5c6ub294 uacbduc6b0 ub300uccb4 uba54uc2dcuc9c0 uc0acuc6a9
            _completionMessage = wasFocusMode
                ? 'uc9d1uc911 uc2dcuac04 ${_focusTime}ubd84uc774 uc644ub8ccub418uc5c8uc2b5ub2c8ub2e4. ud734uc2ddud560 uc2dcuac04uc785ub2c8ub2e4!'
                : 'ud734uc2dd uc2dcuac04 ${_restTime}ubd84uc774 uc644ub8ccub418uc5c8uc2b5ub2c8ub2e4. ub2e4uc2dc uc9d1uc911ud560 uc2dcuac04uc785ub2c8ub2e4!';
          }

          // uc644ub8cc ucf5cubc31 ud638ucd9c
          if (_onTimerCompleted != null) {
            _onTimerCompleted!(wasFocusMode);
          }

          // 경과 시간 초기화 (추가)
          _elapsed = 0;

          // ubaa8ub4dc uc804ud658
          toggleMode();
        }
        // 진행 상황 메시지 처리 (JSON 형식)
        else if (message is Map) {
          try {
            if (message.containsKey('type') && message['type'] == 'progress') {
              // 진행 상황 업데이트
              _elapsed = message['elapsed'] as int;

              // 디버그 로그 (매 진행 상황 메시지마다 출력하지 않고 10초마다만 출력)
              if (_elapsed % 10 == 0 || _elapsed == 1) {
                debugPrint(
                    '타이머 진행 중: $_elapsed초 경과, ${message['remaining']}초 남음');
              }

              // UI 업데이트를 위해 리스너에게 알림
              notifyListeners();
            }
          } catch (e) {
            debugPrint('진행 상황 메시지 처리 오류: $e');
          }
        }
      });
    }).catchError((e) {
      debugPrint(
          'ubc31uadf8ub77cuc6b4ub4dc ud0c0uc774uba38 uc2dcuc791 uc624ub958: $e');
    });

    // uccab uc54cub9bc uc608uc57d
    _scheduleNotification();
  }

  // 알림 예약
  Future<void> _scheduleNotification() async {
    if (kIsWeb) return; // 웹에서는 알림 사용 불가

    try {
      // 현재 모드에 따라 알림 예약
      final int minutes = _isFocusMode ? _focusTime : _restTime;

      // NotificationService를 통해 타이머 시작 알림 표시
      await _notificationService.showTimerStartNotification(
        isFocusMode: _isFocusMode,
        minutes: minutes,
      );
    } catch (e) {
      // 오류가 발생해도 앱 실행에 영향이 없도록 처리
      debugPrint('TimerService: 알림 예약 오류 $e');
    }
  }

  // 백그라운드 타이머 실행 함수
  static void _runTimerIsolate(TimerData data) async {
    final int totalSeconds =
        (data.isFocusMode ? data.focusTime : data.restTime) * 60;
    int elapsed = 0;

    // 디버그 정보 (백그라운드 isolate에서는 print 사용)
    print(
        '백그라운드 타이머 시작: ${data.isFocusMode ? "집중" : "휴식"} 모드, ${totalSeconds}초');

    // 1초마다 카운트다운하면서 진행 상황 전송
    for (int i = 0; i < totalSeconds; i++) {
      // 1초 대기
      await Future.delayed(const Duration(seconds: 1));

      // 경과 시간 증가
      elapsed++;

      // 매초마다 진행 상황 전송하도록 변경 (10초마다 → 매초)
      data.sendPort.send({
        'type': 'progress',
        'elapsed': elapsed,
        'total': totalSeconds,
        'remaining': totalSeconds - elapsed
      });
    }

    // 완료 메시지 전송
    data.sendPort.send('toggle');
    print('백그라운드 타이머 완료: ${totalSeconds}초 경과');
  }
}

/// 타이머 데이터
///
/// Isolate 간 데이터 전송을 위한 클래스
class TimerData {
  final SendPort sendPort;
  final int focusTime;
  final int restTime;
  final bool isFocusMode;

  TimerData({
    required this.sendPort,
    required this.focusTime,
    required this.restTime,
    required this.isFocusMode,
  });
}
