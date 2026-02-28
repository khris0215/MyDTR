import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/internship_profile.dart';
import '../models/time_log.dart';
import '../notifiers/dtr_provider.dart';
import 'profile_wizard.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openWizard(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileWizardPage()));
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DtrProvider>();
    return Scaffold(
      key: _scaffoldKey,
      drawer: _ProfileDrawer(
        onAddProfile: () => _openWizard(context),
        onOpenSettings: () => _openSettings(context),
      ),
      floatingActionButton: provider.selectedProfile == null
          ? FloatingActionButton.extended(
              onPressed: () => _openWizard(context),
              label: const Text('Add Internship'),
              icon: const Icon(Icons.add),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showLogSheet(context),
              label: const Text('Log Time'),
              icon: const Icon(Icons.schedule),
            ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: provider.isLoading
              ? const _LoadingState()
              : provider.selectedProfile == null
              ? _EmptyState(onCreate: () => _openWizard(context))
              : _Dashboard(
                  scaffoldKey: _scaffoldKey,
                  onOpenSettings: () => _openSettings(context),
                ),
        ),
      ),
    );
  }

  void _showLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogSheet(),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            color: theme.colorScheme.secondary,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            'Create an internship profile to start tracking.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'My DTR keeps logs offline on your device. Build one profile per internship and start logging shifts instantly.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create internship profile'),
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.scaffoldKey, required this.onOpenSettings});

  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DtrProvider>();
    final profile = provider.selectedProfile!;
    final theme = Theme.of(context);
    final segments = _segmentsForShift(profile.shiftType);
    final daysLeft = provider.daysLeftForSelected();
    final weeksLeft = profile.workingDays.isEmpty
        ? 0
        : (daysLeft / profile.workingDays.length).ceil();
    final monthsLeft = weeksLeft == 0 ? 0 : (weeksLeft / 4).ceil();
    final progress = provider.progressForSelected();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => scaffoldKey.currentState?.openDrawer(),
              ),
              Expanded(
                child: Text(
                  'My DTR',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ProfileSummaryCard(
            profile: profile,
            loggedHours: provider.recordedHoursForProfile(profile.id),
            onAvatarTap: () => _handleAvatarTap(context, profile),
          ),
          const SizedBox(height: 18),
          _ProgressCard(
            progress: progress,
            profile: profile,
            daysLeft: daysLeft,
            weeksLeft: weeksLeft,
            monthsLeft: monthsLeft,
          ),
          const SizedBox(height: 18),
          Text('Shift Logging', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Column(
            children: segments
                .map(
                  (segment) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ShiftTile(segment: segment),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          _DailyTimeline(logs: provider.selectedLogs),
        ],
      ),
    );
  }

  Future<void> _handleAvatarTap(
    BuildContext context,
    InternshipProfile profile,
  ) async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (file == null) {
        return;
      }
      await context.read<DtrProvider>().updateProfileAvatar(
        profile.id,
        file.path,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } on PlatformException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to access gallery (${error.code}).')),
      );
    }
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.profile,
    required this.loggedHours,
    required this.onAvatarTap,
  });

  final InternshipProfile profile;
  final double loggedHours;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workingDays = profile.workingDays.map((day) => day.label).join(' · ');
    final remaining = (profile.totalHoursRequired - loggedHours).clamp(
      0,
      profile.totalHoursRequired,
    );
    final avatarPath = profile.avatarPath;
    ImageProvider? avatarImage;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        avatarImage = FileImage(file);
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onAvatarTap,
                  borderRadius: BorderRadius.circular(48),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: theme.colorScheme.secondary.withAlpha(40),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(profile.name.substring(0, 1).toUpperCase())
                        : null,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        profile.shiftType.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Working days · $workingDays',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the photo to set or change the internship image.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _ProfileStatBadge(
                  label: 'Logged hours',
                  value: '${loggedHours.toStringAsFixed(1)} h',
                ),
                _ProfileStatBadge(
                  label: 'Remaining',
                  value: '${remaining.toStringAsFixed(1)} h',
                ),
                _ProfileStatBadge(
                  label: 'Hours/day',
                  value: profile.hoursPerDay.toStringAsFixed(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatBadge extends StatelessWidget {
  const _ProfileStatBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.profile,
    required this.daysLeft,
    required this.weeksLeft,
    required this.monthsLeft,
  });

  final double progress;
  final InternshipProfile profile;
  final int daysLeft;
  final int weeksLeft;
  final int monthsLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentText = NumberFormat.percentPattern().format(progress);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress overview', style: theme.textTheme.titleMedium),
                Text(percentText, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ProgressStat(
                  label: 'Hours/day',
                  value: profile.hoursPerDay.toStringAsFixed(1),
                ),
                _ProgressStat(label: 'Days left', value: daysLeft.toString()),
                _ProgressStat(label: 'Weeks left', value: weeksLeft.toString()),
                _ProgressStat(
                  label: 'Months left',
                  value: monthsLeft.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({required this.segment});

  final ShiftSegment segment;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DtrProvider>();
    final theme = Theme.of(context);
    final todayToken = DateFormat('yyyyMMdd').format(DateTime.now());
    final relevantLogs = provider.selectedLogs
        .where((log) => log.segment == segment && log.dayToken == todayToken)
        .toList();
    final timeIn = relevantLogs.firstWhereOrNull(
      (log) => log.direction == LogDirection.timeIn,
    );
    final timeOut = relevantLogs.firstWhereOrNull(
      (log) => log.direction == LogDirection.timeOut,
    );
    final timeFmt = DateFormat('h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(segment.label, style: theme.textTheme.titleMedium),
                Icon(
                  Icons.watch_later_outlined,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ShiftButton(
                    label: 'Time in',
                    timeLabel: timeIn == null
                        ? 'Not logged'
                        : timeFmt.format(timeIn.timestamp),
                    onPressed: timeIn == null
                        ? () => provider.logShift(
                            segment: segment,
                            direction: LogDirection.timeIn,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShiftButton(
                    label: 'Time out',
                    timeLabel: timeOut == null
                        ? 'Not logged'
                        : timeFmt.format(timeOut.timestamp),
                    onPressed: timeOut == null
                        ? () => provider.logShift(
                            segment: segment,
                            direction: LogDirection.timeOut,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftButton extends StatelessWidget {
  const _ShiftButton({
    required this.label,
    required this.timeLabel,
    this.onPressed,
  });

  final String label;
  final String timeLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogged = onPressed == null;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: isLogged ? Colors.white24 : theme.colorScheme.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _DailyTimeline extends StatelessWidget {
  const _DailyTimeline({required this.logs});

  final List<TimeLog> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily timeline', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'No logs yet for this profile. Capture a time in to start the record.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = <String, List<TimeLog>>{};
    for (final log in logs) {
      grouped.putIfAbsent(log.dayToken, () => []).add(log);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily timeline', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            ...sortedKeys.take(7).map((key) {
              final parsedDate = _parseDayToken(key);
              final displayDate = parsedDate == null
                  ? key
                  : DateFormat('MMM d, yyyy').format(parsedDate);
              final entries = grouped[key]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayDate,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entries
                          .map(
                            (log) => Chip(
                              label: Text(
                                '${log.segment.label} ${log.direction == LogDirection.timeIn ? 'IN' : 'OUT'} • ${DateFormat('h:mm a').format(log.timestamp)}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LogSheet extends StatelessWidget {
  const _LogSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DtrProvider>();
    final profile = provider.selectedProfile;
    if (profile == null) {
      return const SizedBox.shrink();
    }
    final segments = _segmentsForShift(profile.shiftType);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Log shift',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Timestamps use your device clock and are saved instantly.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                ...segments.map(
                  (segment) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ShiftTile(segment: segment),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDrawer extends StatelessWidget {
  const _ProfileDrawer({
    required this.onAddProfile,
    required this.onOpenSettings,
  });

  final VoidCallback onAddProfile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DtrProvider>();
    final profiles = provider.profiles;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Internship profiles',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final isActive = provider.selectedProfile?.id == profile.id;
                  return ListTile(
                    selected: isActive,
                    leading: CircleAvatar(
                      child: Text(profile.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(profile.name),
                    subtitle: Text(profile.shiftType.label),
                    onTap: () {
                      provider.selectProfile(profile.id);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: profiles.length >= 4 ? null : onAddProfile,
                      icon: const Icon(Icons.add),
                      label: const Text('Add internship profile'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenSettings();
                    },
                    child: const Text('Settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _morningController;
  late final TextEditingController _afternoonController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DtrProvider>();
    _morningController = TextEditingController(
      text: provider.debugMorningHours.toStringAsFixed(1),
    );
    _afternoonController = TextEditingController(
      text: provider.debugAfternoonHours.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _morningController.dispose();
    _afternoonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DtrProvider>();
    final theme = Theme.of(context);
    final simulatedDay = DateFormat(
      'EEE, MMM d',
    ).format(provider.debugSimulatedDate);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Settings & debug tools', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use debug timestamps'),
                subtitle: const Text(
                  'Time in/out buttons will use the configured morning and afternoon durations.',
                ),
                value: provider.debugUseFixedTimes,
                onChanged: provider.setDebugUseFixedTimes,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _morningController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Morning hours',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _afternoonController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Afternoon hours',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _saveHours(context),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Apply debug hours'),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simulated date'),
                subtitle: Text(simulatedDay),
                trailing: Chip(
                  label: Text(
                    provider.debugDayOffset == 0
                        ? 'Today'
                        : '+${provider.debugDayOffset}d',
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => provider.shiftDebugDay(1),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: const Text('Add a day'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: provider.debugDayOffset == 0
                          ? null
                          : provider.resetDebugDayOffset,
                      child: const Text('Reset simulated day'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Morning logs start at 8:00 AM, afternoon at 1:00 PM. Adjust the hour values above to control how many hours get recorded automatically.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveHours(BuildContext context) {
    final provider = context.read<DtrProvider>();
    final morning = double.tryParse(_morningController.text);
    final afternoon = double.tryParse(_afternoonController.text);
    provider.updateDebugHours(morning: morning, afternoon: afternoon);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Debug hours updated.')));
  }
}

List<ShiftSegment> _segmentsForShift(ShiftType type) {
  switch (type) {
    case ShiftType.morningOnly:
      return const [ShiftSegment.morning];
    case ShiftType.afternoonOnly:
      return const [ShiftSegment.afternoon];
    case ShiftType.morningAfternoon:
      return const [ShiftSegment.morning, ShiftSegment.afternoon];
    case ShiftType.night:
      return const [ShiftSegment.night];
  }
}

DateTime? _parseDayToken(String token) {
  if (token.length >= 8) {
    final year = int.tryParse(token.substring(0, 4));
    final month = int.tryParse(token.substring(4, 6));
    final day = int.tryParse(token.substring(6, 8));
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }
  return null;
}
