import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('annotation == (non-identical instances, full field path)', () {
    test('HomeWidgetAndroidConfiguration equal and non-equal', () {
      final a = HomeWidgetAndroidConfiguration(
        minWidth: 1,
        useGlanceTheme: true,
        backgroundColor: const HWDefaultColor(HWColorRole.contentPrimary),
      );
      final b = HomeWidgetAndroidConfiguration(
        minWidth: 1,
        useGlanceTheme: true,
        backgroundColor: const HWDefaultColor(HWColorRole.contentPrimary),
      );
      expect(identical(a, b), isFalse);
      expect(a, b);
      final c = HomeWidgetAndroidConfiguration(
        minWidth: 2,
        useGlanceTheme: true,
        backgroundColor: const HWDefaultColor(HWColorRole.contentPrimary),
      );
      expect(a, isNot(equals(c)));
    });

    test('HomeWidgetIOSConfiguration equal and non-equal', () {
      final a = HomeWidgetIOSConfiguration(
        groupId: 'g',
        backgroundColor: const HWDefaultColor(HWColorRole.contentPrimary),
      );
      final b = HomeWidgetIOSConfiguration(
        groupId: 'g',
        backgroundColor: const HWDefaultColor(HWColorRole.contentPrimary),
      );
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(
        a,
        isNot(
          equals(
            HomeWidgetIOSConfiguration(
              groupId: 'g',
              backgroundColor:
                  const HWDefaultColor(HWColorRole.contentTertiary),
            ),
          ),
        ),
      );
    });

    test('HomeWidget equal and non-equal', () {
      final a = HomeWidget(
        name: 'n',
        description: 'd',
        widget: const HWText.fixed('a'),
      );
      final b = HomeWidget(
        name: 'n',
        description: 'd',
        widget: const HWText.fixed('a'),
      );
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(
        a,
        isNot(
          equals(
            HomeWidget(
              name: 'm',
              description: 'd',
              widget: const HWText.fixed('a'),
            ),
          ),
        ),
      );
    });
  });
}
