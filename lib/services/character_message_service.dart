import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'language_service.dart';
import 'package:flutter/material.dart';
import '../generated/app_localizations.dart';

/// 캐릭터 메시지 서비스
///
/// 캐릭터 타입별 메시지를 JSON 파일에서 로드하고 관리하는 서비스
class CharacterMessageService extends ChangeNotifier {
  // 싱글톤 인스턴스
  static final CharacterMessageService _instance =
      CharacterMessageService._internal();
  factory CharacterMessageService() => _instance;
  CharacterMessageService._internal();

  // 언어별, 캐릭터 타입별 메시지 데이터를 저장할 맵
  final Map<String, Map<String, dynamic>> _messagesData = {};

  // 언어 서비스
  final LanguageService _languageService = LanguageService();

  // 랜덤 생성기
  final Random _random = Random();

  // 메시지 캐싱 시스템
  final Map<String, String> _cachedMessages = {};
  final Map<String, DateTime> _lastMessageUpdateTime = {};

  // 메시지 업데이트 간격 (5분 = 300초)
  static const int _messageUpdateIntervalSeconds = 300;

  // 서비스 초기화 및 메시지 데이터 로드
  Future<void> init() async {
    // 지원하는 모든 언어에 대해 메시지 로드
    for (var language in _languageService.supportedLanguages) {
      await _loadMessagesForLanguage(language.code, 'healing');
      // 추후 다른 캐릭터 타입도 추가 가능
      // await _loadMessagesForLanguage(language.code, 'nature');
      // await _loadMessagesForLanguage(language.code, 'cosmic');
      // await _loadMessagesForLanguage(language.code, 'tech');
    }
  }

  // 특정 언어와 캐릭터 타입의 메시지 데이터 로드
  Future<void> _loadMessagesForLanguage(
    String langCode,
    String characterType,
  ) async {
    try {
      // 언어별 메시지 파일 경로
      final String filePath =
          'assets/messages/${characterType}_messages_$langCode.json';

      // 해당 언어에 대한 JSON 파일 존재 여부 확인
      try {
        final jsonString = await rootBundle.loadString(filePath);
        final data = json.decode(jsonString);

        // 언어별로 메시지 데이터 저장
        if (!_messagesData.containsKey(langCode)) {
          _messagesData[langCode] = {};
        }
        _messagesData[langCode]![characterType] = data;
        print('$langCode 언어의 $characterType 캐릭터 메시지 데이터 로드 완료');
      } catch (e) {
        print('$langCode 언어의 $characterType 메시지 파일 로드 실패, 기본 파일 사용: $e');

        // 언어별 파일이 없는 경우, 기본 파일 시도
        final defaultJsonString = await rootBundle.loadString(
          'assets/messages/${characterType}_messages.json',
        );
        final defaultData = json.decode(defaultJsonString);

        // 해당 언어의 맵이 없으면 생성
        if (!_messagesData.containsKey(langCode)) {
          _messagesData[langCode] = {};
        }
        _messagesData[langCode]![characterType] = defaultData;
        print('$langCode 언어에 대해 기본 $characterType 메시지 데이터 로드 완료');
      }
    } catch (e) {
      print('$langCode 언어의 $characterType 캐릭터 메시지 로드 최종 실패: $e');
      // 기본 데이터가 없어도 앱이 작동할 수 있도록 빈 데이터 설정
      if (!_messagesData.containsKey(langCode)) {
        _messagesData[langCode] = {};
      }
      _messagesData[langCode]![characterType] = {};
    }
  }

  // 감정과 상태에 따른 메시지 랜덤 선택 (캐싱 적용)
  String getRandomMessageFor(
    String characterType,
    String emotion,
    String state, {
    dynamic localizations, // 타입을 dynamic으로 변경
  }) {
    // 현재 언어 코드 가져오기
    final String langCode = _languageService.currentLanguageCode;

    // 캐시 키 생성 (언어 코드 포함)
    final String cacheKey = '${langCode}_${characterType}_${emotion}_${state}';

    // 현재 시간
    final now = DateTime.now();

    // 캐시된 메시지가 있고, 업데이트 시간이 5분 이내라면 캐시된 메시지 반환
    if (_cachedMessages.containsKey(cacheKey) &&
        _lastMessageUpdateTime.containsKey(cacheKey)) {
      final lastUpdate = _lastMessageUpdateTime[cacheKey]!;
      final diff = now.difference(lastUpdate).inSeconds;

      if (diff < _messageUpdateIntervalSeconds) {
        return _cachedMessages[cacheKey]!;
      }
    }

    // 새 메시지 선택 필요
    try {
      // 해당 언어와 캐릭터 타입의 데이터가 없을 경우
      if (!_messagesData.containsKey(langCode) ||
          !_messagesData[langCode]!.containsKey(characterType)) {
        return localizations?.loadingMessages ?? 'Loading messages...';
      }

      // 감정에 따른 메시지 가져오기
      final emotionData = _messagesData[langCode]![characterType]?['emotions'];
      if (emotionData == null || !emotionData.containsKey(emotion)) {
        if (localizations != null) {
          return localizations.noMessagesForEmotion(emotion);
        }
        return 'No messages for $emotion state.';
      }

      final emotionStateData = emotionData[emotion];
      if (emotionStateData == null || !emotionStateData.containsKey(state)) {
        if (localizations != null) {
          return localizations.noMessagesForEmotion(state);
        }
        return 'No messages for $state state.';
      }

      final emotionMessages = emotionStateData[state] as List;

      if (emotionMessages.isEmpty) {
        if (localizations != null) {
          return localizations.noMessagesForEmotion(emotion);
        }
        return 'No messages for $emotion state.';
      }

      // 랜덤 메시지 선택
      final message =
          emotionMessages[_random.nextInt(emotionMessages.length)].toString();

      // 메시지 캐싱
      _cachedMessages[cacheKey] = message;
      _lastMessageUpdateTime[cacheKey] = now;

      return message;
    } catch (e) {
      print(
        '메시지 가져오기 실패 (언어: $langCode, 캐릭터: $characterType, 감정: $emotion, 상태: $state): $e',
      );

      // 영어 메시지로 폴백
      if (langCode != 'en' && _messagesData.containsKey('en')) {
        try {
          final englishMessages = _messagesData['en']?[characterType]
              ?['emotions']?[emotion]?[state] as List?;
          if (englishMessages != null && englishMessages.isNotEmpty) {
            return englishMessages[_random.nextInt(englishMessages.length)]
                .toString();
          }
        } catch (e2) {
          print('영어 메시지 폴백 실패: $e2');
        }
      }

      // 한국어 메시지로 폴백
      if (langCode != 'ko' && _messagesData.containsKey('ko')) {
        try {
          final koreanMessages = _messagesData['ko']?[characterType]
              ?['emotions']?[emotion]?[state] as List?;
          if (koreanMessages != null && koreanMessages.isNotEmpty) {
            return koreanMessages[_random.nextInt(koreanMessages.length)]
                .toString();
          }
        } catch (e3) {
          print('한국어 메시지 폴백 실패: $e3');
        }
      }

      // 마지막 폴백 - 키값 사용
      return 'howAreYouFeeling';
    }
  }

  // 타이머 상태에 따른 메시지 생성 (캐싱 적용)
  String getTimerStateMessage(
    String characterType,
    String emotion,
    bool isFocusMode,
    int elapsedMinutes,
    int targetMinutes, {
    dynamic localizations,
  }) {
    // 타이머 메시지 상태 결정
    String messageState = "normal";
    int remainingMinutes = targetMinutes - elapsedMinutes;

    if (isFocusMode) {
      if (remainingMinutes <= 5) {
        messageState = "end";
      } else if (elapsedMinutes < 5) {
        messageState = "start";
      } else {
        messageState = "normal";
      }

      // 집중모드 메시지 생성
      if (messageState == "end") {
        return localizations?.focusEndingSoon ?? "Focus time ends soon!";
      } else if (messageState == "start") {
        return localizations?.focusStarted ?? "Focus time started!";
      } else {
        if (localizations != null) {
          return localizations.focusingRemainingTime(remainingMinutes);
        }
        return "Focusing! $remainingMinutes minutes left.";
      }
    } else {
      // 휴식모드
      if (remainingMinutes <= 5) {
        messageState = "end";
      } else if (elapsedMinutes < 5) {
        messageState = "start";
      } else {
        messageState = "normal";
      }

      // 휴식모드 메시지 생성
      if (messageState == "end") {
        return localizations?.restEndingSoon ?? "Break time ends soon!";
      } else if (messageState == "start") {
        return localizations?.restStarted ?? "Break time started!";
      } else {
        if (localizations != null) {
          return localizations.restingRemainingTime(remainingMinutes);
        }
        return "Taking a break! $remainingMinutes minutes left.";
      }
    }
  }

  // 준수율에 따른 피드백 메시지 가져오기
  String getAdherenceFeedback(
    String characterType,
    double adherenceRate, {
    dynamic localizations, // 타입을 dynamic으로 변경
  }) {
    // 현재 언어 코드 가져오기
    final String langCode = _languageService.currentLanguageCode;

    try {
      if (!_messagesData.containsKey(langCode) ||
          !_messagesData[langCode]!.containsKey(characterType)) {
        return localizations?.loadingAdherenceFeedback ??
            'loadingAdherenceFeedback';
      }

      final adherenceFeedback =
          _messagesData[langCode]![characterType]?['adherence_feedback'];
      if (adherenceFeedback == null) {
        return localizations?.regularBreaksGood ?? 'regularBreaksGood';
      }

      List<String> messages;

      if (adherenceRate >= 80) {
        if (adherenceFeedback['high'] == null) {
          return localizations?.adherenceHigh ?? 'adherenceHigh';
        }
        messages = List<String>.from(adherenceFeedback['high']);
      } else if (adherenceRate >= 50) {
        if (adherenceFeedback['medium'] == null) {
          return localizations?.adherenceMedium ?? 'adherenceMedium';
        }
        messages = List<String>.from(adherenceFeedback['medium']);
      } else {
        if (adherenceFeedback['low'] == null) {
          return localizations?.adherenceLow ?? 'adherenceLow';
        }
        messages = List<String>.from(adherenceFeedback['low']);
      }

      if (messages.isEmpty) {
        return localizations?.regularBreaksGood ?? 'regularBreaksGood';
      }

      return messages[_random.nextInt(messages.length)];
    } catch (e) {
      print('준수율 피드백 가져오기 실패 (언어: $langCode): $e');

      // 영어 메시지로 폴백
      if (langCode != 'en' && _messagesData.containsKey('en')) {
        try {
          return _getAdherenceFeedbackFallback(
            'en',
            characterType,
            adherenceRate,
            localizations: localizations,
          );
        } catch (e2) {
          print('영어 준수율 피드백 폴백 실패: $e2');
        }
      }

      // 한국어 메시지로 폴백
      if (langCode != 'ko' && _messagesData.containsKey('ko')) {
        try {
          return _getAdherenceFeedbackFallback(
            'ko',
            characterType,
            adherenceRate,
            localizations: localizations,
          );
        } catch (e3) {
          print('한국어 준수율 피드백 폴백 실패: $e3');
        }
      }

      return localizations?.regularBreaksGood ?? 'regularBreaksGood';
    }
  }

  // 폴백으로 준수율 피드백 가져오기
  String _getAdherenceFeedbackFallback(
    String langCode,
    String characterType,
    double adherenceRate, {
    dynamic localizations, // 타입을 dynamic으로 변경
  }) {
    if (!_messagesData.containsKey(langCode) ||
        !_messagesData[langCode]!.containsKey(characterType)) {
      return localizations?.regularBreaksGood ?? 'regularBreaksGood';
    }

    final adherenceFeedback =
        _messagesData[langCode]![characterType]?['adherence_feedback'];
    if (adherenceFeedback == null) {
      return localizations?.regularBreaksGood ?? 'regularBreaksGood';
    }

    List<String> messages;

    if (adherenceRate >= 80) {
      if (adherenceFeedback['high'] == null) {
        return localizations?.adherenceHigh ?? 'adherenceHigh';
      }
      messages = List<String>.from(adherenceFeedback['high']);
    } else if (adherenceRate >= 50) {
      if (adherenceFeedback['medium'] == null) {
        return localizations?.adherenceMedium ?? 'adherenceMedium';
      }
      messages = List<String>.from(adherenceFeedback['medium']);
    } else {
      if (adherenceFeedback['low'] == null) {
        return localizations?.adherenceLow ?? 'adherenceLow';
      }
      messages = List<String>.from(adherenceFeedback['low']);
    }

    if (messages.isEmpty) {
      return localizations?.regularBreaksGood ?? 'regularBreaksGood';
    }

    return messages[_random.nextInt(messages.length)];
  }
}
