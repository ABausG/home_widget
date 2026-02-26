import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

/// A Flutter Plugin to simplify setting up and communicating with HomeScreenWidgets
class HomeWidget {
  static const MethodChannel _channel = MethodChannel('home_widget');
  static const EventChannel _eventChannel = EventChannel('home_widget/updates');

  static String? groupId;

  static Future<bool?> saveWidgetData<T>(String id, T? data) {
    return _channel.invokeMethod<bool>('saveWidgetData', {
      'id': id,
      'data': data,
    });
  }

  /// --- Updated to async + compute to avoid stutter on Android ---
  static Future<bool?> updateWidget({
    String? name,
    String? androidName,
    String? iOSName,
    String? qualifiedAndroidName,
  }) async {
    final Map<String, dynamic> args = await compute(_prepareUpdateArgs, {
      'name': name,
      'android': androidName,
      'ios': iOSName,
      'qualifiedAndroidName': qualifiedAndroidName,
    });

    return _channel.invokeMethod('updateWidget', args);
  }

  static Map<String, dynamic> _prepareUpdateArgs(Map<String, dynamic> input) {
    // Heavy computation can go here in future if needed
    return {
      'name': input['name'],
      'android': input['android'],
      'ios': input['ios'],
      'qualifiedAndroidName': input['qualifiedAndroidName'],
    };
  }

  static Future<bool?> isRequestPinWidgetSupported() {
    return _channel.invokeMethod('isRequestPinWidgetSupported');
  }

  static Future<void> requestPinWidget({
    String? name,
    String? androidName,
    String? qualifiedAndroidName,
  }) {
    return _channel.invokeMethod('requestPinWidget', {
      'name': name,
      'android': androidName,
      'qualifiedAndroidName': qualifiedAndroidName,
    });
  }

  static Future<T?> getWidgetData<T>(String id, {T? defaultValue}) {
    return _channel.invokeMethod<T>('getWidgetData', {
      'id': id,
      'defaultValue': defaultValue,
    });
  }

  static Future<bool?> setAppGroupId(String groupId) {
    HomeWidget.groupId = groupId;
    return _channel.invokeMethod('setAppGroupId', {'groupId': groupId});
  }

  static Future<Uri?> initiallyLaunchedFromHomeWidget() {
    return _channel
        .invokeMethod<String>('initiallyLaunchedFromHomeWidget')
        .then(_handleReceivedData);
  }

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
          debugPrint('Received Data($value) is not parsable into an Uri');
        }
      }
      return Uri();
    } else {
      return null;
    }
  }

  @Deprecated('Use `registerInteractivityCallback` instead')
  static Future<bool?> registerBackgroundCallback(
    FutureOr<void> Function(Uri?) callback,
  ) =>
      registerInteractivityCallback(callback);

  static Future<bool?> registerInteractivityCallback(
    FutureOr<void> Function(Uri?) callback,
  ) {
    final args = <dynamic>[
      ui.PluginUtilities.getCallbackHandle(callbackDispatcher)?.toRawHandle(),
      ui.PluginUtilities.getCallbackHandle(callback)?.toRawHandle(),
    ];
    return _channel.invokeMethod('registerBackgroundCallback', args);
  }

  static Future<String> renderFlutterWidget(
    Widget widget, {
    required String key,
    Size logicalSize = const Size(200, 200),
    double? pixelRatio,
  }) async {
    pixelRatio ??=
        PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;

    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    try {
      final RenderView renderView = RenderView(
        view: ui.PlatformDispatcher.instance.implicitView!,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: repaintBoundary,
        ),
        configuration: ViewConfiguration(
          logicalConstraints: BoxConstraints.tight(logicalSize),
          devicePixelRatio: pixelRatio,
        ),
      );

      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      final RenderObjectToWidgetElement<RenderBox> rootElement =
          RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [widget],
          ),
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final ui.Image image =
          await repaintBoundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      late final String? directory;
      if (Platform.isIOS) {
        final PathProviderFoundation provider = PathProviderFoundation();
        assert(
          HomeWidget.groupId != null,
          'No groupId defined. Did you forget to call `HomeWidget.setAppGroupId`',
        );
        directory = await provider.getContainerPath(
          appGroupIdentifier: HomeWidget.groupId!,
        );
      } else {
        directory = (await getApplicationSupportDirectory()).path;
      }

      final String path = '$directory/home_widget/$key.png';
      final File file = File(path);
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(byteData!.buffer.asUint8List());

      _channel.invokeMethod<bool>('saveWidgetData', {
        'id': key,
        'data': path,
      });

      return path;
    } catch (e) {
      throw Exception('Failed to render the widget: $e');
    }
  }

  static Future<List<HomeWidgetInfo>> getInstalledWidgets() async {
    final result =
        await _channel.invokeMethod('getInstalledWidgets') as List<dynamic>?;
    return result
            ?.map((widget) => (widget as Map).cast<String, dynamic>())
            .map(HomeWidgetInfo.fromMap)
            .toList() ??
        [];
  }
}
