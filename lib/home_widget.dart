import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget_callback_dispatcher.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

/// A Flutter Plugin to simplify setting up and communicating with HomeScreenWidgets
class HomeWidget {
  static const MethodChannel _channel = MethodChannel('home_widget');
  static const EventChannel _eventChannel = EventChannel('home_widget/updates');

  /// The AppGroupId used for iOS Widgets
  static String? groupId;

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
    HomeWidget.groupId = groupId;
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
      ui.PluginUtilities.getCallbackHandle(callbackDispatcher)?.toRawHandle(),
      ui.PluginUtilities.getCallbackHandle(callback)?.toRawHandle()
    ];
    return _channel.invokeMethod('registerBackgroundCallback', args);
  }

  /// Generate a screenshot based on a given widget.
  /// This method renders the widget to an image (png) file with the provided filename.
  /// The png file is saved to the App Group container and the full path is returned as a string.
  /// The filename is saved to UserDefaults using the provided key.
  static Future renderFlutterWidget(
    Widget widget, {
    String fileName = 'screenshot',
    String key = 'filename',
    double? pixelRatio,
    Size? logicalSize,
  }) async {
    /// finding the widget in the current context by the key.
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();

    /// create a new pipeline owner
    final PipelineOwner pipelineOwner = PipelineOwner();

    /// create a new build owner
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    try {
      final RenderView renderView = RenderView(
        view: ui.PlatformDispatcher.instance.implicitView!,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: repaintBoundary,
        ),
        configuration: ViewConfiguration(
          size: logicalSize ?? Size.zero,
          devicePixelRatio: 1.0,
        ),
      );

      /// setting the rootNode to the renderview of the widget
      pipelineOwner.rootNode = renderView;

      /// setting the renderView to prepareInitialFrame
      renderView.prepareInitialFrame();

      /// setting the rootElement with the widget that has to be captured
      final RenderObjectToWidgetElement<RenderBox> rootElement =
          RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            // image is center aligned
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget,
            ],
          ),
        ),
      ).attachToRenderTree(buildOwner);

      ///adding the rootElement to the buildScope
      buildOwner.buildScope(rootElement);

      ///adding the rootElement to the buildScope
      buildOwner.buildScope(rootElement);

      /// finialize the buildOwner
      buildOwner.finalizeTree();

      ///Flush Layout
      pipelineOwner.flushLayout();

      /// Flush Compositing Bits
      pipelineOwner.flushCompositingBits();

      /// Flush paint
      pipelineOwner.flushPaint();

      final ui.Image image =
          await repaintBoundary.toImage(pixelRatio: pixelRatio ?? 1.0);

      /// The raw image is converted to byte data.
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      try {
        late final String? directory;
        try {
          // coverage:ignore-start
          if (Platform.environment.containsKey('FLUTTER_TEST')) {
            throw UnsupportedError(
              'Tests should always use default Path provider for easier mocking',
            );
          }
          final PathProviderFoundation provider = PathProviderFoundation();
          directory = await provider.getContainerPath(
            appGroupIdentifier: HomeWidget.groupId!,
          );
          // coverage:ignore-end
        } on UnsupportedError catch (_) {
          directory = (await getApplicationSupportDirectory()).path;
        }
        final String path = '$directory/home_widget/$fileName.png';
        final File file = File(path);
        if (!await file.exists()) {
          file.create(recursive: true);
        }
        await file.writeAsBytes(byteData!.buffer.asUint8List());

        // Save the filename to UserDefaults if a key was provided
        _channel.invokeMethod<bool>('saveWidgetData', {
          'id': key,
          'data': path,
        });

        return path;
      } catch (e) {
        throw Exception('Failed to save screenshot to app group container: $e');
      }
    } catch (e) {
      throw Exception('Failed to render the widget: $e');
    }
  }
}
