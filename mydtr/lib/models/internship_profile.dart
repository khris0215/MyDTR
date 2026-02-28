import 'package:collection/collection.dart';

enum ShiftType { morningOnly, afternoonOnly, morningAfternoon, night }

enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

class InternshipProfile {
  const InternshipProfile({
    required this.id,
    required this.name,
    required this.totalHoursRequired,
    required this.hoursPerDay,
    required this.workingDays,
    required this.shiftType,
    this.avatarPath,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double totalHoursRequired;
  final double hoursPerDay;
  final List<Weekday> workingDays;
  final ShiftType shiftType;
  final String? avatarPath;
  final DateTime createdAt;

  double get weeksRequired =>
      totalHoursRequired / (hoursPerDay * workingDays.length);

  InternshipProfile copyWith({
    String? id,
    String? name,
    double? totalHoursRequired,
    double? hoursPerDay,
    List<Weekday>? workingDays,
    ShiftType? shiftType,
    String? avatarPath,
    DateTime? createdAt,
  }) {
    return InternshipProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      totalHoursRequired: totalHoursRequired ?? this.totalHoursRequired,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      workingDays: workingDays ?? this.workingDays,
      shiftType: shiftType ?? this.shiftType,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'total_hours_required': totalHoursRequired,
      'hours_per_day': hoursPerDay,
      'working_days': workingDays.map((d) => d.name).join(','),
      'shift_type': shiftType.name,
      'avatar_path': avatarPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static InternshipProfile fromMap(Map<String, dynamic> map) {
    final workingDayNames =
        (map['working_days'] as String?)
            ?.split(',')
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];
    return InternshipProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      totalHoursRequired: (map['total_hours_required'] as num).toDouble(),
      hoursPerDay: (map['hours_per_day'] as num).toDouble(),
      workingDays: workingDayNames
          .map(
            (value) =>
                Weekday.values.firstWhereOrNull(
                  (element) => element.name == value,
                ) ??
                Weekday.monday,
          )
          .toList(),
      shiftType: ShiftType.values.firstWhere(
        (type) => type.name == map['shift_type'],
        orElse: () => ShiftType.morningOnly,
      ),
      avatarPath: map['avatar_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

extension WeekdayFormatting on Weekday {
  String get label {
    switch (this) {
      case Weekday.monday:
        return 'Mon';
      case Weekday.tuesday:
        return 'Tue';
      case Weekday.wednesday:
        return 'Wed';
      case Weekday.thursday:
        return 'Thu';
      case Weekday.friday:
        return 'Fri';
      case Weekday.saturday:
        return 'Sat';
      case Weekday.sunday:
        return 'Sun';
    }
  }
}

extension ShiftTypeFormatting on ShiftType {
  String get label {
    switch (this) {
      case ShiftType.morningOnly:
        return 'Morning only';
      case ShiftType.afternoonOnly:
        return 'Afternoon only';
      case ShiftType.morningAfternoon:
        return 'Morning + Afternoon';
      case ShiftType.night:
        return 'Night shift';
    }
  }
}
