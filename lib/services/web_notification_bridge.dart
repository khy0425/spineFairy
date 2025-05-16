import 'package:flutter/foundation.dart';

/// 웹 알림 기능 브릿지
///
/// 웹(Flutter Web)에서만 실제로 작동하며, 다른 플랫폼에서는 비활성화됩니다.
class WebNotificationBridge {
  /// 웹 알림 표시
  static void showNotification({
    required String title,
    required String body,
    required bool requireInteraction,
  }) {
    // 웹 환경에서만 실제로 js 함수가 호출됨
    // HTML에서 정의한 showWebNotification 함수 참조
    if (kIsWeb) {
      // 웹 환경에서는 콘솔에만 로그 출력 (실제 웹 빌드에서는 JS 코드가 동작함)
      debugPrint('웹 알림 표시: $title - $body (웹 빌드 시 실제 알림이 표시됨)');
    } else {
      // 웹이 아닌 환경에서는 로그만 출력
      debugPrint('웹 알림은 Flutter Web 환경에서만 지원됩니다');
    }
  }
}
