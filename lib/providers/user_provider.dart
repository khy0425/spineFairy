import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/models.dart';

/// 사용자 Provider
///
/// 앱 전체에서 사용자 정보를 관리하는 Provider
class UserProvider extends ChangeNotifier {
  User? _user;
  String _name = ''; // 사용자 이름

  // 현재 로그인된 사용자
  User? get user => _user;

  // 저장된 사용자 정보가 있는지 확인 (첫 사용자인지 체크)
  bool get isFirstTimeUser => _user == null;

  // Provider 초기화: 저장된 사용자 정보 불러오기
  Future<void> initialize() async {
    await loadUserFromPrefs();
    await _loadName();
  }

  // 사용자 설정 및 알림
  void setUser(User user) {
    _user = user;
    _saveUserToPrefs(user);
    notifyListeners();
  }

  // 사용자 정보 업데이트
  void updateUser({
    String? nickname,
    CharacterSettings? characterSettings,
    int? reminderTime,
    String? name, // 이름 매개변수 추가
    Character? character, // Character 매개변수 추가
  }) {
    if (_user == null) return;

    // Character 객체가 전달된 경우 CharacterSettings로 변환
    CharacterSettings? settings = characterSettings;
    if (character != null) {
      settings = CharacterSettings(
        name: character.name,
        imageUrl: character.imageUrl,
        emotionTheme: character.emotionTheme,
        personalityType: character.personalityType,
      );
    }

    // 사용자 정보 업데이트
    _user = _user!.copyWith(
      nickname:
          nickname ?? (name != null ? name : null), // name이 있으면 nickname으로 사용
      characterSettings: settings,
      reminderTime: reminderTime,
    );

    _saveUserToPrefs(_user!);
    notifyListeners();
  }

  // 사용자 정보 SharedPreferences에 저장
  Future<void> _saveUserToPrefs(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = jsonEncode(user.toJson());
    await prefs.setString('user_data', userJson);
  }

  // SharedPreferences에서 사용자 정보 불러오기
  Future<void> loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');

    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        _user = User.fromJson(userData);
        notifyListeners();
      } catch (e) {
        debugPrint('사용자 정보 로드 오류: $e');
      }
    }
  }

  // 사용자 정보 초기화 (로그아웃)
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    _user = null;
    notifyListeners();
  }

  // 기본 캐릭터 및 설정으로 신규 사용자 생성
  Future<void> createDefaultUser(String nickname) async {
    final defaultCharacterSettings = CharacterSettings(
      name: '요정',
      imageUrl: 'assets/images/characters/healing/normal.png',
      emotionTheme: 'healing',
      personalityType: 'healing',
    );

    // UUID 생성을 대신해 간단한 ID 생성
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    final newUser = User(
      id: userId,
      nickname: nickname,
      characterSettings: defaultCharacterSettings,
      reminderTime: 50,
    );

    setUser(newUser);
  }

  // 사용자 생성
  Future<void> createUser({required Character character}) async {
    // 캐릭터 설정 생성
    final characterSettings = CharacterSettings(
      name: character.name,
      imageUrl: character.imageUrl,
      emotionTheme: character.emotionTheme,
      personalityType: character.personalityType,
    );

    // UUID 생성을 대신해 간단한 ID 생성
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    // 사용자 생성
    final newUser = User(
      id: userId,
      nickname: character.name,
      characterSettings: characterSettings,
      reminderTime: 50,
    );

    // 저장
    setUser(newUser);
  }

  // getter
  String get name => _name;

  // 이름 로드 함수
  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('user_name') ?? '';
    notifyListeners();
  }

  // 이름 설정 함수
  Future<void> setName(String newName) async {
    if (newName.isEmpty) return;

    _name = newName;

    // 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName);

    notifyListeners();
  }
}
