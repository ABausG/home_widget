import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final testData = <String, dynamic>{
    'stringKey': 'stringValue',
    'intKey': 12,
    'boolKey': true,
    'floatingNumberKey': 12.1,
    'nullValueKey': null,
  };

  final defaultValue = MapEntry('defaultKey', 'defaultValue');

  setUpAll(() {
    // Clear all Data
    for (final key in testData.keys) {
      HomeWidget.saveWidgetData(key, null);
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
      final returnValue = await HomeWidget.getWidgetData(defaultValue.key,
          defaultValue: defaultValue.value);

      expect(returnValue, defaultValue.value);
    });
  });

  testWidgets('Update Widget completes', (tester) async {
    final returnValue = await HomeWidget.updateWidget(
      name: 'HomeWidgetExampleProvider',
    ).timeout(Duration(seconds: 5));

    expect(returnValue, true);
  });

  testWidgets('Register Background Callback', (tester) async {
    await HomeWidget.registerBackgroundCallback(backgroundCallback);
  });

  testWidgets(
      'Initially Launched completes and returns null if not launched from widget',
      (tester) async {
    final retrievedData = await HomeWidget.initiallyLaunchedFromHomeWidget();
    expect(retrievedData, isNull);
  });
}

void backgroundCallback(Uri? uri) {}
