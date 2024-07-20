import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:home_widget/home_widget.dart';
import 'package:mocktail/mocktail.dart';

// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'mocks.dart';

const updateChannel = MethodChannel('home_widget/updates');

void main() {
  const channel = MethodChannel('home_widget');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Completer<dynamic> passedArguments;

  dynamic launchUri;

  setUp(() {
    launchUri = null;
    passedArguments = Completer();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        // ignore: body_might_complete_normally_nullable
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
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
        case 'requestPinWidget':
          return null;
        case 'isRequestPinWidgetSupported':
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getWidgetData', () async {
    const dataId = 'TestId';
    expect(await HomeWidget.getWidgetData(dataId), 'TestData');
    final arguments = await passedArguments.future;

    expect(arguments['id'], dataId);
  });

  test('getWidgetData passes Default Value', () async {
    const dataId = 'TestId';
    const defaultValue = 'Default Value';
    await HomeWidget.getWidgetData(dataId, defaultValue: defaultValue);
    final arguments = await passedArguments.future;

    expect(arguments['defaultValue'], defaultValue);
  });

  test('saveWidgetData', () async {
    const id = 'TestId';
    const value = 'Test Value';
    expect(await HomeWidget.saveWidgetData(id, value), true);
    final arguments = await passedArguments.future;

    expect(arguments['id'], id);
    expect(arguments['data'], value);
  });

  test('updateWidget', () async {
    expect(
      await HomeWidget.updateWidget(
        name: 'name',
        androidName: 'androidName',
        iOSName: 'iOSName',
        qualifiedAndroidName: 'com.example.androidName',
      ),
      true,
    );

    final arguments = await passedArguments.future;

    expect(arguments['name'], 'name');
    expect(arguments['android'], 'androidName');
    expect(arguments['ios'], 'iOSName');
    expect(arguments['qualifiedAndroidName'], 'com.example.androidName');
  });

  test('isRequestPinWidgetSupported', () async {
    expect(
      await HomeWidget.isRequestPinWidgetSupported(),
      true,
    );

    final arguments = await passedArguments.future;

    expect(arguments, isNull);
  });

  test('requestPinWidget', () async {
    await HomeWidget.requestPinWidget(
      name: 'name',
      androidName: 'androidName',
      qualifiedAndroidName: 'com.example.androidName',
    );

    final arguments = await passedArguments.future;

    expect(arguments['name'], 'name');
    expect(arguments['android'], 'androidName');
    expect(arguments['qualifiedAndroidName'], 'com.example.androidName');
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
    const appGroup = 'Default Value';
    await HomeWidget.setAppGroupId(appGroup);
    final arguments = await passedArguments.future;

    expect(arguments['groupId'], appGroup);
  });

  test('Register Background Callback passes Handles', () async {
    final dispatcherHandle =
        PluginUtilities.getCallbackHandle(callbackDispatcher)?.toRawHandle();
    final callbackHandle =
        PluginUtilities.getCallbackHandle(testCallback)?.toRawHandle();

    // ignore: deprecated_member_use_from_same_package
    expect(await HomeWidget.registerBackgroundCallback(testCallback), true);

    final argument = await passedArguments.future;

    expect(argument[0], dispatcherHandle);
    expect(argument[1], callbackHandle);
  });

  test('Register Interactivity Callback passes Handles', () async {
    final dispatcherHandle =
        PluginUtilities.getCallbackHandle(callbackDispatcher)?.toRawHandle();
    final callbackHandle =
        PluginUtilities.getCallbackHandle(testCallback)?.toRawHandle();

    expect(await HomeWidget.registerInteractivityCallback(testCallback), true);

    final argument = await passedArguments.future;

    expect(argument[0], dispatcherHandle);
    expect(argument[1], callbackHandle);
  });

  group('Widget Clicked', () {
    test('Send Uris to Stream', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(updateChannel.name,
              // ignore: body_might_complete_normally_nullable
              (message) async {
        emitEvent(
          updateChannel.codec
              .encodeSuccessEnvelope('homeWidget://homeWidgetTest'),
        );
        emitEvent(updateChannel.codec.encodeSuccessEnvelope(2));
        emitEvent(updateChannel.codec.encodeSuccessEnvelope(null));
      });

      final expectation = expectLater(
        HomeWidget.widgetClicked,
        emitsInOrder([
          Uri.parse('homeWidget://homeWidgetTest'),
          Uri(),
          null,
        ]),
      );

      await expectation;
    });
  });

  group('Render Flutter Widget', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final directory = Directory('app/directory');

    const size = Size(201, 201);
    final targetWidget = SizedBox.fromSize(
      size: size,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.red,
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: Colors.green,
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );

    setUp(() {
      final pathProvider = MockPathProvider();
      when(() => pathProvider.getApplicationSupportPath())
          .thenAnswer((invocation) async => directory.path);
      PathProviderPlatform.instance = pathProvider;
    });

    testGoldens('Render Flutter Widget', (tester) async {
      final byteCompleter = Completer<Uint8List>();
      final file = MockFile();

      when(() => file.exists()).thenAnswer((invocation) async => false);
      when(() => file.create(recursive: true))
          .thenAnswer((invocation) async => file);
      when(() => file.writeAsBytes(any())).thenAnswer((invocation) async {
        byteCompleter
            .complete(Uint8List.fromList(invocation.positionalArguments.first));
        return file;
      });

      await IOOverrides.runZoned(
        () async {
          await tester.runAsync(() async {
            final path = await HomeWidget.renderFlutterWidget(
              targetWidget,
              key: 'screenshot',
              logicalSize: size,
            );
            final expectedPath = '${directory.path}/home_widget/screenshot.png';
            expect(path, equals(expectedPath));

            final arguments = await passedArguments.future;
            expect(arguments['id'], 'screenshot');
            expect(arguments['data'], expectedPath);
          });
        },
        createFile: (path) {
          when(() => file.path).thenReturn(path);
          return file;
        },
      );

      final bytes = await byteCompleter.future;

      await tester.pumpWidgetBuilder(
        Image.memory(
          bytes,
          width: size.height,
          height: size.height,
        ),
        surfaceSize: size,
      );

      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'render-flutter-widget');
    });

    testGoldens('Error rendering Flutter Widget throws', (tester) async {
      final file = MockFile();
      await IOOverrides.runZoned(
        () async {
          await tester.runAsync(
            () async {
              expect(
                () async => await HomeWidget.renderFlutterWidget(
                  Builder(builder: (_) => const SizedBox()),
                  logicalSize: Size.zero,
                  key: 'screenshot',
                ),
                throwsException,
              );
            },
          );
        },
        createFile: (path) {
          when(() => file.path).thenReturn(path);
          return file;
        },
      );
    });

    testGoldens('Error saving Widget throws', (tester) async {
      final file = MockFile();

      when(() => file.exists()).thenAnswer((invocation) async => false);
      when(() => file.create(recursive: true))
          .thenAnswer((invocation) async => file);
      when(() => file.writeAsBytes(any()))
          .thenAnswer((invocation) => Future.error('Error'));

      await IOOverrides.runZoned(
        () async {
          await tester.runAsync(() async {
            expect(
              () async => await HomeWidget.renderFlutterWidget(
                targetWidget,
                logicalSize: size,
                key: 'screenshot',
              ),
              throwsException,
            );
          });
        },
        createFile: (path) {
          when(() => file.path).thenReturn(path);
          return file;
        },
      );
    });
  });

  group('getInstalledWidgets', () {
    test(
        'returns a list of HomeWidgetInfo objects when method channel provides data',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getInstalledWidgets':
            return [
              {"id": "widget1", "name": "Widget One"},
              {"id": "widget2", "name": "Widget Two"},
            ];
          default:
            return null;
        }
      });

      final expectedWidgets = [
        HomeWidgetInfo.fromMap({"id": "widget1", "name": "Widget One"}),
        HomeWidgetInfo.fromMap({"id": "widget2", "name": "Widget Two"}),
      ];

      final widgets = await HomeWidget.getInstalledWidgets();

      expect(widgets, equals(expectedWidgets));
    });

    test('returns an empty list when method channel returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          // ignore: body_might_complete_normally_nullable
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getInstalledWidgets':
            return null;
        }
      });

      final widgets = await HomeWidget.getInstalledWidgets();

      expect(widgets, isEmpty);
    });
  });
}

void emitEvent(ByteData? event) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    updateChannel.name,
    event,
    (ByteData? reply) {},
  );
}

Future<void> testCallback(Uri? uri) async {
  debugPrint('Called TestCallback');
}
