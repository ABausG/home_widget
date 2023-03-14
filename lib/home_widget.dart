import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget_callback_dispatcher.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

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
  /// Android Widgets will look for [qualifiedAndroidName] then [androidName] and then for [name]
  /// iOS Widgets will look for [iOSName] and then for [name]
  ///
  /// [qualifiedAndroidName] will use the name as is to find the WidgetProvider
  /// [androidName] must match the classname of the WidgetProvider, prefixed by the package name
  /// The name of the iOS Widget must match the kind specified when creating the Widget
  static Future<bool?> updateWidget({
    String? name,
    String? androidName,
    String? iOSName,
    String? qualifiedAndroidName,
  }) {
    return _channel.invokeMethod('updateWidget', {
      'name': name,
      'android': androidName,
      'ios': iOSName,
      'qualifiedAndroidName': qualifiedAndroidName,
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

  static Uri? _handleReceivedData(dynamic value) {
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

  /// Generate a screenshot based on the build context of a widget.
  /// This method renders the widget to an image (png) file with the provided filename.
  /// The png file is saved to the App Group container and the full path is returned as a string.
  /// The filename is optionally saved to UserDefaults using the provided key.
  static Future<String?> renderFlutterWidget(
    String appGroupId,
    BuildContext context,
    String filename,
    String? key,
  ) async {
    // Get the render object for the widget
    final RenderRepaintBoundary boundary =
        context.findRenderObject() as RenderRepaintBoundary;

    // Create a screenshot of the widget
    final image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio);
    final byteData = await image.toByteData(format: ImageByteFormat.png);

    // Save the screenshot to a file in the app group container
    final PathProviderFoundation provider = PathProviderFoundation();
    try {
      final String? directory = await provider.getContainerPath(
        appGroupIdentifier: appGroupId,
      );
      final String path = '$directory/$filename.png';
      final File file = File(path);
      await file.writeAsBytes(byteData!.buffer.asUint8List());

      // Save the filename to UserDefaults if a key was provided
      if (key != null) {
        _channel.invokeMethod<bool>('saveWidgetData', {
          'id': key,
          'data': '$filename.png',
        });
      }
      return path;
    } catch (e) {
      throw Exception('Failed to save screenshot to app group container: $e');
    }
  }
}
