import 'package:intl/intl.dart';

/// 루틴 로그 모델
///
/// 사용자의 일일 활동 기록을 저장하는 모델
class RoutineLog {
  final int? id; // 데이터베이스 ID
  final String userId; // 사용자 ID
  final DateTime date; // 기록 날짜
  final int focusedTime; // 집중한 시간 (분)
  final int restTime; // 쉰 시간 (분)
  final String? feedbackMessage; // 피드백 메시지

  RoutineLog({
    this.id,
    required this.userId,
    required this.date,
    required this.focusedTime,
    required this.restTime,
    this.feedbackMessage,
  });

  // 날짜 포맷 정의
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // JSON으로부터 RoutineLog 객체 생성
  factory RoutineLog.fromJson(Map<String, dynamic> json) {
    return RoutineLog(
      id: json['id'],
      userId: json['userId'],
      date: _dateFormat.parse(json['date']),
      focusedTime: json['focusedTime'],
      restTime: json['restTime'],
      feedbackMessage: json['feedbackMessage'],
    );
  }

  // RoutineLog 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': _dateFormat.format(date),
      'focusedTime': focusedTime,
      'restTime': restTime,
      'feedbackMessage': feedbackMessage,
    };
  }

  // 데이터베이스 맵으로부터 RoutineLog 객체 생성
  factory RoutineLog.fromMap(Map<String, dynamic> map) {
    return RoutineLog(
      id: map['id'],
      userId: map['user_id'],
      date: _dateFormat.parse(map['date']),
      focusedTime: map['focused_time'],
      restTime: map['rest_time'],
      feedbackMessage: map['feedback_message'],
    );
  }

  // RoutineLog 객체를 데이터베이스 맵으로 변환
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': _dateFormat.format(date),
      'focused_time': focusedTime,
      'rest_time': restTime,
      'feedback_message': feedbackMessage,
    };
  }

  // 루틴 준수율 계산 (0-100%)
  double get adherenceRate {
    // 총 활동 시간
    final totalTime = focusedTime + restTime;

    // 총 활동 시간이 없으면 0% 반환
    if (totalTime == 0) return 0.0;

    // 준수율 계산 (집중 시간이 전체의 70% 이상이면 좋은 준수율)
    // 0.7은 집중 시간의 이상적인 비율 (70%)
    final focusRatio = focusedTime / totalTime;
    const idealRatio = 0.7;

    // 준수율 계산 (집중 시간 비율이 이상적인 비율과 얼마나 가까운지)
    final adherence =
        (focusRatio >= idealRatio) ? 100.0 : (focusRatio / idealRatio) * 100.0;

    return adherence;
  }

  // RoutineLog 객체 복제 및 속성 업데이트
  RoutineLog copyWith({
    int? id,
    String? userId,
    DateTime? date,
    int? focusedTime,
    int? restTime,
    String? feedbackMessage,
  }) {
    return RoutineLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      focusedTime: focusedTime ?? this.focusedTime,
      restTime: restTime ?? this.restTime,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
    );
  }

  // 일일 총 활동 시간 (분)
  int get totalActivityTime => focusedTime + restTime;
}
