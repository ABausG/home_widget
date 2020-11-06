import 'dart:async';

import 'package:flutter/services.dart';

class HomeWidget {
  static const MethodChannel _channel = MethodChannel('home_widget');

  static Future<bool> saveWidgetData<T>(String id, T data) async {
    return await _channel.invokeMethod<bool>('saveWidgetData', {
      'id': id,
      'data': data,
    });
  }

  static Future<bool> updateWidget({String name, String androidName, String iOSName}) async {
    return _channel.invokeMethod('updateWidget', {
      'name': name,
      'android': androidName,
      'ios': iOSName,
    });
  }

  static Future<T> getWidgetData<T>(String id, {T defaultValue}) {
    return _channel.invokeMethod<T>('getWidgetData', {
      'id': id,
      'defaultValue': defaultValue,
    });
  }

  static Future<bool> setAppGroupId(String groupId) {
    return _channel.invokeMethod('setAppGroupId', {'groupId' : groupId});
  }
}
