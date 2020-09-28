
import 'dart:async';

import 'package:flutter/services.dart';

class HomeWidget {
  static const MethodChannel _channel =
      const MethodChannel('home_widget');

  static Future<bool> saveWidgetData(String id, String data) async {
    final bool success = await _channel.invokeMethod<bool>('saveWidgetData', {'id':id,'data':data,});
    return success;
  }

  static Future<bool> updateWidget(String name) async {
    final bool success = await _channel.invokeMethod('updateWidget', {'name':name,});
    return success;
  }

  static Future<String> getWidgetData(String id, {String defaultValue}) async {
    final String data = await _channel.invokeMethod<String>('getWidgetData', {'id':id,'defaultValue':defaultValue,});
    return data;
  }
}
