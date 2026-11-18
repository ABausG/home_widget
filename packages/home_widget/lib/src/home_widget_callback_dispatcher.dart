import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Dispatcher used for calling dart code from Native Code while in the background
@pragma("vm:entry-point")
Future<void> callbackDispatcher() async {
  const backgroundChannel = MethodChannel('home_widget/background');
  WidgetsFlutterBinding.ensureInitialized();

  backgroundChannel.setMethodCallHandler((call) async {
    final args = call.arguments as List<Object?>;

    final callback =
        _lookUpCallback(args[0]) ??
        (args.length > 2 ? _lookUpCallback(args[2]) : null);
    if (callback == null) {
      debugPrint(
        'home_widget: The registered interactivity callback could not be '
        'found. Call HomeWidget.registerInteractivityCallback in the app again.',
      );
      return;
    }

    final rawUri = args[1] as String?;

    Uri? uri;
    if (rawUri != null) {
      uri = Uri.parse(rawUri);
    }

    await callback.call(uri);
  });

  await backgroundChannel.invokeMethod('HomeWidget.backgroundInitialized');
}

FutureOr<void> Function(Uri?)? _lookUpCallback(Object? rawHandle) {
  if (rawHandle is! int || rawHandle == 0) {
    return null;
  }
  return PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(rawHandle),
      )
      as FutureOr<void> Function(Uri?)?;
}
