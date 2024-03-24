import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

/// Used for Background Updates using Workmanager Plugin
@pragma("vm:entry-point")
void callbackDispatcher() async {
  Workmanager().executeTask((taskName, inputData) {
    final now = DateTime.now();
    return Future.wait<bool?>([
      HomeWidget.saveWidgetData(
        'title',
        'Updated from Background',
      ),
      HomeWidget.saveWidgetData(
        'message',
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),
    ]).then((value) async {
      Future.wait<bool?>([
        HomeWidget.updateWidget(
          name: 'HomeWidgetExampleProvider',
          iOSName: 'HomeWidgetExample',
        ),
        if (Platform.isAndroid)
          HomeWidget.updateWidget(
            qualifiedAndroidName:
                'es.antonborri.home_widget_example.glance.HomeWidgetReceiver',
          ),
      ]);
      return !value.contains(false);
    });
  });
}

/// Called when Doing Background Work initiated from Widget
@pragma("vm:entry-point")
Future<void> interactiveCallback(Uri? data) async {
  if (data?.host == 'titleclicked') {
    final greetings = [
      'Hello',
      'Hallo',
      'Bonjour',
      'Hola',
      'Ciao',
      '哈洛',
      '안녕하세요',
      'xin chào',
    ];
    final selectedGreeting = greetings[Random().nextInt(greetings.length)];
    await HomeWidget.setAppGroupId('YOUR_GROUP_ID');
    await HomeWidget.saveWidgetData<String>('title', selectedGreeting);
    await HomeWidget.updateWidget(
      name: 'HomeWidgetExampleProvider',
      iOSName: 'HomeWidgetExample',
    );
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(
        qualifiedAndroidName:
            'es.antonborri.home_widget_example.glance.HomeWidgetReceiver',
      );
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isRequestPinWidgetSupported = false;

  @override
  void initState() {
    super.initState();
    HomeWidget.setAppGroupId('YOUR_GROUP_ID');
    HomeWidget.registerInteractivityCallback(interactiveCallback);
    _checkPinability();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkForWidgetLaunch();
    HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future _sendData() async {
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', _titleController.text),
        HomeWidget.saveWidgetData<String>('message', _messageController.text),
        HomeWidget.renderFlutterWidget(
          const Icon(
            Icons.flutter_dash,
            size: 200,
          ),
          logicalSize: const Size(200, 200),
          key: 'dashIcon',
        ),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future _updateWidget() async {
    try {
      return Future.wait([
        HomeWidget.updateWidget(
          name: 'HomeWidgetExampleProvider',
          iOSName: 'HomeWidgetExample',
        ),
        if (Platform.isAndroid)
          HomeWidget.updateWidget(
            qualifiedAndroidName:
                'es.antonborri.home_widget_example.glance.HomeWidgetReceiver',
          ),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Updating Widget. $exception');
    }
  }

  Future _loadData() async {
    try {
      return Future.wait([
        HomeWidget.getWidgetData<String>('title', defaultValue: 'Default Title')
            .then((value) => _titleController.text = value ?? ''),
        HomeWidget.getWidgetData<String>(
          'message',
          defaultValue: 'Default Message',
        ).then((value) => _messageController.text = value ?? ''),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Getting Data. $exception');
    }
  }

  Future<void> _sendAndUpdate() async {
    await _sendData();
    await _updateWidget();
  }

  void _checkForWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  void _launchedFromWidget(Uri? uri) {
    if (uri != null) {
      showDialog(
        context: context,
        builder: (buildContext) => AlertDialog(
          title: const Text('App started from HomeScreenWidget'),
          content: Text('Here is the URI: $uri'),
        ),
      );
    }
  }

  void _startBackgroundUpdate() {
    Workmanager().registerPeriodicTask(
      '1',
      'widgetBackgroundUpdate',
      frequency: const Duration(minutes: 15),
    );
  }

  void _stopBackgroundUpdate() {
    Workmanager().cancelByUniqueName('1');
  }

  Future<void> _getInstalledWidgets() async {
    try {
      final widgets = await HomeWidget.getInstalledWidgets();
      if (!mounted) return;

      String getText(HomeWidgetInfo widget) {
        if (Platform.isIOS) {
          return 'iOS Family: ${widget.iOSFamily}, iOS Kind: ${widget.iOSKind}';
        } else {
          return 'Android Widget id: ${widget.androidWidgetId}, '
              'Android Class Name: ${widget.androidClassName}, '
              'Android Label: ${widget.androidLabel}';
        }
      }

      await showDialog(
        context: context,
        builder: (buildContext) => AlertDialog(
          title: const Text('Installed Widgets'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Number of widgets: ${widgets.length}'),
              const Divider(),
              for (final widget in widgets)
                Text(
                  getText(widget),
                ),
            ],
          ),
        ),
      );
    } on PlatformException catch (exception) {
      debugPrint('Error getting widget information. $exception');
    }
  }

  Future<void> _checkPinability() async {
    final isRequestPinWidgetSupported =
        await HomeWidget.isRequestPinWidgetSupported();
    if (mounted) {
      setState(() {
        _isRequestPinWidgetSupported = isRequestPinWidgetSupported ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeWidget Example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Title',
                ),
                controller: _titleController,
              ),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Body',
                ),
                controller: _messageController,
              ),
              ElevatedButton(
                onPressed: _sendAndUpdate,
                child: const Text('Send Data to Widget'),
              ),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Load Data'),
              ),
              ElevatedButton(
                onPressed: _checkForWidgetLaunch,
                child: const Text('Check For Widget Launch'),
              ),
              if (Platform.isAndroid)
                ElevatedButton(
                  onPressed: _startBackgroundUpdate,
                  child: const Text('Update in background'),
                ),
              if (Platform.isAndroid)
                ElevatedButton(
                  onPressed: _stopBackgroundUpdate,
                  child: const Text('Stop updating in background'),
                ),
              ElevatedButton(
                onPressed: _getInstalledWidgets,
                child: const Text('Get Installed Widgets'),
              ),
              if (_isRequestPinWidgetSupported)
                ElevatedButton(
                  onPressed: () => HomeWidget.requestPinWidget(
                    qualifiedAndroidName:
                        'es.antonborri.home_widget_example.glance.HomeWidgetReceiver',
                  ),
                  child: const Text('Pin Widget'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
