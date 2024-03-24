import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Need Group Id', () {
    testWidgets('Save Data needs GroupId', (tester) async {
      expect(
        () async => await HomeWidget.saveWidgetData('AnyId', null),
        throwsException,
      );
    });
  });

  group('With Group Id', () {
    final testData = <String, dynamic>{
      'stringKey': 'stringValue',
      'intKey': 12,
      'boolKey': true,
      'floatingNumberKey': 12.1,
      'nullValueKey': null,
      'uint8ListKey': Uint8List.fromList([]),
    };

    const defaultValue = MapEntry('defaultKey', 'defaultValue');

    setUpAll(() async {
      // Add Group Id
      await HomeWidget.setAppGroupId('group.es.antonborri.integrationtest');
      // Clear all Data
      for (final key in testData.keys) {
        await HomeWidget.saveWidgetData(key, null);
      }
    });

    group('Test Data operations', () {
      for (final testSet in testData.entries) {
        testWidgets('Test ${testSet.value?.runtimeType}', (tester) async {
          // Save Data
          await HomeWidget.saveWidgetData(testSet.key, testSet.value);

          final retrievedData = await HomeWidget.getWidgetData(testSet.key);
          expect(retrievedData, testSet.value);
        });
      }

      testWidgets('Delete Value successful', (tester) async {
        final initialData = await HomeWidget.getWidgetData(testData.keys.first);
        expect(initialData, testData.values.first);

        await HomeWidget.saveWidgetData(testData.values.first, null);

        final deletedData = await HomeWidget.getWidgetData(testData.keys.first);
        expect(deletedData, testData.values.first);
      });

      testWidgets('Returns default Value', (tester) async {
        final returnValue = await HomeWidget.getWidgetData(
          defaultValue.key,
          defaultValue: defaultValue.value,
        );

        expect(returnValue, defaultValue.value);
      });
    });

    testWidgets('Update Widget completes', (tester) async {
      final returnValue = await HomeWidget.updateWidget(
        name: 'HomeWidgetExampleProvider',
        iOSName: 'HomeWidgetExample',
      ).timeout(const Duration(seconds: 5));

      expect(returnValue, true);
    });

    group('Initially Launched', () {
      testWidgets(
          'Initially Launched completes and returns null if not launched from widget',
          (tester) async {
        await HomeWidget.setAppGroupId('group.es.antonborri.integrationtest');
        final retrievedData =
            await HomeWidget.initiallyLaunchedFromHomeWidget();
        expect(retrievedData, isNull);
      });

      group('Register Background Callback', () {
        testWidgets('RegisterBackgroundCallback completes without error',
            (tester) async {
          final deviceInfo = await DeviceInfoPlugin().iosInfo;
          final hasInteractiveWidgets =
              double.parse(deviceInfo.systemVersion.split('.').first) >= 17.0;
          await HomeWidget.setAppGroupId('group.es.antonborri.integrationtest');
          if (hasInteractiveWidgets) {
            final registerCallbackResult =
                await HomeWidget.registerInteractivityCallback(
              interactivityCallback,
            );

            expect(
              registerCallbackResult,
              isTrue,
            );
          } else {
            expect(
              () async => await HomeWidget.registerInteractivityCallback(
                interactivityCallback,
              ),
              throwsA(isA<PlatformException>()),
            );
          }
        });
      });
    });
  });

  testWidgets('Get Installed Widgets returns empty list', (tester) async {
    final retrievedData = await HomeWidget.getInstalledWidgets();
    expect(retrievedData, isEmpty);
  });
}

Future<void> interactivityCallback(Uri? uri) async {}
