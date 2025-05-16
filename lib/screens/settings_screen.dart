import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/app_localizations.dart';

import '../providers/user_provider.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import 'dart:io' show Platform;

/// 설정 화면
///
/// 사용자 설정을 관리하는 화면 (이름, 알림, 타이머 시간 등)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isNotificationEnabled = true;
  int _focusTime = 25;
  int _restTime = 5;
  bool _isLoading = true;
  // 진동 강도 (0-100%)
  int _vibrationIntensity = 70;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserSettings();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 설정 불러오기
  Future<void> _loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );

      setState(() {
        _nameController.text = userProvider.user?.name ?? '';
        _isNotificationEnabled = prefs.getBool('notifications_enabled') ?? true;
        _focusTime = prefs.getInt('focus_time') ?? 25;
        _restTime = prefs.getInt('rest_time') ?? 5;
        _vibrationIntensity = prefs.getInt('vibration_intensity') ?? 70;
        _isLoading = false;
      });

      // 알림 서비스 설정
      await notificationService.initialize();
    } catch (e) {
      debugPrint('설정을 불러오는 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 알림 설정 저장
  Future<void> _saveNotificationSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );

      setState(() {
        _isNotificationEnabled = value;
      });

      await prefs.setBool('notifications_enabled', value);
      await notificationService.initialize();
      _showSettingSavedMessage();
    } catch (e) {
      debugPrint('알림 설정 저장 중 오류 발생: $e');
    }
  }

  // 진동 강도 설정 저장
  Future<void> _saveVibrationIntensity(int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );

      setState(() {
        _vibrationIntensity = value;
      });

      await prefs.setInt('vibration_intensity', value);
      await notificationService.setVibrationIntensity(value);
      _showSettingSavedMessage();
    } catch (e) {
      debugPrint('진동 강도 설정 저장 중 오류 발생: $e');
    }
  }

  // 타이머 설정 저장
  Future<void> _saveTimerSetting({int? focusTime, int? restTime}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (focusTime != null) {
        setState(() {
          _focusTime = focusTime;
        });
        await prefs.setInt('focus_time', focusTime);
      }

      if (restTime != null) {
        setState(() {
          _restTime = restTime;
        });
        await prefs.setInt('rest_time', restTime);
      }

      _showSettingSavedMessage();
    } catch (e) {
      debugPrint('타이머 설정 저장 중 오류 발생: $e');
    }
  }

  // 이름 설정 저장
  Future<void> _saveNameSetting(String? value) async {
    if (value == null || value.isEmpty) return;
    if (_formKey.currentState?.validate() != true) return;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 사용자 정보 업데이트
      userProvider.updateUser(name: value);
      _showSettingSavedMessage();
    } catch (e) {
      debugPrint('이름 설정 저장 중 오류 발생: $e');
    }
  }

  // 설정 저장 메시지 표시
  void _showSettingSavedMessage() {
    if (mounted) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.settingsSaved ?? '설정이 저장되었습니다.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // 설정 화면 구성
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(localizations?.settings ?? '설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이름 설정
              Text(
                localizations?.userName ?? '사용자 이름',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: localizations?.nameInputHint ?? '이름을 입력하세요',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations?.nameRequired ?? '이름을 입력해주세요';
                  }
                  return null;
                },
                onChanged: _saveNameSetting,
              ),
              const SizedBox(height: 24),

              // 알림 설정
              Text(
                localizations?.notifications ?? '알림',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(
                  localizations?.notificationDesc ?? '타이머 종료 시 알림을 받습니다',
                ),
                value: _isNotificationEnabled,
                onChanged: _saveNotificationSetting,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              // 진동 강도 설정 (모바일 기기에서만 표시)
              if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ...[
                Text(
                  _getLocalizedVibrationText(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.vibration, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _vibrationIntensity.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: '$_vibrationIntensity%',
                        onChanged: (double value) {
                          _saveVibrationIntensity(value.round());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$_vibrationIntensity%'),
                    const SizedBox(width: 12),
                    // 진동 테스트 버튼 추가
                    ElevatedButton(
                      onPressed: () => _testVibration(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(40, 36),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app, size: 16),
                          const SizedBox(width: 4),
                          Text(_getLocalizedTestText(context)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // 타이머 설정
              Text(
                localizations?.timerSettings ?? '타이머 설정',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTimerSetting(
                      localizations?.focusTimeMins ?? '집중 시간 (분)',
                      _focusTime,
                      (value) => _saveTimerSetting(focusTime: value),
                      min: 5,
                      max: 120,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimerSetting(
                      localizations?.restTimeMins ?? '휴식 시간 (분)',
                      _restTime,
                      (value) => _saveTimerSetting(restTime: value),
                      min: 1,
                      max: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 언어 설정
              Text(
                localizations?.language ?? '언어',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildLanguageSelector(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // 타이머 설정 위젯
  Widget _buildTimerSetting(
    String label,
    int value,
    Function(int) onChanged, {
    required int min,
    required int max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  // 언어 선택 위젯
  Widget _buildLanguageSelector() {
    final localizations = AppLocalizations.of(context);
    final languageService = Provider.of<LanguageService>(context);

    debugPrint('💬 언어 선택기 빌드: 현재 언어=${languageService.currentLanguageCode}');

    return DropdownButtonFormField<Locale>(
      value: languageService.currentLocale,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: [
        DropdownMenuItem(
          value: const Locale('ko'),
          child: Text(localizations?.korean ?? '한국어'),
        ),
        DropdownMenuItem(
          value: const Locale('en'),
          child: Text(localizations?.english ?? '영어'),
        ),
        DropdownMenuItem(
          value: const Locale('ja'),
          child: Text(localizations?.japanese ?? '일본어'),
        ),
        DropdownMenuItem(
          value: const Locale('zh'),
          child: Text(localizations?.chinese ?? '중국어'),
        ),
      ],
      onChanged: (locale) {
        if (locale != null) {
          debugPrint('💬 언어 선택 변경: ${locale.languageCode}');
          languageService.setLocale(locale);
        }
      },
    );
  }

  // 진동 테스트 실행
  Future<void> _testVibration() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final notificationService = Provider.of<NotificationService>(
          context,
          listen: false,
        );

        // 현재 설정된 진동 강도로 진동 테스트
        await notificationService.testVibration();

        // 진동 테스트 메시지 표시 (다국어 지원)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_getLocalizedTestingMessage(context, _vibrationIntensity)),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('진동 테스트 오류: $e');
    }
  }

  // 현재 언어에 맞는 테스트 중 메시지 반환
  String _getLocalizedTestingMessage(BuildContext context, int intensity) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final langCode = languageService.currentLanguageCode;

    // 지원하는 언어별 번역 텍스트
    switch (langCode) {
      case 'ko':
        return '현재 ${intensity}% 강도로 진동 테스트 중';
      case 'en':
        return 'Testing vibration at ${intensity}% intensity';
      case 'ja':
        return '${intensity}%の強度で振動をテスト中';
      case 'zh':
        return '以${intensity}%强度测试振动';
      default:
        return '현재 ${intensity}% 강도로 진동 테스트 중';
    }
  }

  // 현재 언어에 맞는 진동 강도 텍스트 반환
  String _getLocalizedVibrationText(BuildContext context) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final langCode = languageService.currentLanguageCode;

    // 지원하는 언어별 번역 텍스트
    switch (langCode) {
      case 'ko':
        return '진동 강도';
      case 'en':
        return 'Vibration Intensity';
      case 'ja':
        return '振動強度';
      case 'zh':
        return '振动强度';
      default:
        return '진동 강도';
    }
  }

  // 현재 언어에 맞는 테스트 텍스트 반환
  String _getLocalizedTestText(BuildContext context) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final langCode = languageService.currentLanguageCode;

    // 지원하는 언어별 번역 텍스트
    switch (langCode) {
      case 'ko':
        return '테스트';
      case 'en':
        return 'Test';
      case 'ja':
        return 'テスト';
      case 'zh':
        return '测试';
      default:
        return '테스트';
    }
  }
}
