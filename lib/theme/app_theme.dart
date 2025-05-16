import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 앱 테마 및 폰트 설정을 관리하는 클래스
class AppTheme {
  /// 현재 언어 코드에 따라 적절한 테마를 생성
  static ThemeData getThemeForLanguage(String languageCode) {
    // 언어별 파스텔 컬러 테마
    Color seedColor;
    switch (languageCode) {
      case 'ko':
        seedColor = Colors.blue.shade300; // 파스텔 파랑
        break;
      case 'en':
        seedColor = Colors.green.shade300; // 파스텔 초록
        break;
      case 'ja':
        seedColor = Colors.orange.shade300; // 파스텔 주황
        break;
      case 'zh':
        seedColor = Colors.pink.shade300; // 파스텔 핑크
        break;
      default:
        seedColor = Colors.purple.shade300; // 기본 파스텔 보라
    }

    // 기본 텍스트 테마
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      // 버튼 스타일 커스터마이징
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          elevation: 3,
        ),
      ),
      // 카드 스타일 커스터마이징
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
    );

    // 모든 언어에 시스템 기본 폰트 사용 (커스텀 폰트 제거)
    return baseTheme;
  }
}
