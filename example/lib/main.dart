import 'dart:async';
import 'dart:io';
//import 'dart:js_interop';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import 'database_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:duration/duration.dart';
import 'package:duration/locale.dart';

// alan sdk key - medwidget
//567aae2456b47dec4300cfee9f26137b2e956eca572e1d8b807a3e2338fdd0dc/stage

/// Used for Background Updates using Workmanager Plugin
@pragma("vm:entry-point")
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final now = DateTime.now();
    await DatabaseHelper().setConfig(
            'lastExecuteDate', DateTime.now().toString());
    final String? lastTakenDateTimeStr =
        await DatabaseHelper().getConfigValue('lastTakenDate');
    if (lastTakenDateTimeStr != null && lastTakenDateTimeStr.length>0) {
      await HomeWidget.saveWidgetData(
        'title',
        '${lastTakenDateTimeStr}',
      );
    }
    //final tit=await HomeWidget.getWidgetData<String>('title', defaultValue: 'wud u get ur meds');
    return Future.wait<bool?>([
      /*HomeWidget.saveWidgetData(
        'title',
        '${tit}',
      ),
      HomeWidget.saveWidgetData(
        'message',
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),*/
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

  //if (data?.host == 'titleclicked') {
    final greetings = [
      'take your meds',
      'meds pending',
      'medicine required',
    ];
    final selectedGreeting = greetings[Random().nextInt(greetings.length)];

    await HomeWidget.saveWidgetData<String>('title', selectedGreeting);
    await HomeWidget.updateWidget(
        name: 'HomeWidgetExampleProvider', iOSName: 'HomeWidgetExample');
  //}
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
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  TimeOfDay? _selectedTime;
  DateTime? _selectedDate;
  List<DateTime> _storedDates = [];
  DateTime? _lastStoredDateTime;
   DateTime? _lastTakenDateTime;
    DateTime? _lastForgottenDateTime;

  @override
  void initState() {
    super.initState();
    List<DateTime> _storedDates = [];
    _loadStoredDates();
    _initializeSelectedDate();
    _initializeSelectedTime();
    _initializeLastTakenDate();
    _initializeLastForgottenDateTime();
    HomeWidget.setAppGroupId('YOUR_GROUP_ID');
    HomeWidget.registerBackgroundCallback(backgroundCallback);
     initPlatformState();
  }
   
     Future<void> _initializeLastTakenDate() async {
    final String? lastTakenDateTimeStr =
        await DatabaseHelper().getConfigValue('lastTakenDate');
    if (lastTakenDateTimeStr != null && lastTakenDateTimeStr.length>0) {
      setState(() {
        _lastTakenDateTime = DateTime.parse(lastTakenDateTimeStr);
      });
    }
  }

   Future<void> _initializeSelectedTime() async {
    final String? ret =
        await DatabaseHelper().getConfigValue('startTime');
    if (ret != null) {
          final timeComponents = ret.split(':');
    if (timeComponents.length == 2) {
      final hour = int.tryParse(timeComponents[0]);
      final minute = int.tryParse(timeComponents[1]);
      if (hour != null && minute != null) {
        print(ret);
        setState(() {
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
        });
      }
    }
    }
  }

   Future<void> _initializeSelectedDate() async {
    final String? lastStoredDateTimeStr =
        await DatabaseHelper().getConfigValue('lastStoredDate');
    if (lastStoredDateTimeStr != null) {
      setState(() {
        _selectedDate = DateTime.parse(lastStoredDateTimeStr);
      });
    }
  }

void initPlatformState() async {
  var initializationSettingsAndroid = AndroidInitializationSettings('ic_launcher');
  var initializationSettingsIOS = null; // IOSInitializationSettings();
  var initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
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
       String selectedTimeString =
    '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
       await DatabaseHelper().setConfig(
            'startTime', selectedTimeString);
            print(selectedTimeString);
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
       await DatabaseHelper().setConfig(
            'lastStoredDate', pickedDate.toString());
    _loadStoredDates();
    }
  }


  Future _sendReminder() async {
    try {
      if(_lastTakenDateTime?.day!=DateTime.now().day) {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', 'meds due'),
        HomeWidget.saveWidgetData<String>('message', "last taken ${_lastTakenDateTime??''}\nlast forgotten ${_lastForgottenDateTime??''}\n"),
        HomeWidget.renderFlutterWidget(
          Icon(
            Icons.medication,
            size: 240,
          ),
          logicalSize: Size(240, 240),
          key: 'dashIcon',
        ),
      ]);

      } else {
    final nice = [
      'nice job',
      'way to go',
      'rock on',
      'keep it up',
      'good',
      'nice',
    ];
    final selectedNice = nice[Random().nextInt(nice.length)];
    final selectedNice2 = nice[Random().nextInt(nice.length)];
    final take = [
      'taken',
      '',
      'done',
      'got it',
      'conquered',
      'smashed it',
      'completed',
      'compliant',
      'took'
    ];
    final selectedTaken = take[Random().nextInt(take.length)];
    final around = [
      'around',
      'circa',
      'sometime',
    ];
    final selectedAround = around[Random().nextInt(around.length)];
      final d = _lastTakenDateTime?.difference(DateTime.now())??Duration.zero;
      final duration = printDuration(d);
      DateFormat dateFormat = DateFormat('h:mm a');
      String formattedTime = dateFormat.format(_lastTakenDateTime??DateTime.now());
      final forgottenStr = _lastForgottenDateTime!=null?"days since last forgot: ":"";
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', '$selectedNice'),
        HomeWidget.saveWidgetData<String>('message', "$selectedNice2\n$selectedTaken $formattedTime $selectedAround ${duration} ago\n$forgottenStr${_lastForgottenDateTime?.difference(DateTime.now()).inDays??''}\n"),
        HomeWidget.renderFlutterWidget(
          Icon(
            Icons.medical_information,
            size: 240,
          ),
          logicalSize: Size(240, 240),
          key: 'dashIcon',
        ),
      ]);

      }
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future _sendForgot() async {
    await DatabaseHelper().setConfig(
          'lastForgottenDate', DateTime.now().toString());
    final String? lastForgotten =
        await DatabaseHelper().getConfigValue('lastForgottenDate');
    try {
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', 'meds forgot. ${lastForgotten}'),
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
      await DatabaseHelper().setConfig(
          'lastTakenDate', DateTime.now().toString());
      return Future.wait([
        HomeWidget.saveWidgetData<String>('title', 'meds taken.'),
        HomeWidget.saveWidgetData<String>('message', "${DateTime.now().toIso8601String()}"),
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
            .then((value) => _titleController.text = value ?? ''),
        HomeWidget.getWidgetData<String>('message',
                defaultValue: 'I DID  I FORGOT')
            .then((value) => _messageController.text = value ?? ''),
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
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  void _checkForWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  void _launchedFromWidget(Uri? uri) {
    if (uri != null && uri.toString().length>0) {
      showDialog(
          context: context,
          builder: (buildContext) => AlertDialog(
                title: Text('App started from HomeScreenWidget'),
                content: Text('Here is the URI: $uri'),
              ));
    }
  }

  void _startBackgroundUpdate() {


    Workmanager().cancelByUniqueName('1');
    Workmanager().registerPeriodicTask('1', 'widgetBackgroundUpdate',
        frequency: Duration(minutes: 15),
        inputData: {
    'int': 1,
    'bool': true,
    'double': 1.0,
    'string': 'string',
    'array': [1, 2, 3],
    });
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  void _stopBackgroundUpdate() {
    Workmanager().cancelByUniqueName('1');
  }

    Future<void> _initializeLastForgottenDateTime() async {
    final String? lastForgottenDateTimeStr =
        await DatabaseHelper().getConfigValue('lastForgottenDate');
    if (lastForgottenDateTimeStr != null && lastForgottenDateTimeStr.length>0) {
      setState(() {
        _lastForgottenDateTime = DateTime.parse(lastForgottenDateTimeStr);
      });
    }
  }

  Future<void> _undoTakenAndForget() async {
    await DatabaseHelper().setConfig('lastForgottenDate', '');
    await DatabaseHelper().setConfig('lastTakenDate', '');
    setState(() {
    _lastForgottenDateTime=null;
    _lastTakenDateTime=null;
    });
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
            SizedBox(width: 16),
            ElevatedButton(
              onPressed: _undoTakenAndForget,
              child: Text('undo'),
            ),
            ElevatedButton(
  onPressed: _sendReminderAndUpdate,
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

                      Center(
            child: Text(
              _lastTakenDateTime != null
                  ? 'Last Taken: $_lastTakenDateTime'
                  : 'No taken date',
              style: TextStyle(fontSize: 20),
            ),
          ),
                    Center(
            child: Text(
              _lastForgottenDateTime != null
                  ? 'Last Forgotten: $_lastForgottenDateTime'
                  : 'No forgotten date',
              style: TextStyle(fontSize: 20),
            ),
          ),
Text(
              _lastStoredDateTime != null
                  ? 'Last Stored DateTime: $_lastStoredDateTime'
                  : 'No stored DateTime',
              style: TextStyle(fontSize: 20),
            ),
            /*
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
*/
Expanded(
            child: ListView.builder(
              itemCount: _storedDates.length,
              itemBuilder: (context, index) {
                final storedDateTime = _storedDates[index];
                final reversedIndex = _storedDates.length - index - 1;
                final reversedDateTime = _storedDates[reversedIndex];
                final formattedDateTime =
                  DateFormat('MMM dd, h:mm a').format(reversedDateTime);
                return ListTile(
                  title: Text(formattedDateTime),
                  //subtitle: Text('Count: ${_storedDates.length}'),
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
