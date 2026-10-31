import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';

Completer<Uri> completer = Completer();
const backgroundChannel = MethodChannel('home_widget/background');

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

  testWidgets('Callback Dispatcher waits for each callback independently', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await initializeControlledDispatcher(tester);
      var firstReplied = false;
      final first = sendBackgroundCall(tester, 'first').then((reply) {
        firstReplied = true;
        return reply;
      });
      await firstStarted.future;
      try {
        final second = await sendBackgroundCall(
          tester,
          'second',
        ).timeout(const Duration(seconds: 5));
        expect(backgroundChannel.codec.decodeEnvelope(second!), isNull);
        expect(firstReplied, isFalse);
        expect(callbackEvents, ['start:first', 'start:second', 'end:second']);
      } finally {
        releaseFirst.complete();
      }
      expect(backgroundChannel.codec.decodeEnvelope((await first)!), isNull);
      expect(firstReplied, isTrue);
      expect(callbackEvents, [
        'start:first',
        'start:second',
        'end:second',
        'end:first',
      ]);
    });
  });

  testWidgets('Callback Dispatcher preserves callback errors independently', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await initializeControlledDispatcher(tester);
      final replies = await Future.wait([
        sendBackgroundCall(tester, 'fail'),
        sendBackgroundCall(tester, 'second'),
      ]);
      expect(
        () => backgroundChannel.codec.decodeEnvelope(replies[0]!),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'controlled'),
        ),
      );
      expect(backgroundChannel.codec.decodeEnvelope(replies[1]!), isNull);
      expect(callbackEvents, ['start:fail', 'start:second', 'end:second']);
    });
  });

  testWidgets('Callback Dispatcher preserves missing-plugin replies', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await initializeControlledDispatcher(tester);
      final replies = await Future.wait([
        sendBackgroundCall(tester, 'missing'),
        sendBackgroundCall(tester, 'second'),
      ]);
      expect(replies[0], isNull);
      expect(backgroundChannel.codec.decodeEnvelope(replies[1]!), isNull);
      expect(callbackEvents, ['start:missing', 'start:second', 'end:second']);
    });
  });
}

List<String> callbackEvents = [];
late Completer<void> firstStarted;
late Completer<void> releaseFirst;

Future<void> initializeControlledDispatcher(WidgetTester tester) async {
  callbackEvents = [];
  firstStarted = Completer<void>();
  releaseFirst = Completer<void>();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    backgroundChannel,
    (call) async => true,
  );
  await callbackDispatcher();
}

Future<ByteData?> sendBackgroundCall(WidgetTester tester, String name) {
  final result = Completer<ByteData?>();
  final handle = PluginUtilities.getCallbackHandle(
    controlledCallback,
  )!.toRawHandle();
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    backgroundChannel.name,
    backgroundChannel.codec.encodeMethodCall(
      MethodCall('', [handle, 'homewidget://$name']),
    ),
    result.complete,
  );
  return result.future;
}

@pragma('vm:entry-point')
Future<void> controlledCallback(Uri? uri) async {
  final name = uri!.host;
  callbackEvents.add('start:$name');
  if (name == 'first') {
    firstStarted.complete();
    await releaseFirst.future;
  } else if (name == 'fail') {
    throw PlatformException(code: 'controlled');
  } else if (name == 'missing') {
    throw MissingPluginException('controlled');
  }
  callbackEvents.add('end:$name');
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
