import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HomeWidget', () {
    test('can be const-constructed with only name', () {
      const annotation = HomeWidget(name: 'Test');
      expect(annotation.name, 'Test');
      expect(annotation.dartOutput, null);
      expect(annotation.android, null);
      expect(annotation.iOS, null);
    });

    test('can be const-constructed with all fields', () {
      const annotation = HomeWidget(
        name: 'Test',
        dartOutput: 'lib/foo.dart',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.example'),
      );
      expect(annotation.name, 'Test');
      expect(annotation.dartOutput, 'lib/foo.dart');
      expect(annotation.android?.packageName, 'com.example');
      expect(annotation.iOS?.groupId, 'group.example');
    });
  });

  group('HomeWidgetAndroidConfiguration', () {
    test('can be const-constructed without packageName', () {
      const config = HomeWidgetAndroidConfiguration();
      expect(config.packageName, null);
    });

    test('can be const-constructed with packageName', () {
      const config = HomeWidgetAndroidConfiguration(packageName: 'com.example');
      expect(config.packageName, 'com.example');
    });

    test('resizeMode and widgetCategory round-trip in equality', () {
      const a = HomeWidgetAndroidConfiguration(
        resizeMode: HWAndroidResizeMode.horizontalAndVertical,
        widgetCategory: HWAndroidWidgetCategory.keyguard,
      );
      const b = HomeWidgetAndroidConfiguration(
        resizeMode: HWAndroidResizeMode.horizontalAndVertical,
        widgetCategory: HWAndroidWidgetCategory.keyguard,
      );
      const c = HomeWidgetAndroidConfiguration(
        resizeMode: HWAndroidResizeMode.none,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('HomeWidgetIOSConfiguration', () {
    test('can be const-constructed with groupId', () {
      const config = HomeWidgetIOSConfiguration(groupId: 'group.example');
      expect(config.groupId, 'group.example');
    });

    test('HomeWidgetIOSConfiguration equality', () {
      const config1 = HomeWidgetIOSConfiguration(groupId: 'group.example');
      const config2 = HomeWidgetIOSConfiguration(groupId: 'group.example');
      const config3 = HomeWidgetIOSConfiguration(groupId: 'group.other');

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });
  });

  group('Equality tests', () {
    test('HomeWidget equality', () {
      const config1 = HomeWidget(
        name: 'Test',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
      );
      const config2 = HomeWidget(
        name: 'Test',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.example'),
      );
      const config3 = HomeWidget(name: 'Other');

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });

    test('HomeWidgetAndroidConfiguration equality', () {
      const config1 =
          HomeWidgetAndroidConfiguration(packageName: 'com.example');
      const config2 =
          HomeWidgetAndroidConfiguration(packageName: 'com.example');
      const config3 = HomeWidgetAndroidConfiguration(packageName: 'com.other');

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });
  });
}
