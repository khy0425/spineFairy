import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/models.dart';
import '../services/services.dart';
import '../models/character_model.dart';
import '../services/timer_service.dart';
import '../generated/app_localizations.dart';

/// 캐릭터 디스플레이 위젯
///
/// 캐릭터의 감정 상태에 따른 이미지와 메시지를 표시하는 위젯
class CharacterDisplay extends StatefulWidget {
  final Character character;
  final TimerService timerService;
  final double? displaySize;

  const CharacterDisplay({
    Key? key,
    required this.character,
    required this.timerService,
    this.displaySize,
  }) : super(key: key);

  @override
  State<CharacterDisplay> createState() => _CharacterDisplayState();
}

class _CharacterDisplayState extends State<CharacterDisplay>
    with SingleTickerProviderStateMixin {
  // 현재 감정 상태
  String _emotion = Character.NORMAL;
  // 이전 감정 상태 (변화 감지용)
  String _previousEmotion = Character.NORMAL;
  // 현재 메시지
  String _message = "";
  // 타이머 상태
  TimerState _timerState = TimerState.inactive;

  // 감정 변화 강조 애니메이션 컨트롤러
  late AnimationController _emotionChangeController;
  late Animation<double> _pulseAnimation;

  // 감정 변화 감지 플래그
  bool _emotionChanged = false;

  // 터치 관련 변수
  int _touchCount = 0;
  DateTime? _lastTouchTime;
  bool _isTouchReacting = false;

  // 터치 감정 시퀀스
  final List<String> _touchEmotions = [
    Character.NORMAL,
    Character.WORRIED,
    Character.SAD,
    Character.HAPPY,
    Character.DISAPPOINTED,
    Character.WORRIED,
    Character.SAD,
    Character.SLEEPY,
    Character.HAPPY,
    Character.DISAPPOINTED,
  ];

  // 추가: 터치 리셋 타이머 변수 선언 (class 상단에 추가)
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    widget.timerService.addListener(_onTimerStateChanged);

    // 초기 감정 상태 설정
    _updateEmotionAndMessage();

    // 감정 변화 애니메이션 컨트롤러 초기화
    _emotionChangeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 펄스 애니메이션 생성
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _emotionChangeController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // 애니메이션 상태 리스너 추가
    _emotionChangeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 애니메이션이 최대 크기에 도달하면 다시 작아지는 애니메이션 시작
        _emotionChangeController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        // 애니메이션이 완전히 작아져서 원래 크기로 돌아왔을 때
        if (mounted) {
          setState(() {
            _emotionChanged = false;
          });
        }
      }
    });

    // 이미지 사전 로드는 didChangeDependencies에서 처리
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 모든 감정 이미지 사전 로드 (context 준비된 후 호출)
    _preloadAllImages();
  }

  // 모든 감정 이미지 사전 로드
  void _preloadAllImages() {
    if (!mounted) return;

    // 사용할 모든 감정 종류 리스트
    final emotions = [
      Character.NORMAL,
      Character.HAPPY,
      Character.SAD,
      Character.WORRIED,
      Character.SLEEPY,
      Character.EXCITED,
      Character.DISAPPOINTED,
      Character.PROUD,
    ];

    // 각 감정별 이미지 사전 로드
    for (var emotion in emotions) {
      final imageUrl = widget.character.getEmotionImage(emotion);

      try {
        // 이미지 사전 로드
        precacheImage(AssetImage(imageUrl), context);
      } catch (e) {
        // 오류 처리 (로그 없이)
      }
    }
  }

  // 터치 이벤트 처리
  void _handleCharacterTouch() {
    final now = DateTime.now();
    final appLocalizations = AppLocalizations.of(context);

    // 마지막 터치로부터 5초가 지났으면 카운트 리셋
    if (_lastTouchTime != null &&
        now.difference(_lastTouchTime!).inSeconds > 5) {
      _touchCount = 0;
    }

    // 터치 카운트 증가
    _touchCount++;
    _lastTouchTime = now;

    // 터치 반응 인덱스 (최대값 제한)
    int reactionIndex = (_touchCount - 1) % 10; // 10개의 반응으로 제한

    // 현재 실행 중인 타이머 취소 (여러번 터치해도 타이머가 중첩되지 않도록)
    if (_resetTimer != null && _resetTimer!.isActive) {
      _resetTimer!.cancel();
    }

    // 현재 언어에 맞는 터치 반응 메시지 가져오기
    String message = '';
    if (appLocalizations != null) {
      switch (reactionIndex) {
        case 0:
          message = appLocalizations.touchReaction1;
          break;
        case 1:
          message = appLocalizations.touchReaction2;
          break;
        case 2:
          message = appLocalizations.touchReaction3;
          break;
        case 3:
          message = appLocalizations.touchReaction4;
          break;
        case 4:
          message = appLocalizations.touchReaction5;
          break;
        case 5:
          message = appLocalizations.touchReaction6;
          break;
        case 6:
          message = appLocalizations.touchReaction7;
          break;
        case 7:
          message = appLocalizations.touchReaction8;
          break;
        case 8:
          message = appLocalizations.touchReaction9;
          break;
        case 9:
          message = appLocalizations.touchReaction10;
          break;
        default:
          message = appLocalizations.touchReaction1;
      }
    } else {
      // 로컬라이제이션을 사용할 수 없는 경우 기본 영어 메시지
      final List<String> fallbackMessages = [
        "Hmm? Why are you touching me?",
        "If you keep touching me, I'll feel weird...",
        "Please stop touching me!",
        "Ouch... that tickles...",
        "Please stop now!",
        "I can't focus like this!",
        "I might get angry...",
        "Phew... I'm being patient...",
        "Hehe... actually I like it...",
        "Now I'm really angry!! 😡",
      ];
      message = fallbackMessages[reactionIndex];
    }

    // 터치 반응 표시 (애니메이션과 함께)
    setState(() {
      // 이전 감정 저장
      _previousEmotion = _emotion;

      // 새 감정으로 변경
      _emotion = _touchEmotions[reactionIndex];
      _message = message;
      _emotionChanged = true;
      _isTouchReacting = true;

      // 진행 중인 애니메이션 중지
      if (_emotionChangeController.isAnimating) {
        _emotionChangeController.stop();
      }

      // 애니메이션 효과 (펄스 효과)
      _emotionChangeController.reset(); // 이미 실행 중인 애니메이션 초기화
      _emotionChangeController.forward(); // 커지는 애니메이션 시작

      // 햅틱 피드백 (터치 느낌)
      HapticFeedback.mediumImpact();
    });

    // 5초 후 자동으로 원래 상태로 돌아가기
    _resetTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          // 현재 감정을 이전 감정으로 기록
          _previousEmotion = _emotion;

          // 타이머 상태에 맞는 감정으로 복원
          _updateEmotionAndMessage();

          // 애니메이션 실행하지 않고 상태만 변경
          // 감정 변화 표시 비활성화
          _emotionChanged = false;

          // 터치 반응 종료 표시 (상태 추적용)
          _isTouchReacting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _emotionChangeController.dispose();
    _resetTimer?.cancel(); // 타이머 정리
    widget.timerService.removeListener(_onTimerStateChanged);
    super.dispose();
  }

  // 타이머 상태 변경 시 호출
  void _onTimerStateChanged() {
    if (!_isTouchReacting) {
      _updateEmotionAndMessage();
    }
  }

  // 감정과 메시지 업데이트
  void _updateEmotionAndMessage() {
    if (!mounted || _isTouchReacting) return;

    setState(() {
      // 이전 상태 저장
      _previousEmotion = _emotion;
      _timerState = widget.timerService.currentState;

      // 타이머 상태에 따라 감정 설정
      String newEmotion;
      switch (_timerState) {
        case TimerState.inactive:
          newEmotion = Character.NORMAL;
          break;
        case TimerState.focusMode:
          // 집중 시간에 따라 다른 감정 표현
          final elapsed = widget.timerService.elapsed;
          final duration = widget.timerService.focusTime * 60;

          if (elapsed < duration * 0.3) {
            // 초반 30%는 신나는 상태
            newEmotion = Character.EXCITED;
          } else if (elapsed < duration * 0.7) {
            // 중반 40%는 집중 상태
            newEmotion = Character.NORMAL;
          } else {
            // 후반 30%는 졸린/지친 상태
            newEmotion = Character.SLEEPY;
          }
          break;
        case TimerState.restMode:
          // 휴식 시간에 따라 다른 감정 표현
          final elapsed = widget.timerService.elapsed;
          final duration = widget.timerService.restTime * 60;

          if (elapsed < duration * 0.5) {
            // 초반 50%는 행복한 상태
            newEmotion = Character.HAPPY;
          } else {
            // 후반 50%는 기대/준비 상태
            newEmotion = Character.PROUD;
          }
          break;
        default:
          newEmotion = _emotion;
          break;
      }

      // 감정 변화 감지
      if (_emotion != newEmotion) {
        _emotion = newEmotion;

        // 감정 변화 감지 및 애니메이션 시작
        _emotionChanged = true;

        // 이미 실행 중인 애니메이션 리셋 후 새 애니메이션 시작
        _emotionChangeController.reset();
        _emotionChangeController.forward(from: 0.0);
      }

      // 감정과 타이머 상태에 따른 메시지 설정
      _message = widget.character.getMessageByTimerState(
        _emotion,
        _timerState,
        widget.timerService.elapsed ~/ 60,
        _timerState == TimerState.focusMode
            ? widget.timerService.focusTime
            : widget.timerService.restTime,
        isCompleted: false,
        isStopped: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 계산 - 높이를 고려하여 조정
    final screenSize = MediaQuery.of(context).size;
    final availableHeight = screenSize.height * 0.7; // 사용 가능한 높이의 70%로 제한

    // 화면 크기에 맞게 캐릭터 크기 조정 (또는 직접 지정된 크기 사용)
    final characterSize =
        widget.displaySize ??
        (screenSize.width * 0.4 < availableHeight * 0.5
            ? screenSize.width *
                0.4 // 화면 너비의 40%
            : availableHeight * 0.5); // 또는 사용 가능한 높이의 50%

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 필요한 공간만 차지하도록 설정
          children: [
            // 캐릭터 이미지와 배경 효과 (GestureDetector로 감싸서 터치 감지)
            GestureDetector(
              onTap: _handleCharacterTouch,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 감정 상태에 따른 배경 효과
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: characterSize + 30,
                    height: characterSize + 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.character.emotionColors[_emotion]
                          ?.withOpacity(_emotionChanged ? 0.4 : 0.2),
                    ),
                  ),
                  // 애니메이션 효과를 위한 내부 배경
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: characterSize + 15,
                    height: characterSize + 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.character.emotionColors[_emotion]
                          ?.withOpacity(_emotionChanged ? 0.5 : 0.3),
                    ),
                  ),
                  // 감정 변화 강조 표시 (감정 변화 시에만 표시)
                  if (_emotionChanged)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: (characterSize + 40) * _pulseAnimation.value,
                          height: (characterSize + 40) * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  widget.character.emotionColors[_emotion] ??
                                  Colors.blue,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (widget
                                            .character
                                            .emotionColors[_emotion] ??
                                        Colors.blue)
                                    .withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  // 캐릭터 이미지
                  _buildCharacterImage(characterSize),
                  // 감정 변화 표시 아이콘 (감정 변화 시에만 표시)
                  if (_emotionChanged)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.character.emotionIcons[_emotion],
                                color: widget.character.emotionColors[_emotion],
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16.0),

            // 캐릭터 대화 메시지 말풍선
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color:
                        _emotionChanged
                            ? (widget.character.emotionColors[_emotion] ??
                                    Colors.blue)
                                .withOpacity(0.3)
                            : Colors.black.withOpacity(0.1),
                    blurRadius: _emotionChanged ? 15 : 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border:
                    _emotionChanged
                        ? Border.all(
                          color: (widget.character.emotionColors[_emotion] ??
                                  Colors.blue)
                              .withOpacity(0.5),
                          width: 2,
                        )
                        : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 캐릭터 이름과 감정 아이콘
                  Row(
                    children: [
                      Text(
                        widget.character.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _emotionChanged
                          ? TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 1.0 + sin(value * 4 * pi) * 0.2,
                                child: Icon(
                                  widget.character.emotionIcons[_emotion],
                                  color:
                                      widget.character.emotionColors[_emotion],
                                  size: 20,
                                ),
                              );
                            },
                          )
                          : Icon(
                            widget.character.emotionIcons[_emotion],
                            color: widget.character.emotionColors[_emotion],
                            size: 20,
                          ),
                      // 감정 변화 표시 (텍스트)
                      if (_emotionChanged)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (widget
                                          .character
                                          .emotionColors[_emotion] ??
                                      Colors.blue)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _isTouchReacting ? '터치 반응' : '감정 변화',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 캐릭터 메시지
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 500),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          _emotionChanged ? FontWeight.bold : FontWeight.normal,
                      color: _emotionChanged ? Colors.black : Colors.black87,
                    ),
                    child: Text(_message),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 캐릭터 이미지를 로드하고 표시하는 메소드
  Widget _buildCharacterImage(double size) {
    // 감정에 따른 이미지 경로 가져오기
    final imageUrl = widget.character.getEmotionImage(_emotion);

    // 이미지 캐시 키 변경 - 매번 다시 로드하지 않고 emotion에 따라서만 키 변경
    final cacheKey = '$imageUrl-$_emotion';

    return Stack(
      alignment: Alignment.center,
      children: [
        // 배경 원형 (항상 표시)
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                widget.character.emotionColors[_emotion]?.withOpacity(0.2) ??
                Colors.grey.withOpacity(0.2),
          ),
        ),

        // 감정 변화 효과 애니메이션 (감정 변화 시에만 표시) - 캐릭터 이미지 아래에 표시
        if (_emotionChanged)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: size * _pulseAnimation.value,
                height: size * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        widget.character.emotionColors[_emotion] ?? Colors.blue,
                    width: 1.5,
                  ),
                ),
              );
            },
          ),

        // 이미지 표시 - 항상 최상위에 배치
        // 이미지 전환을 부드럽게 하기 위해 AnimatedSwitcher 사용
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Image.asset(
            imageUrl,
            key: ValueKey(cacheKey),
            width: size * 0.95,
            height: size * 0.95,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // 대체 이미지 또는 아이콘으로 대체
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 감정 아이콘 표시
                    Icon(
                      widget.character.emotionIcons[_emotion] ?? Icons.face,
                      color:
                          widget.character.emotionColors[_emotion] ??
                          Colors.blue,
                      size: size * 0.6,
                    ),
                    // 디버그 모드에서 감정 이름 표시
                    if (kDebugMode)
                      Text(
                        '[$_emotion] 로드 실패',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// 집중 모드 배경 효과
class _FocusModeBubblesPainter extends CustomPainter {
  final Color color;
  final Random random = Random();

  _FocusModeBubblesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const bubbleCount = 20;
    final paint =
        Paint()
          ..color = color.withOpacity(0.4)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < bubbleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 5 + 1;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 휴식 모드 배경 효과
class _RestModeBubblesPainter extends CustomPainter {
  final Random random = Random();

  @override
  void paint(Canvas canvas, Size size) {
    const bubbleCount = 15;
    final colors = [
      Colors.pink.shade100.withOpacity(0.3),
      Colors.blue.shade100.withOpacity(0.3),
      Colors.purple.shade100.withOpacity(0.3),
      Colors.amber.shade100.withOpacity(0.3),
    ];

    for (int i = 0; i < bubbleCount; i++) {
      final paint =
          Paint()
            ..color = colors[random.nextInt(colors.length)]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;

      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final width = random.nextDouble() * 20 + 10;
      final height = random.nextDouble() * 20 + 10;

      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: width,
        height: height,
      );

      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 일반 모드 배경 효과
class _NormalModeBubblesPainter extends CustomPainter {
  final Color color;
  final Random random = Random();

  _NormalModeBubblesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const bubbleCount = 10;
    final paint =
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    for (int i = 0; i < bubbleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 15 + 5;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 별 효과 (집중 모드용)
class _StarsPainter extends CustomPainter {
  final Color color;
  final Random random = Random();

  _StarsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const starCount = 12;
    final paint =
        Paint()
          ..color = color.withOpacity(0.5)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < starCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2 + 1;

      final path = Path();
      const starPoints = 5;
      final innerRadius = radius * 0.4;
      final outerRadius = radius;
      final centerX = x;
      final centerY = y;

      final angle = 2 * pi / starPoints;

      for (int i = 0; i < starPoints; i++) {
        final outerX = centerX + outerRadius * cos(i * angle - pi / 2);
        final outerY = centerY + outerRadius * sin(i * angle - pi / 2);

        final innerX = centerX + innerRadius * cos((i + 0.5) * angle - pi / 2);
        final innerY = centerY + innerRadius * sin((i + 0.5) * angle - pi / 2);

        if (i == 0) {
          path.moveTo(outerX, outerY);
        } else {
          path.lineTo(outerX, outerY);
        }

        path.lineTo(innerX, innerY);
      }
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
