import 'package:flutter/foundation.dart';
import 'dart:js' as js;

/// 웹 알림 기능 브릿지 구현 (웹용)
class WebNotificationBridge {
  /// 웹 알림 표시
  static void showNotification({
    required String title,
    required String body,
    required bool requireInteraction,
  }) {
    try {
      // JavaScript 함수 호출
      js.context.callMethod(
        'showWebNotification',
        [title, body, requireInteraction],
      );
      debugPrint('웹 알림 표시: $title');
    } catch (e) {
      debugPrint('웹 알림 표시 오류: $e');
    }
  }
}
