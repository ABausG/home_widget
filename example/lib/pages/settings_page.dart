import 'package:flutter/material.dart';
import 'package:medwidget_app/database_helper.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSimpleMode = false;
  TimeOfDay? _selectedNightStartTime;
  TimeOfDay? _selectedMorningStartTime;

  @override
  void initState() {
    super.initState();
    List<DateTime> _storedDates = [];
    _initializeSelectedNightStartTime();
    _initializeSelectedMorningStartTime();
    _loadSimpleModeState();
  }
   Future<void> _initializeSelectedMorningStartTime() async {
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
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simple Mode (Image only):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
          ],
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
      selectedDateTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        pickedTime.hour,
        pickedTime.minute,
      );
       String selectedTimeString =
    '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
      await DatabaseHelper().setConfig('morningStartTime', selectedTimeString);
            print(selectedTimeString);
    }
  }

}
