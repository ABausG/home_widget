import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:streak_widget/src/home_widget/streak.home_widget.dart';
import 'package:streak_widget/src/streak_status.dart';

/// How long one entry of the rotation stays on screen.
const Duration streakSlotDuration = Duration(minutes: 15);

/// [time] rounded down to the quarter hour it falls into.
DateTime floorToSlot(DateTime time) => DateTime(
  time.year,
  time.month,
  time.day,
  time.hour,
  time.minute - time.minute % 15,
);

/// The instant the slot after the one containing [from] becomes active.
DateTime nextSlotStart([DateTime? from]) =>
    floorToSlot(from ?? DateTime.now()).add(streakSlotDuration);

/// Builds the rotation the widget plays back on its own.
///
/// The first key is [from] (default now) floored to the quarter hour, so slot 0
/// is the entry that is active right away. Each following slot moves 15 minutes
/// ahead and draws a mascot from [status] at random: every picture of the pool
/// shows once before any repeats, and never twice in a row. About half the
/// slots also get a caption, drawn the same way; the others carry none.
///
/// Pass a seeded [random] for a reproducible rotation.
Map<DateTime, StreakTimedData> buildStreakSchedule(
  StreakStatus status, {
  DateTime? from,
  int slots = 24,
  Random? random,
}) {
  final rng = random ?? Random();
  final start = floorToSlot(from ?? DateTime.now());
  final mascots = _ShuffleBag(status.mascots, rng);
  final messages = _ShuffleBag(status.messages, rng);
  return {
    for (var i = 0; i < slots; i++)
      start.add(streakSlotDuration * i): StreakTimedData(
        mascot: AssetImage(mascots.next()),
        message: rng.nextBool() ? messages.next() : null,
      ),
  };
}

/// Hands out every item of a pool in random order before starting over, without
/// handing out the same item twice in a row.
class _ShuffleBag<T> {
  _ShuffleBag(this._pool, this._random);

  final List<T> _pool;
  final Random _random;
  final List<T> _remaining = [];
  T? _last;

  T next() {
    if (_remaining.isEmpty) {
      _remaining
        ..addAll(_pool)
        ..shuffle(_random);
      if (_remaining.length > 1 && _remaining.last == _last) {
        final first = _remaining.first;
        _remaining.first = _remaining.last;
        _remaining.last = first;
      }
    }
    return _last = _remaining.removeLast();
  }
}

/// The entry a widget would show at [now]: the greatest key at or before it.
MapEntry<DateTime, StreakTimedData>? currentStreakEntry(
  Map<DateTime, StreakTimedData> schedule, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  MapEntry<DateTime, StreakTimedData>? current;
  for (final entry in schedule.entries) {
    if (entry.key.isAfter(at)) continue;
    if (current == null || entry.key.isAfter(current.key)) current = entry;
  }
  return current;
}

/// The instant after which [schedule] has nothing left to show.
DateTime? streakScheduleEnd(Map<DateTime, StreakTimedData> schedule) {
  if (schedule.isEmpty) return null;
  return schedule.keys
      .reduce((a, b) => a.isAfter(b) ? a : b)
      .add(streakSlotDuration);
}
