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

  /// Refreshes the preview the launcher shows for the Widget in its gallery
  ///
  /// This is Android only and requires Android 15 (API 35). There the system is
  /// asked to re-render the generated preview of the Widget from its Glance
  /// `providePreview`, so the gallery can show the Widget filled with the
  /// current data instead of a static image.
  ///
  /// Returns `true` when the system accepted the new preview. Returns `false`
  /// when the system rate limit was hit (previews may only be updated about
  /// twice per hour and Widget), below Android 15, and when the resolved
  /// provider is not a Glance Widget.
  ///
  /// On iOS this does nothing and returns `false`, whatever it is passed:
  /// WidgetKit renders the gallery preview itself by calling the Widget's
  /// `getSnapshot` with `context.isPreview` set, so there is no preview for the
  /// plugin to push and no iOS Widget to name.
  ///
  /// Android Widgets will look for [qualifiedAndroidName] then [androidName] and then for [name]
  ///
  /// [qualifiedAndroidName] will use the name as is to find the WidgetProvider
  /// [androidName] must match the classname of the WidgetProvider, prefixed by the package name
  ///
  /// On Android, throws a `PlatformException` (code `-8`) if no
  /// `AppWidgetProvider` matching [qualifiedAndroidName]/[androidName]/[name]
  /// can be resolved, or if rendering the preview failed.
  static Future<bool?> updateWidgetPreview({
    String? name,
    String? androidName,
    String? qualifiedAndroidName,
  }) {
    return _channel.invokeMethod('updateWidgetPreview', {
      'name': name,
      'android': androidName,
      'qualifiedAndroidName': qualifiedAndroidName,
    });
  }

  /// Schedules updates of the HomeScreen Widget at the given [updateTimes]
  ///
  /// This is Android only. There the plugin uses `AlarmManager` to broadcast a
  /// Widget update at each of the given times, and returns `true`.
  ///
  /// On iOS this does nothing and returns `false`. A WidgetKit Widget decides
  /// for itself when its content changes by returning future `TimelineEntry`s
  /// from its `TimelineProvider`, so there is no schedule for the plugin to
  /// keep. Write the times into the Widget's data with [saveWidgetData] (or
  /// [saveFile]) instead and build the timeline from them.
  ///
  /// Any previously scheduled updates for the same Widget are replaced.
  /// Passing an empty list is equivalent to [cancelScheduledWidgetUpdates].
  /// Times in the past are ignored.
  ///
  /// Android Widgets will look for [qualifiedAndroidName] then [androidName] and then for [name]
  ///
  /// [qualifiedAndroidName] will use the name as is to find the WidgetProvider
  /// [androidName] must match the classname of the WidgetProvider, prefixed by the package name
  ///
  /// For exact alarms on Android 12+ the app needs to hold the
  /// `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM` permission. The plugin does not
  /// declare it. Without it updates are still scheduled, just inexact.
  /// Use [canScheduleExactWidgetUpdates] to find out which of the two applies.
  ///
  /// On Android the app also has to register
  /// `es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver` in its own
  /// `AndroidManifest.xml` (together with the `RECEIVE_BOOT_COMPLETED`
  /// permission) for the updates to be delivered and to survive a reboot.
  ///
  /// On Android, throws a `PlatformException` (code `-6`) if no
  /// `AppWidgetProvider` matching [qualifiedAndroidName]/[androidName]/[name]
  /// can be resolved.
  ///
  /// ## Timezones and DST
  ///
  /// [updateTimes] are absolute instants, not wall-clock times — only the
  /// underlying epoch milliseconds are sent to the platform, so a local
  /// [DateTime] and its `toUtc()` equivalent schedule the exact same update.
  /// A recurring wall-clock schedule such as "every day at 06:00 local time"
  /// is therefore not maintained across a DST change or a timezone change by
  /// the plugin: the app has to recompute the times and call this method
  /// again if the drift matters.
  static Future<bool?> scheduleWidgetUpdates(
    List<DateTime> updateTimes, {
    String? name,
    String? androidName,
    String? qualifiedAndroidName,
  }) {
    final millis = updateTimes
        .map((time) => time.millisecondsSinceEpoch)
        .toList();
    return _channel.invokeMethod('scheduleWidgetUpdates', {
      'updateTimes': millis,
      'name': name,
      'android': androidName,
      'qualifiedAndroidName': qualifiedAndroidName,
    });
  }

  /// Cancels all updates scheduled with [scheduleWidgetUpdates]
  ///
  /// This is Android only and returns `true` there. On iOS nothing was ever
  /// scheduled, so this does nothing and returns `false`.
  ///
  /// Android Widgets will look for [qualifiedAndroidName] then [androidName] and then for [name]
  ///
  /// [qualifiedAndroidName] will use the name as is to find the WidgetProvider
  /// [androidName] must match the classname of the WidgetProvider, prefixed by the package name
  ///
  /// On Android, throws a `PlatformException` (code `-7`) if no
  /// `AppWidgetProvider` matching [qualifiedAndroidName]/[androidName]/[name]
  /// can be resolved.
  static Future<bool?> cancelScheduledWidgetUpdates({
    String? name,
    String? androidName,
    String? qualifiedAndroidName,
  }) {
    return _channel.invokeMethod('cancelScheduledWidgetUpdates', {
      'name': name,
      'android': androidName,
      'qualifiedAndroidName': qualifiedAndroidName,
    });
  }

  /// Whether [scheduleWidgetUpdates] can schedule *exact* updates
  ///
  /// On iOS this is always `false`: [scheduleWidgetUpdates] schedules nothing
  /// there, and WidgetKit renders a Widget's own timeline entries on a best
  /// effort basis, so it may show them later than their date.
  ///
  /// On Android this is `true` below Android 12 (API 31). From Android 12 on it
  /// reflects `AlarmManager.canScheduleExactAlarms()`, which requires the app to
  /// declare either
  /// * `android.permission.SCHEDULE_EXACT_ALARM` — granted by default on
  ///   Android 13+, revocable by the user, or
  /// * `android.permission.USE_EXACT_ALARM` — always granted, but only allowed
  ///   for apps whose core function needs exact alarms (Google Play reviews it).
  ///
  /// The plugin declares neither so apps can choose. When this returns `false`,
  /// [scheduleWidgetUpdates] does not throw — it silently falls back to inexact
  /// alarms, which the system may delay (typically by minutes, more while the
  /// device is dozing).
  static Future<bool?> canScheduleExactWidgetUpdates() {
    return _channel.invokeMethod('canScheduleExactWidgetUpdates');
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
  ///
  /// A click that reaches the App while nothing listens to [widgetClicked] is
  /// answered here too, so it is not lost. That is how a click arrives when
  /// Android restarts the process of an App whose task is still there: the
  /// Activity comes back with the Intent it was first started with, and the
  /// click follows before any Dart code listens.
  static Future<Uri?> initiallyLaunchedFromHomeWidget() {
    return _channel
        .invokeMethod<String>('initiallyLaunchedFromHomeWidget')
        .then(_handleReceivedData);
  }

  /// Checks if the App was initially launched via the Widget configure action on Android.
  /// Only works on Android. Ensure to call `HomeWidget.finishHomeWidgetConfigure` once you want to complete the configuration
  static Future<String?> initiallyLaunchedFromHomeWidgetConfigure() {
    return _channel.invokeMethod<String>(
      'initiallyLaunchedFromHomeWidgetConfigure',
    );
  }

  /// Ends the Widget configure action on Android.
  /// This should be called when finishing up a Widget Configuration that was initiated based on `HomeWidget.initiallyLaunchedFromHomeWidgetConfigure`
  static Future<void> finishHomeWidgetConfigure() {
    return _channel.invokeMethod<void>('finishHomeWidgetConfigure');
  }

  /// The click events of the platform, shared by every listener: the native
  /// side has one event sink, which a second platform stream would take over
  /// and tear down again when it is cancelled.
  static final Stream<dynamic> _clickEvents = _eventChannel
      .receiveBroadcastStream();

  /// Receives Updates if App Launched via the Widget
  static Stream<Uri?> get widgetClicked {
    return _clickEvents.map<Uri?>(_handleReceivedData);
  }

  /// The clicks [launches] decodes, shared by all of its listeners.
  ///
  /// A click repeating the initial Uri while that Uri is first being read is
  /// the same launch reported twice, and is dropped here once for everyone.
  static final StreamController<Uri> _launchClicks =
      StreamController<Uri>.broadcast(
        onListen: () {
          _launchClicksSubscription = widgetClicked.listen(
            _addLaunchClick,
            onError: _launchClicks.addError,
          );
        },
        onCancel: () {
          final subscription = _launchClicksSubscription;
          _launchClicksSubscription = null;
          unawaited(subscription?.cancel());
        },
      );

  static StreamSubscription<Uri?>? _launchClicksSubscription;

  /// The initial Uri as [launches] reads it, once per run of the App.
  static Future<Uri?>? _launchInitialUri;

  /// Whether the read of [_launchInitialUri] has completed.
  static bool _launchInitialUriRead = false;

  /// Whether a [launches] listener has been handed the initial launch.
  static bool _initialLaunchDelivered = false;

  /// The clicks still waiting for the initial Uri, in order.
  static Future<void> _launchClickQueue = Future<void>.value();

  /// A read that fails is not kept, so the next [launches] listener reads
  /// again. It still ends the window in which clicks repeating the initial Uri
  /// are dropped.
  static Future<Uri?> _readLaunchInitialUri() =>
      _launchInitialUri ??= initiallyLaunchedFromHomeWidget().then(
        (uri) {
          _launchInitialUriRead = true;
          return uri;
        },
        onError: (Object error, StackTrace stackTrace) {
          _launchInitialUri = null;
          _launchInitialUriRead = true;
          Error.throwWithStackTrace(error, stackTrace);
        },
      );

  static void _addLaunchClick(Uri? uri) {
    if (uri == null) return;
    if (_launchInitialUriRead) {
      _launchClickQueue = _launchClickQueue.then((_) => _launchClicks.add(uri));
      return;
    }
    _launchClickQueue = _launchClickQueue.then((_) async {
      Uri? initial;
      try {
        initial = await _readLaunchInitialUri();
      } on Object {
        // Whoever listens to [launches] is told about the failed read.
      }
      if (uri != initial) _launchClicks.add(uri);
    });
  }

  /// Forgets what [launches] remembers about the run of the App.
  @visibleForTesting
  static void debugResetLaunches() {
    _launchInitialUri = null;
    _launchInitialUriRead = false;
    _initialLaunchDelivered = false;
    _launchClickQueue = Future<void>.value();
  }

  /// The launch [decode] reads out of the Uri the App was started with by a
  /// click on a HomeScreen Widget
  ///
  /// Returns `null` when the App was started any other way, and when [decode]
  /// returns `null` because the Uri is not one it knows. The scheme of the Uri
  /// handed to [decode] is lower-cased, whatever casing the Widget wrote it
  /// with.
  static Future<T?> initialLaunch<T extends Object>(
    T? Function(Uri uri) decode,
  ) async {
    final uri = await initiallyLaunchedFromHomeWidget();
    return uri == null ? null : decode(uri);
  }

  /// Every launch [decode] reads out of a click on a HomeScreen Widget
  ///
  /// Emits the launch the App was started with first, if there was one, then
  /// one for every click while the App is running. Clicks arriving while the
  /// initial Uri is still being read are kept. A Uri [decode] returns `null`
  /// for is skipped, so the Stream only ever carries launches [decode] knows.
  ///
  /// The initial launch is delivered once per run of the App: as soon as one
  /// listener has decoded the initial Uri to a launch and received it, every
  /// Stream listened to later starts with clicks only. A listener whose
  /// [decode] does not know the initial Uri leaves it for another one. Use
  /// [initialLaunch] to read it again. A click that reached the App before
  /// anything listened counts as the initial launch, see
  /// [initiallyLaunchedFromHomeWidget].
  ///
  /// Any number of these Streams can be listened to at once, each with a
  /// [decode] of its own. An exception [decode] throws, and a failure to read
  /// the initial Uri, arrive as an error of the Stream, which keeps going with
  /// the clicks. A Stream listened to after a failed read reads it again.
  ///
  /// The scheme of the Uri handed to [decode] is lower-cased, whatever casing
  /// the Widget wrote it with.
  static Stream<T> launches<T extends Object>(
    T? Function(Uri uri) decode,
  ) async* {
    final clicks = StreamController<T>();
    final subscription = _launchClicks.stream.listen((uri) {
      try {
        final launch = decode(uri);
        if (launch != null) clicks.add(launch);
      } on Object catch (error, stackTrace) {
        clicks.addError(error, stackTrace);
      }
    }, onError: clicks.addError);
    try {
      Uri? uri;
      if (!_initialLaunchDelivered) {
        try {
          uri = await _readLaunchInitialUri();
        } on Object catch (error, stackTrace) {
          yield* Stream<T>.error(error, stackTrace);
        }
      }
      if (uri != null && !_initialLaunchDelivered) {
        T? initial;
        try {
          initial = decode(uri);
        } on Object catch (error, stackTrace) {
          yield* Stream<T>.error(error, stackTrace);
        }
        if (initial != null) {
          _initialLaunchDelivered = true;
          yield initial;
        }
      }
      yield* clicks.stream;
    } finally {
      await subscription.cancel();
      // Not awaited: a controller nobody listened to never reports done.
      unawaited(clicks.close());
    }
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
  ) => registerInteractivityCallback(callback);

  /// Register a callback that gets called when clicked on a specific View in a HomeWidget
  /// This enables having Interactive Widgets that can call Dart Code
  /// More Info on setting this up in the README
  ///
  /// Without a [key] the callback takes the default slot: it receives every
  /// interaction that names no key, and every interaction whose key has no
  /// callback of its own.
  ///
  /// With a [key] the callback is registered next to the default one and only
  /// receives interactions sent with the same key, so several Widgets can each
  /// have their own callback. The native side passes the key along with the
  /// Uri: `HomeWidgetBackgroundIntent.getBroadcast(context, uri, key)` or
  /// `HomeWidgetInteractivityAction` on Android,
  /// `HomeWidgetBackgroundWorker.run(url:appGroup:key:)` on iOS.
  ///
  /// [appGroupId] names the App Group the callback is stored in on iOS, so
  /// registering works without calling [setAppGroupId] first. It defaults to
  /// [groupId] and has no effect on Android.
  ///
  /// The [callback] runs in a separate background isolate that finds it only
  /// by its callback handle, so it must be a top-level or static function
  /// annotated with `@pragma('vm:entry-point')`. Closures and instance methods
  /// have no such handle and make this method throw an [ArgumentError].
  ///
  /// On iOS, throws a `PlatformException` with code `-7` when neither
  /// [appGroupId] nor [setAppGroupId] provided an App Group, and with code `-5`
  /// below iOS 17, where Widgets cannot be interactive.
  static Future<bool?> registerInteractivityCallback(
    FutureOr<void> Function(Uri?) callback, {
    String? key,
    String? appGroupId,
  }) {
    final dispatcherHandle = ui.PluginUtilities.getCallbackHandle(
      callbackDispatcher,
    )?.toRawHandle();
    final callbackHandle = ui.PluginUtilities.getCallbackHandle(
      callback,
    )?.toRawHandle();
    if (dispatcherHandle == null || callbackHandle == null) {
      throw ArgumentError.value(
        callback,
        'callback',
        "must be a top-level or static function annotated with @pragma('vm:entry-point'). "
            'Closures and instance methods cannot run in the background engine',
      );
    }
    final args = <dynamic>[
      dispatcherHandle,
      callbackHandle,
      if (key != null || appGroupId != null) ...[key, appGroupId],
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
          final ByteData? byteData = await info.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
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

      final ui.Image image = await repaintBoundary.toImage(
        pixelRatio: pixelRatio,
      );

      /// The raw image is converted to byte data.
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

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
