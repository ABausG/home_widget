import 'dart:async';

import 'package:flutter/services.dart';

class HomeWidget {
  static const MethodChannel _channel = const MethodChannel('home_widget');

  static Future<bool> saveWidgetData(String id, String data) async {
    return await _channel.invokeMethod<bool>('saveWidgetData', {
      'id': id,
      'data': data,
    });
  }

  static Future<bool> updateWidget(String name) async {
    return _channel.invokeMethod('updateWidget', {
      'name': name,
    });
  }

  static Future<String> getWidgetData(String id, {String defaultValue}) {
    return _channel.invokeMethod<String>('getWidgetData', {
      'id': id,
      'defaultValue': defaultValue,
    });
  }

  static Future<bool> setAppGroupId(String groupId) {
    return _channel.invokeMethod('setAppGroupId', {'groupId' : groupId});
  }
}
