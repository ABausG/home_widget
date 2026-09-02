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
      const widget = HWText.fixed('a');
      final a = HomeWidget(name: 'n', description: 'd', widget: widget);
      final b = HomeWidget(name: 'n', description: 'd', widget: widget);
      expect(identical(a, b), isFalse);
      expect(a, b);
      // Scalar fields participate.
      expect(
        a,
        isNot(equals(HomeWidget(name: 'm', description: 'd', widget: widget))),
      );
      expect(a, isNot(equals(HomeWidget(name: 'n', widget: widget))));
      expect(
        a,
        isNot(
          equals(
            HomeWidget(
              name: 'n',
              description: 'd',
              widget: widget,
              dartOutput: 'out.dart',
            ),
          ),
        ),
      );
      // The widget tree compares by identity -- HWWidget defines no `==`, so a
      // separately built but structurally identical tree is not equal.
      final other = HWText.fixed('a');
      expect(identical(widget, other), isFalse);
      expect(
        a,
        isNot(equals(HomeWidget(name: 'n', description: 'd', widget: other))),
      );
    });

    test('HomeWidget equality includes widgetUrl', () {
      final a = HomeWidget(name: 'n', widgetUrl: 'myapp://widget');
      expect(a.widgetUrl, 'myapp://widget');
      expect(a, HomeWidget(name: 'n', widgetUrl: 'myapp://widget'));
      expect(
        a.hashCode,
        HomeWidget(name: 'n', widgetUrl: 'myapp://widget').hashCode,
      );
      expect(a, isNot(equals(HomeWidget(name: 'n', widgetUrl: 'myapp://x'))));
      expect(a, isNot(equals(HomeWidget(name: 'n'))));
    });

    test('platform configuration equality includes widgetUrl', () {
      const android = HomeWidgetAndroidConfiguration(widgetUrl: 'myapp://a');
      expect(
        android,
        const HomeWidgetAndroidConfiguration(widgetUrl: 'myapp://a'),
      );
      expect(
        android,
        isNot(
          equals(
            const HomeWidgetAndroidConfiguration(widgetUrl: 'myapp://b'),
          ),
        ),
      );

      const ios =
          HomeWidgetIOSConfiguration(groupId: 'g', widgetUrl: 'myapp://a');
      expect(
        ios,
        const HomeWidgetIOSConfiguration(groupId: 'g', widgetUrl: 'myapp://a'),
      );
      expect(
        ios,
        isNot(
          equals(
            const HomeWidgetIOSConfiguration(
              groupId: 'g',
              widgetUrl: 'myapp://b',
            ),
          ),
        ),
      );
    });

    test('Android configuration equality includes openAppOnTap', () {
      const on = HomeWidgetAndroidConfiguration();
      const off = HomeWidgetAndroidConfiguration(openAppOnTap: false);

      expect(on, const HomeWidgetAndroidConfiguration(openAppOnTap: true));
      expect(
        on.hashCode,
        const HomeWidgetAndroidConfiguration(openAppOnTap: true).hashCode,
      );
      expect(on, isNot(equals(off)));
    });

    test('HomeWidget equality includes localization', () {
      final a = HomeWidget(
        name: 'n',
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      );
      expect(
        a,
        HomeWidget(
          name: 'n',
          localization: const HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            HomeWidget(
              name: 'n',
              localization: const HomeWidgetLocalization(
                defaultLocale: 'de',
                supportedLocales: ['en', 'de'],
              ),
            ),
          ),
        ),
      );
    });
  });

  group('HomeWidgetLocalization ==/hashCode', () {
    HomeWidgetLocalization make({
      String defaultLocale = 'en',
      List<String> supportedLocales = const ['en', 'de'],
      Map<String, String>? name = const {'de': 'Name'},
      Map<String, String>? description = const {'de': 'Beschreibung'},
    }) =>
        HomeWidgetLocalization(
          defaultLocale: defaultLocale,
          supportedLocales: supportedLocales,
          name: name,
          description: description,
        );

    test('non-identical instances with the same fields are equal', () {
      final a = make();
      final b = make();
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('an instance equals itself', () {
      final a = make();
      expect(a == a, isTrue);
    });

    test('is never equal to a value of another type', () {
      expect(make() == Object(), isFalse);
    });

    test('every field participates in equality', () {
      final base = make();
      expect(base, isNot(equals(make(defaultLocale: 'de'))));
      expect(base, isNot(equals(make(supportedLocales: const ['en', 'fr']))));
      expect(base, isNot(equals(make(name: const {'de': 'Andere'}))));
      expect(base, isNot(equals(make(description: const {'de': 'Andere'}))));
    });

    test('supportedLocales compares by length and by order', () {
      final base = make();
      expect(base, isNot(equals(make(supportedLocales: const ['en']))));
      expect(base, isNot(equals(make(supportedLocales: const ['de', 'en']))));
      expect(base, make(supportedLocales: const ['en', 'de']));
    });

    test('an omitted translation map only matches another omitted one', () {
      expect(make(name: null), make(name: null));
      expect(make(name: null), isNot(equals(make())));
      expect(make(), isNot(equals(make(name: null))));
    });

    test('translation maps compare by length, keys and values', () {
      final base = make(name: const {'de': 'Name', 'fr': 'Nom'});
      // Fewer entries.
      expect(base, isNot(equals(make(name: const {'de': 'Name'}))));
      // Same size, different key.
      expect(
        base,
        isNot(equals(make(name: const {'de': 'Name', 'es': 'Nom'}))),
      );
      // Same keys, different value.
      expect(
        base,
        isNot(equals(make(name: const {'de': 'Name', 'fr': 'Autre'}))),
      );
      // Literal ordering is not part of the map's identity.
      expect(base, make(name: const {'fr': 'Nom', 'de': 'Name'}));
    });

    test('hashCode ignores translation ordering', () {
      expect(
        make(name: const {'de': 'Name', 'fr': 'Nom'}).hashCode,
        make(name: const {'fr': 'Nom', 'de': 'Name'}).hashCode,
      );
    });

    test('hashCode tolerates omitted translation maps', () {
      expect(
        make(name: null, description: null).hashCode,
        make(name: null, description: null).hashCode,
      );
      expect(
        make(name: null, description: null).hashCode,
        isNot(make().hashCode),
      );
    });

    test('hashCode distinguishes differing locales', () {
      expect(make().hashCode, isNot(make(defaultLocale: 'de').hashCode));
      expect(
        make().hashCode,
        isNot(make(supportedLocales: const ['en', 'fr']).hashCode),
      );
    });
  });
}
