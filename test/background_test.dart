import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget_callback_dispatcher.dart';

Completer<Uri> completer = Completer();
const backgroundChannel = MethodChannel('home_widget/background');

void main() {
  testWidgets('Callback Dispatcher calls callbacks', (tester) async {
    final callbackHandle =
        PluginUtilities.getCallbackHandle(testCallback)?.toRawHandle();
    const testUri = 'homeWidget://homeWidgetTest';

    tester.binding.defaultBinaryMessenger
        // ignore: body_might_complete_normally_nullable
        .setMockMethodCallHandler(backgroundChannel, (call) {
      if (call.method == 'HomeWidget.backgroundInitialized') {
        emitEvent(
          tester,
          backgroundChannel.codec
              .encodeMethodCall(MethodCall('', [callbackHandle, testUri])),
        );
      }
    });

    callbackDispatcher();

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

void testCallback(Uri? uri) {
  completer.complete(uri);
}
