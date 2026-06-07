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
import 'utils/test_png.dart';

const updateChannel = MethodChannel('home_widget/updates');

void main() {
  const channel = MethodChannel('home_widget');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Completer<dynamic> passedArguments;

  dynamic launchUri;
  dynamic configureWidgetId;

  setUp(() {
    launchUri = null;
    configureWidgetId = null;
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
        case 'initiallyLaunchedFromHomeWidgetConfigure':
          return Future.value(configureWidgetId);
        case 'finishHomeWidgetConfigure':
          return null;
        case 'registerBackgroundCallback':
          return true;
        case 'requestPinWidget':
          return null;
        case 'isRequestPinWidgetSupported':
          return true;
      }
      throw UnimplementedError(
        'Method ${methodCall.method} not implemented in mock',
      );
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getWidgetData', () async {
    const dataId = 'TestId';
    expect(await HomeWidget.getWidgetData<String>(dataId), 'TestData');
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

  test('getWidgetData passes appGroupId when provided', () async {
    const dataId = 'TestId';
    const appGroupId = 'group.test.per.call';
    await HomeWidget.getWidgetData<String>(dataId, appGroupId: appGroupId);
    final arguments = await passedArguments.future;

    expect(arguments['id'], dataId);
    expect(arguments['appGroupId'], appGroupId);
  });

  group('saveWidgetData', () {
    test('saves data with value', () async {
      const id = 'TestId';
      const value = 'Test Value';
      expect(await HomeWidget.saveWidgetData(id, value), true);
      final arguments = await passedArguments.future;

      expect(arguments['id'], id);
      expect(arguments['data'], value);
    });

    test('passes appGroupId when provided', () async {
      const id = 'TestId';
      const value = 'Test Value';
      const appGroupId = 'group.test.per.call';
      expect(
        await HomeWidget.saveWidgetData(id, value, appGroupId: appGroupId),
        true,
      );
      final arguments = await passedArguments.future;

      expect(arguments['id'], id);
      expect(arguments['data'], value);
      expect(arguments['appGroupId'], appGroupId);
    });

    group('deleteFile', () {
      late List<MethodCall> invocations;
      dynamic getWidgetDataReturn;
      Object? getWidgetDataError;

      setUp(() {
        invocations = [];
        getWidgetDataReturn = null;
        getWidgetDataError = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        // ignore: body_might_complete_normally_nullable
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          invocations.add(call);
          switch (call.method) {
            case 'getWidgetData':
              if (getWidgetDataError != null) throw getWidgetDataError!;
              return getWidgetDataReturn;
            case 'saveWidgetData':
              return true;
            default:
              return null;
          }
        });
      });

      test('deleteFile false with null only invokes saveWidgetData', () async {
        const id = 'TestId';
        expect(
          await HomeWidget.saveWidgetData(id, null, deleteFile: false),
          true,
        );
        expect(invocations.length, 1);
        expect(invocations.single.method, 'saveWidgetData');
        expect(invocations.single.arguments['id'], id);
        expect(invocations.single.arguments['data'], isNull);
      });

      test(
        'non-String path skips delete; getWidgetData then saveWidgetData',
        () async {
          getWidgetDataReturn = 42;
          const id = 'fileKey';
          expect(await HomeWidget.saveWidgetData(id, null), true);
          expect(invocations.map((c) => c.method).toList(), [
            'getWidgetData',
            'saveWidgetData',
          ]);
          expect(invocations[0].arguments['id'], id);
          expect(invocations[1].arguments['data'], isNull);
        },
      );

      test('delete flow forwards appGroupId to get and save', () async {
        getWidgetDataReturn = '/widget/file.bin';
        const id = 'fileKey';
        const appGroupId = 'group.test.per.call';
        expect(
          await HomeWidget.saveWidgetData(id, null, appGroupId: appGroupId),
          true,
        );
        expect(invocations.map((c) => c.method).toList(), [
          'getWidgetData',
          'saveWidgetData',
        ]);
        expect(invocations[0].arguments['id'], id);
        expect(invocations[0].arguments['appGroupId'], appGroupId);
        expect(invocations[1].arguments['id'], id);
        expect(invocations[1].arguments['data'], isNull);
        expect(invocations[1].arguments['appGroupId'], appGroupId);
      });

      test('String path not under home_widget skips file delete', () async {
        getWidgetDataReturn = '/widget/file.bin';
        final file = MockFile();

        await IOOverrides.runZoned(
          () async {
            expect(await HomeWidget.saveWidgetData('k', null), true);
            verifyNever(() => file.exists());
            verifyNever(() => file.delete());
          },
          createFile: (path) {
            when(() => file.path).thenReturn(path);
            return file;
          },
        );

        expect(invocations.map((c) => c.method), [
          'getWidgetData',
          'saveWidgetData',
        ]);
      });

      test('managed path missing file never calls delete', () async {
        getWidgetDataReturn = '/app/support/home_widget/missing.bin';
        final file = MockFile();
        when(() => file.exists()).thenAnswer((_) async => false);

        await IOOverrides.runZoned(
          () async {
            expect(await HomeWidget.saveWidgetData('k', null), true);
            verify(() => file.exists()).called(1);
            verifyNever(() => file.delete());
          },
          createFile: (path) {
            when(() => file.path).thenReturn(path);
            return file;
          },
        );
      });

      test('managed path existing file deletes once', () async {
        getWidgetDataReturn = '/app/support/home_widget/file.bin';
        final file = MockFile();
        when(() => file.exists()).thenAnswer((_) async => true);
        when(() => file.delete()).thenAnswer((_) async => file);

        await IOOverrides.runZoned(
          () async {
            expect(await HomeWidget.saveWidgetData('k', null), true);
            verify(() => file.delete()).called(1);
          },
          createFile: (path) {
            when(() => file.path).thenReturn(path);
            return file;
          },
        );
      });

      test('getWidgetData throws; error propagates so caller can handle; '
          'saveWidgetData channel not invoked', () async {
        getWidgetDataError = Exception('channel fail');
        await expectLater(
          HomeWidget.saveWidgetData('id', null),
          throwsA(anything),
        );
        expect(invocations.map((c) => c.method), ['getWidgetData']);
        expect(invocations.any((c) => c.method == 'saveWidgetData'), isFalse);
      });

      test(
        'exists throws; error propagates; saveWidgetData channel not invoked',
        () async {
          getWidgetDataReturn = '/app/home_widget/f';
          final file = MockFile();
          when(() => file.exists()).thenThrow(Exception('io'));

          await IOOverrides.runZoned(
            () async {
              await expectLater(
                HomeWidget.saveWidgetData('id', null),
                throwsA(anything),
              );
            },
            createFile: (path) {
              when(() => file.path).thenReturn(path);
              return file;
            },
          );

          expect(invocations.map((c) => c.method), ['getWidgetData']);
          expect(invocations.any((c) => c.method == 'saveWidgetData'), isFalse);
        },
      );

      test(
        'managed path delete failure is ignored; saveWidgetData still invoked',
        () async {
          getWidgetDataReturn = '/app/home_widget/f';
          final file = MockFile();
          when(() => file.exists()).thenAnswer((_) async => true);
          when(() => file.delete()).thenAnswer(
            (_) async => throw FileSystemException('delete', 'path'),
          );

          await IOOverrides.runZoned(
            () async {
              expect(await HomeWidget.saveWidgetData('id', null), true);
            },
            createFile: (path) {
              when(() => file.path).thenReturn(path);
              return file;
            },
          );

          expect(invocations.map((c) => c.method), [
            'getWidgetData',
            'saveWidgetData',
          ]);
        },
      );
    });
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
    expect(await HomeWidget.isRequestPinWidgetSupported(), true);

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

  group('initiallyLaunchedFromHomeWidgetConfigure', () {
    test('Valid widget ID is returned', () async {
      configureWidgetId = '7';

      final returnedId =
          await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure();

      expect(returnedId, '7');
    });

    test('null return value returns null', () async {
      configureWidgetId = null;

      final returnedId =
          await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure();

      expect(returnedId, null);
    });
  });

  test('finishHomeWidgetConfigure', () async {
    await HomeWidget.finishHomeWidgetConfigure();
    final arguments = await passedArguments.future;

    expect(arguments, isNull);
  });

  test('Set Group Id', () async {
    const appGroup = 'Default Value';
    await HomeWidget.setAppGroupId(appGroup);
    final arguments = await passedArguments.future;

    expect(arguments['groupId'], appGroup);
  });

  test('per-call appGroupId does not change global groupId', () async {
    const globalGroupId = 'group.global';
    const perCallGroupId = 'group.per.call';
    final invocations = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          invocations.add(call);
          switch (call.method) {
            case 'setAppGroupId':
              return true;
            case 'saveWidgetData':
              return true;
            default:
              return null;
          }
        });

    await HomeWidget.setAppGroupId(globalGroupId);
    await HomeWidget.saveWidgetData('k', 'v', appGroupId: perCallGroupId);
    expect(HomeWidget.groupId, globalGroupId);
    expect(invocations.last.arguments['appGroupId'], perCallGroupId);
  });

  test('Register Background Callback passes Handles', () async {
    final dispatcherHandle = PluginUtilities.getCallbackHandle(
      callbackDispatcher,
    )?.toRawHandle();
    final callbackHandle = PluginUtilities.getCallbackHandle(
      testCallback,
    )?.toRawHandle();

    // ignore: deprecated_member_use_from_same_package
    expect(await HomeWidget.registerBackgroundCallback(testCallback), true);

    final argument = await passedArguments.future;

    expect(argument[0], dispatcherHandle);
    expect(argument[1], callbackHandle);
  });

  test('Register Interactivity Callback passes Handles', () async {
    final dispatcherHandle = PluginUtilities.getCallbackHandle(
      callbackDispatcher,
    )?.toRawHandle();
    final callbackHandle = PluginUtilities.getCallbackHandle(
      testCallback,
    )?.toRawHandle();

    expect(await HomeWidget.registerInteractivityCallback(testCallback), true);

    final argument = await passedArguments.future;

    expect(argument[0], dispatcherHandle);
    expect(argument[1], callbackHandle);
  });

  group('Widget Clicked', () {
    test('Send Uris to Stream', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            updateChannel.name,
            // ignore: body_might_complete_normally_nullable
            (message) async {
              emitEvent(
                updateChannel.codec.encodeSuccessEnvelope(
                  'homeWidget://homeWidgetTest',
                ),
              );
              emitEvent(updateChannel.codec.encodeSuccessEnvelope(2));
              emitEvent(updateChannel.codec.encodeSuccessEnvelope(null));
            },
          );

      final expectation = expectLater(
        HomeWidget.widgetClicked,
        emitsInOrder([Uri.parse('homeWidget://homeWidgetTest'), Uri(), null]),
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
          Expanded(child: ColoredBox(color: Colors.red)),
          Expanded(child: ColoredBox(color: Colors.green)),
          Expanded(child: ColoredBox(color: Colors.blue)),
        ],
      ),
    );

    setUp(() {
      final pathProvider = MockPathProvider();
      when(
        () => pathProvider.getApplicationSupportPath(),
      ).thenAnswer((invocation) async => directory.path);
      PathProviderPlatform.instance = pathProvider;
    });

    testGoldens('Render Flutter Widget', (tester) async {
      final byteCompleter = Completer<Uint8List>();
      final file = MockFile();

      when(() => file.exists()).thenAnswer((invocation) async => false);
      when(
        () => file.create(recursive: true),
      ).thenAnswer((invocation) async => file);
      when(() => file.writeAsBytes(any())).thenAnswer((invocation) async {
        byteCompleter.complete(
          Uint8List.fromList(invocation.positionalArguments.first as List<int>),
        );
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
        Image.memory(bytes, width: size.height, height: size.height),
        surfaceSize: size,
      );

      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'render-flutter-widget');
    });

    testGoldens('Error rendering Flutter Widget throws', (tester) async {
      final file = MockFile();
      await IOOverrides.runZoned(
        () async {
          await tester.runAsync(() async {
            expect(
              () async => await HomeWidget.renderFlutterWidget(
                Builder(builder: (_) => const SizedBox()),
                logicalSize: Size.zero,
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

    testGoldens('Error saving Widget throws', (tester) async {
      final file = MockFile();

      when(() => file.exists()).thenAnswer((invocation) async => false);
      when(
        () => file.create(recursive: true),
      ).thenAnswer((invocation) async => file);
      when(
        () => file.writeAsBytes(any()),
      ).thenAnswer((invocation) => Future.error('Error'));

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

  group('saveFile', () {
    final directory = Directory('app/directory');

    setUp(() {
      final pathProvider = MockPathProvider();
      when(
        () => pathProvider.getApplicationSupportPath(),
      ).thenAnswer((invocation) async => directory.path);
      PathProviderPlatform.instance = pathProvider;
    });

    test('writes bytes and saves path to widget data', () async {
      final file = MockFile();
      final payload = Uint8List.fromList([1, 2, 3]);

      when(() => file.exists()).thenAnswer((invocation) async => false);
      when(
        () => file.create(recursive: true),
      ).thenAnswer((invocation) async => file);
      when(() => file.writeAsBytes(any())).thenAnswer((invocation) async {
        expect(invocation.positionalArguments.first, orderedEquals(payload));
        return file;
      });

      await IOOverrides.runZoned(
        () async {
          final path = await HomeWidget.saveFile(
            'myKey',
            payload,
            extension: 'json',
          );
          expect(path, '${directory.path}/home_widget/myKey.json');
          final arguments = await passedArguments.future;
          expect(arguments['id'], 'myKey');
          expect(arguments['data'], path);
        },
        createFile: (path) {
          when(() => file.path).thenReturn(path);
          return file;
        },
      );
    });

    test('passes appGroupId to saved widget path metadata', () async {
      final file = MockFile();
      final payload = Uint8List.fromList([1, 2, 3]);

      when(() => file.exists()).thenAnswer((invocation) async => false);
      when(
        () => file.create(recursive: true),
      ).thenAnswer((invocation) async => file);
      when(
        () => file.writeAsBytes(any()),
      ).thenAnswer((invocation) async => file);

      await IOOverrides.runZoned(
        () async {
          final path = await HomeWidget.saveFile(
            'myKey',
            payload,
            extension: 'json',
            appGroupId: 'group.test.per.call',
          );
          expect(path, '${directory.path}/home_widget/myKey.json');
          final arguments = await passedArguments.future;
          expect(arguments['id'], 'myKey');
          expect(arguments['data'], path);
          expect(arguments['appGroupId'], 'group.test.per.call');
        },
        createFile: (path) {
          when(() => file.path).thenReturn(path);
          return file;
        },
      );
    });

    test('strips leading dot from extension', () async {
      final file = MockFile();
      final payload = Uint8List.fromList([1, 2, 3]);

      when(() => file.exists()).thenAnswer((invocation) async => false);
      when(
        () => file.create(recursive: true),
      ).thenAnswer((invocation) async => file);
      when(() => file.writeAsBytes(any())).thenAnswer((invocation) async {
        return file;
      });

      await IOOverrides.runZoned(
        () async {
          final path = await HomeWidget.saveFile(
            'myKey',
            payload,
            extension: '.json',
          );
          expect(path, '${directory.path}/home_widget/myKey.json');
        },
        createFile: (path) {
          when(() => file.path).thenReturn(path);
          return file;
        },
      );
    });

    test('rejects invalid key', () async {
      expect(() => HomeWidget.saveFile('', Uint8List(0)), throwsArgumentError);
      expect(
        () => HomeWidget.saveFile('../x', Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => HomeWidget.saveFile('a b', Uint8List(0)),
        throwsArgumentError,
      );
    });

    test('rejects invalid extension', () async {
      expect(
        () => HomeWidget.saveFile('k', Uint8List(0), extension: ''),
        throwsArgumentError,
      );
      expect(
        () => HomeWidget.saveFile('k', Uint8List(0), extension: 'a/b'),
        throwsArgumentError,
      );
    });
  });

  group('saveImage', () {
    final directory = Directory('app/directory');

    setUp(() {
      final pathProvider = MockPathProvider();
      when(
        () => pathProvider.getApplicationSupportPath(),
      ).thenAnswer((invocation) async => directory.path);
      PathProviderPlatform.instance = pathProvider;
    });

    testWidgets('encodes ImageProvider to PNG and saves via saveFile', (
      tester,
    ) async {
      final file = MockFile();

      when(() => file.exists()).thenAnswer((invocation) async => false);
      when(
        () => file.create(recursive: true),
      ).thenAnswer((invocation) async => file);
      when(() => file.writeAsBytes(any())).thenAnswer((invocation) async {
        expect(
          (invocation.positionalArguments.first as List<int>).length,
          greaterThan(0),
        );
        return file;
      });

      await IOOverrides.runZoned(
        () async {
          await tester.runAsync(() async {
            final path = await HomeWidget.saveImage(
              'shot',
              MemoryImage(kTestPngBytes),
            );
            expect(path, '${directory.path}/home_widget/shot.png');
            final arguments = await passedArguments.future;
            expect(arguments['id'], 'shot');
            expect(arguments['data'], path);
          });
        },
        createFile: (path) {
          when(() => file.path).thenReturn(path);
          return file;
        },
      );
    });

    testWidgets('propagates error when image bytes cannot be decoded', (
      tester,
    ) async {
      await IOOverrides.runZoned(() async {
        await tester.runAsync(() async {
          await expectLater(
            HomeWidget.saveImage(
              'bad',
              MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3, 4])),
            ),
            throwsA(anything),
          );
        });
      }, createFile: (path) => MockFile());
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
      },
    );

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
      .handlePlatformMessage(updateChannel.name, event, (ByteData? reply) {});
}

Future<void> testCallback(Uri? uri) async {
  debugPrint('Called TestCallback');
}
