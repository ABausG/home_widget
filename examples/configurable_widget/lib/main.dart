import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initPunctuations();
  runApp(const MainApp());
}

Future<void> _initPunctuations() async {
  await HomeWidget.setAppGroupId('group.es.antonborri.configurableWidget');
  final punctuations = [
    '!',
    '!!!',
    '.',
    '?',
    // Wave Emoji
    '\u{1F44B}',
  ];
  await HomeWidget.saveWidgetData(
    'punctuations',
    jsonEncode(punctuations),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  List<Map<String, dynamic>> _configurations = [];

  @override
  void initState() {
    super.initState();
    _getInstalledWidgets();
  }

  Future<void> _getInstalledWidgets() async {
    final installedWidgets = await HomeWidget.getInstalledWidgets();
    if (mounted) {
      setState(() {
        _configurations = installedWidgets
            .map((widget) => widget.configuration)
            .nonNulls
            .toList();
      });
    }
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
            )
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final configuration in _configurations)
              Text(
                configuration.toString(),
                textAlign: TextAlign.center,
              )
          ],
        ),
      ),
    );
  }
}
