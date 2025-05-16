import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../generated/app_localizations.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../services/background_service.dart';
import '../widgets/widgets.dart';
import '../providers/user_provider.dart';
import 'settings_screen.dart';

/// Home screen
///
/// Main app screen that provides character display and timer controls
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late TimerService _timerService;
  late final RoutineService _routineService;
  late final AdService _adService;
  late final BackgroundService _backgroundService;
  late final NotificationService _notificationService;
  String _currentEmotion = Character.NORMAL;
  bool _isInitialized = false;
  bool _isLoadingCharacter = true;
  Character _character = Character.defaultCharacter();

  // Banner ad enabled status
  bool _isBannerAdEnabled = false;

  // App lifecycle state
  AppLifecycleState? _appLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerService = TimerService();
    _routineService = RoutineService();
    _adService = AdService();
    _backgroundService = BackgroundService();
    _notificationService = NotificationService();

    // Initialize timer service and start character emotion updates
    _initializeServices().then((_) {
      _updateCharacterEmotion();

      // Add listener to detect timer state changes
      _timerService.addListener(_onTimerStateChanged);

      // Set timer completion callback
      _timerService.setOnTimerCompleted(_onTimerCompleted);
    });

    // Load ad settings
    _loadAdSettings();

    // Load character
    _loadCharacter();
  }

  @override
  void dispose() {
    // Remove timer service listener
    _timerService.removeListener(_onTimerStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      // When app returns to foreground
      // Perform synchronization tasks if needed
      _timerService.initialize();
    }
  }

  // Initialize services
  Future<void> _initializeServices() async {
    await _timerService.initialize();
    await _routineService.initialize();
    await _notificationService.initialize();
    await _notificationService.requestPermission();

    // Initialize ad service
    await _adService.initialize();

    // Initialize background service
    await _backgroundService.initialize();

    // Request background permission at app start (first run only)
    // await _backgroundService.checkAndRequestConsent(context);

    setState(() {
      _isInitialized = true;
    });
  }

  // Timer completion callback
  void _onTimerCompleted(bool wasFocusMode) {
    // Show interstitial ad when focus mode ends (based on probability)
    if (wasFocusMode) {
      print('⏱️ Timer completed: focus mode ${wasFocusMode ? "ended" : "no"}');

      // Show notification
      _notificationService.showTimerCompleteNotification(
        isFocusMode: wasFocusMode,
        minutes:
            wasFocusMode ? _timerService.focusTime : _timerService.restTime,
      );

      // Check if ad should be shown
      bool shouldShow = _adService.shouldShowAd();
      print('🎯 Ad display decision: ${shouldShow ? "show" : "don\'t show"}');

      if (shouldShow) {
        print('📱 Interstitial ad display request');
        // Show ad through ad service
        _adService.showInterstitialAd();
      }
    } else {
      // Show notification when rest mode ends
      _notificationService.showTimerCompleteNotification(
        isFocusMode: wasFocusMode,
        minutes:
            wasFocusMode ? _timerService.focusTime : _timerService.restTime,
      );
    }

    // Update character state
    _updateCharacterEmotion();
  }

  // Handle timer state changes
  void _onTimerStateChanged() {
    // Check if UI update is needed
    if (_timerService.currentState != _getTimerStateFromEmotion()) {
      _updateCharacterEmotion();
    }
  }

  // Infer timer state from current emotion
  TimerState _getTimerStateFromEmotion() {
    switch (_currentEmotion) {
      case Character.EXCITED:
        return TimerState.focusMode;
      case Character.HAPPY:
        return TimerState.restMode;
      default:
        return TimerState.inactive;
    }
  }

  // Update character emotion based on timer state
  void _updateCharacterEmotion() {
    if (!mounted) return;

    setState(() {
      // Set emotion based on timer state
      switch (_timerService.currentState) {
        case TimerState.inactive:
          _currentEmotion = Character.NORMAL;
          break;
        case TimerState.focusMode:
          // Different emotions based on focus time progress
          final elapsed = _timerService.elapsed;
          final duration = _timerService.focusTime * 60;

          if (elapsed < duration * 0.3) {
            // First 30% - excited state
            _currentEmotion = Character.EXCITED;
          } else if (elapsed < duration * 0.7) {
            // Middle 40% - normal/focused state
            _currentEmotion = Character.NORMAL;
          } else {
            // Last 30% - sleepy/tired state
            _currentEmotion = Character.SLEEPY;
          }
          break;
        case TimerState.restMode:
          // Different emotions based on rest time progress
          final elapsed = _timerService.elapsed;
          final duration = _timerService.restTime * 60;

          if (elapsed < duration * 0.5) {
            // First 50% - happy state
            _currentEmotion = Character.HAPPY;
          } else {
            // Last 50% - expectant/ready state
            _currentEmotion = Character.PROUD;
          }
          break;
      }
    });
  }

  // Load ad settings
  Future<void> _loadAdSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final adEnabled = prefs.getBool('show_banner_ads') ?? false;

    setState(() {
      _isBannerAdEnabled = adEnabled;
    });
  }

  // Load character
  Future<void> _loadCharacter() async {
    setState(() {
      _isLoadingCharacter = true;
    });

    try {
      // CharacterService가 정의되지 않아 기본 캐릭터로 대체
      // final character = await CharacterService.loadCharacter();
      setState(() {
        // 기본 캐릭터 사용
        _character = Character.defaultCharacter();
        _isLoadingCharacter = false;
      });
    } catch (e) {
      // 기본 캐릭터 사용
      setState(() {
        _character = Character.defaultCharacter();
        _isLoadingCharacter = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get localizations object
    final localizations = AppLocalizations.of(context);

    // Load user information
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    // Get character settings
    final characterSettings = user?.characterSettings;

    if (!_isInitialized || user == null) {
      // If still initializing or no user information
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Create character object - use localizations instead of hardcoded Korean
    final characterTheme =
        characterSettings?.emotionTheme ?? Character.THEME_HEALING;
    String characterName = characterSettings?.name ?? '';

    // 현재 언어에 따라 캐릭터 이름 동적 변경
    if (characterTheme == Character.THEME_HEALING) {
      characterName = localizations?.healingFairy ?? 'Healing Fairy';
    } else if (characterTheme == Character.THEME_NATURE) {
      characterName = localizations?.characterTypeNature ?? 'Nature Fairy';
    } else if (characterTheme == Character.THEME_COSMIC) {
      characterName = localizations?.characterTypeCosmic ?? 'Cosmic Fairy';
    } else if (characterTheme == Character.THEME_TECH) {
      characterName = localizations?.characterTypeTech ?? 'Tech Fairy';
    }

    final character = Character.withTheme(
      id: 'character_$characterTheme',
      name: characterName,
      emotionTheme: characterTheme,
      personalityType:
          characterSettings?.personalityType ?? Character.PERSONALITY_HEALING,
    );

    // Get screen size information
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenHeight < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.blue[100]!],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              // Set minimum height - dynamically adjust to screen height for scroll activation
              // Use 95% of available height to avoid overflow on various devices
              height: MediaQuery.of(context).size.height * 0.95 -
                  MediaQuery.of(context).padding.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top app bar
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 8.0,
                      bottom: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Advice button
                        ElevatedButton.icon(
                          onPressed: () {
                            // Call advice display function
                            _showAdvice(character.getLocalizedMessage(context));
                          },
                          icon: const Icon(Icons.tips_and_updates),
                          label: Text(localizations?.advice ?? 'Advice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue[200],
                            foregroundColor: Colors.blue[900],
                          ),
                        ),

                        // Timer status display
                        AnimatedBuilder(
                          animation: _timerService,
                          builder: (context, child) {
                            // Set text and color based on timer state
                            String statusText = '';
                            Color statusColor = Colors.grey;

                            switch (_timerService.currentState) {
                              case TimerState.focusMode:
                                statusText =
                                    localizations?.focusing ?? 'Focusing';
                                statusColor = Colors.red;
                                break;
                              case TimerState.restMode:
                                statusText =
                                    localizations?.resting ?? 'Resting';
                                statusColor = Colors.green;
                                break;
                              case TimerState.inactive:
                                statusText = localizations?.ready ?? 'Ready';
                                statusColor = Colors.blue;
                                break;
                            }

                            return Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .fadeIn(duration: 500.ms)
                                .then(delay: 2.seconds)
                                .fadeOut(duration: 500.ms);
                          },
                        ),

                        // Settings button
                        IconButton(
                          icon: const Icon(Icons.settings),
                          color: Colors.blue[900],
                          onPressed: () {
                            // Move to settings screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Character display area
                  Padding(
                    padding: EdgeInsets.only(
                      top: isSmallScreen ? 8.0 : 16.0,
                      bottom: isSmallScreen ? 8.0 : 16.0,
                    ),
                    child: CharacterDisplay(
                      character: character,
                      timerService: _timerService,
                      displaySize: screenHeight *
                          0.3, // Character size proportional to screen size
                    ),
                  ),

                  // Middle spacing
                  SizedBox(height: isSmallScreen ? 8.0 : 16.0),

                  // Timer controls
                  Expanded(
                    child: TimerControl(
                      timerService: _timerService,
                      character: character,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Create app bar widget
  Widget _buildAppBar(String nickname) {
    final localizations = AppLocalizations.of(context);
    String appBarTitle = '';

    if (localizations != null) {
      // Use localization keys
      appBarTitle = localizations.yourSpineFairy(nickname);
    } else {
      appBarTitle = '$nickname\'s Spine Fairy';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title
          Text(
            appBarTitle,
            style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          ),

          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Move to settings screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // Show advice message dialog
  void _showAdvice(String message) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.fairyAdvice ?? 'Fairy\'s Advice'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations?.thankYou ?? 'Thank you!'),
          ),
        ],
      ),
    );
  }

  // Create bottom tips widget
  Widget _buildTips() {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.orange.shade700),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              localizations?.fairyAdvice ?? 'Fairy\'s Advice',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  // Create timer widget
  Widget _buildTimerControls() {
    final localizations = AppLocalizations.of(context);
    // Set text based on current timer state
    String focusText = '';
    String restText = '';

    if (localizations != null) {
      focusText = localizations.focusTimeMinutes(_timerService.focusTime);
      restText = localizations.restTimeMinutes(_timerService.restTime);
    } else {
      focusText = 'Focus: ${_timerService.focusTime} min';
      restText = 'Rest: ${_timerService.restTime} min';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time setting display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Focus time
                Column(
                  children: [
                    Text(
                      focusText,
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.timer, color: Colors.orange.shade800),
                  ],
                ),

                // Separator
                Container(height: 40, width: 1, color: Colors.grey.shade300),

                // Rest time
                Column(
                  children: [
                    Text(
                      restText,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.self_improvement, color: Colors.green.shade700),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
