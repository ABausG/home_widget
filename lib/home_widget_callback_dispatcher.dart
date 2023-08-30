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
    final args = call.arguments;

    final callback = PluginUtilities.getCallbackFromHandle(
      CallbackHandle.fromRawHandle(args[0]),
    ) as FutureOr<void> Function(Uri?);

    final rawUri = args[1] as String?;

    Uri? uri;
    if (rawUri != null) {
      uri = Uri.parse(rawUri);
    }

    await callback.call(uri);
  });

  await backgroundChannel.invokeMethod('HomeWidget.backgroundInitialized');
}
