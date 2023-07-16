import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'database_helper.dart';
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
  TimeOfDay? _selectedTime;
  DateTime? _selectedDate;
  List<DateTime> _storedDates = [];
  DateTime? _lastStoredDateTime;

  @override
  void initState() {
    super.initState();
    List<DateTime> _storedDates = [];
    _loadStoredDates();
    HomeWidget.setAppGroupId('YOUR_GROUP_ID');
    HomeWidget.registerBackgroundCallback(backgroundCallback);
  }

  Future<void> _loadStoredDates() async {
    final List<DateTime> storedDates = await DatabaseHelper().getStoredDates();
    setState(() {
      _storedDates = storedDates;
      _lastStoredDateTime = _storedDates.isNotEmpty ? _storedDates.last : null;
    });
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

  Future<void> _showTimePicker() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
          DateTime selectedDateTime;
    if (_selectedDate != null) {
      selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    } else {
      selectedDateTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        pickedTime.hour,
        pickedTime.minute,
      );
    }
       DatabaseHelper().insertDateTime(selectedDateTime);
    _loadStoredDates();
    }
  }

Future<void> _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
      DatabaseHelper().insertDateTime(pickedDate);
    _loadStoredDates();
    }
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
            ElevatedButton(
          onPressed: () {
            _showTimePicker();
          },
          child: 
          Text(_selectedTime != null
              ? 'Selected Time: ${_selectedTime!.format(context)}'
              : 'Select Time'), // Update button text
        ),
        ElevatedButton(
          onPressed: () {
            _showDatePicker();
          },
          child: Text(_selectedDate != null
              ? 'Selected Date: ${_selectedDate!.toString()}'
              : 'Select Date'), // Update button text
        ),

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
              ),

Text(
              _lastStoredDateTime != null
                  ? 'Last Stored DateTime: $_lastStoredDateTime'
                  : 'No stored DateTime',
              style: TextStyle(fontSize: 20),
            ),
Expanded(
          child: FutureBuilder<DateTime?>(
            future: DatabaseHelper().getLastStoredDateTime(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }
              final lastDateTime = snapshot.data;
              return Center(
                child: Text(
                  lastDateTime != null
                      ? 'Last Stored DateTime: $lastDateTime'
                      : 'No stored DateTime',
                  style: TextStyle(fontSize: 20),
                ),
              );
            },
          ),
        ),

Expanded(
            child: ListView.builder(
              itemCount: _storedDates.length,
              itemBuilder: (context, index) {
                final storedDateTime = _storedDates[index];
                final reversedIndex = _storedDates.length - index - 1;
                final reversedDateTime = _storedDates[reversedIndex];
                return ListTile(
                  title: Text(reversedDateTime.toString()),
                );
              },
            ),
),


/*
              Expanded(
            child: 
ListView.builder(
        itemCount: _storedDates.length,
        itemBuilder: (context, index) {
          final date = _storedDates[index];
          return ListTile(
            title: Text(date.toString()),
          );
        },
),
              ),
*/

          ],
        ),
      ),
    ),
    );
  }
}
