import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

void main() {
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
    HomeWidget.setAppGroupId('group.de.zweidenker.homeWidgetExample');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendTestData() async {
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', _titleController.text),
        HomeWidget.saveWidgetData<String>('message', _messageController.text),
        HomeWidget.saveWidgetData<int>('number', 3),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future<void> _updateWidget() async {
    try {
      return HomeWidget.updateWidget('HomeWidgetExampleProvider');
    } on PlatformException catch (exception) {
      debugPrint('Error Updating Widget. $exception');
    }
  }

  Future<void> _logData() async {
    try {
      return Future.wait([
        HomeWidget.getWidgetData<String>('title', defaultValue: 'Default Title').then((value) => debugPrint('Title $value')),
        HomeWidget.getWidgetData<String>('message', defaultValue: 'Default Message').then((value) => debugPrint('Message $value')),
        HomeWidget.getWidgetData<int>('number',).then((value) => debugPrint('Number $value')),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Getting Data. $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: [
              TextField(
                controller: _titleController,
              ),
              TextField(
                controller: _messageController,
              ),
              RaisedButton(onPressed: _sendTestData, child: Text('Save Data')),
              RaisedButton(
                  onPressed: _updateWidget, child: Text('Update Data')),
              RaisedButton(
                  onPressed: _logData, child: Text('Get Data')),
            ],
          ),
        ),
      ),
    );
  }
}
