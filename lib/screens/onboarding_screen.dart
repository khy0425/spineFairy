import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../generated/app_localizations.dart';

import '../providers/providers.dart';
import '../models/models.dart';
import 'home_screen.dart';

/// 온보딩 화면
///
/// 앱 첫 실행 시 사용자 정보를 설정하는 화면
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // 사용자 입력 값
  String _characterName = '';
  final String _selectedTheme = 'healing';
  final String _selectedPersonality = 'healing';

  // 텍스트 컨트롤러
  late TextEditingController _nameController;

  // 이름 입력 길이 제한 및 오류 메시지
  final int _maxNameLength = 10;
  String? _nameErrorText;

  // 현재 페이지
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    // 텍스트 컨트롤러 초기화 - 기본값 없이 빈 값으로 시작
    _nameController = TextEditingController();

    // 저장된 이름이 있으면 불러오기
    _loadSavedName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 저장된 이름 불러오기
  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_nickname');

    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        _characterName = savedName;
        _nameController.text = savedName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final controller = PageController();
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: PageView(
          controller: controller,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (value) {
            setState(() {
              _currentPage = value;
            });
          },
          children: [
            // 첫 번째 페이지: 캐릭터 이름 설정
            _buildNamePage(userProvider, controller),

            // 두 번째 페이지: 완료
            _buildCompletePage(userProvider),
          ],
        ),
      ),
    );
  }

  // 이름 입력 페이지
  Widget _buildNamePage(UserProvider userProvider, PageController controller) {
    // 화면 크기 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenHeight < 600;
    final localizations = AppLocalizations.of(context);

    // Character 객체 생성 (임시)
    final tempCharacter = Character.defaultCharacter(
      id: 'character_temp',
      name: 'healingFairy',
      emotionTheme: Character.THEME_HEALING,
      personalityType: Character.PERSONALITY_HEALING,
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.0, isSmallScreen ? 8.0 : 16.0, 24.0, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 상단 제목
            Text(
              localizations?.whatShouldICallYou ?? 'What should I call you?',
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: isSmallScreen ? 10.0 : 16.0),

            // 메시지 말풍선
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.shade100.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                localizations?.whatShouldICallYou ?? 'What should I call you?',
                style: const TextStyle(fontSize: 16.0, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: isSmallScreen ? 10.0 : 16.0),

            // 캐릭터 이미지 - 이름 입력 페이지
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 6.0 : 8.0,
              ),
              child: Container(
                width: isSmallScreen ? 120 : 160,
                height: isSmallScreen ? 120 : 160,
                margin: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 6.0 : 12.0,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.indigo.shade100, width: 4.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/characters/healing/happy/happy_removebg.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('온보딩 이미지 로드 실패: $error');
                      // 이미지 로드 실패 시 폴백 아이콘
                      return Icon(
                        Icons.sentiment_very_satisfied,
                        size: isSmallScreen ? 60 : 80,
                        color: Colors.amber.shade300,
                      );
                    },
                  ),
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 10.0 : 16.0),

            // 이름 입력 필드
            TextField(
              controller: _nameController,
              maxLength: _maxNameLength,
              inputFormatters: [
                // 공백 제거
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              buildCounter: (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) {
                return Text(
                  '$currentLength/$maxLength',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                );
              },
              decoration: InputDecoration(
                labelText: localizations?.name ?? 'Name',
                hintText: localizations?.nameInputHint ?? 'Enter your name',
                errorText: _nameErrorText,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: Colors.indigo.shade400,
                    width: 2.0,
                  ),
                ),
                prefixIcon: const Icon(Icons.edit),
              ),
              onChanged: (value) {
                setState(() {
                  // 이름 길이 검증
                  if (value.isEmpty) {
                    _nameErrorText = null;
                  } else if (value.length < 2) {
                    _nameErrorText =
                        localizations?.nameRequired ?? 'Please enter your name';
                  } else {
                    _nameErrorText = null;
                  }
                  _characterName = value;
                });
              },
            ),

            SizedBox(height: isSmallScreen ? 20.0 : 32.0),

            // 다음 버튼
            ElevatedButton(
              onPressed: () async {
                // 이름 검증
                if (_characterName.isEmpty || _characterName.length < 2) {
                  setState(() {
                    _nameErrorText =
                        localizations?.nameRequired ?? 'Please enter your name';
                  });
                  return;
                }
                // 유효한 이름이면 계속 진행

                // 입력한 이름 저장
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_nickname', _characterName);

                final character = Character.defaultCharacter(
                  id: 'character_${_characterName}',
                  name: _characterName,
                  emotionTheme: Character.THEME_HEALING,
                  personalityType: Character.PERSONALITY_HEALING,
                );

                // 사용자 생성 및 저장
                userProvider.createUser(character: character);

                // 다음 페이지로 이동
                controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24.0 : 32.0,
                  vertical: isSmallScreen ? 12.0 : 16.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              child: Text(
                localizations?.startButton ?? 'Start',
                style: const TextStyle(fontSize: 18.0),
              ),
            ),

            SizedBox(height: isSmallScreen ? 20.0 : 32.0), // 하단 여백
          ],
        ),
      ),
    );
  }

  // 완료 페이지
  Widget _buildCompletePage(UserProvider userProvider) {
    // 화면 크기 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenHeight < 600;
    final localizations = AppLocalizations.of(context);

    final scrollKey = GlobalKey();

    // 사용자 정보에서 캐릭터 생성
    final character = Character.defaultCharacter(
      id: 'character_${userProvider.user?.nickname ?? "요정"}',
      name: userProvider.user?.nickname ?? "요정",
      emotionTheme: Character.THEME_HEALING,
      personalityType: Character.PERSONALITY_HEALING,
    );

    // 화면이 표시될 때 스크롤 맨 위로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollKey.currentContext != null) {
        Scrollable.ensureVisible(
          scrollKey.currentContext!,
          duration: const Duration(milliseconds: 300),
        );
      }
    });

    final welcomeText =
        '${localizations?.welcomeMessage ?? "Welcome"}, ${userProvider.user?.nickname ?? "Fairy"}!';

    return SingleChildScrollView(
      key: scrollKey,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.0, isSmallScreen ? 8.0 : 16.0, 24.0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 제목
            Text(
              welcomeText,
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
              textAlign: TextAlign.center,
            ),

            // 작은 화면에서는 간격 조정
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),

            // 메시지 말풍선
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.shade100.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                localizations?.niceToMeetYou ?? "Nice to meet you!",
                style: const TextStyle(fontSize: 16.0, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),

            // 작은 화면에서는 간격 조정
            SizedBox(height: isSmallScreen ? 10.0 : 20.0),

            // 캐릭터 이미지 - 완료 페이지
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 5.0 : 10.0,
              ),
              child: Container(
                width: isSmallScreen ? 120 : 150,
                height: isSmallScreen ? 120 : 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.indigo.shade100, width: 4.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/characters/healing/excited/excited_removebg.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('온보딩 완료 이미지 로드 실패: $error');
                      return Icon(
                        Icons.auto_awesome,
                        size: isSmallScreen ? 60 : 80,
                        color: Colors.pink.shade300,
                      );
                    },
                  ),
                ),
              ),
            ),

            // 작은 화면에서는 간격 조정
            SizedBox(height: isSmallScreen ? 10.0 : 20.0),

            // 시작 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 36.0 : 48.0,
                  vertical: isSmallScreen ? 12.0 : 16.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              child: Text(
                localizations?.startButton ?? 'Start',
                style: const TextStyle(fontSize: 18.0),
              ),
            ),

            // 하단 여백 - 작은 화면에서는 줄임
            SizedBox(height: isSmallScreen ? 20.0 : 40.0),
          ],
        ),
      ),
    );
  }
}
