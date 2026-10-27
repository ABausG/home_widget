import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late String? originalGroup;
  setUp(() => originalGroup = HomeWidget.groupId);
  tearDown(() {
    HomeWidget.groupId = originalGroup;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'storage preserves binary bytes and null deletion on the wire',
    () async {
      final calls = <MethodCall>[];
      final bytes = Uint8List.fromList([0, 127, 128, 255]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'getWidgetData' ? bytes : true;
      });
      expect(await HomeWidget.saveWidgetData('binary', bytes), true);
      expect(calls.last.arguments, {'id': 'binary', 'data': bytes});
      expect(await HomeWidget.getWidgetData<Uint8List>('binary'), bytes);
      expect(await HomeWidget.saveWidgetData('binary', null), true);
      expect(calls.last.method, 'saveWidgetData');
      expect(calls.last.arguments, {'id': 'binary', 'data': null});
    },
  );

  test('missing storage value preserves typed defaults and null', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.arguments['defaultValue'],
    );
    expect(await HomeWidget.getWidgetData<int>('missing'), isNull);
    expect(
      await HomeWidget.getWidgetData<int>('missing', defaultValue: 42),
      42,
    );
    expect(
      await HomeWidget.getWidgetData<bool>('missing', defaultValue: false),
      false,
    );
  });

  test(
    'refresh keeps legacy ios key and forwards both name candidates',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      for (final iosName in <String?>[null, '', 'SpecificKind']) {
        expect(
          await HomeWidget.updateWidget(name: 'FallbackKind', iOSName: iosName),
          true,
        );
        expect(calls.last.method, 'updateWidget');
        expect(calls.last.arguments, {
          'name': 'FallbackKind',
          'android': null,
          'ios': iosName,
          'qualifiedAndroidName': null,
        });
      }
    },
  );

  test('public calls propagate platform errors with details intact', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: '-9',
        message: 'Group denied',
        details: 'group.denied',
      );
    });
    final operations = <Future<Object?> Function()>[
      () => HomeWidget.saveWidgetData('key', 'value'),
      () => HomeWidget.getWidgetData<String>('key'),
      () => HomeWidget.updateWidget(name: 'Kind'),
      () => HomeWidget.getInstalledWidgets(),
      () => HomeWidget.initiallyLaunchedFromHomeWidget(),
      () => HomeWidget.setAppGroupId('group.denied'),
    ];
    for (final operation in operations) {
      await expectLater(
        operation(),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', '-9')
              .having((e) => e.message, 'message', 'Group denied')
              .having((e) => e.details, 'details', 'group.denied'),
        ),
      );
    }
  });

  test('unimplemented native calls preserve MissingPluginException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('Unavailable in this host');
    });
    await expectLater(
      HomeWidget.updateWidget(name: 'Kind'),
      throwsA(isA<MissingPluginException>()),
    );
    await expectLater(
      HomeWidget.getInstalledWidgets(),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
