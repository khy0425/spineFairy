import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'dart:typed_data';
import 'web_notification_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림 서비스
///
/// 앱 내 알림을 관리하는 서비스
class NotificationService extends ChangeNotifier {
  // 싱글톤 인스턴스
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 알림 플러그인 인스턴스
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 초기화 상태
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 알림 ID
  static const int timerNotificationId = 1;
  static const int foregroundNotificationId = 888;

  // 플랫폼 지원 여부
  bool _isNotificationSupported = false;

  // 진동 강도 (0-100%) 기본값 70%
  int _vibrationIntensity = 70;
  int get vibrationIntensity => _vibrationIntensity;

  // 진동 설정 저장 키
  static const String _vibrationIntensityKey = 'vibration_intensity';

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 플랫폼 지원 여부 확인
      _isNotificationSupported =
          !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

      // 지원되지 않는 플랫폼이면 초기화 중단
      if (!_isNotificationSupported) {
        debugPrint('NotificationService: 현재 플랫폼은 알림을 지원하지 않습니다');
        _isInitialized = true;
        return;
      }

      // 저장된 진동 강도 로드
      await _loadVibrationSettings();

      // 안드로이드 설정
      const androidSettings = AndroidInitializationSettings('ic_notification');

      // iOS 및 macOS 설정 (DarwinInitializationSettings 사용)
      final darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification:
            (int id, String? title, String? body, String? payload) {
          debugPrint('NotificationService: iOS 알림 수신 - $title');
        },
      );

      // 초기화 설정
      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      // 알림 플러그인 초기화
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            debugPrint(
                'NotificationService: 알림 탭 - payload: ${response.payload}');
          }
          // 추가 작업 처리
        },
      );

      // 안드로이드 알림 채널 설정
      if (Platform.isAndroid) {
        const androidNotificationChannel = AndroidNotificationChannel(
          'spine_fairy_timer', // 채널 ID
          '척추요정 타이머', // 채널 이름
          description: '척추요정 타이머 알림 채널',
          importance: Importance.high,
          showBadge: true,
        );

        // 안드로이드 알림 채널 생성
        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidNotificationChannel);
      }

      _isInitialized = true;
      debugPrint('NotificationService: 초기화 완료');
    } catch (e) {
      debugPrint('NotificationService: 초기화 오류 $e');
    }
  }

  /// 알림 탭 처리
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      debugPrint('NotificationService: 알림 탭 - payload: ${response.payload}');
    }
    // 앱 포그라운드로 가져오기
    // 타이머 화면으로 이동하기 등의 로직 추가 가능
  }

  /// 알림 권한 요청
  Future<bool> requestPermission() async {
    if (!_isInitialized) await initialize();

    // 지원되지 않는 플랫폼이면 항상 true 반환
    if (!_isNotificationSupported) return true;

    try {
      // iOS 권한 요청
      if (Platform.isIOS) {
        final result = await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return result ?? true;
      }

      // macOS 권한 요청
      if (Platform.isMacOS) {
        final result = await _notifications
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return result ?? true;
      }

      return true; // 기타 플랫폼은 항상 true 반환
    } catch (e) {
      debugPrint('NotificationService: 권한 요청 오류 $e');
      return false;
    }
  }

  /// 타이머 시작 알림 표시
  Future<void> showTimerStartNotification({
    required bool isFocusMode,
    required int minutes,
  }) async {
    if (!_isInitialized) await initialize();

    // 지원되지 않는 플랫폼이면 무시
    if (!_isNotificationSupported) {
      debugPrint('NotificationService: 현재 플랫폼은 알림을 지원하지 않습니다');
      return;
    }

    try {
      // 알림 내용 설정
      final title = '${isFocusMode ? '집중' : '휴식'} 모드 시작';
      final body = '${minutes}분 동안 ${isFocusMode ? '집중' : '휴식'}합니다';

      // 안드로이드 알림 상세 설정
      final androidDetails = AndroidNotificationDetails(
        'spine_fairy_timer', // 채널 ID
        '척추요정 타이머', // 채널 이름
        channelDescription: '척추요정 타이머 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        icon: 'ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
      );

      // iOS 및 macOS 알림 상세 설정
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // 알림 상세 설정
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // 알림 표시
      await _notifications.show(
        timerNotificationId,
        title,
        body,
        notificationDetails,
      );

      debugPrint('NotificationService: 타이머 시작 알림 표시됨');
    } catch (e) {
      debugPrint('NotificationService: 타이머 시작 알림 표시 오류 $e');
    }
  }

  /// 타이머 완료 알림 표시
  Future<void> showTimerCompleteNotification({
    required bool isFocusMode,
    required int minutes,
  }) async {
    if (!_isInitialized) await initialize();

    // 웹 환경에서는 웹 알림 사용
    if (kIsWeb) {
      _showWebNotification(
        title: '${isFocusMode ? '집중' : '휴식'} 시간 완료',
        body: '${minutes}분 ${isFocusMode ? '집중' : '휴식'} 시간이 완료되었습니다',
        isFocusMode: isFocusMode,
      );
      return;
    }

    // 모바일 환경에서는 진동 추가
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _vibrateDevice();
    }

    // 지원되지 않는 플랫폼이면 무시
    if (!_isNotificationSupported) {
      debugPrint('NotificationService: 현재 플랫폼은 알림을 지원하지 않습니다');
      return;
    }

    try {
      // 알림 내용 설정
      final title = '${isFocusMode ? '집중' : '휴식'} 시간 완료';
      final body = '${minutes}분 ${isFocusMode ? '집중' : '휴식'} 시간이 완료되었습니다';

      // 안드로이드 알림 상세 설정
      final androidDetails = AndroidNotificationDetails(
        'spine_fairy_timer', // 채널 ID
        '척추요정 타이머', // 채널 이름
        channelDescription: '척추요정 타이머 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]), // 진동 패턴 추가
        icon: 'ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
      );

      // iOS 및 macOS 알림 상세 설정
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // 알림 상세 설정
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // 알림 표시
      await _notifications.show(
        timerNotificationId,
        title,
        body,
        notificationDetails,
      );

      debugPrint('NotificationService: 타이머 완료 알림 표시됨');
    } catch (e) {
      debugPrint('NotificationService: 타이머 완료 알림 표시 오류 $e');
    }
  }

  /// 데스크톱 환경에서 휴식 모드 완료 특별 알림 표시
  Future<void> showDesktopRestCompleteNotification(
      {required int minutes}) async {
    if (!_isInitialized) await initialize();

    // 웹 환경에서는 웹 알림 사용
    if (kIsWeb) {
      _showWebNotification(
        title: '자세 교정 알림!',
        body:
            '${minutes}분 휴식이 끝났습니다. 다시 집중 모드로 돌아가기 전에 척추 스트레칭을 하고 바른 자세를 취하세요.',
        isFocusMode: false,
      );

      // 추가 알림 표시 (2초 후)
      Future.delayed(const Duration(seconds: 2), () {
        _showWebNotification(
          title: '척추 건강 체크!',
          body: '목과 어깨의 긴장을 풀고, 모니터와의 거리를 확인하세요. 깊은 호흡을 3번 하고 시작하세요.',
          isFocusMode: false,
        );
      });

      return;
    }

    // PC 환경 확인 (macOS 또는 Windows 또는 Linux)
    bool isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    if (!isDesktop) {
      // 데스크톱이 아니면 일반 알림으로 대체
      return showTimerCompleteNotification(
          isFocusMode: false, minutes: minutes);
    }

    try {
      // 데스크톱 알림음 재생
      _playDesktopNotificationSound();

      // 알림 내용 설정 - 자세 교정에 초점을 맞춘 메시지
      final title = '자세 교정 알림!';
      final body =
          '${minutes}분 휴식이 끝났습니다. 다시 집중 모드로 돌아가기 전에 척추 스트레칭을 하고 바른 자세를 취하세요.';

      // macOS 알림 상세 설정 (macOS만 해당)
      final DarwinNotificationDetails? darwinDetails = Platform.isMacOS
          ? const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              // 중요도를 높게 설정하여 사용자의 주의를 끌도록 함
              interruptionLevel: InterruptionLevel.timeSensitive,
            )
          : null;

      // Windows 알림 상세 설정 (Windows만 해당)
      final AndroidNotificationDetails? androidDetails = Platform.isWindows
          ? const AndroidNotificationDetails(
              'spine_fairy_timer',
              '척추요정 타이머',
              channelDescription: '척추요정 타이머 알림 채널',
              importance: Importance.max,
              priority: Priority.high,
              enableLights: true,
              enableVibration: true,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
            )
          : null;

      // 알림 상세 설정
      final notificationDetails = NotificationDetails(
        macOS: darwinDetails,
        android: androidDetails,
      );

      // 알림 표시 (PC 환경에 맞는 특별 ID 사용)
      await _notifications.show(
        timerNotificationId + 100, // 기존 ID와 중복되지 않게 설정
        title,
        body,
        notificationDetails,
      );

      // 잠시 후 두 번째 알림 표시 (강조를 위해)
      await Future.delayed(const Duration(seconds: 2));
      await _notifications.show(
        timerNotificationId + 101,
        '척추 건강 체크!',
        '목과 어깨의 긴장을 풀고, 모니터와의 거리를 확인하세요. 깊은 호흡을 3번 하고 시작하세요.',
        notificationDetails,
      );

      // Windows와 Linux에서는 추가 알림을 위해 시스템 트레이에 메시지 표시 시도
      if (Platform.isWindows || Platform.isLinux) {
        try {
          // Windows/Linux 환경에서는 여러 번 알림을 보내 주의를 끌음
          for (int i = 0; i < 2; i++) {
            await Future.delayed(const Duration(seconds: 3));
            await _notifications.show(
              timerNotificationId + 102 + i,
              '자세 교정 시간!',
              '${i == 0 ? '바른 자세를 위해 어깨를 뒤로 펴고 목을 바로 세우세요.' : '허리를 펴고 의자에 바르게 앉으세요. 손목과 팔의 긴장을 풀어주세요.'}',
              notificationDetails,
            );
          }
        } catch (e) {
          debugPrint('추가 알림 표시 오류: $e');
        }
      }

      debugPrint('NotificationService: 데스크톱 휴식 완료 특별 알림 표시됨');
    } catch (e) {
      debugPrint('NotificationService: 데스크톱 알림 표시 오류 $e');
      // 오류 발생 시 일반 알림으로 대체
      await showTimerCompleteNotification(isFocusMode: false, minutes: minutes);
    }
  }

  /// 웹 브라우저에서 알림 표시 (Chrome, Firefox 등)
  void _showWebNotification({
    required String title,
    required String body,
    required bool isFocusMode,
  }) {
    if (!kIsWeb) return;

    try {
      // WebNotificationBridge를 통해 웹 알림 표시
      WebNotificationBridge.showNotification(
        title: title,
        body: body,
        requireInteraction:
            !isFocusMode, // 휴식 모드 종료 시 상호작용 필요 (사용자가 수동으로 닫아야 함)
      );

      debugPrint('NotificationService: 웹 알림 표시 요청됨');
    } catch (e) {
      debugPrint('NotificationService: 웹 알림 표시 오류 $e');
    }
  }

  /// 데스크톱 알림음 재생 (Windows, macOS, Linux용)
  Future<void> _playDesktopNotificationSound() async {
    if (kIsWeb) return; // 웹에서는 실행하지 않음

    try {
      // AudioPlayer 인스턴스 생성
      final player = AudioPlayer();

      // 알림음 파일 경로 (기존 파일 사용)
      const soundFileName =
          'celestial-love-325229.mp3'; // 기존 assets/sounds 폴더의 파일 사용

      // 볼륨 설정 (0.0 ~ 1.0)
      await player.setVolume(0.6);

      // 알림음 재생 (asset에서 재생)
      await player.play(AssetSource('sounds/$soundFileName'));

      // 재생이 끝나면 리소스 해제
      player.onPlayerComplete.listen((event) {
        player.dispose();
      });

      // 짧은 알림 효과를 위해 5초만 재생하고 중지
      Future.delayed(const Duration(seconds: 5), () {
        player.stop();
        player.dispose();
      });

      debugPrint('데스크톱 알림음 재생 중: $soundFileName');
    } catch (e) {
      debugPrint('알림음 재생 오류: $e');
    }
  }

  /// 진동 강도 로드
  Future<void> _loadVibrationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _vibrationIntensity = prefs.getInt(_vibrationIntensityKey) ?? 70;
  }

  /// 진동 강도 설정
  Future<void> setVibrationIntensity(int intensity) async {
    // 범위 제한 (0-100%)
    if (intensity < 0) intensity = 0;
    if (intensity > 100) intensity = 100;

    // 진동 강도 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_vibrationIntensityKey, intensity);

    // 상태 업데이트
    _vibrationIntensity = intensity;
    notifyListeners();

    debugPrint('NotificationService: 진동 강도 설정 ${intensity}%');
  }

  /// 모바일 기기 진동 실행
  Future<void> _vibrateDevice() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // 사용자 설정에 따른 진동 강도 계산
        // 0%: 진동 없음, 100%: 최대 강도 (255)
        final int amplitude = (_vibrationIntensity * 2.55).round();

        // 강도가 0이면 진동하지 않음
        if (_vibrationIntensity <= 0) {
          debugPrint(
              'NotificationService: 진동 비활성화됨 (강도: ${_vibrationIntensity}%)');
          return;
        }

        // 휴식 모드 종료 시 특별한 진동 패턴 (긴-짧은-긴 진동)
        if (await Vibration.hasCustomVibrationsSupport() ?? false) {
          // 3.1.3 버전에 맞게 업데이트 - 진동 패턴과 강도 설정
          Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500],
            intensities: [
              0,
              amplitude,
              (amplitude * 0.5).round(),
              amplitude,
              (amplitude * 0.5).round(),
              amplitude
            ],
            // amplitude 매개변수 추가
            amplitude: amplitude,
          );
        } else {
          // 기본 진동 (단순 진동 3회) - 더 개선된 방식으로 진동
          // 알림에 적합한 진동 패턴 사용
          try {
            // 알림용 진동 패턴 - 짧은 세 번의 진동
            Vibration.vibrate(
              pattern: [0, 300, 100, 300, 100, 300],
              amplitude: amplitude, // 사용자 설정 강도
            );
          } catch (patternError) {
            // 패턴이 작동하지 않으면 기본 방식으로 대체
            debugPrint('패턴 진동 실패, 기본 진동 사용: $patternError');
            for (int i = 0; i < 3; i++) {
              await Vibration.vibrate(duration: 300, amplitude: amplitude);
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
        }
        debugPrint('NotificationService: 기기 진동 신호 보냄');
      } else {
        debugPrint('NotificationService: 기기가 진동을 지원하지 않습니다');
      }
    } catch (e) {
      debugPrint('NotificationService: 진동 실행 오류 $e');
    }
  }

  /// 타이머 중지 알림 표시
  Future<void> showTimerStoppedNotification({
    required bool isFocusMode,
    required int elapsedMinutes,
    required int targetMinutes,
  }) async {
    if (!_isInitialized) await initialize();

    // 지원되지 않는 플랫폼이면 무시
    if (!_isNotificationSupported) {
      debugPrint('NotificationService: 현재 플랫폼은 알림을 지원하지 않습니다');
      return;
    }

    try {
      // 알림 내용 설정
      final title = '${isFocusMode ? '집중' : '휴식'} 모드 중지됨';
      final body = '${elapsedMinutes}분/${targetMinutes}분이 지난 시점에 중지되었습니다';

      // 안드로이드 알림 상세 설정
      final androidDetails = AndroidNotificationDetails(
        'spine_fairy_timer', // 채널 ID
        '척추요정 타이머', // 채널 이름
        channelDescription: '척추요정 타이머 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        icon: 'ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
      );

      // iOS 및 macOS 알림 상세 설정
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // 알림 상세 설정
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // 알림 표시
      await _notifications.show(
        timerNotificationId,
        title,
        body,
        notificationDetails,
      );

      debugPrint('NotificationService: 타이머 중지 알림 표시됨');
    } catch (e) {
      debugPrint('NotificationService: 타이머 중지 알림 표시 오류 $e');
    }
  }

  /// 타이머 진행 상황 업데이트 알림
  Future<void> updateTimerProgressNotification({
    required bool isFocusMode,
    required int elapsedSeconds,
    required int targetMinutes,
    required int remainingSeconds,
    required int progressPercent,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final minutes = remainingSeconds ~/ 60;
      final seconds = remainingSeconds % 60;
      final timeStr = '${minutes}:${seconds.toString().padLeft(2, '0')}';

      // 안드로이드 알림 상세 설정
      final androidDetails = AndroidNotificationDetails(
        'spine_fairy_timer', // 채널 ID
        '척추요정 타이머', // 채널 이름
        channelDescription: '척추요정 타이머 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: false,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false, // 사용자가 직접 닫을 수 없도록 설정
        playSound: false,
        enableVibration: false,
        icon: 'ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
        showProgress: true,
        maxProgress: targetMinutes * 60,
        progress: elapsedSeconds,
        visibility: NotificationVisibility.public, // 잠금 화면에서도 표시
        fullScreenIntent: false, // 전체 화면으로 표시하지 않음
        usesChronometer: true, // 타이머 경과 시간 표시
      );

      // iOS 및 macOS 알림 상세 설정
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // 알림 상세 설정
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // 알림 표시
      await _notifications.show(
        foregroundNotificationId, // 백그라운드 타이머용 고정 ID 사용
        '${isFocusMode ? '집중' : '휴식'} 모드 진행 중 ($progressPercent%)',
        '남은 시간: $timeStr / ${targetMinutes}:00',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('NotificationService: 타이머 업데이트 알림 표시 오류 $e');
    }
  }

  /// 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) return;

    try {
      await _notifications.cancelAll();
      debugPrint('NotificationService: 모든 알림 취소됨');
    } catch (e) {
      debugPrint('NotificationService: 알림 취소 오류 $e');
    }
  }

  /// 타이머 알림 표시(일반)
  Future<void> showTimerNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // 안드로이드 알림 상세 설정
      final androidDetails = AndroidNotificationDetails(
        'spine_fairy_timer', // 채널 ID
        '척추요정 타이머', // 채널 이름
        channelDescription: '척추요정 타이머 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        icon: 'ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
      );

      // iOS 및 macOS 알림 상세 설정
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // 알림 상세 설정
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // 알림 표시
      await _notifications.show(
        timerNotificationId,
        title,
        body,
        notificationDetails,
      );

      debugPrint('NotificationService: 타이머 알림 표시됨');
    } catch (e) {
      debugPrint('NotificationService: 타이머 알림 표시 오류 $e');
    }
  }

  /// 진동 테스트 실행
  Future<void> testVibration() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // 진동 기능 지원 확인
        if (await Vibration.hasVibrator() ?? false) {
          // 진동 테스트 패턴 실행
          // 사용자 설정 강도 적용
          final int amplitude = (_vibrationIntensity * 2.55).round();

          // 테스트용 진동 패턴: 짧은 진동 1회
          if (await Vibration.hasCustomVibrationsSupport() ?? false) {
            // 사용자 정의 진동 패턴 지원 시
            await Vibration.vibrate(
              duration: 500,
              amplitude: amplitude,
            );
          } else {
            // 기본 진동만 지원하는 경우
            await Vibration.vibrate(duration: 500);
          }

          debugPrint(
              'NotificationService: 진동 테스트 완료 (강도: $_vibrationIntensity%)');
        } else {
          debugPrint('NotificationService: 기기가 진동을 지원하지 않습니다');
        }
      }
    } catch (e) {
      debugPrint('NotificationService: 테스트 진동 실행 오류 $e');
    }
  }
}
