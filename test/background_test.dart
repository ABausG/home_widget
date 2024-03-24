import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';

Completer<Uri> completer = Completer();
const backgroundChannel = MethodChannel('home_widget/background');

void main() {
  testWidgets('Callback Dispatcher calls callbacks', (tester) async {
    final callbackHandle =
        PluginUtilities.getCallbackHandle(testCallback)?.toRawHandle();
    const testUri = 'homeWidget://homeWidgetTest';

    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, (call) async {
      if (call.method == 'HomeWidget.backgroundInitialized') {
        emitEvent(
          tester,
          backgroundChannel.codec
              .encodeMethodCall(MethodCall('', [callbackHandle, testUri])),
        );
        return true;
      } else {
        return null;
      }
    });

    await callbackDispatcher();

    final receivedUri = await completer.future;

    expect(receivedUri, Uri.parse(testUri));
  });
}

void emitEvent(WidgetTester tester, ByteData? event) {
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    backgroundChannel.name,
    event,
    (ByteData? reply) {},
  );
}

Future<void> testCallback(Uri? uri) async {
  completer.complete(uri);
}
