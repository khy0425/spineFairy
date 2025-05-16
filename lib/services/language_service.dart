import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language model with code, name, and native name
class LanguageModel {
  final String code;
  final String name;
  final String nativeName;

  LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

/// List of supported languages in the app
class LanguageService extends ChangeNotifier {
  // Singleton instance
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  // Default language code (Korean)
  static const String defaultLanguageCode = 'ko';

  // Currently selected language
  String _currentLanguageCode = defaultLanguageCode;
  String get currentLanguageCode => _currentLanguageCode;

  // Current locale
  Locale get currentLocale => Locale(_currentLanguageCode);

  // List of supported languages
  final List<LanguageModel> supportedLanguages = [
    LanguageModel(code: 'ko', name: 'Korean', nativeName: '한국어'),
    LanguageModel(code: 'en', name: 'English', nativeName: 'English'),
    LanguageModel(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    LanguageModel(code: 'zh', name: 'Chinese', nativeName: '中文'),
  ];

  // Get current language model
  LanguageModel get currentLanguage {
    return supportedLanguages.firstWhere(
      (lang) => lang.code == _currentLanguageCode,
      orElse: () => supportedLanguages.first,
    );
  }

  // Initialize
  Future<void> init() async {
    await loadSavedLanguage();
  }

  // Load saved language
  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('language_code');

      if (savedLanguage != null &&
          supportedLanguages.any((lang) => lang.code == savedLanguage)) {
        _currentLanguageCode = savedLanguage;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading language settings: $e');
    }
  }

  // Change language
  Future<void> changeLanguage(String languageCode) async {
    debugPrint('💬 언어 변경 시도: 현재=$_currentLanguageCode → 변경=$languageCode');

    if (_currentLanguageCode == languageCode) {
      debugPrint('💬 언어가 이미 $_currentLanguageCode 로 설정되어 있어 변경하지 않음');
      return;
    }

    if (supportedLanguages.any((lang) => lang.code == languageCode)) {
      _currentLanguageCode = languageCode;
      debugPrint('💬 언어 변경 성공: $_currentLanguageCode');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', languageCode);
        debugPrint('💬 언어 설정 저장 완료: $_currentLanguageCode');
      } catch (e) {
        debugPrint('💬 언어 설정 저장 오류: $e');
      }

      notifyListeners();
      debugPrint('💬 언어 변경 알림 완료');
    } else {
      debugPrint('💬 지원하지 않는 언어 코드: $languageCode');
    }
  }

  // Set locale
  Future<void> setLocale(Locale locale) async {
    debugPrint('💬 setLocale 호출: ${locale.languageCode}');
    await changeLanguage(locale.languageCode);
  }

  // Find language model by code
  LanguageModel? getLanguageByCode(String code) {
    try {
      return supportedLanguages.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }

  // Check if language code is valid
  bool isValidLanguageCode(String code) {
    return supportedLanguages.any((lang) => lang.code == code);
  }
}
