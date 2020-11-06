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
      return HomeWidget.updateWidget(name: 'HomeWidgetExampleProvider', iOSName: 'HomeWidgetExample');
    } on PlatformException catch (exception) {
      debugPrint('Error Updating Widget. $exception');
    }
  }

  Future<void> _loadData() async {
    try {
      return Future.wait([
        HomeWidget.getWidgetData<String>('title', defaultValue: 'Default Title').then((value) => _titleController.text = value),
        HomeWidget.getWidgetData<String>('message', defaultValue: 'Default Message').then((value) => _messageController.text = value),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Getting Data. $exception');
    }
  }

  Future<void> _sendAndUpdate() async {
    await _sendData();
    await _updateWidget();
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
              RaisedButton(onPressed: _sendAndUpdate, child: Text('Send Data to Widget')),
              RaisedButton(onPressed: _loadData, child: Text('Load Data')),
            ],
          ),
        ),
      ),
    );
  }
}
