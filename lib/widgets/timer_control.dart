import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../generated/app_localizations.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import 'music_player_widget.dart';

/// 타이머 컨트롤 위젯
///
/// 타이머 시작/중지 및 현재 상태를 보여주는 위젯
class TimerControl extends StatefulWidget {
  final TimerService timerService;
  final Character character;

  const TimerControl({
    super.key,
    required this.timerService,
    required this.character,
  });

  @override
  State<TimerControl> createState() => _TimerControlState();
}

class _TimerControlState extends State<TimerControl> {
  late Timer _uiUpdateTimer;
  String _timerDisplay = '00:00';
  int _elapsedMinutes = 0;
  int _elapsedSeconds = 0;
  TimerState _timerState = TimerState.inactive;
  bool _isActive = false;
  bool _isFocusMode = false;
  Duration _elapsed = Duration.zero;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;
  bool _isPlayingSound = false;

  // 백그라운드 서비스
  final BackgroundService _backgroundService = BackgroundService();
  final NotificationService _notificationService = NotificationService();
  bool _isBackgroundServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _updateTimerState();

    // TimerService가 ChangeNotifier를 상속하므로 addListener를 직접 사용
    widget.timerService.addListener(_updateTimerState);

    // UI 업데이트용 타이머 시작
    _startUiUpdateTimer();

    // 타이머 완료 콜백 설정
    widget.timerService.setOnTimerCompleted(_onTimerCompleted);

    // 백그라운드 서비스 초기화
    _initBackgroundService();

    // 알림 서비스 초기화
    _initNotificationService();
  }

  // 백그라운드 서비스 초기화
  Future<void> _initBackgroundService() async {
    await _backgroundService.initialize();
    setState(() {
      _isBackgroundServiceInitialized = true;
    });
  }

  // 알림 서비스 초기화
  Future<void> _initNotificationService() async {
    await _notificationService.initialize();
    await _notificationService.requestPermission();
  }

  @override
  void dispose() {
    // TimerService 리스너 제거
    widget.timerService.removeListener(_updateTimerState);

    // UI 업데이트 타이머 정지
    _uiUpdateTimer.cancel();

    // 오디오 플레이어 정리
    _audioPlayer.dispose();

    super.dispose();
  }

  // 타이머 완료 콜백
  void _onTimerCompleted(bool wasFocusMode) {
    if (_soundEnabled) {
      _playAlarmSound();
    }

    // 알림 표시
    _notificationService.showTimerCompleteNotification(
      isFocusMode: wasFocusMode,
      minutes:
          wasFocusMode
              ? widget.timerService.focusTime
              : widget.timerService.restTime,
    );

    // 스낵바 표시
    if (mounted) {
      final localizations = AppLocalizations.of(context);

      // 타이머 서비스에서 설정한 메시지 사용 또는 로컬라이제이션 사용
      final message =
          widget.timerService.completionMessage ??
          (wasFocusMode
              ? (localizations?.restStarted ?? "휴식 시간이 시작되었습니다!")
              : (localizations?.focusStarted ?? "집중 시간이 시작되었습니다!"));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          backgroundColor: wasFocusMode ? Colors.green : Colors.blue,
          action: SnackBarAction(
            label: localizations?.ok ?? "확인",
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );

      // 메시지 초기화
      if (widget.timerService.completionMessage != null) {
        widget.timerService.clearCompletionMessage();
      }
    }
  }

  // UI 업데이트용 타이머 시작
  void _startUiUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimerDisplay();
    });
  }

  // 타이머 표시 업데이트
  void _updateTimerDisplay() {
    if (!mounted) return;

    // 타이머 서비스에서 시간 정보 가져오기
    setState(() {
      _timerState = widget.timerService.currentState;
      _isActive = widget.timerService.isActive;
      _isFocusMode = widget.timerService.isFocusMode;

      if (_isActive) {
        // 남은 시간 계산
        final remaining = widget.timerService.remainingDuration;
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;

        // 타이머 표시 업데이트
        _timerDisplay =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        // 경과 시간 업데이트 (캐릭터 메시지 표시용)
        _elapsed = widget.timerService.elapsedDuration;
        _elapsedMinutes = _elapsed.inMinutes;
        _elapsedSeconds = _elapsed.inSeconds % 60;
      } else {
        // 타이머가 비활성 상태일 때 목표 시간 표시
        final targetDuration =
            _isFocusMode
                ? widget.timerService.focusDuration
                : widget.timerService.restDuration;
        final minutes = targetDuration.inMinutes;
        final seconds = targetDuration.inSeconds % 60;

        _timerDisplay =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
    });
  }

  // 알람 소리 재생
  void _playAlarmSound() async {
    // 이미 재생 중이면 중복 재생 방지
    if (_isPlayingSound) return;

    _isPlayingSound = true;

    try {
      // 알림 메시지 표시 (소리 파일이 없더라도 알림은 표시)
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFocusMode
                  ? localizations?.restMode ?? "Rest Mode"
                  : localizations?.focusMode ?? "Focus Mode",
              style: const TextStyle(fontSize: 16),
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: _isFocusMode ? Colors.orange : Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 웹과 모바일 모두에서 작동하는 방식으로 소리 재생 시도
      // 실제 소리 파일이 없어도 앱 기능에 영향을 주지 않도록 예외 처리
      try {
        await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
        await _audioPlayer.resume();

        // 소리가 완료되면 상태 업데이트
        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _isPlayingSound = false;
          });
        });
      } catch (audioError) {
        // 소리 파일 오류는 무시하고 계속 진행 (로그만 출력)
        debugPrint('알람 소리 파일 로드 오류 (무시됨): $audioError');
      }

      // 2초 후에 자동으로 소리 중지 및 상태 초기화 (안전장치)
      Timer(const Duration(seconds: 2), () {
        if (_isPlayingSound) {
          _stopAlarmSound();
        }
      });
    } catch (e) {
      debugPrint('알람 처리 중 오류 발생: $e');
      _isPlayingSound = false;
    }
  }

  // 알람 소리 중지
  void _stopAlarmSound() {
    if (_isPlayingSound) {
      _audioPlayer.stop();
      _isPlayingSound = false;
    }
  }

  // 타이머 상태 업데이트
  void _updateTimerState() {
    if (!mounted) return;

    setState(() {
      _timerState = widget.timerService.currentState;
      _isActive = widget.timerService.isActive;
      _isFocusMode = widget.timerService.isFocusMode;
      _elapsed = Duration(seconds: widget.timerService.elapsed);

      // 타이머 표시도 함께 업데이트
      if (_isActive) {
        // 남은 시간 계산
        final remaining = widget.timerService.remainingDuration;
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;

        // 타이머 표시 업데이트
        _timerDisplay =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      } else {
        // 비활성 상태일 때 목표 시간 표시
        final duration =
            widget.timerService.isFocusMode
                ? widget.timerService.focusDuration
                : widget.timerService.restDuration;
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;

        _timerDisplay =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }

      // 경과 시간 업데이트 (캐릭터 메시지 표시용)
      _elapsedMinutes = _elapsed.inMinutes;
      _elapsedSeconds = _elapsed.inSeconds % 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 화면 크기 확인
            MediaQuery.of(context).size.height < 600
                ? const SizedBox.shrink() // 작은 화면에서는 공간 제거
                : const SizedBox(height: 8),

            // 타이머 표시
            Text(
              _timerDisplay,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8.0),

            // 현재 모드 표시
            Text(
              _getModeText(),
              style: TextStyle(fontSize: 15, color: _getModeColor()),
            ),

            const SizedBox(height: 12.0),

            // 타이머 설정 버튼
            _isActive ? Container() : _buildTimerSettings(context),

            const SizedBox(height: 12.0),

            // 컨트롤 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 시작/중지 버튼
                _buildStartStopButton(),

                const SizedBox(width: 16.0),

                // 모드 전환 버튼 (활성화된 경우에만)
                if (_isActive) _buildToggleModeButton(),

                const SizedBox(width: 16.0),

                // 소리 켜기/끄기 버튼
                _buildSoundToggleButton(),
              ],
            ),

            // 백그라운드 실행 상태 표시
            if (_isBackgroundServiceInitialized) ...[
              const SizedBox(height: 16.0),
              Text(
                localizations?.timerContinuesInBackground ??
                    "Timer continues in background",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 20.0),

            // 힐링 음악 선택 및 재생 위젯
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.music_note),
                  label: Text(localizations?.selectMusic ?? "Select Music"),
                  onPressed: () => _showMusicPlayerDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[100],
                    foregroundColor: Colors.purple[900],
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 시작/중지 버튼 생성
  Widget _buildStartStopButton() {
    final localizations = AppLocalizations.of(context);
    return FloatingActionButton(
      onPressed: _handleStartStop,
      backgroundColor: _getActionButtonColor(),
      foregroundColor: Colors.white,
      elevation: 3,
      splashColor: Colors.white24,
      heroTag: 'startStopButton',
      child: Icon(_getButtonIcon()),
      tooltip:
          _isActive
              ? localizations?.stop ?? "Stop"
              : localizations?.startTimer ?? "Start Timer",
    );
  }

  // 모드 전환 버튼 생성
  Widget _buildToggleModeButton() {
    final localizations = AppLocalizations.of(context);
    return FloatingActionButton(
      onPressed: _handleToggleMode,
      backgroundColor: _getActionButtonColor(),
      foregroundColor: Colors.white,
      elevation: 3,
      splashColor: Colors.white24,
      heroTag: 'toggleModeButton',
      child: Icon(_getToggleIcon()),
      tooltip: localizations?.toggleMode ?? "Toggle Mode",
    );
  }

  // 소리 켜기/끄기 버튼
  Widget _buildSoundToggleButton() {
    final localizations = AppLocalizations.of(context);
    return FloatingActionButton(
      onPressed: _handleSoundToggle,
      backgroundColor: _getActionButtonColor(),
      foregroundColor: Colors.white,
      elevation: 3,
      splashColor: Colors.white24,
      heroTag: 'soundToggleButton',
      child: Icon(_getSoundIcon()),
      tooltip:
          _soundEnabled
              ? localizations?.mute ?? "Mute"
              : localizations?.unmute ?? "Unmute",
    );
  }

  // 타이머 시작
  void _startTimer() async {
    widget.timerService.startTimer();

    // 백그라운드 서비스가 초기화되었으면 백그라운드에서도 타이머 시작
    if (_isBackgroundServiceInitialized) {
      // 사용자의 백그라운드 동의 확인
      bool hasConsent = await _backgroundService.hasUserConsent();

      // 동의가 없으면 요청
      if (!hasConsent) {
        hasConsent = await _backgroundService.showConsentDialog(context);
        if (!hasConsent) {
          // 동의하지 않으면 백그라운드 서비스는 시작하지 않고 앱 내에서만 타이머 실행
          return;
        }
      }

      // 동의를 받았으면 서비스 시작
      final result = await _backgroundService.startService(context);
      if (result) {
        // 백그라운드에서 타이머 시작
        _backgroundService.startTimer(
          isFocusMode: widget.timerService.currentState == TimerState.focusMode,
          minutes:
              widget.timerService.currentState == TimerState.focusMode
                  ? widget.timerService.focusTime
                  : widget.timerService.restTime,
        );
      }
    }
  }

  // 타이머 중지
  void _stopTimer() async {
    widget.timerService.stopTimer();

    // 백그라운드 서비스가 초기화되었으면 백그라운드에서도 타이머 중지
    if (_isBackgroundServiceInitialized) {
      final running = await _backgroundService.isRunning();
      if (running) {
        _backgroundService.stopTimer();
      }
    }
  }

  // 모드 전환
  void _toggleMode() async {
    widget.timerService.toggleMode();

    // 백그라운드 서비스에서도 모드 전환
    if (_isBackgroundServiceInitialized) {
      final running = await _backgroundService.isRunning();
      if (running) {
        // 이전 타이머 중지
        _backgroundService.stopTimer();

        // 새 타이머 시작
        _backgroundService.startTimer(
          isFocusMode: widget.timerService.currentState == TimerState.focusMode,
          minutes:
              widget.timerService.currentState == TimerState.focusMode
                  ? widget.timerService.focusTime
                  : widget.timerService.restTime,
        );
      }
    }
  }

  // 타이머 모드에 따른 텍스트 반환
  String _getModeText() {
    final localizations = AppLocalizations.of(context);
    switch (_timerState) {
      case TimerState.focusMode:
        final minutes = widget.timerService.focusTime;
        return localizations?.focusTimeMinutes(minutes) ??
            "Focus Time $minutes min";
      case TimerState.restMode:
        final minutes = widget.timerService.restTime;
        return localizations?.restTimeMinutes(minutes) ??
            "Rest Time $minutes min";
      case TimerState.inactive:
        return localizations?.ready ?? "Ready";
    }
  }

  // 타이머 모드에 따른 색상 반환
  Color _getModeColor() {
    switch (_timerState) {
      case TimerState.focusMode:
        return Colors.red[700]!;
      case TimerState.restMode:
        return Colors.green[700]!;
      case TimerState.inactive:
        return Colors.blue[700]!;
    }
  }

  // 타이머 설정 위젯 생성
  Widget _buildTimerSettings(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 집중 시간 설정
        _buildTimeSettingButton(
          label: localizations?.focusTime ?? "Focus Time",
          color: Colors.blue.shade700,
          value: widget.timerService.focusTime,
          onTap: () => _showTimeSettingDialog(context, true),
        ),

        const SizedBox(width: 12),

        // 휴식 시간 설정
        _buildTimeSettingButton(
          label: localizations?.restTime ?? "Rest Time",
          color: Colors.orange.shade700,
          value: widget.timerService.restTime,
          onTap: () => _showTimeSettingDialog(context, false),
        ),
      ],
    );
  }

  // 시간 설정 버튼 생성
  Widget _buildTimeSettingButton({
    required String label,
    required Color color,
    required int value,
    required VoidCallback onTap,
  }) {
    final localizations = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      splashColor: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  label.contains(localizations?.focusTime ?? 'Focus')
                      ? Icons.work
                      : Icons.coffee,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  localizations?.minutesValue(value) ?? '$value min',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 시간 설정 다이얼로그 표시
  void _showTimeSettingDialog(BuildContext context, bool isFocusTime) {
    final localizations = AppLocalizations.of(context);
    final currentValue =
        isFocusTime
            ? widget.timerService.focusTime
            : widget.timerService.restTime;

    int selectedValue = currentValue;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              isFocusTime
                  ? localizations?.setFocusTime ?? 'Set Focus Time'
                  : localizations?.setRestTime ?? 'Set Rest Time',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),

                    // 현재 설정값 표시
                    Text(
                      localizations?.minutesValue(selectedValue) ??
                          '$selectedValue min',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color:
                            isFocusTime
                                ? Colors.blue.shade700
                                : Colors.orange.shade700,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 시간 조절 슬라이더
                    Slider(
                      value: selectedValue.toDouble(),
                      min: isFocusTime ? 10 : 5,
                      max: isFocusTime ? 120 : 60, // 최대 시간 확장
                      divisions: isFocusTime ? 22 : 11, // 더 많은 단계 제공
                      activeColor:
                          isFocusTime
                              ? Colors.blue.shade700
                              : Colors.orange.shade700,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedValue = value.toInt();
                        });
                      },
                    ),

                    // 슬라이더 라벨
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localizations?.minutesValue(isFocusTime ? 10 : 5) ??
                                '${isFocusTime ? 10 : 5} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            localizations?.minutesValue(
                                  isFocusTime ? 120 : 60,
                                ) ??
                                '${isFocusTime ? 120 : 60} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 프리셋 버튼
                    const SizedBox(height: 16),
                    Text(
                      localizations?.frequentlyUsedTimes ??
                          'Frequently Used Times',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children:
                          isFocusTime
                              ? [25, 45, 60, 90, 120]
                                  .map(
                                    (minutes) => _buildTimePresetButton(
                                      minutes: minutes,
                                      isSelected: selectedValue == minutes,
                                      color: Colors.blue.shade700,
                                      onTap: () {
                                        setDialogState(() {
                                          selectedValue = minutes;
                                        });
                                      },
                                    ),
                                  )
                                  .toList()
                              : [5, 10, 15, 30, 45]
                                  .map(
                                    (minutes) => _buildTimePresetButton(
                                      minutes: minutes,
                                      isSelected: selectedValue == minutes,
                                      color: Colors.orange.shade700,
                                      onTap: () {
                                        setDialogState(() {
                                          selectedValue = minutes;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                    ),
                  ],
                );
              },
            ),
            actions: [
              // 취소 버튼
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizations?.cancel ?? 'Cancel'),
              ),

              // 저장 버튼
              TextButton(
                onPressed: () {
                  // 값이 변경된 경우 저장
                  if (selectedValue != currentValue) {
                    if (isFocusTime) {
                      widget.timerService.updateTimerSettings(
                        focusTime: selectedValue,
                      );
                    } else {
                      widget.timerService.updateTimerSettings(
                        restTime: selectedValue,
                      );
                    }

                    // 상태 업데이트
                    setState(() {});
                  }

                  Navigator.pop(context);
                },
                child: Text(
                  localizations?.save ?? 'Save',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  // 프리셋 시간 버튼 생성
  Widget _buildTimePresetButton({
    required int minutes,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final localizations = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
          ),
        ),
        child: Text(
          localizations?.minutesValue(minutes) ?? '$minutes min',
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 음악 플레이어 다이얼로그 표시
  void _showMusicPlayerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: MusicPlayerWidget(),
            ),
          ),
        );
      },
    );
  }

  // 시작/중지 버튼 처리
  void _handleStartStop() {
    if (_isActive) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  // 모드 전환 버튼 처리
  void _handleToggleMode() {
    _toggleMode();
  }

  // 소리 켜기/끄기 버튼 처리
  void _handleSoundToggle() {
    setState(() {
      _soundEnabled = !_soundEnabled;
    });
  }

  // 버튼 아이콘 가져오기
  IconData _getButtonIcon() {
    if (_isActive) {
      return Icons.stop;
    } else {
      return Icons.play_arrow;
    }
  }

  // 모드 전환 버튼 아이콘 가져오기
  IconData _getToggleIcon() {
    if (_isFocusMode) {
      return Icons.coffee;
    } else {
      return Icons.work;
    }
  }

  // 소리 버튼 아이콘 가져오기
  IconData _getSoundIcon() {
    if (_soundEnabled) {
      return Icons.volume_up;
    } else {
      return Icons.volume_off;
    }
  }

  // 액션 버튼 색상 설정
  Color _getActionButtonColor() {
    if (_isActive) {
      if (_isFocusMode) {
        // 집중 모드일 때
        return Colors.red.shade500;
      } else {
        // 휴식 모드일 때
        return Colors.green.shade500;
      }
    } else {
      // 대기 상태일 때
      return Colors.blue.shade500;
    }
  }
}
