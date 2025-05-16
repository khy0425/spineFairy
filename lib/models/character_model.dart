import 'package:flutter/material.dart';
import 'dart:math';
import '../services/timer_service.dart';
import '../services/character_message_service.dart';
import 'package:flutter/foundation.dart';
import '../generated/app_localizations.dart';

/// 캐릭터 모델
///
/// 사용자가 선택한 캐릭터의 속성들을 관리
class Character {
  final String id; // 캐릭터 고유 식별자
  final String name;
  final String imageUrl;
  final String emotionTheme;
  final String personalityType;
  final Map<String, String>? emotionImages; // 다양한 감정 이미지 경로를 저장

  // 감정 타입 정의
  static const String HAPPY = 'happy';
  static const String SAD = 'sad';
  static const String WORRIED = 'worried';
  static const String SLEEPY = 'sleepy';
  static const String EXCITED = 'excited';
  static const String NORMAL = 'normal';
  static const String DISAPPOINTED = 'disappointed';
  static const String PROUD = 'proud';

  // 캐릭터 테마 타입 정의
  static const String THEME_HEALING = 'healing';
  static const String THEME_NATURE = 'nature';
  static const String THEME_COSMIC = 'cosmic';
  static const String THEME_TECH = 'tech';

  // 캐릭터 성격 타입 정의
  static const String PERSONALITY_HEALING = 'healing';
  static const String PERSONALITY_ENERGETIC = 'energetic';
  static const String PERSONALITY_TSUNDERE = 'tsundere';
  static const String PERSONALITY_WISE = 'wise';

  Character({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.emotionTheme,
    required this.personalityType,
    this.emotionImages,
  });

  // 이미지 파일 이름 생성 헬퍼 메소드
  static String _getImageFileName(String emotion) {
    return '${emotion}_removebg.png';
  }

  // 이미지 경로 생성 헬퍼 메소드
  static String _getImagePath(String theme, String emotion) {
    // 이미지 파일 경로 수정
    final String fileName = _getImageFileName(emotion);
    // 폴더 구조가 emotions 폴더를 사용하지 않고 각 감정별 폴더를 사용함
    final String path = 'assets/images/characters/$theme/$emotion/$fileName';
    return path;
  }

  // 기본 캐릭터 생성 팩토리 메소드
  factory Character.defaultCharacter({
    String id = 'default_character',
    String name = 'healingFairy',
    String emotionTheme = THEME_HEALING,
    String personalityType = PERSONALITY_HEALING,
  }) {
    // 기본 이미지 경로 설정 - 파일 확장자도 수정되었는지 확인
    final normalImagePath =
        'assets/images/characters/$emotionTheme/$NORMAL/${NORMAL}_removebg.png';

    // 이미지 파일명 변환 (파일명이 일치하지 않는 경우 대응)
    final Map<String, String> emotionFileNames = {
      HAPPY: 'happy_removebg.png',
      SAD: 'sad_removebg.png',
      WORRIED: 'worried_removebg.png',
      SLEEPY: 'sleepy_removebg.png',
      EXCITED: 'excited_removebg.png',
      NORMAL: 'normal_removebg.png',
      DISAPPOINTED: 'disappointed_removebg.png',
      PROUD: 'proud_removebg.png',
    };

    // 감정별 이미지 맵 생성 - 명시적 전체 경로 사용
    final Map<String, String> emotionImages = {};

    // 각 감정별로 이미지 경로 생성
    emotionFileNames.forEach((emotion, fileName) {
      // 수정: 경로 확인 로직 추가
      final path = 'assets/images/characters/$emotionTheme/$emotion/$fileName';
      emotionImages[emotion] = path;
    });

    // 기본 클래스 생성
    final character = Character(
      id: id,
      name: name,
      imageUrl: normalImagePath,
      emotionTheme: emotionTheme,
      personalityType: personalityType,
      emotionImages: emotionImages,
    );

    return character;
  }

  // 특정 테마와 성격의 캐릭터 생성 메소드
  factory Character.withTheme({
    required String id,
    required String name,
    required String emotionTheme,
    required String personalityType,
  }) {
    // 기본 이미지 경로 설정 (경로 확인)
    final normalImagePath =
        'assets/images/characters/$emotionTheme/$NORMAL/${NORMAL}_removebg.png';

    // 이미지 파일명 변환 (파일명이 일치하지 않는 경우 대응)
    final Map<String, String> emotionFileNames = {
      HAPPY: 'happy_removebg.png',
      SAD: 'sad_removebg.png',
      WORRIED: 'worried_removebg.png',
      SLEEPY: 'sleepy_removebg.png',
      EXCITED: 'excited_removebg.png',
      NORMAL: 'normal_removebg.png',
      DISAPPOINTED: 'disappointed_removebg.png',
      PROUD: 'proud_removebg.png',
    };

    // 감정별 이미지 맵 생성 - 명시적 전체 경로 사용
    final Map<String, String> emotionImages = {};

    // 각 감정별로 이미지 경로 생성
    emotionFileNames.forEach((emotion, fileName) {
      // 수정: 경로 확인 로직 추가
      final path = 'assets/images/characters/$emotionTheme/$emotion/$fileName';
      emotionImages[emotion] = path;
    });

    // 기본 클래스 생성
    final character = Character(
      id: id,
      name: name,
      imageUrl: normalImagePath,
      emotionTheme: emotionTheme,
      personalityType: personalityType,
      emotionImages: emotionImages,
    );

    return character;
  }

  // 캐릭터 성격 타입별 피드백 메시지 스타일 가져오기
  String getFeedbackStyle(double adherenceRate) {
    // CharacterMessageService를 사용하여 준수율 피드백 메시지 가져오기
    final messageService = CharacterMessageService();
    return messageService.getAdherenceFeedback(emotionTheme, adherenceRate);
  }

  // 특정 감정에 해당하는 이미지 URL 가져오기
  String getEmotionImage(String emotion) {
    // emotionImages가 null인 경우 기본 이미지 반환
    if (emotionImages == null || emotionImages!.isEmpty) {
      return imageUrl; // 기본 이미지 URL 반환
    }

    // 입력받은 감정을 소문자로 변환
    final lowerEmotion = emotion.toLowerCase();

    // 대소문자를 무시하고 감정 찾기
    final matchingKeys =
        emotionImages!.keys
            .where((key) => key.toLowerCase() == lowerEmotion)
            .toList();

    if (matchingKeys.isNotEmpty) {
      // 일치하는 키 중 첫 번째 것 사용
      return emotionImages![matchingKeys.first]!;
    } else {
      // 유사한 감정 찾기 시도
      String bestMatch = NORMAL; // 기본값

      // 간단한 유사도 검사 (포함 관계)
      for (final key in emotionImages!.keys) {
        if (lowerEmotion.contains(key.toLowerCase()) ||
            key.toLowerCase().contains(lowerEmotion)) {
          bestMatch = key;
          break;
        }
      }

      // 유사한 감정 이미지 사용
      return emotionImages![bestMatch]!;
    }
  }

  // 준수율에 따른 감정 상태 결정
  String getEmotionByAdherenceRate(double adherenceRate) {
    if (adherenceRate >= 90) return PROUD;
    if (adherenceRate >= 80) return HAPPY;
    if (adherenceRate >= 60) return NORMAL;
    if (adherenceRate >= 40) return WORRIED;
    if (adherenceRate >= 20) return DISAPPOINTED;
    return SAD;
  }

  // 인사 메시지 생성 (닉네임 설정 중)
  String getGreetingMessage() {
    // 이 메서드는 직접 다국어 문자열을 반환할 수 없으므로 호출하는 쪽에서 AppLocalizations을 사용해야 함
    return 'whatShouldICallYou'; // 키값만 반환
  }

  // 환영 메시지 생성 (닉네임 설정 후)
  String getWelcomeMessage(String nickname) {
    // 이 메서드는 직접 다국어 문자열을 반환할 수 없으므로 호출하는 쪽에서 AppLocalizations을 사용해야 함
    return 'niceToMeetYou'; // 키값만 반환
  }

  // 타이머 상태에 따른 응원 메시지 가져오기
  String getTimerStateMessage(
    bool isFocusMode,
    int elapsedMinutes,
    int targetMinutes,
  ) {
    // CharacterMessageService를 사용하여 타이머 상태 메시지 가져오기
    final messageService = CharacterMessageService();
    return messageService.getTimerStateMessage(
      emotionTheme,
      NORMAL, // 기본 감정은 NORMAL 사용
      isFocusMode,
      elapsedMinutes,
      targetMinutes,
    );
  }

  // JSON으로부터 Character 객체 생성
  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'],
      name: json['name'],
      imageUrl: json['imageUrl'],
      emotionTheme: json['emotionTheme'],
      personalityType: json['personalityType'],
      emotionImages:
          json['emotionImages'] != null
              ? Map<String, String>.from(json['emotionImages'])
              : null,
    );
  }

  // Character 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'emotionTheme': emotionTheme,
      'personalityType': personalityType,
      'emotionImages': emotionImages,
    };
  }

  // 실제 이미지 파일이 없을 때 폴백 렌더링을 위한 아이콘 정보
  Map<String, IconData> get emotionIcons {
    return {
      HAPPY: Icons.sentiment_very_satisfied,
      SAD: Icons.sentiment_very_dissatisfied,
      WORRIED: Icons.sentiment_dissatisfied,
      SLEEPY: Icons.bedtime,
      EXCITED: Icons.auto_awesome,
      NORMAL: Icons.sentiment_satisfied_alt,
      DISAPPOINTED: Icons.mood_bad,
      PROUD: Icons.emoji_events,
    };
  }

  // 감정에 따른 색상 정보
  Map<String, Color> get emotionColors {
    return {
      HAPPY: Colors.amber.shade300,
      SAD: Colors.blue.shade300,
      WORRIED: Colors.orange.shade300,
      SLEEPY: Colors.indigo.shade200,
      EXCITED: Colors.pink.shade300,
      NORMAL: Colors.pink.shade200,
      DISAPPOINTED: Colors.purple.shade200,
      PROUD: Colors.green.shade300,
    };
  }

  // 특정 감정과 상태에 맞는 메시지를 랜덤하게 선택하여 반환
  String getRandomMessageFor(String emotion, String state) {
    // CharacterMessageService를 사용하여 메시지 가져오기
    final messageService = CharacterMessageService();
    return messageService.getRandomMessageFor(emotionTheme, emotion, state);
  }

  // 타이머 상태에 맞는 메시지 가져오기
  String getMessageByTimerState(
    String emotion,
    TimerState timerState,
    int elapsedMinutes,
    int targetMinutes, {
    bool isCompleted = false,
    bool isStopped = false,
  }) {
    final remainingMinutes = targetMinutes - elapsedMinutes;

    // 타이머 완료 또는 중지 상태 처리
    if (isCompleted) {
      return getRandomMessageFor(emotion, 'completed');
    }

    if (isStopped) {
      // 타이머가 중지되면 걱정이나 실망 감정으로 변경
      final stoppedEmotion =
          elapsedMinutes > (targetMinutes / 2) ? DISAPPOINTED : WORRIED;
      return getRandomMessageFor(stoppedEmotion, 'stopped');
    }

    switch (timerState) {
      case TimerState.inactive:
        return getRandomMessageFor(emotion, 'inactive');

      case TimerState.focusMode:
        // CharacterMessageService를 사용하여 타이머 상태 메시지 가져오기
        final messageService = CharacterMessageService();
        return messageService.getTimerStateMessage(
          emotionTheme,
          emotion,
          true, // isFocusMode
          elapsedMinutes,
          targetMinutes,
        );

      case TimerState.restMode:
        // CharacterMessageService를 사용하여 타이머 상태 메시지 가져오기
        final messageService = CharacterMessageService();
        return messageService.getTimerStateMessage(
          emotionTheme,
          emotion,
          false, // isFocusMode
          elapsedMinutes,
          targetMinutes,
        );

      default:
        return getRandomMessageFor(emotion, 'inactive');
    }
  }

  // 다국어 지원 메시지 가져오기
  String getLocalizedMessage(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return getMessage();

    // localizations에서 키에 해당하는 메시지 찾기
    final random = Random();
    final messageKeys = [
      'advicePosture',
      'adviceBreak',
      'adviceNeckStretch',
      'adviceShoulderRoll',
      'adviceEyeRest',
      'adviceWater',
      'adviceBreathing',
      'adviceCheckPosture',
      'adviceStandSit',
      'adviceWrist',
    ];

    // 랜덤으로 메시지 키 선택
    final selectedKey = messageKeys[random.nextInt(messageKeys.length)];

    // dynamic 접근 방식 사용
    return switch (selectedKey) {
      'advicePosture' => localizations.advicePosture,
      'adviceBreak' => localizations.adviceBreak,
      'adviceNeckStretch' => localizations.adviceNeckStretch,
      'adviceShoulderRoll' => localizations.adviceShoulderRoll,
      'adviceEyeRest' => localizations.adviceEyeRest,
      'adviceWater' => localizations.adviceWater,
      'adviceBreathing' => localizations.adviceBreathing,
      'adviceCheckPosture' => localizations.adviceCheckPosture,
      'adviceStandSit' => localizations.adviceStandSit,
      'adviceWrist' => localizations.adviceWrist,
      _ => localizations.advicePosture,
    };
  }

  // 기본 메시지 가져오기 (하드코딩 버전)
  String getMessage() {
    // 기본 어드바이스 메시지들 정의 - 직접적인 한글 대신 키 값만 반환
    List<String> messageKeys = [
      'advicePosture',
      'adviceBreak',
      'adviceNeckStretch',
      'adviceShoulderRoll',
      'adviceEyeRest',
      'adviceWater',
      'adviceBreathing',
      'adviceCheckPosture',
      'adviceStandSit',
      'adviceWrist',
    ];

    // 랜덤 키 선택
    final random = Random();
    return messageKeys[random.nextInt(messageKeys.length)];
  }

  // 객체 복사 및 필드 업데이트
  Character copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? emotionTheme,
    String? personalityType,
    Map<String, String>? emotionImages,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      emotionTheme: emotionTheme ?? this.emotionTheme,
      personalityType: personalityType ?? this.personalityType,
      emotionImages: emotionImages ?? this.emotionImages,
    );
  }

  // 사용 가능한 캐릭터 목록 가져오기
  static List<Character> getAvailableCharacters() {
    return [
      Character.defaultCharacter(),
      Character.withTheme(
        id: 'healing_character',
        name: 'healingFairy',
        emotionTheme: THEME_HEALING,
        personalityType: PERSONALITY_HEALING,
      ),
      Character.withTheme(
        id: 'nature_character',
        name: 'characterTypeNature',
        emotionTheme: THEME_NATURE,
        personalityType: PERSONALITY_WISE,
      ),
      Character.withTheme(
        id: 'cosmic_character',
        name: 'characterTypeCosmic',
        emotionTheme: THEME_COSMIC,
        personalityType: PERSONALITY_ENERGETIC,
      ),
      Character.withTheme(
        id: 'tech_character',
        name: 'characterTypeTech',
        emotionTheme: THEME_TECH,
        personalityType: PERSONALITY_TSUNDERE,
      ),
    ];
  }
}
