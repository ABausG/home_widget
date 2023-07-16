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
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) {
    final now = DateTime.now();
    return Future.wait<bool?>([
      HomeWidget.saveWidgetData(
        'title',
        'meds awaiting',
      ),
      HomeWidget.saveWidgetData(
        'message',
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),
      HomeWidget.updateWidget(
        name: 'HomeWidgetExampleProvider',
        iOSName: 'HomeWidgetExample',
      ),
    ]).then((value) {
      return !value.contains(false);
    });
  });
}

/// Called when Doing Background Work initiated from Widget
@pragma("vm:entry-point")
void backgroundCallback(Uri? data) async {
  print(data);

  if (data?.host == 'titleclicked') {
    final greetings = [
      'take your meds',
      'meds pending',
      'medicine required',
    ];
    final selectedGreeting = greetings[Random().nextInt(greetings.length)];

    await HomeWidget.saveWidgetData<String>('title', selectedGreeting);
    await HomeWidget.updateWidget(
        name: 'HomeWidgetExampleProvider', iOSName: 'HomeWidgetExample');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(MaterialApp(home: MyApp()));
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
    HomeWidget.registerBackgroundCallback(backgroundCallback);
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

  Future _sendReminder() async {
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', 'morning meds due'),
        HomeWidget.saveWidgetData<String>('message', "take your abilify."),
        HomeWidget.renderFlutterWidget(
          Icon(
            Icons.access_time,
            size: 240,
          ),
          logicalSize: Size(240, 240),
          key: 'dashIcon',
        ),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future _sendForgot() async {
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', 'meds forgot.'),
        HomeWidget.saveWidgetData<String>('message', "meds at.."),
        HomeWidget.renderFlutterWidget(
          Icon(
            Icons.stop_circle,
            size: 240,
          ),
          logicalSize: Size(240, 240),
          key: 'dashIcon',
        ),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future _sendTaken() async {
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', 'meds taken.'),
        HomeWidget.saveWidgetData<String>('message', "took the meds at.."),
        HomeWidget.renderFlutterWidget(
          Icon(
            Icons.stop_circle,
            size: 240,
          ),
          logicalSize: Size(240, 240),
          key: 'dashIcon',
        ),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }
  Future _sendData() async {
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', _titleController.text),
        HomeWidget.saveWidgetData<String>('message', _messageController.text),
        HomeWidget.renderFlutterWidget(
          Icon(
            Icons.flutter_dash,
            size: 240,
          ),
          logicalSize: Size(240, 240),
          key: 'dashIcon',
        ),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future _updateWidget() async {
    try {
      return HomeWidget.updateWidget(
          name: 'HomeWidgetExampleProvider', iOSName: 'HomeWidgetExample');
    } on PlatformException catch (exception) {
      debugPrint('Error Updating Widget. $exception');
    }
  }

  Future _loadData() async {
    try {
      return Future.wait([
        HomeWidget.getWidgetData<String>('title', defaultValue: 'Take your meds')
            .then((value) => _titleController.text = value ?? 'Take your meds'),
        HomeWidget.getWidgetData<String>('message',
                defaultValue: 'I DID  I FORGOT')
            .then((value) => _messageController.text = value ?? 'I DID I FORGOT'),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Getting Data. $exception');
    }
  }

  Future<void> _sendReminderAndUpdate() async {
    await _sendReminder();
    await _updateWidget();
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  Future<void> _sendForgotAndUpdate() async {
    await _sendForgot();
    await _updateWidget();
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  Future<void> _sendTakenAndUpdate() async {
    await _sendTaken();
    await _updateWidget();
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
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
                title: Text('App started from HomeScreenWidget'),
                content: Text('Here is the URI: $uri'),
              ));
    }
  }

  void _startBackgroundUpdate() {
    Workmanager().registerPeriodicTask('1', 'widgetBackgroundUpdate',
        frequency: Duration(minutes: 15));
  }

  void _stopBackgroundUpdate() {
    Workmanager().cancelByUniqueName('1');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
   child: 
   
   Scaffold(
      appBar: null, /*AppBar(
        title: const Text('medwidget - 1 meds'),
      ),*/
      body: Center(
        child: Column(
          children: [
            Text("take your morning meds"),
            Row(children: [
            ElevatedButton(
              onPressed: _sendTakenAndUpdate,
              child: Text('taken'),
            ),
            SizedBox(width: 16),
            ElevatedButton(
              onPressed: _sendForgotAndUpdate,
              child: Text('forgot'),
            ),
            ElevatedButton(
  onPressed: _sendReminderAndUpdate
  /* () {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }*/,
  child: Text("close app")
)
            

            ],),
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
            ElevatedButton(
              onPressed: _checkForWidgetLaunch,
              child: Text('Check For Widget Launch'),
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
