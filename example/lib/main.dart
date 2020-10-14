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
    HomeWidget.setAppGroupId('YOUR_APP_GROUP_ID');
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
        HomeWidget.saveWidgetData('title', _titleController.text),
        HomeWidget.saveWidgetData('message', _messageController.text),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future<void> _updateWidget() async {
    try {
      return HomeWidget.updateWidget('HomeWidgetExampleProvider');
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
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
            ],
          ),
        ),
      ),
    );
  }
}
