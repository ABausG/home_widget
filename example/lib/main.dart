import 'dart:async';
import 'dart:io';
//import 'dart:js_interop';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/src/date_time.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

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
    final String? lastTakenDateTimeStr = await DatabaseHelper().getConfigValue('lastTakenDate');
    final now = DateTime.now();
    final bool simpleMode = await DatabaseHelper().getConfigValue('simpleMode')=='1';
    if (lastTakenDateTimeStr != null && lastTakenDateTimeStr.length>0) {
        DateTime lastTaken = DateTime.parse(lastTakenDateTimeStr);
        if(lastTaken.day==DateTime.now().day) {
      await HomeWidget.saveWidgetData('message','meds taken');
        } else {
      await HomeWidget.saveWidgetData('message','meds due');
        }
      /*await HomeWidget.saveWidgetData(
        'title',
        '${lastTakenDateTimeStr}',
      );*/
    } else {
      await HomeWidget.saveWidgetData('message','meds due');
    }
    final msg=await HomeWidget.getWidgetData<String>('message');
    return Future.wait<bool?>([
     // HomeWidget.saveWidgetData('message','$msg (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})',),
      HomeWidget.updateWidget( name: 'HomeWidgetExampleProvider', iOSName: 'HomeWidgetExample',),
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
    await HomeWidget.updateWidget(name: 'HomeWidgetExampleProvider', iOSName: 'HomeWidgetExample');
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
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSimpleMode = false;
  TimeOfDay? _selectedNightStartTime;
  TimeOfDay? _selectedMorningStartTime;
  DateTime? _selectedDate;
  List<DateTime> _storedDates = [];
  DateTime? _lastStoredDateTime;
   DateTime? _lastTakenDateTime;
    DateTime? _lastForgottenDateTime;
    String _message="msg test";
    String _title="title";
    String _iconpath="";

  @override
  void initState() {
    super.initState();
    List<DateTime> _storedDates = [];
    _loadStoredDates();
    _initializeSelectedNightStartTime();
    _initializeSelectedDate();
print('dude Start Time: $_selectedMorningStartTime');
    _initializeSelectedTime();
print('dude Start Time: $_selectedMorningStartTime');
    _initializeLastTakenDate();
    _initializeLastForgottenDateTime();
    _loadSimpleModeState();
    HomeWidget.setAppGroupId('YOUR_GROUP_ID');
    HomeWidget.registerBackgroundCallback(backgroundCallback);
     initPlatformState();
     initTimeZone();
print('dude Start Time: $_selectedMorningStartTime');
     Future.delayed(Duration(seconds: 10), () {
    scheduleMorningStartNotification();
  });
     Future.delayed(Duration(seconds: 1), () {
      _loadData();
    });
     //_loadData();
  }

  void initTimeZone() async {
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));
}


  Future<void> _loadSimpleModeState() async {
    final String? simpleModeValueStr = await DatabaseHelper().getConfigValue('simpleMode');
    if (simpleModeValueStr != null) {
      setState(() {
        _isSimpleMode = simpleModeValueStr == '1';
      });
    }
  }
   
     Future<void> _initializeSelectedNightStartTime() async {
    final String? ret = await DatabaseHelper().getConfigValue('nightStartTime');
    if (ret != null) {
      final timeComponents = ret.split(':');
      if (timeComponents.length == 2) {
        final hour = int.tryParse(timeComponents[0]);
        final minute = int.tryParse(timeComponents[1]);
        if (hour != null && minute != null) {
          setState(() {
            _selectedNightStartTime = TimeOfDay(hour: hour, minute: minute);
          });
        }
      }
    }
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
        await DatabaseHelper().getConfigValue('morningStartTime');
    if (ret != null) {
          final timeComponents = ret.split(':');
    if (timeComponents.length == 2) {
      final hour = int.tryParse(timeComponents[0]);
      final minute = int.tryParse(timeComponents[1]);
      if (hour != null && minute != null) {
        print(ret);
         _selectedMorningStartTime = TimeOfDay(hour: hour, minute: minute);
        setState(() {
          _selectedMorningStartTime = TimeOfDay(hour: hour, minute: minute);
        });
      }
    }
    } else {
      print("db failed");
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

Future<void> scheduleMorningStartNotification() async {
  TimeOfDay tmp = _selectedMorningStartTime?? TimeOfDay(hour: 8, minute: 0);
print('Morning Start Time: $_selectedMorningStartTime');
  var androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'morning_start_channel_id',
    'Morning Start Channel',
    importance: Importance.max,
    priority: Priority.high,
  );
 // var iOSPlatformChannelSpecifics = IOSNotificationDetails();
  var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics, iOS: null);

  var now = DateTime.now();
  var morningStartTime = DateTime(now.year, now.month, now.day, tmp.hour, tmp.minute);
  // Check if the morning start time has already passed for today; if yes, schedule it for the next day
  if (morningStartTime.isBefore(now)) {
    morningStartTime = morningStartTime.add(Duration(days: 1));
  }
print('Morning Start Time: $morningStartTime');
  // Schedule the notification
  await flutterLocalNotificationsPlugin.zonedSchedule(
    0, // Unique ID for the notification
    'Good morning!',
    'Time to start your day!',
    TZDateTime.from(morningStartTime, tz.local),
    platformChannelSpecifics,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
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

  Future<void> _showMorningTimePicker() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null && pickedTime != _selectedMorningStartTime) {
      setState(() {
        _selectedMorningStartTime = pickedTime;
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
      await DatabaseHelper().setConfig('morningStartTime', selectedTimeString);
            print(selectedTimeString);
      scheduleMorningStartNotification();
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

String generateMessage()
{
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
      'about',
    ];
    final selectedAround = around[Random().nextInt(around.length)];
      final d =DateTime.now().difference(_lastTakenDateTime??DateTime.now());
      final duration = printDuration(d);
      DateFormat dateFormat = DateFormat('h:mm a');
      String formattedTime = dateFormat.format(_lastTakenDateTime??DateTime.now());
      final forgottenStr = _lastForgottenDateTime!=null?"days since last forgot: ":"";
      final widgetUpdateStr = "widget updated ${dateFormat.format(DateTime.now())}";
      return "$selectedNice2\n$selectedTaken $formattedTime $selectedAround ${duration} ago\n$forgottenStr${_lastForgottenDateTime?.difference(DateTime.now()).inDays??''}\n$widgetUpdateStr";
}

  Future _sendReminder() async {
    try {
      if(_lastTakenDateTime?.day!=DateTime.now().day) {
      return Future.wait([
        _isSimpleMode?HomeWidget.saveWidgetData<String>('title', ''):HomeWidget.saveWidgetData<String>('title', 'meds due'),
        _isSimpleMode?HomeWidget.saveWidgetData<String>('message', ''):HomeWidget.saveWidgetData<String>('message', ""),//"last taken ${_lastTakenDateTime??''}\nlast forgotten ${_lastForgottenDateTime??''}\n"),
        HomeWidget.renderFlutterWidget( Icon(Icons.medication, size: 100,), logicalSize: Size(100, 100), key: 'dashIcon',),
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
      String msg = generateMessage();
      return Future.wait([
        _isSimpleMode?HomeWidget.saveWidgetData<String>('title', ''):HomeWidget.saveWidgetData<String>('title', '$selectedNice'),
        _isSimpleMode?HomeWidget.saveWidgetData<String>('message', ''):HomeWidget.saveWidgetData<String>('message', msg), //"$selectedNice2\n$selectedTaken $formattedTime $selectedAround ${duration} ago\n$forgottenStr${_lastForgottenDateTime?.difference(DateTime.now()).inDays??''}\n$widgetUpdateStr"),
        HomeWidget.renderFlutterWidget(Icon(Icons.check, size: 200,), logicalSize: Size(200, 200), key: 'dashIcon',),
      ]);

      }
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future _sendForgot() async {
    await DatabaseHelper().setConfig(
          'lastForgottenDate', DateTime.now().toString());
    try {
      String msg = generateMessage();
      return Future.wait([
        _isSimpleMode?HomeWidget.saveWidgetData<String>('title', ''):HomeWidget.saveWidgetData<String>('title', 'meds forgotten'),
        _isSimpleMode?HomeWidget.saveWidgetData<String>('message', ''):HomeWidget.saveWidgetData<String>('message', msg),
        HomeWidget.renderFlutterWidget( Icon( Icons.alarm_sharp, size: 200,), logicalSize: Size(200, 200), key: 'dashIcon',),
      ]);
    } on PlatformException catch (exception) {
      debugPrint('Error Sending Data. $exception');
    }
  }

  Future _sendTaken() async {
    try {
      await DatabaseHelper().setConfig('lastTakenDate', DateTime.now().toString());
      String msg = generateMessage();
      return Future.wait([
        _isSimpleMode?HomeWidget.saveWidgetData<String>('title', ''): HomeWidget.saveWidgetData<String>('title', 'meds taken.'),
        _isSimpleMode?HomeWidget.saveWidgetData<String>('message', ''):HomeWidget.saveWidgetData<String>('message', msg), //"${DateTime.now().toIso8601String()}"),
        HomeWidget.renderFlutterWidget( Icon( Icons.check, size: 200,), logicalSize: Size(200, 200), key: 'dashIcon',),
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
            size: 200,
          ),
          logicalSize: Size(200, 200),
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
        HomeWidget.getWidgetData<String>('title', defaultValue: '')
            .then((value) => _title=_titleController.text = value ?? '').whenComplete(() => setState((){})),
        HomeWidget.getWidgetData<String>('message', defaultValue: '')
            .then((value) => _message=_messageController.text = value ?? '').whenComplete(() => setState((){})),
        HomeWidget.getWidgetData<String>('dashIcon')
            .then((value) =>  _iconpath=value??"" ).whenComplete(() => setState((){})),
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
  if (uri?.path.contains('meds%%20due')==true) {
      showDialog(
          context: context,
          builder: (buildContext) => AlertDialog(
                title: Text('Meds due'),
                content: Text('Here is the URI: $uri'),
              ));

  } else {
      showDialog(
          context: context,
          builder: (buildContext) => AlertDialog(
                title: Text('App started from HomeScreenWidget'),
                content: Text('Here is the URI: $uri\n ${uri.path}'),
              ));
  }
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
      body:
         Center(
        child: Column(
          children: [
            Text(_title,style: TextStyle(fontSize: 34),),
            _iconpath.length>0?Image.file(File(_iconpath)):Container(),
            Text(_message),
            Row(children: [
            SizedBox(width: 16),
            SizedBox(width: 16),
            SizedBox(width: 16),
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
            SizedBox(width: 16),
            ElevatedButton(
  onPressed: _sendReminderAndUpdate,
  child: Text("close")
)
            

            ],),

           Switch(
    value: _isSimpleMode, // Step 1: Update the variable name in the widget
    onChanged: (value) {
      setState(() {
        _isSimpleMode = value; // Step 1: Update the variable name in the callback
      });
      int simpleModeValue = _isSimpleMode ? 1 : 0;

      // Save the simple mode value to the database
      DatabaseHelper().setConfig('simpleMode', simpleModeValue.toString());
    },
  ),
            ElevatedButton(
          onPressed: () {
            _showMorningTimePicker();
          },
          child: 
          Text(_selectedMorningStartTime != null
              ? 'Morning Start Time: ${_selectedMorningStartTime!.format(context)}'
              : 'Morning Start Time'),
        ),
          ElevatedButton(
    onPressed: _showNightStartTimePicker,
    child: Text(_selectedNightStartTime != null
        ? 'Night Start Time: ${_selectedNightStartTime!.format(context)}'
        : 'Night Start Time'),
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

  Future<void> _showNightStartTimePicker() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedNightStartTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null && pickedTime != _selectedNightStartTime) {
      setState(() {
        _selectedNightStartTime = pickedTime;
      });

      // Convert the selected time to a string representation
      String selectedNightStartTimeString =
          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';

      // Save the selected time to the database
      await DatabaseHelper().setConfig('nightStartTime', selectedNightStartTimeString);
    }
  }
}

