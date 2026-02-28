import 'package:collection/collection.dart';

enum ShiftSegment { morning, afternoon, night }

enum LogDirection { timeIn, timeOut }

class TimeLog {
  const TimeLog({
    required this.id,
    required this.profileId,
    required this.segment,
    required this.direction,
    required this.timestamp,
    required this.dayToken,
  });

  final String id;
  final String profileId;
  final ShiftSegment segment;
  final LogDirection direction;
  final DateTime timestamp;
  final String dayToken;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profile_id': profileId,
      'segment': segment.name,
      'direction': direction.name,
      'timestamp': timestamp.toIso8601String(),
      'day_token': dayToken,
    };
  }

  static TimeLog fromMap(Map<String, dynamic> map) {
    return TimeLog(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      segment:
          ShiftSegment.values.firstWhereOrNull(
            (value) => value.name == map['segment'],
          ) ??
          ShiftSegment.morning,
      direction:
          LogDirection.values.firstWhereOrNull(
            (value) => value.name == map['direction'],
          ) ??
          LogDirection.timeIn,
      timestamp: DateTime.parse(map['timestamp'] as String),
      dayToken: map['day_token'] as String,
    );
  }
}

extension ShiftSegmentFormatting on ShiftSegment {
  String get label {
    switch (this) {
      case ShiftSegment.morning:
        return 'Morning';
      case ShiftSegment.afternoon:
        return 'Afternoon';
      case ShiftSegment.night:
        return 'Night';
    }
  }
}
