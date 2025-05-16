import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'generated/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'generated/app_localizations.dart';

import 'models/models.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'services/services.dart';
import 'theme/app_theme.dart';
import 'screens/language_selection_screen.dart';
import 'screens/name_input_screen.dart';
import 'services/character_message_service.dart';
import 'services/language_service.dart';
import 'services/timer_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 릴리스 모드에서는 로그 출력을 하지 않음
  if (kDebugMode) {
    debugPrint(
      '🚀 App started (Build mode: ${kReleaseMode ? "release" : "debug/profile"})',
    );
  }

  runApp(const SpinFairyApp());
}

/// AI 척추요정 앱
///
/// 집중 시간과 휴식 시간을 관리하고 건강한 습관을 형성할 수 있게 도와주는 앱
class SpinFairyApp extends StatelessWidget {
  const SpinFairyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => CharacterMessageService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: Consumer<LanguageService>(
        builder: (context, languageService, _) {
          return MaterialApp(
            title: 'SpinFairy',
            debugShowCheckedModeBanner: false,
            // 다국어 지원 설정
            locale: Locale(languageService.currentLanguageCode),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // 현재 언어에 맞는 테마 적용
            theme: AppTheme.getThemeForLanguage(
              languageService.currentLanguageCode,
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const AppEntryPoint(),
              '/settings': (context) => const SettingsScreen(),
              '/language': (context) => const LanguageSelectionScreen(),
            },
          );
        },
      ),
    );
  }
}

/// 앱 진입점
///
/// 사용자 정보 로드 및 초기 라우팅 처리
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  // 서비스 및 사용자 데이터 초기화
  Future<void> _initServices() async {
    try {
      // 언어 서비스 초기화
      await Provider.of<LanguageService>(context, listen: false).init();

      // 캐릭터 메시지 서비스 초기화
      await Provider.of<CharacterMessageService>(context, listen: false).init();

      // 사용자 데이터 로드
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.initialize();
    } catch (e) {
      // 오류 처리
      if (kDebugMode) {
        print('초기화 오류: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final languageService = Provider.of<LanguageService>(context);

    // 로딩 중이면 로딩 화면 표시
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 사용자가 언어를 선택하지 않았으면 언어 선택 화면으로 이동
    if (languageService.currentLanguageCode ==
            LanguageService.defaultLanguageCode &&
        userProvider.isFirstTimeUser) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LanguageSelectionScreen(),
      );
    }

    // 사용자가 이름을 입력하지 않았으면 이름 입력 화면으로 이동
    if (userProvider.name.isEmpty) {
      return MaterialApp(
        title: 'SpinFairy',
        debugShowCheckedModeBanner: false,
        // 다국어 지원 설정
        locale: Locale(languageService.currentLanguageCode),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // 현재 언어에 맞는 테마 적용
        theme: AppTheme.getThemeForLanguage(
          languageService.currentLanguageCode,
        ),
        home: const NameInputScreen(),
      );
    }

    // 나머지 경우에는 메인 앱 표시
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TimerService()),
        ChangeNotifierProvider(create: (context) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'SpinFairy',
        debugShowCheckedModeBanner: false,
        // 다국어 지원 설정
        locale: Locale(languageService.currentLanguageCode),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // 현재 언어에 맞는 테마 적용
        theme: AppTheme.getThemeForLanguage(
          languageService.currentLanguageCode,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

/// 설정 화면
///
/// 앱 설정을 변경할 수 있는 화면
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 다국어 지원으로 문자열 리소스 사용
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations?.settings ?? 'Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 언어 변경 설정 추가
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(localizations?.language ?? 'Language'),
              subtitle: Consumer<LanguageService>(
                builder: (context, languageService, _) {
                  return Text(languageService.currentLanguage.nativeName);
                },
              ),
              onTap: () {
                Navigator.pushNamed(context, '/language');
              },
            ),
          ),
          const SizedBox(height: 16),
          // 앱 정보
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(localizations?.about ?? 'About'),
              subtitle: const Text('1.0.0'),
            ),
          ),
          const SizedBox(height: 16),
          // 추가 설정 항목들
        ],
      ),
    );
  }
}
