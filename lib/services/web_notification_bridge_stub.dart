import 'package:flutter/foundation.dart';

/// 웹 알림 기능 브릿지 더미 구현 (비웹용)
class WebNotificationBridge {
  /// 웹 알림 표시 (비웹 환경에서는 동작하지 않음)
  static void showNotification({
    required String title,
    required String body,
    required bool requireInteraction,
  }) {
    // 웹이 아닌 환경에서는 아무 작업도 수행하지 않음
    debugPrint('웹 알림은 Flutter Web 환경에서만 지원됩니다: $title');
  }
}
