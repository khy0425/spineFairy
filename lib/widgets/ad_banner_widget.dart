import 'package:flutter/material.dart';
import '../services/ad_service.dart';

/// 광고 배너 위젯
///
/// 앱 하단에 표시되는 배너 광고 위젯
/// 실제 광고는 없고 더미로 표시합니다.
class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final adService = AdService();

    // 더미 배너 표시
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          '광고 영역',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
