import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 음악 트랙 정보
class MusicTrack {
  final String title; // 곡 제목
  final String artist; // 아티스트
  final String filePath; // 파일 경로

  const MusicTrack({
    required this.title,
    required this.artist,
    required this.filePath,
  });

  @override
  String toString() => '$title - $artist';
}

/// 재생 모드
enum PlayMode {
  single, // 한 곡 재생
  repeat, // 한 곡 반복
  sequential, // 순차 재생
  random, // 무작위 재생
}

/// 음악 서비스
///
/// 휴식 시간 동안 음악을 재생하는 서비스
class MusicService extends ChangeNotifier {
  // 싱글톤 패턴
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  // 플레이어 인스턴스
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 현재 재생 상태
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // 현재 재생 중인 트랙 인덱스
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  // 현재 재생 중인 트랙
  MusicTrack? _currentTrack;
  MusicTrack? get currentTrack => _currentTrack;

  // 볼륨 (0.0 ~ 1.0)
  double _volume = 0.7;
  double get volume => _volume;

  // 재생 모드
  PlayMode _playMode = PlayMode.sequential;
  PlayMode get playMode => _playMode;

  // 음악 트랙 목록
  final List<MusicTrack> _tracks = [
    const MusicTrack(
      title: 'A Comfortable Living Space',
      artist: 'Jazz Relaxing',
      filePath:
          'assets/sounds/a-comfortable-living-space-jazz-relaxing-instagram-music-217770.mp3',
    ),
    const MusicTrack(
      title: '123 Sisters',
      artist: 'Ambient',
      filePath: 'assets/sounds/123-sisters-298285.mp3',
    ),
    const MusicTrack(
      title: 'Starry Sky',
      artist: 'Calm Dreamy Piano',
      filePath: 'assets/sounds/starry-sky-calm-dreamy-piano-235728.mp3',
    ),
    const MusicTrack(
      title: 'Water Fall',
      artist: 'Nature Sounds',
      filePath: 'assets/sounds/122-water-fall-298284.mp3',
    ),
    const MusicTrack(
      title: 'Bumpy Crows Lazing on Clouds',
      artist: 'Ambient',
      filePath: 'assets/sounds/121-bumpy-crows-lazing-on-clouds-298283.mp3',
    ),
    const MusicTrack(
      title: 'Celestial Love',
      artist: 'Relaxing',
      filePath: 'assets/sounds/celestial-love-325229.mp3',
    ),
  ];

  List<MusicTrack> get tracks => _tracks;

  // 서비스 초기화 여부
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 오디오 플레이어 설정
      _audioPlayer.setReleaseMode(ReleaseMode.release);
      _audioPlayer.setVolume(_volume);

      // 트랙 완료 콜백 설정
      _audioPlayer.onPlayerComplete.listen((_) {
        _onTrackComplete();
      });

      _isInitialized = true;
      debugPrint('음악 서비스 초기화 완료');
    } catch (e) {
      debugPrint('음악 서비스 초기화 오류: $e');
    }
  }

  /// 트랙 재생
  Future<void> play({int? index}) async {
    if (!_isInitialized) await initialize();

    if (_tracks.isEmpty) {
      debugPrint('재생할 트랙이 없습니다.');
      return;
    }

    // 인덱스가 지정되어 있으면 해당 트랙으로 설정
    if (index != null && index >= 0 && index < _tracks.length) {
      _currentIndex = index;
    }

    // 현재 트랙 설정
    _currentTrack = _tracks[_currentIndex];

    try {
      // 파일 경로로 오디오 소스 설정
      await _audioPlayer.setSource(
        AssetSource(_currentTrack!.filePath.replaceFirst('assets/', '')),
      );
      await _audioPlayer.resume();

      _isPlaying = true;
      debugPrint('재생 중: ${_currentTrack.toString()}');
      notifyListeners();
    } catch (e) {
      debugPrint('재생 오류: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 일시 정지
  Future<void> pause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 재생 재개
  Future<void> resume() async {
    if (!_isPlaying && _currentTrack != null) {
      await _audioPlayer.resume();
      _isPlaying = true;
      notifyListeners();
    } else if (!_isPlaying) {
      await play();
    }
  }

  /// 재생 중지
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    notifyListeners();
  }

  /// 다음 트랙 재생
  Future<void> playNext() async {
    if (_tracks.isEmpty) return;

    // 재생 모드에 따라 다음 트랙 인덱스 결정
    switch (_playMode) {
      case PlayMode.single:
      case PlayMode.repeat:
        // 현재 트랙 유지
        break;

      case PlayMode.sequential:
        // 순차적으로 다음 트랙
        _currentIndex = (_currentIndex + 1) % _tracks.length;
        break;

      case PlayMode.random:
        // 무작위 트랙 (현재와 다른 트랙)
        if (_tracks.length > 1) {
          int nextIndex;
          do {
            nextIndex = Random().nextInt(_tracks.length);
          } while (nextIndex == _currentIndex);
          _currentIndex = nextIndex;
        }
        break;
    }

    // 선택된 트랙 재생
    await play(index: _currentIndex);
  }

  /// 이전 트랙 재생
  Future<void> playPrevious() async {
    if (_tracks.isEmpty) return;

    // 재생 모드에 따라 이전 트랙 인덱스 결정
    switch (_playMode) {
      case PlayMode.single:
      case PlayMode.repeat:
        // 현재 트랙 유지
        break;

      case PlayMode.sequential:
        // 순차적으로 이전 트랙
        _currentIndex = (_currentIndex - 1 + _tracks.length) % _tracks.length;
        break;

      case PlayMode.random:
        // 무작위 트랙 (현재와 다른 트랙)
        if (_tracks.length > 1) {
          int prevIndex;
          do {
            prevIndex = Random().nextInt(_tracks.length);
          } while (prevIndex == _currentIndex);
          _currentIndex = prevIndex;
        }
        break;
    }

    // 선택된 트랙 재생
    await play(index: _currentIndex);
  }

  /// 트랙 완료 시 처리
  void _onTrackComplete() {
    // 재생 모드에 따라 다음 동작 결정
    switch (_playMode) {
      case PlayMode.single:
        // 단일 재생은 끝나면 멈춤
        _isPlaying = false;
        notifyListeners();
        break;

      case PlayMode.repeat:
        // 현재 트랙 다시 재생
        play(index: _currentIndex);
        break;

      case PlayMode.sequential:
      case PlayMode.random:
        // 다음 트랙 재생
        playNext();
        break;
    }
  }

  /// 볼륨 설정
  Future<void> setVolume(double value) async {
    if (value < 0.0) value = 0.0;
    if (value > 1.0) value = 1.0;

    _volume = value;
    await _audioPlayer.setVolume(_volume);
    notifyListeners();
  }

  /// 재생 모드 설정
  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  /// 타이머 모드 변경 시 음악 동작 처리
  void handleTimerModeChange(bool isFocusMode) {
    if (isFocusMode) {
      // 집중 모드로 전환 시 음악 정지
      stop();
    } else {
      // 휴식 모드로 전환 시 음악 재생
      if (!_isPlaying) {
        play();
      }
    }
  }

  /// 리소스 해제
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
