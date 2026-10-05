import 'dart:async';

import 'package:flutter/material.dart';
import 'package:streak_widget/src/home_widget/streak.home_widget.dart';
import 'package:streak_widget/src/streak_schedule.dart';
import 'package:streak_widget/src/streak_status.dart';

void main() {
  runApp(const DasholingoApp());
}

const Color _duoGreen = Color(0xFF58CC02);

class DasholingoApp extends StatelessWidget {
  const DasholingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dasholingo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _duoGreen)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _duoGreen,
          brightness: Brightness.dark,
        ),
      ),
      home: const StreakPage(),
    );
  }
}

class StreakPage extends StatefulWidget {
  const StreakPage({super.key});

  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> with WidgetsBindingObserver {
  int _streak = 0;
  StreakStatus _status = StreakStatus.pending;
  Map<DateTime, StreakTimedData> _schedule = const {};
  bool _savingSchedule = false;
  bool _restored = false;
  bool _canPin = false;
  Timer? _slotTimer;
  Timer? _streakDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule = buildStreakSchedule(_status);
    _armSlotTimer();
    unawaited(_restore());
    unawaited(_checkPinSupport());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slotTimer?.cancel();
    _streakDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _restored) {
      unawaited(_saveSchedule(_status));
    }
  }

  Future<void> _restore() async {
    final data = await StreakHomeWidget.getData();
    if (!mounted) return;
    final status = data.frozen == true
        ? StreakStatus.frozen
        : data.completed == true
        ? StreakStatus.completed
        : StreakStatus.pending;
    setState(() => _streak = data.streak ?? 0);
    await _saveSchedule(status);
    _restored = true;
  }

  Future<void> _checkPinSupport() async {
    final supported = await StreakHomeWidget.isRequestPinWidgetSupported();
    if (!mounted) return;
    setState(() => _canPin = supported);
  }

  /// Writes the flags and a fresh 24 slot rotation, then refreshes the widget.
  Future<void> _saveSchedule(StreakStatus status) async {
    if (_savingSchedule) return;
    final schedule = buildStreakSchedule(status);
    setState(() {
      _status = status;
      _schedule = schedule;
      _savingSchedule = true;
    });
    try {
      await StreakHomeWidget.saveData(
        completed: status == StreakStatus.completed,
        frozen: status == StreakStatus.frozen,
        timedData: schedule,
      );
      await StreakHomeWidget.updateWidget();
    } catch (error) {
      _report('Could not save the rotation: $error');
    } finally {
      if (mounted) setState(() => _savingSchedule = false);
    }
    _armSlotTimer();
  }

  void _setStreak(int value) {
    final streak = value.clamp(0, 365);
    if (streak == _streak) return;
    setState(() => _streak = streak);
    _streakDebounce?.cancel();
    _streakDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveStreak(streak));
    });
  }

  Future<void> _saveStreak(int streak) async {
    try {
      await StreakHomeWidget.saveData(streak: streak);
      await StreakHomeWidget.updateWidget();
    } catch (error) {
      _report('Could not save the streak: $error');
    }
  }

  Future<void> _refreshWidget() async {
    try {
      await StreakHomeWidget.updateWidget();
      _report('Widget refreshed');
    } catch (error) {
      _report('Could not refresh the widget: $error');
    }
  }

  Future<void> _pinWidget() async {
    try {
      await StreakHomeWidget.requestPinWidget();
    } catch (error) {
      _report('Could not ask the launcher: $error');
    }
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Re-renders the preview when the widget on the home screen would flip.
  void _armSlotTimer() {
    _slotTimer?.cancel();
    final now = DateTime.now();
    _slotTimer = Timer(nextSlotStart(now).difference(now), () {
      if (!mounted) return;
      setState(() {});
      _armSlotTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = currentStreakEntry(_schedule);
    final end = streakScheduleEnd(_schedule);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dasholingo'),
        bottom: _savingSchedule
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: _PreviewTile(
              streak: _streak,
              status: _status,
              entry: entry?.value,
            ),
          ),
          const SizedBox(height: 24),
          _StreakControl(streak: _streak, onChanged: _setStreak),
          const SizedBox(height: 24),
          _StatusControl(
            status: _status,
            enabled: !_savingSchedule,
            onChanged: (status) => unawaited(_saveSchedule(status)),
          ),
          const SizedBox(height: 24),
          _Explainer(nextSlot: nextSlotStart(), scheduleEnd: end),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => unawaited(_refreshWidget()),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh widget'),
              ),
              if (_canPin)
                FilledButton.icon(
                  onPressed: () => unawaited(_pinWidget()),
                  icon: const Icon(Icons.add_to_home_screen),
                  label: const Text('Add to home screen'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mirrors what the home screen shows right now.
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.streak,
    required this.status,
    required this.entry,
  });

  final int streak;
  final StreakStatus status;
  final StreakTimedData? entry;

  @override
  Widget build(BuildContext context) {
    final mascot = entry?.mascot;
    final message = entry?.message;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 170,
        height: 170,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mascot != null) Image(image: mascot, fit: BoxFit.cover),
            Align(
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _Pill(
                  padding: const EdgeInsetsDirectional.only(start: 6, end: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: [
                      Icon(status.icon, size: 24, color: status.color),
                      Text(
                        '$streak',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          color: status.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (message != null)
              Align(
                alignment: AlignmentDirectional.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _Pill(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xF2FFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.padding, required this.child});

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x73000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StreakControl extends StatelessWidget {
  const _StreakControl({required this.streak, required this.onChanged});

  final int streak;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Streak', style: theme.textTheme.titleMedium),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: streak == 0 ? null : () => onChanged(streak - 1),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Center(
                child: Text('$streak', style: theme.textTheme.headlineMedium),
              ),
            ),
            IconButton.filledTonal(
              onPressed: streak == 365 ? null : () => onChanged(streak + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Slider(
          value: streak.toDouble(),
          max: 365,
          divisions: 365,
          label: '$streak',
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
    );
  }
}

class _StatusControl extends StatelessWidget {
  const _StatusControl({
    required this.status,
    required this.enabled,
    required this.onChanged,
  });

  final StreakStatus status;
  final bool enabled;
  final ValueChanged<StreakStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<StreakStatus>(
          showSelectedIcon: false,
          segments: [
            for (final value in StreakStatus.values)
              ButtonSegment<StreakStatus>(
                value: value,
                label: Text(value.label, maxLines: 1, softWrap: false),
              ),
          ],
          selected: {status},
          onSelectionChanged: enabled
              ? (selection) => onChanged(selection.first)
              : null,
        ),
      ],
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer({required this.nextSlot, required this.scheduleEnd});

  final DateTime nextSlot;
  final DateTime? scheduleEnd;

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = scheduleEnd;
    final until = end == null
        ? ''
        : ', saved rotation runs until ${_time(end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How the rotation works', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Picking a status saves 24 timed entries, one per quarter hour, each '
          'with a random picture and, about half the time, a caption. Dash '
          'swaps them on her own, with Dasholingo closed.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Next change at ${_time(nextSlot)}$until.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
