import 'package:flutter/material.dart';
import '../generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:spin_fairy/screens/name_input_screen.dart';
import 'package:spin_fairy/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = LanguageService.defaultLanguageCode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
  }

  // 저장된 언어 설정 로드
  Future<void> _loadSelectedLanguage() async {
    final languageService = context.read<LanguageService>();
    setState(() {
      _selectedLanguage = languageService.currentLanguageCode;
    });
  }

  // 언어 선택 저장 및 다음 화면으로 이동
  Future<void> _saveLanguageAndContinue() async {
    setState(() {
      _isLoading = true;
    });

    final languageService = context.read<LanguageService>();
    await languageService.changeLanguage(_selectedLanguage);

    // 이름 입력 화면으로 이동
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const NameInputScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = context.watch<LanguageService>();
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    // AppLocalizations이 없는 첫 단계이므로 하드코딩된 문자열 사용
    final languageTexts = {
      'ko': '한국어',
      'en': 'English',
      'ja': '日本語',
      'zh': '中文',
    };

    final titleText = {
      'ko': '언어 선택',
      'en': 'Select Language',
      'ja': '言語を選択',
      'zh': '选择语言',
    };

    final continueButtonText = {
      'ko': '계속하기',
      'en': 'Continue',
      'ja': '続ける',
      'zh': '继续',
    };

    // 언어별 파스텔 컬러
    final languageColors = {
      'ko': const Color(0xFFE6F7FF), // 파스텔 파랑
      'en': const Color(0xFFE6FFEC), // 파스텔 초록
      'ja': const Color(0xFFFFF2E6), // 파스텔 주황
      'zh': const Color(0xFFFFE6EA), // 파스텔 핑크
    };

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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            titleText[_selectedLanguage] ?? 'Select Language',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              color: Colors.deepPurple.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 캐릭터 이미지와 말풍선 추가 (이름 입력 화면과 일치)
                        if (!isKeyboardVisible) ...[
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
                                      color: Colors.deepPurple.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '안녕하세요! / Hello! / こんにちは! / 你好!',
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
                          const SizedBox(height: 20),
                        ],

                        // 언어 선택 리스트
                        SizedBox(
                          height:
                              isKeyboardVisible
                                  ? MediaQuery.of(context).size.height *
                                      0.3 // 키보드가 보이면 높이 축소
                                  : MediaQuery.of(context).size.height *
                                      0.5, // 키보드가 안 보이면 더 넓게
                          child: ListView.builder(
                            itemCount:
                                languageService.supportedLanguages.length,
                            itemBuilder: (context, index) {
                              final language =
                                  languageService.supportedLanguages[index];
                              final isSelected =
                                  language.code == _selectedLanguage;

                              return Card(
                                elevation: isSelected ? 4 : 2,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 4.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                  side:
                                      isSelected
                                          ? BorderSide(
                                            color: Colors.deepPurple.shade300,
                                            width: 2.0,
                                          )
                                          : BorderSide.none,
                                ),
                                color:
                                    languageColors[language.code] ??
                                    Colors.white,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedLanguage = language.code;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16.0),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16.0,
                                      horizontal: 12.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Radio<String>(
                                          value: language.code,
                                          groupValue: _selectedLanguage,
                                          activeColor:
                                              Colors.deepPurple.shade400,
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _selectedLanguage = value;
                                              });
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                language.nativeName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                              Text(
                                                language.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Colors.black54,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.deepPurple.shade400,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // 계속하기 버튼
                    Padding(
                      padding: EdgeInsets.only(
                        top: 20.0,
                        bottom: isKeyboardVisible ? 0 : 20.0,
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveLanguageAndContinue,
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
                                  continueButtonText[_selectedLanguage] ??
                                      'Continue',
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
