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

  /// The AppGroupId used for iOS Widgets
  static String? groupId;

  /// Save [data] to the Widget Storage
  ///
  /// Returns whether the data was saved or not
  static Future<bool?> saveWidgetData<T>(
    String id,
    T? data, {
    bool deleteFile = true,
    String? appGroupId,
  }) async {
    if (deleteFile && data == null) {
      final raw = await getWidgetData<dynamic>(id, appGroupId: appGroupId);
      if (raw is String && _isHomeWidgetManagedFilePath(raw)) {
        final file = File(raw);
        if (await file.exists()) {
          try {
            await file.delete();
          } on FileSystemException {
            // Keep clearing widget data even when file cleanup fails.
          }
        }
      }
    }

    final arguments = <String, dynamic>{
      'id': id,
      'data': data,
      if (appGroupId != null) 'appGroupId': appGroupId,
    };
    return _channel.invokeMethod<bool>('saveWidgetData', arguments);
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

  /// Determines whether pinning HomeScreen Widget is supported.
  static Future<bool?> isRequestPinWidgetSupported() {
    return _channel.invokeMethod('isRequestPinWidgetSupported');
  }

  /// Requests to Pin (Add) the HomeScreenWidget to the User's Home Screen
  ///
  /// This is supported only on some Android Launchers and only with Android API 26+
  ///
  /// Android Widgets will look for [qualifiedAndroidName] then [androidName] and then for [name]
  /// There is no iOS alternative.
  ///
  /// [qualifiedAndroidName] will use the name as is to find the WidgetProvider.
  /// [androidName] must match the classname of the WidgetProvider, prefixed by the package name.
  static Future<void> requestPinWidget({
    String? name,
    String? androidName,
    // String? iOSName,
    String? qualifiedAndroidName,
  }) {
    return _channel.invokeMethod('requestPinWidget', {
      'name': name,
      'android': androidName,
      // 'ios': iOSName,
      'qualifiedAndroidName': qualifiedAndroidName,
    });
  }

  /// Returns Data saved with [saveWidgetData]
  /// [id] of Data Saved
  /// [defaultValue] value to use if no data was found
  static Future<T?> getWidgetData<T>(
    String id, {
    T? defaultValue,
    String? appGroupId,
  }) {
    final arguments = <String, dynamic>{
      'id': id,
      'defaultValue': defaultValue,
      if (appGroupId != null) 'appGroupId': appGroupId,
    };
    return _channel.invokeMethod<T>('getWidgetData', arguments);
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

  /// Checks if the App was initially launched via the Widget configure action on Android.
  /// Only works on Android. Ensure to call `HomeWidget.finishHomeWidgetConfigure` once you want to complete the configuration
  static Future<String?> initiallyLaunchedFromHomeWidgetConfigure() {
    return _channel
        .invokeMethod<String>('initiallyLaunchedFromHomeWidgetConfigure');
  }

  /// Ends the Widget configure action on Android.
  /// This should be called when finishing up a Widget Configuration that was initiated based on `HomeWidget.initiallyLaunchedFromHomeWidgetConfigure`
  static Future<void> finishHomeWidgetConfigure() {
    return _channel.invokeMethod<void>('finishHomeWidgetConfigure');
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
          debugPrint('Received Data($value) is not parsable into an Uri');
        }
      }
      return Uri();
    } else {
      return null;
    }
  }

  /// Register a callback that gets called when clicked on a specific View in a HomeWidget
  /// This enables having Interactive Widgets that can call Dart Code
  /// More Info on setting this up in the README
  @Deprecated('Use `registerInteractivityCallback` instead')
  static Future<bool?> registerBackgroundCallback(
    FutureOr<void> Function(Uri?) callback,
  ) =>
      registerInteractivityCallback(callback);

  /// Register a callback that gets called when clicked on a specific View in a HomeWidget
  /// This enables having Interactive Widgets that can call Dart Code
  /// More Info on setting this up in the README
  static Future<bool?> registerInteractivityCallback(
    FutureOr<void> Function(Uri?) callback,
  ) {
    final args = <dynamic>[
      ui.PluginUtilities.getCallbackHandle(callbackDispatcher)?.toRawHandle(),
      ui.PluginUtilities.getCallbackHandle(callback)?.toRawHandle(),
    ];
    return _channel.invokeMethod('registerBackgroundCallback', args);
  }

  /// Paths written by [saveFile], [saveImage], and [renderFlutterWidget] live
  /// under a `home_widget` directory; only those files are removed when
  /// clearing a key with [saveWidgetData].
  static bool _isHomeWidgetManagedFilePath(String path) {
    final normalized = path.replaceAll(r'\', '/');
    return normalized.contains('/home_widget/');
  }

  static String _normalizeExtension(String extension) {
    var ext = extension.trim();
    if (ext.startsWith('.')) {
      ext = ext.substring(1);
    }
    if (ext.isEmpty) {
      throw ArgumentError.value(extension, 'extension', 'must not be empty');
    }
    if (ext.contains('/') || ext.contains(r'\') || ext.contains('..')) {
      throw ArgumentError.value(
        extension,
        'extension',
        'must not contain path separators',
      );
    }
    return ext;
  }

  static void _validateKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty');
    }
    if (key.contains('/') ||
        key.contains(r'\') ||
        key.contains('..') ||
        key.contains(' ')) {
      throw ArgumentError.value(
        key,
        'key',
        'must not contain /, \\, .., or spaces',
      );
    }
  }

  /// Writes [bytes] to the shared widget storage area and stores the absolute
  /// file path under [key] via [saveWidgetData] (same as [renderFlutterWidget]).
  ///
  /// On iOS the file is written under the app group container; on Android under
  /// the application support directory. In both cases the path is
  /// `{container}/home_widget/{key}.{extension}`.
  static Future<String> saveFile(
    String key,
    Uint8List bytes, {
    String extension = 'bin',
    String? appGroupId,
  }) async {
    final ext = _normalizeExtension(extension);
    _validateKey(key);

    try {
      late final String? directory;
      // coverage:ignore-start
      if (Platform.isIOS) {
        final PathProviderFoundation provider = PathProviderFoundation();
        final resolvedGroupId = appGroupId ?? HomeWidget.groupId;
        assert(
          resolvedGroupId != null,
          'No groupId defined. Did you forget to call `HomeWidget.setAppGroupId`',
        );
        directory = await provider.getContainerPath(
          appGroupIdentifier: resolvedGroupId!,
        );

        if (directory == null) {
          throw StateError(
            'Widget storage directory is null for group "$resolvedGroupId". '
            'Verify App Group configuration and HomeWidget.setAppGroupId.',
          );
        }
      } else {
        // coverage:ignore-end
        directory = (await getApplicationSupportDirectory()).path;
      }

      final String path = '$directory/home_widget/$key.$ext';
      final File file = File(path);
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(bytes);

      await saveWidgetData<String>(key, path, appGroupId: appGroupId);

      return path;
    } catch (e) {
      throw Exception('Failed to save file to widget container: $e');
    }
  }

  /// Encodes the first decoded frame of [imageProvider] as PNG and saves it
  /// via [saveFile] with extension `png`. Animated images use the first frame
  /// only.
  static Future<String> saveImage(
    String key,
    ImageProvider imageProvider, {
    ImageConfiguration configuration = ImageConfiguration.empty,
    String? appGroupId,
  }) async {
    _validateKey(key);
    final completer = Completer<Uint8List>();
    final stream = imageProvider.resolve(configuration);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) async {
        stream.removeListener(listener);
        try {
          final ByteData? byteData =
              await info.image.toByteData(format: ui.ImageByteFormat.png);
          // coverage:ignore-start
          if (byteData == null) {
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('Failed to encode image to PNG'),
              );
            }
          } else
          // coverage:ignore-end
          if (!completer.isCompleted) {
            completer.complete(byteData.buffer.asUint8List());
          }
        }
        // coverage:ignore-start
        catch (e, st) {
          if (!completer.isCompleted) {
            completer.completeError(e, st);
          }
        }
        // coverage:ignore-end
      },
      onError: (Object exception, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    final bytes = await completer.future;
    return saveFile(key, bytes, extension: 'png', appGroupId: appGroupId);
  }

  /// Generate a screenshot based on a given widget.
  /// This method renders the widget to an image (png) file with the provided filename.
  /// The png file is saved to the App Group container and the full path is returned as a string.
  /// The filename is saved to UserDefaults using the provided key.
  ///
  /// This method can throw in case the widget could not be converted to an
  /// image or if the image could not be saved to a file.
  static Future<String> renderFlutterWidget(
    Widget widget, {
    required String key,
    Size logicalSize = const Size(200, 200),
    double? pixelRatio,
    String? appGroupId,
  }) async {
    pixelRatio ??=
        PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;

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
          logicalConstraints: BoxConstraints.tight(logicalSize),
          devicePixelRatio: pixelRatio,
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
            children: [widget],
          ),
        ),
      ).attachToRenderTree(buildOwner);

      ///adding the rootElement to the buildScope
      buildOwner.buildScope(rootElement);

      ///adding the rootElement to the buildScope
      buildOwner.buildScope(rootElement);

      /// finalize the buildOwner
      buildOwner.finalizeTree();

      ///Flush Layout
      pipelineOwner.flushLayout();

      /// Flush Compositing Bits
      pipelineOwner.flushCompositingBits();

      /// Flush paint
      pipelineOwner.flushPaint();

      final ui.Image image =
          await repaintBoundary.toImage(pixelRatio: pixelRatio);

      /// The raw image is converted to byte data.
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      // coverage:ignore-start
      if (byteData == null) {
        throw Exception('Failed to encode widget to PNG');
      }
      // coverage:ignore-end

      try {
        return await saveFile(
          key,
          byteData.buffer.asUint8List(),
          extension: 'png',
          appGroupId: appGroupId,
        );
      } catch (e) {
        throw Exception('Failed to save screenshot to app group container: $e');
      }
    } catch (e) {
      throw Exception('Failed to render the widget: $e');
    }
  }

  /// On iOS, returns a list of [HomeWidgetInfo] for each type of widget currently installed,
  /// regardless of the number of instances.
  /// On Android, returns a list of [HomeWidgetInfo] for each instance of each widget
  /// currently pinned on the home screen.
  /// Returns an empty list if no widgets are pinned.
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
