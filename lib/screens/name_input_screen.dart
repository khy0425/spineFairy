import 'package:flutter/material.dart';
import '../generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spin_fairy/screens/home_screen.dart'; // CharacterSelectionScreen 대신 HomeScreen 임포트
import 'package:spin_fairy/services/language_service.dart';
import 'package:spin_fairy/providers/user_provider.dart'; // UserProvider 임포트
import 'package:spin_fairy/models/models.dart'; // Character 모델 임포트를 위해 추가

class NameInputScreen extends StatefulWidget {
  const NameInputScreen({Key? key}) : super(key: key);

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 저장된 사용자 이름 로드
  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? '';
      if (userName.isNotEmpty) {
        _nameController.text = userName;
      }
    } catch (e) {
      debugPrint('사용자 이름 로드 오류: $e');
    }
  }

  // 사용자 이름 저장 및 다음 화면으로 이동 (캐릭터 선택 건너뛰기)
  Future<void> _saveNameAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = _nameController.text.trim();
      await prefs.setString('user_name', userName);

      // UserProvider를 통해 기본 캐릭터로 사용자 생성
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 기본 힐링 캐릭터 생성
      final defaultCharacter = Character(
        id: 'character_healing',
        name: '힐링 요정',
        imageUrl: 'assets/images/characters/healing/normal.png',
        emotionTheme: 'healing',
        personalityType: 'healing',
      );

      // 사용자 생성 및 이름 설정
      await userProvider.createUser(character: defaultCharacter);
      await userProvider.setName(userName);

      if (mounted) {
        // 캐릭터 선택 화면을 건너뛰고 바로 홈 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint('사용자 이름 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이름을 저장하는 데 문제가 발생했습니다.')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = context.watch<LanguageService>();
    final langCode = languageService.currentLanguageCode;
    final localizations = AppLocalizations.of(context);

    // 키보드 표시 여부 확인
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = keyboardHeight > 0;

    // AppLocalizations을 사용한 문자열 처리
    final titleText =
        localizations?.whatShouldICallYou ?? '제가 당신을 뭐라고 불러야 할까요?';
    final greetingText = localizations?.niceToMeetYou ?? '만나서 반가워요!';
    final nextButtonText = localizations?.continueButton ?? '다음';
    final nameEmptyErrorText = localizations?.nameRequired ?? '이름을 입력해주세요';
    final nameTooLongErrorText =
        '이름이 너무 깁니다 (최대 20자)'; // 이 문자열은 AppLocalizations에 없으므로 하드코딩 유지

    // 언어별 파스텔 컬러
    final Color backgroundColor;
    final Color accentColor;

    switch (langCode) {
      case 'ko':
        backgroundColor = const Color(0xFFE6F7FF); // 파스텔 파랑
        accentColor = Colors.blue.shade300;
        break;
      case 'en':
        backgroundColor = const Color(0xFFE6FFEC); // 파스텔 초록
        accentColor = Colors.green.shade300;
        break;
      case 'ja':
        backgroundColor = const Color(0xFFFFF2E6); // 파스텔 주황
        accentColor = Colors.orange.shade300;
        break;
      case 'zh':
        backgroundColor = const Color(0xFFFFE6EA); // 파스텔 핑크
        accentColor = Colors.pink.shade300;
        break;
      default:
        backgroundColor = const Color(0xFFF5E6FF); // 파스텔 보라
        accentColor = Colors.purple.shade300;
    }

    return Scaffold(
      // 키보드가 올라와도 resize 하지 않음 (SingleChildScrollView로 처리)
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          // 전체 화면을 스크롤 가능하게 만들어 키보드가 올라와도 스크롤로 모든 요소에 접근 가능
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                // 키보드가 올라오면 하단 패딩 추가 (버튼이 키보드 위에 표시되도록)
                bottom: 20.0 + (keyboardHeight > 0 ? keyboardHeight * 0.5 : 0),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            titleText,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              color: Colors.deepPurple.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        // 키보드가 올라오면 캐릭터 이미지를 숨김
                        if (!_isKeyboardVisible) ...[
                          const SizedBox(height: 20),
                          // 캐릭터 이미지와 말풍선
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // 캐릭터 이미지
                              Image.asset(
                                'assets/images/characters/healing/happy/happy_removebg.png',
                                height: 180,
                              ),

                              // 말풍선
                              Positioned(
                                top: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: accentColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    greetingText,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple.shade800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 20),

                        // 입력 폼
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            side: BorderSide(color: accentColor, width: 1.0),
                          ),
                          color: backgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKey,
                              child: TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(color: accentColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(
                                      color: accentColor.withOpacity(0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(
                                      color: accentColor,
                                      width: 2.0,
                                    ),
                                  ),
                                  labelText: titleText,
                                  labelStyle: TextStyle(
                                    color: Colors.deepPurple.shade700,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.person,
                                    color: accentColor,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                  // 키보드로 인한 오버플로우 방지
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.auto,
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.deepPurple.shade900,
                                ),
                                textInputAction: TextInputAction.done,
                                maxLength: 20,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return nameEmptyErrorText;
                                  }
                                  if (value.length > 20) {
                                    return nameTooLongErrorText;
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _saveNameAndContinue(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 다음 버튼 - 컬럼 하단에 배치
                    Padding(
                      padding: EdgeInsets.only(
                        top: 20.0,
                        bottom: _isKeyboardVisible ? 0 : 20.0,
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveNameAndContinue,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.deepPurple.shade300,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 3,
                        ),
                        child:
                            _isLoading
                                ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                                : Text(
                                  nextButtonText,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
