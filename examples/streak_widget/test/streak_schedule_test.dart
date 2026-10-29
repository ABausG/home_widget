import 'dart:io';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_widget/src/home_widget/streak.home_widget.dart';
import 'package:streak_widget/src/streak_schedule.dart';
import 'package:streak_widget/src/streak_status.dart';

void main() {
  test('the first slot is the quarter hour containing "from"', () {
    final schedule = buildStreakSchedule(
      StreakStatus.pending,
      from: DateTime(2026, 3, 7, 9, 37, 42),
      slots: 2,
    );

    final keys = schedule.keys.toList()..sort();
    expect(keys.first, DateTime(2026, 3, 7, 9, 30));
    expect(keys.last, DateTime(2026, 3, 7, 9, 45));
  });

  test('the schedule has one entry per 15 minutes', () {
    final from = DateTime(2026, 3, 7, 9, 0);
    final schedule = buildStreakSchedule(StreakStatus.completed, from: from);

    expect(schedule, hasLength(24));
    expect(streakScheduleEnd(schedule), DateTime(2026, 3, 7, 15, 0));
  });

  List<StreakTimedData> inOrder(Map<DateTime, StreakTimedData> schedule) => [
    for (final key in schedule.keys.toList()..sort()) schedule[key]!,
  ];

  String mascotOf(StreakTimedData entry) =>
      (entry.mascot! as AssetImage).assetName;

  for (final status in StreakStatus.values) {
    test('${status.name} shows its whole pool before repeating a mascot', () {
      for (var seed = 0; seed < 50; seed++) {
        final mascots = inOrder(
          buildStreakSchedule(status, slots: 48, random: Random(seed)),
        ).map(mascotOf).toList();
        final pool = status.mascots.length;

        expect(status.mascots, containsAll(mascots.toSet()));
        for (var i = 1; i < mascots.length; i++) {
          expect(mascots[i], isNot(mascots[i - 1]));
        }
        for (var i = 0; i + pool <= mascots.length; i += pool) {
          expect(mascots.sublist(i, i + pool).toSet(), hasLength(pool));
        }
      }
    });
  }

  test('the same seed builds the same rotation, another seed another one', () {
    List<(String, String?)> rotation(int seed) => [
      for (final entry in inOrder(
        buildStreakSchedule(StreakStatus.pending, random: Random(seed)),
      ))
        (mascotOf(entry), entry.message),
    ];

    expect(rotation(7), rotation(7));
    expect(rotation(7), isNot(rotation(8)));
  });

  test('some slots carry a caption from the pool and some carry none', () {
    const status = StreakStatus.completed;
    final messages = inOrder(
      buildStreakSchedule(status, random: Random(1)),
    ).map((entry) => entry.message).toList();

    expect(messages, contains(null));
    expect(messages.nonNulls, isNotEmpty);
    expect(status.messages, containsAll(messages.nonNulls.toSet()));
    expect(StreakTimedData(message: null).toJson(), isNot(contains('message')));
  });

  test('every Dash picture belongs to a pool and exists', () {
    final pooled = {
      for (final status in StreakStatus.values) ...status.mascots,
    };
    final onDisk = Directory('assets/dash')
        .listSync()
        .map((file) => 'assets/dash/${file.uri.pathSegments.last}')
        .where((path) => path.endsWith('.png'))
        .toSet();

    expect(pooled, onDisk);
  });

  test('currentStreakEntry picks the latest slot at or before now', () {
    final from = DateTime(2026, 3, 7, 9, 0);
    final schedule = buildStreakSchedule(
      StreakStatus.pending,
      from: from,
      slots: 4,
    );

    final current = currentStreakEntry(
      schedule,
      now: DateTime(2026, 3, 7, 9, 44, 59),
    );

    expect(current?.key, DateTime(2026, 3, 7, 9, 30));
    expect(
      nextSlotStart(DateTime(2026, 3, 7, 9, 44)),
      DateTime(2026, 3, 7, 9, 45),
    );
  });
}
