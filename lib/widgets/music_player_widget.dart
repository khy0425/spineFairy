import 'package:flutter/material.dart';
import '../services/services.dart';
import '../generated/app_localizations.dart';

/// 음악 플레이어 위젯
///
/// 휴식 모드에서 음악을 재생하는 위젯
class MusicPlayerWidget extends StatefulWidget {
  const MusicPlayerWidget({super.key});

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  final MusicService _musicService = MusicService();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _musicService.addListener(_onMusicServiceChanged);
  }

  @override
  void dispose() {
    _musicService.removeListener(_onMusicServiceChanged);
    super.dispose();
  }

  // 음악 서비스 초기화
  Future<void> _initializeService() async {
    await _musicService.initialize();
    setState(() {});
  }

  // 음악 서비스 상태 변경 시 UI 업데이트
  void _onMusicServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로컬라이제이션 객체 가져오기
    final localizations = AppLocalizations.of(context);

    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final safeAreaInsets = MediaQuery.of(context).padding;

    // 기기별 적절한 높이 계산
    // 확장 모드에서의 높이를 화면의 30%로 제한 (다양한 화면 크기에 대응)
    final maxExpandedHeightPercent = screenSize.height < 700 ? 0.25 : 0.30;
    final maxExpandedHeight = screenSize.height * maxExpandedHeightPercent;

    // 기본 축소 상태 높이와 확장 상태 높이 계산
    const collapsedHeight = 100.0;
    final expandedHeight = _expanded ? 220.0 : collapsedHeight;

    // 경계 초과 여부 확인 및 최종 높이 설정
    final isHeightOverflow = _expanded && expandedHeight > maxExpandedHeight;
    final useHeight = isHeightOverflow ? maxExpandedHeight : expandedHeight;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: useHeight),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child:
            _expanded
                ? SingleChildScrollView(
                  child: _buildPlayerContent(localizations),
                )
                : _buildPlayerContent(localizations),
      ),
    );
  }

  // 플레이어 내용 구성
  Widget _buildPlayerContent(AppLocalizations? localizations) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 기본 플레이어 컨트롤 (항상 표시)
        _buildBasicPlayerControls(localizations),

        // 확장된 컨트롤 (확장 시에만 표시)
        if (_expanded) _buildExpandedControls(localizations),
      ],
    );
  }

  // 기본 플레이어 컨트롤
  Widget _buildBasicPlayerControls(AppLocalizations? localizations) {
    final track = _musicService.currentTrack;
    final isPlaying = _musicService.isPlaying;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade100,
        child: Icon(Icons.music_note, color: Colors.orange.shade700),
      ),
      title:
          track != null
              ? Text(
                track.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              )
              : Text(localizations?.selectMusic ?? 'Select Music'),
      subtitle:
          track != null
              ? Text(track.artist, overflow: TextOverflow.ellipsis)
              : Text(localizations?.restMode ?? 'Rest Mode'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 재생/일시정지 버튼
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            color: Colors.orange.shade700,
            iconSize: 40,
            onPressed: () {
              isPlaying ? _musicService.pause() : _musicService.resume();
            },
          ),

          // 확장/축소 버튼
          IconButton(
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
          ),
        ],
      ),
      onTap: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
    );
  }

  // 확장된 컨트롤
  Widget _buildExpandedControls(AppLocalizations? localizations) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 곡 선택 드롭다운
          _buildTrackSelector(localizations),

          const SizedBox(height: 8),

          // 트랙 컨트롤 버튼
          _buildTrackControls(),

          const SizedBox(height: 8),

          // 재생 모드 버튼들
          _buildPlayModeControls(localizations),
        ],
      ),
    );
  }

  // 트랙 선택 드롭다운
  Widget _buildTrackSelector(AppLocalizations? localizations) {
    return DropdownButtonHideUnderline(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.orange.shade300, width: 1),
          ),
        ),
        child: DropdownButton<int>(
          isExpanded: true,
          value: _musicService.currentIndex,
          hint: Text(localizations?.selectMusic ?? 'Select Music'),
          onChanged: (int? index) {
            if (index != null) {
              _musicService.play(index: index);
            }
          },
          items: List.generate(_musicService.tracks.length, (index) {
            final track = _musicService.tracks[index];
            return DropdownMenuItem<int>(
              value: index,
              child: Text(
                '${track.title} - ${track.artist}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }),
        ),
      ),
    );
  }

  // 트랙 컨트롤 버튼들
  Widget _buildTrackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 이전 트랙 버튼
        IconButton(
          icon: const Icon(Icons.skip_previous),
          color: Colors.orange.shade700,
          onPressed: () {
            _musicService.playPrevious();
          },
        ),

        // 재생/일시정지 버튼
        IconButton(
          icon: Icon(
            _musicService.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
          ),
          iconSize: 48,
          color: Colors.orange.shade700,
          onPressed: () {
            _musicService.isPlaying
                ? _musicService.pause()
                : _musicService.resume();
          },
        ),

        // 다음 트랙 버튼
        IconButton(
          icon: const Icon(Icons.skip_next),
          color: Colors.orange.shade700,
          onPressed: () {
            _musicService.playNext();
          },
        ),

        // 볼륨 버튼
        IconButton(
          icon: const Icon(Icons.volume_up),
          color: Colors.orange.shade700,
          onPressed: () {
            _showVolumeDialog();
          },
        ),
      ],
    );
  }

  // 재생 모드 버튼들
  Widget _buildPlayModeControls(AppLocalizations? localizations) {
    final currentMode = _musicService.playMode;

    return Container(
      width: double.infinity,
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 한 곡 재생 모드
            _buildPlayModeButton(
              PlayMode.single,
              Icons.filter_1,
              localizations?.single ?? 'Single',
              currentMode == PlayMode.single,
            ),

            const SizedBox(width: 4),

            // 한 곡 반복 모드
            _buildPlayModeButton(
              PlayMode.repeat,
              Icons.repeat_one,
              localizations?.repeat ?? 'Repeat',
              currentMode == PlayMode.repeat,
            ),

            const SizedBox(width: 4),

            // 순차 재생 모드
            _buildPlayModeButton(
              PlayMode.sequential,
              Icons.repeat,
              localizations?.sequential ?? 'Sequential',
              currentMode == PlayMode.sequential,
            ),

            const SizedBox(width: 4),

            // 무작위 재생 모드
            _buildPlayModeButton(
              PlayMode.random,
              Icons.shuffle,
              localizations?.random ?? 'Random',
              currentMode == PlayMode.random,
            ),
          ],
        ),
      ),
    );
  }

  // 재생 모드 버튼
  Widget _buildPlayModeButton(
    PlayMode mode,
    IconData icon,
    String tooltip,
    bool isSelected,
  ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(icon),
          color: isSelected ? Colors.orange.shade700 : Colors.grey,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          onPressed: () {
            _musicService.setPlayMode(mode);
          },
        ),
      ),
    );
  }

  // 볼륨 조절 다이얼로그 표시
  void _showVolumeDialog() {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              double volume = _musicService.volume;

              return AlertDialog(
                title: Text(localizations?.volumeControl ?? 'Volume Control'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 볼륨 표시
                    Text(
                      '${(volume * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 볼륨 슬라이더
                    Slider(
                      value: volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      activeColor: Colors.orange.shade700,
                      onChanged: (value) {
                        setState(() {
                          volume = value;
                        });
                        _musicService.setVolume(value);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(localizations?.ok ?? 'OK'),
                  ),
                ],
              );
            },
          ),
    );
  }
}
