import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/dtr_database.dart';
import '../models/internship_profile.dart';
import '../models/time_log.dart';

class DtrProvider extends ChangeNotifier {
  DtrProvider(this._database);

  final DtrDatabase _database;
  final Uuid _uuid = const Uuid();

  final List<InternshipProfile> _profiles = [];
  final Map<String, List<TimeLog>> _logsByProfile = {};

  bool _isLoading = true;
  String? _selectedProfileId;
  bool _debugUseFixedTimes = false;
  double _debugMorningHours = 4;
  double _debugAfternoonHours = 4;
  int _debugDayOffset = 0;

  bool get isLoading => _isLoading;
  List<InternshipProfile> get profiles => List.unmodifiable(_profiles);
  InternshipProfile? get selectedProfile {
    if (_selectedProfileId == null) {
      return null;
    }
    return _profiles.firstWhereOrNull(
      (profile) => profile.id == _selectedProfileId,
    );
  }

  List<TimeLog> get selectedLogs {
    if (_selectedProfileId == null) {
      return const <TimeLog>[];
    }
    return List.unmodifiable(
      _logsByProfile[_selectedProfileId!] ?? <TimeLog>[],
    );
  }

  bool get debugUseFixedTimes => _debugUseFixedTimes;
  double get debugMorningHours => _debugMorningHours;
  double get debugAfternoonHours => _debugAfternoonHours;
  int get debugDayOffset => _debugDayOffset;
  DateTime get debugSimulatedDate =>
      DateTime.now().add(Duration(days: _debugDayOffset));

  Future<void> bootstrap() async {
    _isLoading = true;
    notifyListeners();
    final items = await _database.fetchProfiles();
    _profiles
      ..clear()
      ..addAll(items);
    if (_profiles.isNotEmpty) {
      await selectProfile(_profiles.first.id, notify: false);
    } else {
      _selectedProfileId = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectProfile(String profileId, {bool notify = true}) async {
    _selectedProfileId = profileId;
    final logs = await _database.fetchLogs(profileId);
    _logsByProfile[profileId] = logs;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> createProfile({
    required String name,
    required double totalHours,
    required double hoursPerDay,
    required List<Weekday> workingDays,
    required ShiftType shiftType,
    String? avatarPath,
  }) async {
    final profile = InternshipProfile(
      id: _uuid.v4(),
      name: name.trim(),
      totalHoursRequired: totalHours,
      hoursPerDay: hoursPerDay,
      workingDays: workingDays,
      shiftType: shiftType,
      avatarPath: avatarPath,
      createdAt: DateTime.now(),
    );
    await _database.insertProfile(profile);
    _profiles.insert(0, profile);
    await selectProfile(profile.id, notify: false);
    _selectedProfileId = profile.id;
    notifyListeners();
  }

  Future<void> removeProfile(String profileId) async {
    await _database.removeProfile(profileId);
    _profiles.removeWhere((profile) => profile.id == profileId);
    _logsByProfile.remove(profileId);
    if (_selectedProfileId == profileId) {
      _selectedProfileId = _profiles.isNotEmpty ? _profiles.first.id : null;
    }
    if (_selectedProfileId != null) {
      await selectProfile(_selectedProfileId!, notify: false);
    }
    notifyListeners();
  }

  Future<void> updateProfileAvatar(String profileId, String? avatarPath) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1) {
      return;
    }
    final updated = _profiles[index].copyWith(avatarPath: avatarPath);
    _profiles[index] = updated;
    await _database.updateProfile(updated);
    notifyListeners();
  }

  void setDebugUseFixedTimes(bool value) {
    if (_debugUseFixedTimes == value) {
      return;
    }
    _debugUseFixedTimes = value;
    notifyListeners();
  }

  void updateDebugHours({double? morning, double? afternoon}) {
    var didChange = false;
    if (morning != null && morning > 0 && morning != _debugMorningHours) {
      _debugMorningHours = morning;
      didChange = true;
    }
    if (afternoon != null &&
        afternoon > 0 &&
        afternoon != _debugAfternoonHours) {
      _debugAfternoonHours = afternoon;
      didChange = true;
    }
    if (didChange) {
      notifyListeners();
    }
  }

  void shiftDebugDay(int days) {
    if (days == 0) {
      return;
    }
    _debugDayOffset += days;
    notifyListeners();
  }

  void resetDebugDayOffset() {
    if (_debugDayOffset == 0) {
      return;
    }
    _debugDayOffset = 0;
    notifyListeners();
  }

  Future<void> logShift({
    required ShiftSegment segment,
    required LogDirection direction,
  }) async {
    if (_selectedProfileId == null) {
      return;
    }
    final now = _timestampForLog(segment, direction);
    final dayToken = DateFormat('yyyyMMdd').format(now);
    final log = TimeLog(
      id: _uuid.v4(),
      profileId: _selectedProfileId!,
      segment: segment,
      direction: direction,
      timestamp: now,
      dayToken: dayToken,
    );
    await _database.insertLog(log);
    final logs = _logsByProfile[_selectedProfileId!] ?? <TimeLog>[];
    _logsByProfile[_selectedProfileId!] = [...logs, log]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  double recordedHoursForProfile(String profileId) {
    final logs = _logsByProfile[profileId] ?? <TimeLog>[];
    final grouped = <String, Map<ShiftSegment, List<TimeLog>>>{};
    for (final log in logs) {
      grouped.putIfAbsent(log.dayToken, () => {});
      final segments = grouped[log.dayToken]!;
      segments.putIfAbsent(log.segment, () => []);
      segments[log.segment]!.add(log);
    }

    double totalMinutes = 0;
    for (final day in grouped.values) {
      for (final segmentLogs in day.values) {
        final timeIn = segmentLogs
            .where((log) => log.direction == LogDirection.timeIn)
            .map((log) => log.timestamp)
            .fold<DateTime?>(
              null,
              (prev, ts) => prev == null || ts.isBefore(prev) ? ts : prev,
            );
        final timeOut = segmentLogs
            .where((log) => log.direction == LogDirection.timeOut)
            .map((log) => log.timestamp)
            .fold<DateTime?>(
              null,
              (prev, ts) => prev == null || ts.isAfter(prev) ? ts : prev,
            );
        if (timeIn != null && timeOut != null && timeOut.isAfter(timeIn)) {
          totalMinutes += timeOut.difference(timeIn).inMinutes.toDouble();
        }
      }
    }

    return totalMinutes / 60.0;
  }

  DateTime _timestampForLog(ShiftSegment segment, LogDirection direction) {
    if (!_debugUseFixedTimes) {
      return DateTime.now();
    }
    final base = debugSimulatedDate;
    final startHour = _startHourForSegment(segment);
    final start = DateTime(base.year, base.month, base.day, startHour, 0);
    final minutes = (_hoursForSegment(segment) * 60).round();
    final safeMinutes = minutes <= 0 ? 1 : minutes;
    return direction == LogDirection.timeIn
        ? start
        : start.add(Duration(minutes: safeMinutes));
  }

  double _hoursForSegment(ShiftSegment segment) {
    switch (segment) {
      case ShiftSegment.morning:
        return _debugMorningHours;
      case ShiftSegment.afternoon:
      case ShiftSegment.night:
        return _debugAfternoonHours;
    }
  }

  int _startHourForSegment(ShiftSegment segment) {
    switch (segment) {
      case ShiftSegment.morning:
        return 8;
      case ShiftSegment.afternoon:
        return 13;
      case ShiftSegment.night:
        return 20;
    }
  }

  double progressForSelected() {
    final profile = selectedProfile;
    if (profile == null) {
      return 0;
    }
    final recorded = recordedHoursForProfile(profile.id);
    return (recorded / profile.totalHoursRequired).clamp(0.0, 1.0);
  }

  int daysLeftForSelected() {
    final profile = selectedProfile;
    if (profile == null) {
      return 0;
    }
    final recorded = recordedHoursForProfile(profile.id);
    final remaining = (profile.totalHoursRequired - recorded).clamp(
      0,
      double.infinity,
    );
    if (profile.hoursPerDay <= 0) {
      return 0;
    }
    return (remaining / profile.hoursPerDay).ceil();
  }
}
