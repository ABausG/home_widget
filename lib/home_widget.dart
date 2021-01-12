import 'dart:async';

import 'package:flutter/services.dart';

class HomeWidget {
  static const MethodChannel _channel = MethodChannel('home_widget');

  /// Save [data] to the Widget Storage
  ///
  /// Returns whether the data was saved or not
  static Future<bool> saveWidgetData<T>(String id, T data) {
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
  static Future<bool> updateWidget(
      {String name, String androidName, String iOSName}) {
    return _channel.invokeMethod('updateWidget', {
      'name': name,
      'android': androidName,
      'ios': iOSName,
    });
  }

  /// Returns Data saved with [saveWidgetData]
  /// [id] of Data Saved
  /// [defaultValue] value to use if no data was found
  static Future<T> getWidgetData<T>(String id, {T defaultValue}) {
    return _channel.invokeMethod<T>('getWidgetData', {
      'id': id,
      'defaultValue': defaultValue,
    });
  }

  /// Required on iOS to set the AppGroupId [groupId] in order to ensure
  /// communication between the App and the Widget Extension
  static Future<bool> setAppGroupId(String groupId) {
    return _channel.invokeMethod('setAppGroupId', {'groupId': groupId});
  }
}
