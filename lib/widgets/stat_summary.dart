import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/services.dart';

/// 통계 요약 위젯
///
/// 사용자의 일일/주간 통계를 간략하게 표시하는 위젯
class StatSummary extends StatefulWidget {
  final String userId;

  const StatSummary({super.key, required this.userId});

  @override
  State<StatSummary> createState() => _StatSummaryState();
}

class _StatSummaryState extends State<StatSummary> {
  final RoutineService _routineService = RoutineService();
  final AdService _adService = AdService();

  // 통계 데이터
  int _todayFocusedTime = 0;
  int _todayRestTime = 0;
  double _todayAdherenceRate = 0.0;
  bool _isLoadingReward = false;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
  }

  // 오늘의 통계 데이터 로드
  Future<void> _loadTodayStats() async {
    final todayLog = await _routineService.getTodayLog(widget.userId);

    if (todayLog != null) {
      setState(() {
        _todayFocusedTime = todayLog.focusedTime;
        _todayRestTime = todayLog.restTime;
        _todayAdherenceRate = todayLog.adherenceRate;
      });
    }
  }

  // 보상형 광고 표시 및 보상 지급
  Future<void> _showRewardedAd() async {
    if (_isLoadingReward) return;

    setState(() {
      _isLoadingReward = true;
    });

    // 광고 로드 및 표시
    final isRewarded = await _adService.showRewardedAd();

    // 보상 지급 (광고 시청 완료 시)
    if (isRewarded) {
      // 집중 시간 보너스 (5분) 추가
      await _routineService.addFocusedTime(widget.userId, 5);

      // 통계 다시 로드
      await _loadTodayStats();

      // 사용자에게 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('축하합니다! 집중 시간 5분이 추가되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingReward = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.0),
      ),
      margin: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 오늘 날짜
          Text(
            _getFormattedDate(),
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8.0),

          // 통계 그리드
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.timer,
                value: _formatMinutes(_todayFocusedTime),
                label: '집중',
              ),
              _buildStatItem(
                icon: Icons.self_improvement,
                value: _formatMinutes(_todayRestTime),
                label: '휴식',
              ),
              _buildStatItem(
                icon: Icons.show_chart,
                value: '${_todayAdherenceRate.round()}%',
                label: '준수율',
              ),
            ],
          ),

          const SizedBox(height: 8.0),

          // 버튼 행
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 새로고침 버튼
              TextButton.icon(
                onPressed: _loadTodayStats,
                icon: const Icon(Icons.refresh, size: 16.0),
                label: const Text('새로고침'),
              ),

              const SizedBox(width: 16.0),

              // 보상형 광고 버튼
              ElevatedButton.icon(
                onPressed: _isLoadingReward ? null : _showRewardedAd,
                icon:
                    _isLoadingReward
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.add_circle, size: 16.0),
                label: const Text('집중 시간 보너스'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade200,
                  foregroundColor: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 통계 아이템 위젯 생성
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24.0),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 14.0)),
      ],
    );
  }

  // 오늘 날짜 포맷팅
  String _getFormattedDate() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy년 MM월 dd일');
    return formatter.format(now);
  }

  // 분 단위 시간 포맷팅
  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes분';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;

      if (remainingMinutes == 0) {
        return '$hours시간';
      } else {
        return '$hours시간 $remainingMinutes분';
      }
    }
  }
}
