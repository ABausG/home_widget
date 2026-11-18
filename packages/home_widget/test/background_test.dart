import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';

Completer<Uri> completer = Completer();
const backgroundChannel = MethodChannel('home_widget/background');
const unknownHandle = 4242;

void main() {
  testWidgets('Callback Dispatcher calls callbacks', (tester) async {
    final callbackHandle = PluginUtilities.getCallbackHandle(
      testCallback,
    )?.toRawHandle();
    const testUri = 'homeWidget://homeWidgetTest';

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      backgroundChannel,
      (call) async {
        if (call.method == 'HomeWidget.backgroundInitialized') {
          emitEvent(
            tester,
            backgroundChannel.codec.encodeMethodCall(
              MethodCall('', [callbackHandle, testUri]),
            ),
          );
          return true;
        } else {
          return null;
        }
      },
    );

    await callbackDispatcher();

    final receivedUri = await completer.future;

    expect(receivedUri, Uri.parse(testUri));
  });

  testWidgets(
    'Callback Dispatcher falls back to the default callback for an unknown handle',
    (tester) async {
      completer = Completer();
      final defaultHandle = PluginUtilities.getCallbackHandle(
        testCallback,
      )?.toRawHandle();
      const testUri = 'homeWidget://homeWidgetTest';
      await startDispatcher(tester);

      final reply = await sendCall(tester, [
        unknownHandle,
        testUri,
        defaultHandle,
      ]);

      expect(backgroundChannel.codec.decodeEnvelope(reply!), isNull);
      expect(await completer.future, Uri.parse(testUri));
    },
  );

  testWidgets(
    'Callback Dispatcher ignores an interaction without a known callback',
    (tester) async {
      completer = Completer();
      await startDispatcher(tester);

      final reply = await sendCall(tester, [
        unknownHandle,
        'homeWidget://homeWidgetTest',
        null,
      ]);

      expect(backgroundChannel.codec.decodeEnvelope(reply!), isNull);
      expect(completer.isCompleted, isFalse);
    },
  );
}

Future<void> startDispatcher(WidgetTester tester) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    backgroundChannel,
    (call) async => true,
  );
  await callbackDispatcher();
}

Future<ByteData?> sendCall(WidgetTester tester, List<Object?> arguments) {
  final reply = Completer<ByteData?>();
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    backgroundChannel.name,
    backgroundChannel.codec.encodeMethodCall(MethodCall('', arguments)),
    reply.complete,
  );
  return reply.future;
}

void emitEvent(WidgetTester tester, ByteData? event) {
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    backgroundChannel.name,
    event,
    (ByteData? reply) {},
  );
}

@pragma('vm:entry-point')
Future<void> testCallback(Uri? uri) async {
  completer.complete(uri);
}
