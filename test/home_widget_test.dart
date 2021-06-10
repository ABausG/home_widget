import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:home_widget/home_widget_callback_dispatcher.dart';

const updateChannel = MethodChannel('home_widget/updates');

void main() {
  const channel = MethodChannel('home_widget');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Completer<dynamic> passedArguments;

  dynamic launchUri;

  setUp(() {
    launchUri = null;
    passedArguments = Completer();
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      passedArguments.complete(methodCall.arguments);
      switch (methodCall.method) {
        case 'saveWidgetData':
          return true;
        case 'getWidgetData':
          return 'TestData';
        case 'updateWidget':
          return true;
        case 'setAppGroupId':
          return true;
        case 'initiallyLaunchedFromHomeWidget':
          return Future.value(launchUri);
        case 'registerBackgroundCallback':
          return true;
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getWidgetData', () async {
    final dataId = 'TestId';
    expect(await HomeWidget.getWidgetData(dataId), 'TestData');
    final arguments = await passedArguments.future;

    expect(arguments['id'], dataId);
  });

  test('getWidgetData passes Default Value', () async {
    final dataId = 'TestId';
    final defaultValue = 'Default Value';
    await HomeWidget.getWidgetData(dataId, defaultValue: defaultValue);
    final arguments = await passedArguments.future;

    expect(arguments['defaultValue'], defaultValue);
  });

  test('saveWidgetData', () async {
    final id = 'TestId';
    final value = 'Test Value';
    expect(await HomeWidget.saveWidgetData(id, value), true);
    final arguments = await passedArguments.future;

    expect(arguments['id'], id);
    expect(arguments['data'], value);
  });

  test('updateWidget', () async {
    expect(
        await HomeWidget.updateWidget(
            name: 'name', androidName: 'androidName', iOSName: 'iOSName'),
        true);

    final arguments = await passedArguments.future;

    expect(arguments['name'], 'name');
    expect(arguments['android'], 'androidName');
    expect(arguments['ios'], 'iOSName');
  });

  group('initiallyLaunchedFromHomeWidget', () {
    test('Valid Uri String gets parsed', () async {
      launchUri = 'homeWidget://homeWidgetTest';

      final parsedUri = await HomeWidget.initiallyLaunchedFromHomeWidget();

      expect(parsedUri, Uri(scheme: 'homeWidget', host: 'homeWidgetTest'));
    });

    test('Malformed Uri String returns empty Uri', () async {
      launchUri = 'tcp://[fe80::a8e8:2b42:3c07:c04a%2510]:port/name';

      final parsedUri = await HomeWidget.initiallyLaunchedFromHomeWidget();

      expect(parsedUri, Uri());
    });

    test('null return value returns null', () async {
      launchUri = null;

      final parsedUri = await HomeWidget.initiallyLaunchedFromHomeWidget();

      expect(parsedUri, null);
    });
  });

  test('Set Group Id', () async {
    final appGroup = 'Default Value';
    await HomeWidget.setAppGroupId(appGroup);
    final arguments = await passedArguments.future;

    expect(arguments['groupId'], appGroup);
  });

  test('Register Background Callback passes Handles', () async {
    final dispatcherHandle =
        PluginUtilities.getCallbackHandle(callbackDispatcher)?.toRawHandle();
    final callbackHandle =
        PluginUtilities.getCallbackHandle(testCallback)?.toRawHandle();

    expect(await HomeWidget.registerBackgroundCallback(testCallback), true);

    final argument = await passedArguments.future;

    expect(argument[0], dispatcherHandle);
    expect(argument[1], callbackHandle);
  });

  group('Widget Clicked', () {
    test('Send Uris to Stream', () async {
      updateChannel.binaryMessenger.setMockMessageHandler(updateChannel.name,
          (message) async {
        emitEvent(updateChannel.codec
            .encodeSuccessEnvelope('homeWidget://homeWidgetTest'));
        emitEvent(updateChannel.codec.encodeSuccessEnvelope(2));
        emitEvent(updateChannel.codec.encodeSuccessEnvelope(null));
      });

      final expectation = expectLater(
          HomeWidget.widgetClicked,
          emitsInOrder([
            Uri.parse('homeWidget://homeWidgetTest'),
            Uri(),
            null,
          ]));

      await expectation;
    });
  });
}

void emitEvent(ByteData? event) {
  updateChannel.binaryMessenger.handlePlatformMessage(
    updateChannel.name,
    event,
    (ByteData? reply) {},
  );
}

void testCallback(Uri? uri) {
  debugPrint('Called TestCallback');
}
