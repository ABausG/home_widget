import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Counter App', home: const CounterPage());
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _counter = 0;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  final GlobalKey _scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeHomeWidget();
    _checkInitialLaunch();
    _listenToWidgetClicks();
  }

  Future<void> _initializeHomeWidget() async {
    await HomeWidget.setAppGroupId('group.es.antonborri.lockscreenWidgets');

    final savedCount = await HomeWidget.getWidgetData<int>(
      'counter',
      defaultValue: 0,
    );
    if (mounted) {
      setState(() {
        _counter = savedCount ?? 0;
      });
    }
  }

  Future<void> _checkInitialLaunch() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();

    _handleWidgetLaunch(uri);
  }

  void _listenToWidgetClicks() {
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetLaunch,
    );
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null) return;
    final countParam = uri.queryParameters['count'];
    if (countParam != null) {
      final count = int.tryParse(countParam);
      if (count != null && mounted) {
        final scaffoldContext = _scaffoldKey.currentContext;
        if (scaffoldContext != null) {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(
              content: Text('Widget clicked with count: $count'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _incrementCounter() async {
    setState(() {
      _counter++;
    });
    await _updateWidget();
  }

  Future<void> _updateWidget() async {
    await HomeWidget.saveWidgetData<int>('counter', _counter);
    await HomeWidget.updateWidget(iOSName: 'LockscreenWidget');
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Counter App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
