import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spin_fairy/providers/user_provider.dart';
import 'package:spin_fairy/screens/home_screen.dart';
import 'package:spin_fairy/services/language_service.dart';
import '../generated/app_localizations.dart';

import '../models/models.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({Key? key}) : super(key: key);

  @override
  State<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  String _selectedCharacterType = 'healing';
  bool _isLoading = false;

  // 캐릭터 타입 정의
  final List<Map<String, dynamic>> _characterTypes = [
    {'type': 'healing', 'icon': Icons.favorite},
    {'type': 'cute', 'icon': Icons.child_care},
    {'type': 'energetic', 'icon': Icons.flash_on},
    {'type': 'cool', 'icon': Icons.star},
    {'type': 'nature', 'icon': Icons.eco},
    {'type': 'cosmic', 'icon': Icons.nights_stay},
    {'type': 'tech', 'icon': Icons.smart_toy},
  ];

  // 캐릭터 선택 및 이동
  Future<void> _selectCharacterAndContinue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 캐릭터 객체 생성
      final character = Character(
        id: 'character_$_selectedCharacterType',
        name: _getCharacterName(_selectedCharacterType),
        imageUrl: 'assets/images/characters/$_selectedCharacterType/normal.png',
        emotionTheme: _selectedCharacterType,
        personalityType: _selectedCharacterType,
      );

      // 사용자 생성
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.createUser(character: character);

      // 홈 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint('캐릭터 생성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 캐릭터 타입에 따른 이름 반환
  String _getCharacterName(String type) {
    final localizations = AppLocalizations.of(context);
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final langCode = languageService.currentLanguageCode;

    // 디버그 로그 추가
    debugPrint('_getCharacterName 호출: 타입=$type, 언어 코드=$langCode');

    // 로컬라이제이션에서 먼저 이름을 찾습니다
    if (localizations != null) {
      switch (type) {
        case 'healing':
          final name = localizations.healingFairy;
          debugPrint('로컬라이제이션에서 찾은 이름: $name');
          return name;
        case 'cute':
          return localizations.characterTypeCute;
        case 'energetic':
          return localizations.characterTypeEnergetic;
        case 'cool':
          return localizations.characterTypeCool;
        case 'nature':
          return localizations.characterTypeNature;
        case 'cosmic':
          return localizations.characterTypeCosmic;
        case 'tech':
          return localizations.characterTypeTech;
      }
    } else {
      debugPrint('경고: AppLocalizations가 null입니다');
    }

    // 로컬라이제이션이 없거나 특정 타입이 없는 경우 언어별 하드코딩 이름을 사용
    final names = {
      'ko': {
        'healing': '힐링 요정',
        'cute': '귀여운 요정',
        'energetic': '활발한 요정',
        'cool': '쿨한 요정',
        'nature': '자연 요정',
        'cosmic': '우주 요정',
        'tech': '테크 요정',
      },
      'en': {
        'healing': 'Healing Fairy',
        'cute': 'Cute Fairy',
        'energetic': 'Energetic Fairy',
        'cool': 'Cool Fairy',
        'nature': 'Nature Fairy',
        'cosmic': 'Cosmic Fairy',
        'tech': 'Tech Fairy',
      },
      'ja': {
        'healing': 'ヒーリング妖精',
        'cute': 'かわいい妖精',
        'energetic': '活発な妖精',
        'cool': 'クールな妖精',
        'nature': '自然の妖精',
        'cosmic': '宇宙の妖精',
        'tech': 'テクノロジー妖精',
      },
      'zh': {
        'healing': '治愈精灵',
        'cute': '可爱精灵',
        'energetic': '活力精灵',
        'cool': '酷炫精灵',
        'nature': '自然精灵',
        'cosmic': '宇宙精灵',
        'tech': '科技精灵',
      },
    };

    final result =
        names[langCode]?[type] ?? names['en']?[type] ?? 'Spine Fairy';
    debugPrint('하드코딩 맵에서 찾은 이름: $result (언어: $langCode)');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final langCode = languageService.currentLanguageCode;
    final localizations = AppLocalizations.of(context);

    // 다국어 지원이 없는 경우를 위한 하드코딩된 문자열
    final titleText = {
      'ko': '캐릭터 선택',
      'en': 'Choose Your Character',
      'ja': 'キャラクターを選択',
      'zh': '选择角色',
    };

    final startButtonText = {
      'ko': '시작하기',
      'en': 'Start',
      'ja': '始める',
      'zh': '开始',
    };

    // 캐릭터 타입 이름 다국어 지원
    final characterTypeNames = {
      'ko': {
        'healing': '힐링',
        'cute': '귀여움',
        'energetic': '활발함',
        'cool': '쿨함',
        'nature': '자연',
        'cosmic': '우주',
        'tech': '테크',
      },
      'en': {
        'healing': 'Healing',
        'cute': 'Cute',
        'energetic': 'Energetic',
        'cool': 'Cool',
        'nature': 'Nature',
        'cosmic': 'Cosmic',
        'tech': 'Tech',
      },
      'ja': {
        'healing': 'ヒーリング',
        'cute': 'キュート',
        'energetic': 'エネルギッシュ',
        'cool': 'クール',
        'nature': '自然',
        'cosmic': '宇宙',
        'tech': 'テック',
      },
      'zh': {
        'healing': '疗愈',
        'cute': '可爱',
        'energetic': '活力',
        'cool': '酷炫',
        'nature': '自然',
        'cosmic': '宇宙',
        'tech': '科技',
      },
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Text(
                  localizations?.characterSelectionTitle ??
                      titleText[langCode] ??
                      'Choose Your Character',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 20),
              // 캐릭터 타입 선택 탭
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _characterTypes.length,
                  itemBuilder: (context, index) {
                    final type = _characterTypes[index]['type'] as String;
                    final icon = _characterTypes[index]['icon'] as IconData;
                    final isSelected = type == _selectedCharacterType;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        avatar: Icon(
                          icon,
                          color: isSelected ? Colors.white : null,
                        ),
                        label: Text(
                          characterTypeNames[langCode]?[type] ??
                              type.capitalize(),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCharacterType = type;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // 선택된 캐릭터 이미지 표시
              Expanded(
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/characters/$_selectedCharacterType/normal.png',
                          height: 250,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              height: 250,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getCharacterName(_selectedCharacterType),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 시작 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _selectCharacterAndContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        localizations?.startButton ??
                            startButtonText[langCode] ??
                            'Start',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// String 확장 메서드 추가
extension StringExtension on String {
  String capitalize() {
    return isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
  }
}
