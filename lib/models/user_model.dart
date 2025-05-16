/// 사용자 모델
///
/// 사용자의 기본 정보 및 설정을 저장하는 모델
class User {
  final String id;
  final String nickname;
  final String name; // 사용자 실제 이름
  final CharacterSettings characterSettings;
  final int reminderTime; // 분 단위 (기본 50분)

  User({
    required this.id,
    required this.nickname,
    this.name = '', // 사용자 이름 추가
    required this.characterSettings,
    this.reminderTime = 50,
  });

  // JSON으로부터 User 객체 생성
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nickname: json['nickname'],
      name: json['name'] ?? '', // 사용자 이름 추가
      characterSettings: CharacterSettings.fromJson(json['characterSettings']),
      reminderTime: json['reminderTime'] ?? 50,
    );
  }

  // User 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'name': name, // 사용자 이름 추가
      'characterSettings': characterSettings.toJson(),
      'reminderTime': reminderTime,
    };
  }

  // User 객체 복사 및 필드 업데이트
  User copyWith({
    String? id,
    String? nickname,
    String? name, // 사용자 이름 추가
    CharacterSettings? characterSettings,
    int? reminderTime,
  }) {
    return User(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      name: name ?? this.name, // 사용자 이름 추가
      characterSettings: characterSettings ?? this.characterSettings,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

/// 캐릭터 설정 모델
///
/// 요정 캐릭터의 기본 속성 관리
class CharacterSettings {
  final String name;
  final String imageUrl;
  final String emotionTheme; // 감정 표현 테마 (힐링형, 활력형, 츤데레형 등)
  final String personalityType;

  CharacterSettings({
    required this.name,
    required this.imageUrl,
    required this.emotionTheme,
    required this.personalityType,
  });

  // JSON으로부터 CharacterSettings 객체 생성
  factory CharacterSettings.fromJson(Map<String, dynamic> json) {
    return CharacterSettings(
      name: json['name'],
      imageUrl: json['imageUrl'],
      emotionTheme: json['emotionTheme'],
      personalityType: json['personalityType'],
    );
  }

  // CharacterSettings 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'emotionTheme': emotionTheme,
      'personalityType': personalityType,
    };
  }

  // 객체 복사 및 필드 업데이트
  CharacterSettings copyWith({
    String? name,
    String? imageUrl,
    String? emotionTheme,
    String? personalityType,
  }) {
    return CharacterSettings(
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      emotionTheme: emotionTheme ?? this.emotionTheme,
      personalityType: personalityType ?? this.personalityType,
    );
  }
}
