import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/internship_profile.dart';
import '../notifiers/dtr_provider.dart';

class ProfileWizardPage extends StatefulWidget {
  const ProfileWizardPage({super.key});

  @override
  State<ProfileWizardPage> createState() => _ProfileWizardPageState();
}

class _ProfileWizardPageState extends State<ProfileWizardPage> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _totalHoursController = TextEditingController();
  final TextEditingController _hoursPerDayController = TextEditingController();
  String? _avatarPath;

  int _currentStep = 0;
  Set<Weekday> _selectedDays = {
    Weekday.monday,
    Weekday.tuesday,
    Weekday.wednesday,
    Weekday.thursday,
    Weekday.friday,
  };
  ShiftType _shiftType = ShiftType.morningOnly;

  @override
  void dispose() {
    _nameController.dispose();
    _totalHoursController.dispose();
    _hoursPerDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DtrProvider>();
    final isAtCapacity = provider.profiles.length >= 4;
    return Scaffold(
      appBar: AppBar(title: const Text('Add internship profile')),
      body: isAtCapacity
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Maximum of 4 profiles reached.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Delete an existing internship profile from the drawer to create a new one.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: _handleContinue,
              onStepCancel: _handleBack,
              controlsBuilder: (context, details) {
                final isLast = _currentStep == 3;
                return Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(isLast ? 'Save profile' : 'Next'),
                    ),
                    const SizedBox(width: 12),
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                  ],
                );
              },
              steps: [
                Step(
                  title: const Text('Basics'),
                  state: _currentStep > 0
                      ? StepState.complete
                      : StepState.indexed,
                  isActive: _currentStep >= 0,
                  content: Form(
                    key: _formKeyStep1,
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            onTap: _pickAvatar,
                            borderRadius: BorderRadius.circular(48),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.white12,
                              backgroundImage: _avatarImage,
                              child: _avatarImage == null
                                  ? const Icon(Icons.photo_camera_outlined)
                                  : null,
                            ),
                          ),
                        ),
                        if (_avatarPath != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _avatarPath = null),
                              child: const Text('Remove photo'),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Optional: add a profile photo now or later from the dashboard.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white60),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Internship name',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Requirements'),
                  state: _currentStep > 1
                      ? StepState.complete
                      : StepState.indexed,
                  isActive: _currentStep >= 1,
                  content: Form(
                    key: _formKeyStep2,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _totalHoursController,
                          decoration: const InputDecoration(
                            labelText: 'Total required hours',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final parsed = double.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a positive number of hours';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _hoursPerDayController,
                          decoration: const InputDecoration(
                            labelText: 'Hours per working day',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final parsed = double.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter hours per day';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Schedule'),
                  state: _currentStep > 2
                      ? StepState.complete
                      : StepState.indexed,
                  isActive: _currentStep >= 2,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Working days',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: Weekday.values
                            .map(
                              (day) => FilterChip(
                                label: Text(day.label),
                                selected: _selectedDays.contains(day),
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      _selectedDays.add(day);
                                    } else if (_selectedDays.length > 1) {
                                      _selectedDays.remove(day);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Shift type',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      ...ShiftType.values.map(
                        (type) => RadioListTile<ShiftType>(
                          title: Text(type.label),
                          value: type,
                          groupValue: _shiftType,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _shiftType = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Review'),
                  isActive: _currentStep >= 3,
                  content: _buildReviewCard(context),
                ),
              ],
            ),
    );
  }

  void _handleContinue() async {
    if (_currentStep == 0 &&
        !(_formKeyStep1.currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep == 1 &&
        !(_formKeyStep2.currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one working day.')),
      );
      return;
    }
    final provider = context.read<DtrProvider>();
    final totalHours = double.parse(_totalHoursController.text);
    final hoursPerDay = double.parse(_hoursPerDayController.text);
    await provider.createProfile(
      name: _nameController.text,
      totalHours: totalHours,
      hoursPerDay: hoursPerDay,
      workingDays: _selectedDays.toList(),
      shiftType: _shiftType,
      avatarPath: _avatarPath,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _handleBack() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _pickAvatar() async {
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
      setState(() => _avatarPath = file.path);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to pick image (${error.code}).')),
      );
    }
  }

  ImageProvider? get _avatarImage {
    final path = _avatarPath;
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    return FileImage(file);
  }

  Widget _buildReviewCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewRow(
              'Internship',
              _nameController.text.isEmpty ? 'Not set' : _nameController.text,
            ),
            _reviewRow(
              'Total hours',
              _totalHoursController.text.isEmpty
                  ? '—'
                  : _totalHoursController.text,
            ),
            _reviewRow(
              'Hours/day',
              _hoursPerDayController.text.isEmpty
                  ? '—'
                  : _hoursPerDayController.text,
            ),
            _reviewRow(
              'Working days',
              _selectedDays.map((d) => d.label).join(', '),
            ),
            _reviewRow('Shift type', _shiftType.label),
            const SizedBox(height: 12),
            Text(
              'Timestamps rely on your phone clock and sync locally only.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
