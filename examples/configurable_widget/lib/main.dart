import 'dart:convert';
import 'dart:io';

import 'package:configurable_widget/android_configuration_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initPunctuations();
  runApp(const MainApp());
}

@pragma('vm:entry-point')
Future<void> configureMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isAndroid) {
    final configuredWidgetId =
        await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure();

    if (configuredWidgetId != null) {
      return runApp(
        MaterialApp(
          home: AndroidConfigurationPage(widgetId: configuredWidgetId),
        ),
      );
    }
  }
  return main();
}

const List<String> punctuations = [
  '!',
  '!!!',
  '.',
  '?',
  // Wave Emoji
  '\u{1F44B}',
];

/// Send a List of possible punctuations to the widget.
Future<void> _initPunctuations() async {
  // Needed for communication between the app and the widget
  await HomeWidget.setAppGroupId('group.es.antonborri.configurableWidget');
  // Save the punctuations to the widget
  await HomeWidget.saveWidgetData('punctuations', jsonEncode(punctuations));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

/// One pinned widget plus optional configuration map (JSON-serializable).
class _InstalledWidgetEntry {
  const _InstalledWidgetEntry({required this.info, this.configuration});

  final HomeWidgetInfo info;
  final Map<String, dynamic>? configuration;
}

class _MainAppState extends State<MainApp> {
  List<_InstalledWidgetEntry> _installedWidgets = [];

  @override
  void initState() {
    super.initState();
    _getInstalledWidgets();
  }

  /// Same storage keys as [AndroidConfigurationPage] (`name.{id}`, `punctuation.{id}`).
  static Future<Map<String, dynamic>> _androidConfigurationFromStorage(
    int widgetId,
  ) async {
    final name = await HomeWidget.getWidgetData<String>('name.$widgetId');
    final punctuation = await HomeWidget.getWidgetData<String>(
      'punctuation.$widgetId',
    );
    return <String, dynamic>{'name': name, 'punctuation': punctuation};
  }

  /// Loads pinned home screen widget instances (Android: per instance; iOS: per kind).
  Future<void> _getInstalledWidgets() async {
    try {
      final installedWidgets = await HomeWidget.getInstalledWidgets();
      final entries = <_InstalledWidgetEntry>[];
      for (final w in installedWidgets) {
        Map<String, dynamic>? configuration;
        if (Platform.isAndroid && w.androidWidgetId != null) {
          configuration = await _androidConfigurationFromStorage(
            w.androidWidgetId!,
          );
        } else if (Platform.isIOS && w.configuration != null) {
          configuration = Map<String, dynamic>.from(w.configuration!);
        }
        entries.add(
          _InstalledWidgetEntry(info: w, configuration: configuration),
        );
      }
      if (!mounted) return;
      setState(() {
        _installedWidgets = entries;
      });
    } on PlatformException catch (e) {
      debugPrint('getInstalledWidgets failed: $e');
    }
  }

  String _describeWidget(_InstalledWidgetEntry entry) {
    final widget = entry.info;
    if (Platform.isIOS) {
      final parts = <String>[
        if (widget.iOSFamily != null) 'family: ${widget.iOSFamily}',
        if (widget.iOSKind != null) 'kind: ${widget.iOSKind}',
      ];
      if (entry.configuration != null) {
        parts.add(jsonEncode(entry.configuration));
      }
      return parts.isEmpty ? widget.toString() : parts.join('\n');
    }
    final id = widget.androidWidgetId;
    final cls = widget.androidClassName ?? '?';
    final label = widget.androidLabel ?? '';
    final header = 'id=$id $cls${label.isNotEmpty ? ' ($label)' : ''}';
    if (entry.configuration == null) return header;
    return '$header\n${jsonEncode(entry.configuration)}';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _getInstalledWidgets,
            ),
          ],
        ),
        body: _installedWidgets.isEmpty
            ? const Center(
                child: Text(
                  'No pinned home screen widgets for this app.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _installedWidgets.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _describeWidget(_installedWidgets[index]),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
