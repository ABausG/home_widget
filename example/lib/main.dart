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
  @override
  void initState() {
    super.initState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _sendTestData() async {

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      final result = await Future.wait([
        HomeWidget.saveWidgetData('title', 'Title'),
        HomeWidget.saveWidgetData('message', 'Message'),
      ]);

        HomeWidget.updateWidget('HomeWidgetExampleProvider');

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
          child: RaisedButton(
            onPressed: _sendTestData,
              child: Text('Home Widget Test')),
        ),
      ),
    );
  }
}
