import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timer_service.dart';
import 'notification_service.dart';
import 'statistics_service.dart';

/// 백그라운드 서비스
///
/// 앱이 백그라운드에 있을 때 타이머 상태를 유지하고 사용자에게 알림을 보내는 서비스
class BackgroundService {
  // 싱글톤 인스턴스
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  // 서비스 인스턴스
  final FlutterBackgroundService _service = FlutterBackgroundService();

  // 타이머 서비스
  final TimerService _timerService = TimerService();

  // 알림 서비스
  final NotificationService _notificationService = NotificationService();

  // 통계 서비스
  final StatisticsService _statisticsService = StatisticsService();

  // 초기화 완료 여부
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 서비스 실행 여부
  bool _isRunning = false;

  // 백그라운드 동의 키
  static const String _keyBackgroundConsent = 'background_consent';
  // 첫 실행 확인 키
  static const String _keyFirstRun = 'first_run_completed';

  /// 앱 시작 시 백그라운드 권한 체크 및 요청
  ///
  /// 앱이 처음 시작될 때나 메인 화면에서 호출하여 백그라운드 실행 권한을 요청합니다.
  /// 한 번 동의한 경우 다시 물어보지 않습니다.
  Future<bool> checkAndRequestConsent(BuildContext context) async {
    // 이미 동의한 경우 바로 true 반환
    if (await hasUserConsent()) return true;

    // 첫 실행 확인
    final prefs = await SharedPreferences.getInstance();
    final firstRunCompleted = prefs.getBool(_keyFirstRun) ?? false;

    // 처음 실행이 아니고 아직 동의하지 않은 경우, 동의 팝업 표시하지 않고 false 반환
    if (firstRunCompleted) return false;

    // 첫 실행 표시
    await prefs.setBool(_keyFirstRun, true);

    // 동의 다이얼로그 표시 및 결과 반환
    final consent = await showConsentDialog(context);
    return consent;
  }

  /// 서비스가 실행 중인지 확인
  Future<bool> isRunning() async {
    _isRunning = await _service.isRunning();
    return _isRunning;
  }

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 알림 서비스 초기화
      await _notificationService.initialize();

      // 서비스 설정 (오류가 발생하여 주석 처리)
      /* 
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          // 앱 ID
          onStart: _onStart,
          autoStart: false,
          isForegroundMode: true,

          // 알림 설정
          foregroundServiceNotificationId:
              NotificationService.foregroundNotificationId,
          initialNotificationTitle: '척추요정',
          initialNotificationContent: '타이머가 백그라운드에서 실행 중입니다',

          // 알림 채널 ID
          notificationChannelId: 'spine_fairy_timer',
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );
      */

      // 활성화된 서비스 설정
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          // 앱 ID
          onStart: _onStart,
          autoStart: false,
          isForegroundMode: true,

          // 알림 설정
          foregroundServiceNotificationId:
              NotificationService.foregroundNotificationId,
          initialNotificationTitle: '척추요정',
          initialNotificationContent: '타이머가 백그라운드에서 실행 중입니다',

          // 알림 채널 ID
          notificationChannelId: 'spine_fairy_timer',
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );

      // 초기화 완료
      _isInitialized = true;
      debugPrint('BackgroundService: 초기화 완료');
    } catch (e) {
      debugPrint('BackgroundService: 초기화 오류 $e');
    }
  }

  /// 백그라운드 동의 확인
  Future<bool> hasUserConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundConsent) ?? false;
  }

  /// 백그라운드 동의 설정
  Future<void> setUserConsent(bool consent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundConsent, consent);
  }

  /// 백그라운드 동의 다이얼로그 표시
  Future<bool> showConsentDialog(BuildContext context) async {
    // 이미 동의한 경우
    if (await hasUserConsent()) return true;

    // 동의 다이얼로그 표시
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('백그라운드 실행 허용'),
        content: const Text(
          '앱이 백그라운드에서도 타이머를 계속 실행하고 알림을 표시하도록 허용하시겠습니까?\n\n'
          '이 기능을 활성화하면 앱을 닫아도 타이머가 계속 작동합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('예, 허용합니다'),
          ),
        ],
      ),
    );

    // 동의 여부 저장
    final consent = result ?? false;
    await setUserConsent(consent);
    return consent;
  }

  /// 서비스 시작
  Future<bool> startService(BuildContext context) async {
    try {
      // 서비스 시작
      await _service.startService();

      // 상태 업데이트
      _isRunning = await _service.isRunning();
      debugPrint('BackgroundService: 서비스 시작 $_isRunning');
      return _isRunning;
    } catch (e) {
      debugPrint('BackgroundService: 서비스 시작 오류 $e');
      return false;
    }
  }

  /// 서비스 중지
  Future<bool> stopService() async {
    try {
      // 서비스 중지
      _service.invoke('stopService');

      // 상태 업데이트
      _isRunning = await _service.isRunning();
      debugPrint('BackgroundService: 서비스 중지 ${!_isRunning}');
      return !_isRunning;
    } catch (e) {
      debugPrint('BackgroundService: 서비스 중지 오류 $e');
      return false;
    }
  }

  /// 타이머 시작
  Future<bool> startTimer({
    required bool isFocusMode,
    required int minutes,
  }) async {
    try {
      // 서비스 실행 확인
      if (!await isRunning()) return false;

      // 타이머 시작 호출
      _service.invoke('startTimer', {
        'isFocusMode': isFocusMode,
        'minutes': minutes,
      });

      debugPrint(
        'BackgroundService: 타이머 시작 요청 (집중모드: $isFocusMode, $minutes분)',
      );
      return true;
    } catch (e) {
      debugPrint('BackgroundService: 타이머 시작 오류 $e');
      return false;
    }
  }

  /// 타이머 일시정지/재개
  Future<bool> toggleTimerPause() async {
    try {
      // 서비스 실행 확인
      if (!await isRunning()) return false;

      // 타이머 일시정지/재개 호출
      _service.invoke('toggleTimerPause');

      debugPrint('BackgroundService: 타이머 일시정지/재개 요청');
      return true;
    } catch (e) {
      debugPrint('BackgroundService: 타이머 일시정지/재개 오류 $e');
      return false;
    }
  }

  /// 타이머 중지
  Future<bool> stopTimer() async {
    try {
      // 서비스 실행 확인
      if (!await isRunning()) return false;

      // 타이머 중지 호출
      _service.invoke('stopTimer');

      debugPrint('BackgroundService: 타이머 중지 요청');
      return true;
    } catch (e) {
      debugPrint('BackgroundService: 타이머 중지 오류 $e');
      return false;
    }
  }
}

/// iOS 백그라운드 핸들러
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// 백그라운드 시작 핸들러
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // 디버그 모드
  debugPrint('BackgroundService: 서비스 시작됨');

  // 안드로이드 서비스 설정
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // 타이머 서비스 인스턴스 생성
  final timerService = TimerService();

  // 알림 서비스 초기화
  final notificationService = NotificationService();
  await notificationService.initialize();

  // 통계 서비스 초기화
  final statisticsService = StatisticsService();

  // 타이머 상태 변수
  bool isFocusMode = false;
  int targetMinutes = 0;
  int elapsedSeconds = 0;
  bool isTimerRunning = false;
  bool isTimerPaused = false;
  DateTime? startTime;
  Timer? timer;

  // 타이머 업데이트 함수
  void updateTimer() {
    if (!isTimerRunning || isTimerPaused) return;

    // 경과 시간 계산
    if (startTime != null) {
      final now = DateTime.now();
      final diff = now.difference(startTime!);
      elapsedSeconds = diff.inSeconds;

      // 알림 업데이트
      final remainingSeconds = (targetMinutes * 60) - elapsedSeconds;
      if (remainingSeconds <= 0) {
        // 타이머 완료
        isTimerRunning = false;
        elapsedSeconds = targetMinutes * 60;

        // 통계 기록
        if (isFocusMode) {
          statisticsService.recordFocusSession(elapsedSeconds, completed: true);
        } else {
          statisticsService.recordRestSession(elapsedSeconds, completed: true);
        }

        // 완료 알림
        notificationService.showTimerCompleteNotification(
          isFocusMode: isFocusMode,
          minutes: targetMinutes,
        );

        return;
      }

      // 각 초마다 상태표시줄 알림 업데이트
      final progressPercent =
          ((elapsedSeconds / (targetMinutes * 60)) * 100).round();
      notificationService.updateTimerProgressNotification(
        isFocusMode: isFocusMode,
        elapsedSeconds: elapsedSeconds,
        targetMinutes: targetMinutes,
        remainingSeconds: remainingSeconds,
        progressPercent: progressPercent,
      );

      // 서비스 업데이트
      FlutterBackgroundService().invoke('updateTimer', {
        'elapsed': elapsedSeconds,
        'remaining': remainingSeconds,
        'progress': progressPercent,
        'isFocusMode': isFocusMode,
      });
    }
  }

  // 1초마다 상태 업데이트
  service.on('stopService').listen((event) {
    // 타이머 정리
    timer?.cancel();

    // 서비스 중지
    service.stopSelf();
  });

  // 타이머 시작 이벤트
  service.on('startTimer').listen((event) {
    if (event == null) return;

    // 타이머 리셋
    timer?.cancel();

    // 파라미터 파싱
    isFocusMode = event['isFocusMode'] ?? false;
    targetMinutes = event['minutes'] ?? 25;

    // 타이머 시작
    isTimerRunning = true;
    isTimerPaused = false;
    elapsedSeconds = 0;
    startTime = DateTime.now();

    // 알림 초기화
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: '${isFocusMode ? '집중' : '휴식'} 모드 시작',
        content: '목표 시간: ${targetMinutes}분',
      );
    }

    // 타이머 시작 알림
    notificationService.showTimerStartNotification(
      isFocusMode: isFocusMode,
      minutes: targetMinutes,
    );

    // 타이머 시작
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updateTimer();
    });
  });

  // 타이머 일시정지/재개 이벤트
  service.on('toggleTimerPause').listen((event) {
    // 타이머 일시정지/재개
    isTimerPaused = !isTimerPaused;

    // 알림 업데이트
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title:
            '${isFocusMode ? '집중' : '휴식'} 모드 ${isTimerPaused ? '일시정지' : '재개'}',
        content: isTimerPaused ? '타이머가 일시정지되었습니다' : '타이머가 재개되었습니다',
      );
    }

    // 타이머 시간 조정
    if (!isTimerPaused) {
      // 재개 시 시작 시간 조정
      startTime = DateTime.now().subtract(Duration(seconds: elapsedSeconds));
    }
  });

  // 타이머 중지 이벤트
  service.on('stopTimer').listen((event) {
    // 타이머 중지
    if (isTimerRunning) {
      // 통계 기록
      if (isFocusMode) {
        statisticsService.recordFocusSession(elapsedSeconds, completed: false);
      } else {
        statisticsService.recordRestSession(elapsedSeconds, completed: false);
      }

      // 타이머 리셋
      isTimerRunning = false;
      isTimerPaused = false;
      timer?.cancel();
      timer = null;

      // 알림 업데이트
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '타이머 중지됨',
          content: '${isFocusMode ? '집중' : '휴식'} 모드가 중지되었습니다',
        );
      }

      // 중지 알림
      notificationService.showTimerStoppedNotification(
        isFocusMode: isFocusMode,
        elapsedMinutes: elapsedSeconds ~/ 60,
        targetMinutes: targetMinutes,
      );
    }
  });

  // 주기적 업데이트
  service.invoke('update');
}
