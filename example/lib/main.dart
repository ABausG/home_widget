import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager.executeTask((taskName, inputData) {
    debugPrint("Native called background task: $taskName");

    final now = DateTime.now();
    return Future.wait<bool>([
      HomeWidget.saveWidgetData('title', 'Updated from Background'),
      HomeWidget.saveWidgetData('message',
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}'),
      HomeWidget.updateWidget(
          name: 'HomeWidgetExampleProvider', iOSName: 'HomeWidgetExample'),
    ]).then((value) {
      return !value.contains(false);
    });
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager.initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    HomeWidget.setAppGroupId('YOUR_GROUP_ID');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendData() async {
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', _titleController.text),
        HomeWidget.saveWidgetData<String>('message', _messageController.text),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future<void> _updateWidget() async {
    try {
      return HomeWidget.updateWidget(
          name: 'HomeWidgetExampleProvider', iOSName: 'HomeWidgetExample');
    } on PlatformException catch (exception) {
      debugPrint('Error Updating Widget. $exception');
    }
  }

  Future<void> _loadData() async {
    try {
      return Future.wait([
        HomeWidget.getWidgetData<String>('title', defaultValue: 'Default Title')
            .then((value) => _titleController.text = value),
        HomeWidget.getWidgetData<String>('message',
                defaultValue: 'Default Message')
            .then((value) => _messageController.text = value),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Getting Data. $exception');
    }
  }

  Future<void> _sendAndUpdate() async {
    await _sendData();
    await _updateWidget();
  }

  void _startBackgroundUpdate() {
    Workmanager.registerPeriodicTask('1', 'widgetBackgroundUpdate',
        frequency: Duration(minutes: 15));
  }

  void _stopBackgroundUpdate() {
    Workmanager.cancelByUniqueName('1');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('HomeWidget Example'),
        ),
        body: Center(
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Title',
                ),
                controller: _titleController,
              ),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Body',
                ),
                controller: _messageController,
              ),
              ElevatedButton(
                onPressed: _sendAndUpdate,
                child: Text('Send Data to Widget'),
              ),
              ElevatedButton(
                onPressed: _loadData,
                child: Text('Load Data'),
              ),
              if (Platform.isAndroid)
                ElevatedButton(
                  onPressed: _startBackgroundUpdate,
                  child: Text('Update in background'),
                ),
              if (Platform.isAndroid)
                ElevatedButton(
                  onPressed: _stopBackgroundUpdate,
                  child: Text('Stop updating in background'),
                )
            ],
          ),
        ),
      ),
    );
  }
}
