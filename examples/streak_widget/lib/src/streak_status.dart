import 'package:flutter/material.dart';

/// The three presentations the Streak widget switches between.
///
/// The colors and icons match the ones in `home_widget/streak.dart`, so the
/// in-app preview and the home screen agree.
enum StreakStatus {
  pending(
    label: 'Pending',
    color: Color(0xE0AFAFAF),
    icon: Icons.local_fire_department,
    mascots: [
      'assets/dash/time_wait.png',
      'assets/dash/wait_lean.png',
      'assets/dash/waiting_tab.png',
      'assets/dash/sad_wait.png',
      'assets/dash/stars_wait.png',
      'assets/dash/alarm_work.png',
      'assets/dash/angry_tap.png',
      'assets/dash/door_peek.png',
      'assets/dash/class_learn.png',
      'assets/dash/teacher.png',
      'assets/dash/drill.png',
      'assets/dash/warning.png',
      'assets/dash/fire_rod.png',
      'assets/dash/fire_side.png',
      'assets/dash/cook_hell.png',
      'assets/dash/hell_climb.png',
      'assets/dash/hell_up.png',
      'assets/dash/sit_skyline.png',
      'assets/dash/sleep.png',
      'assets/dash/stone.png',
    ],
    messages: [
      'Dash is waiting',
      "5 minutes. That's it.",
      'Your streak is at risk',
      'One lesson. Go.',
      'Dash is tapping her foot',
      'Still nothing?',
      'The bird is watching',
    ],
  ),
  completed(
    label: 'Completed',
    color: Color(0xE0FF9600),
    icon: Icons.local_fire_department,
    mascots: [
      'assets/dash/success_grass.png',
      'assets/dash/dance.png',
      'assets/dash/dance_forrest.png',
      'assets/dash/hero.png',
      'assets/dash/hell_dance.png',
      'assets/dash/roll.png',
    ],
    messages: [
      'Streak secured',
      'Dash is proud',
      'Lesson done. Nice.',
      'Nothing but fire',
      'You did the thing',
      'Dash is dancing',
      'Come back tomorrow',
      'Certified consistent',
    ],
  ),
  frozen(
    label: 'Frozen',
    color: Color(0xE01CB0F6),
    icon: Icons.ac_unit,
    mascots: [
      'assets/dash/freeze.png',
      'assets/dash/stone.png',
      'assets/dash/sleep.png',
      'assets/dash/cave_lie.png',
      'assets/dash/diver.png',
      'assets/dash/sit_skyline.png',
    ],
    messages: [
      'Streak on ice',
      'Thawing tomorrow',
      'Dash is chilling',
      'Freeze applied',
      'Your streak naps',
      'Cold, but safe',
      'Back at it tomorrow',
    ],
  );

  const StreakStatus({
    required this.label,
    required this.color,
    required this.icon,
    required this.mascots,
    required this.messages,
  });

  final String label;
  final Color color;
  final IconData icon;

  /// Asset paths one is drawn from per 15 minute slot.
  final List<String> mascots;

  /// Captions a slot may show.
  final List<String> messages;
}
