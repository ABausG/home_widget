import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget_callback_dispatcher.dart';

/// A Flutter Plugin to simplify setting up and communicating with HomeScreenWidgets
class HomeWidget {
  static const MethodChannel _channel = MethodChannel('home_widget');
  static const EventChannel _eventChannel = EventChannel('home_widget/updates');

  /// Save [data] to the Widget Storage
  ///
  /// Returns whether the data was saved or not
  static Future<bool?> saveWidgetData<T>(String id, T? data) {
    return _channel.invokeMethod<bool>('saveWidgetData', {
      'id': id,
      'data': data,
    });
  }

  /// Updates the HomeScreen Widget
  ///
  /// Android Widgets will look for [androidName] and then for [name]
  /// iOS Widgets will look for [iOSName] and then for [name]
  ///
  /// The name of the Android Widget must match the classname of the WidgetProvider
  /// The name of the iOS Widget must match the kind specified when creating the Widget
  static Future<bool?> updateWidget({
    String? name,
    String? androidName,
    String? iOSName,
  }) {
    return _channel.invokeMethod('updateWidget', {
      'name': name,
      'android': androidName,
      'ios': iOSName,
    });
  }

  /// Returns Data saved with [saveWidgetData]
  /// [id] of Data Saved
  /// [defaultValue] value to use if no data was found
  static Future<T?> getWidgetData<T>(String id, {T? defaultValue}) {
    return _channel.invokeMethod<T>('getWidgetData', {
      'id': id,
      'defaultValue': defaultValue,
    });
  }

  /// Required on iOS to set the AppGroupId [groupId] in order to ensure
  /// communication between the App and the Widget Extension
  static Future<bool?> setAppGroupId(String groupId) {
    return _channel.invokeMethod('setAppGroupId', {'groupId': groupId});
  }

  /// Checks if the App was initially launched via the Widget
  static Future<Uri?> initiallyLaunchedFromHomeWidget() {
    return _channel
        .invokeMethod<String>('initiallyLaunchedFromHomeWidget')
        .then(_handleReceivedData);
  }

  /// Receives Updates if App Launched via the Widget
  static Stream<Uri?> get widgetClicked {
    return _eventChannel
        .receiveBroadcastStream()
        .map<Uri?>(_handleReceivedData);
  }

  static Uri? _handleReceivedData(dynamic? value) {
    if (value != null) {
      if (value is String) {
        try {
          return Uri.parse(value);
        } on FormatException {
          debugPrint('Received Data($value) is not parsebale into an Uri');
        }
      }
      return Uri();
    } else {
      return null;
    }
  }

  /// Register a callback that gets called when clicked on a specific View in a HomeWidget
  /// supported only on Android
  /// More Info on setting this up in the README
  static Future<bool?> registerBackgroundCallback(Function(Uri?) callback) {
    final args = <dynamic>[
      PluginUtilities.getCallbackHandle(callbackDispatcher)?.toRawHandle(),
      PluginUtilities.getCallbackHandle(callback)?.toRawHandle()
    ];
    return _channel.invokeMethod('registerBackgroundCallback', args);
  }
}
