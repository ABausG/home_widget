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

  group('format ==/hashCode (non-identical instances, full field path)', () {
    test('HWNumberFormat variants compare by every field', () {
      expect(
        const HWNumberFormat.decimal(minimumFractionDigits: 1),
        const HWNumberFormat.decimal(minimumFractionDigits: 1),
      );
      expect(
        const HWNumberFormat.decimal(minimumFractionDigits: 1).hashCode,
        const HWNumberFormat.decimal(minimumFractionDigits: 1).hashCode,
      );
      expect(
        const HWNumberFormat.decimal(),
        isNot(equals(const HWNumberFormat.decimal(useGrouping: false))),
      );
      expect(
        const HWNumberFormat.decimal(),
        isNot(equals(const HWNumberFormat.decimal(maximumFractionDigits: 2))),
      );

      expect(
        const HWNumberFormat.percent(maximumFractionDigits: 0),
        const HWNumberFormat.percent(maximumFractionDigits: 0),
      );
      expect(
        const HWNumberFormat.percent(),
        isNot(equals(const HWNumberFormat.percent(minimumFractionDigits: 1))),
      );

      expect(
        const HWNumberFormat.compact(),
        const HWNumberFormat.compact(),
      );
      expect(
        const HWNumberFormat.pattern('#0'),
        const HWNumberFormat.pattern('#0'),
      );
      expect(
        const HWNumberFormat.pattern('#0'),
        isNot(equals(const HWNumberFormat.pattern('#0.0'))),
      );
    });

    test('the number format variants never equal one another', () {
      const variants = <HWNumberFormat>[
        HWNumberFormat.decimal(),
        HWNumberFormat.percent(),
        HWNumberFormat.currency(currency: HWCurrency.code('EUR')),
        HWNumberFormat.compact(),
        HWNumberFormat.pattern('#0'),
      ];
      for (var i = 0; i < variants.length; i++) {
        for (var j = 0; j < variants.length; j++) {
          if (i == j) continue;
          expect(variants[i], isNot(equals(variants[j])));
        }
      }
    });

    test('HWCurrency compares by code or by field', () {
      expect(const HWCurrency.code('EUR'), const HWCurrency.code('EUR'));
      expect(
        const HWCurrency.code('EUR').hashCode,
        const HWCurrency.code('EUR').hashCode,
      );
      expect(
        const HWCurrency.code('EUR'),
        isNot(equals(const HWCurrency.code('USD'))),
      );
      expect(
        const HWCurrency.data(HWString('cur')),
        const HWCurrency.data(HWString('cur')),
      );
      expect(
        const HWCurrency.data(HWString('cur')),
        isNot(equals(const HWCurrency.data(HWString('other')))),
      );
      expect(
        const HWCurrency.code('EUR'),
        isNot(equals(const HWCurrency.data(HWString('cur')))),
      );
    });

    test('the currency takes part in the format equality', () {
      expect(
        const HWNumberFormat.currency(
          currency: HWCurrency.code('EUR'),
          decimalDigits: 2,
        ),
        const HWNumberFormat.currency(
          currency: HWCurrency.code('EUR'),
          decimalDigits: 2,
        ),
      );
      expect(
        const HWNumberFormat.currency(currency: HWCurrency.code('EUR')),
        isNot(
          equals(
            const HWNumberFormat.currency(currency: HWCurrency.code('USD')),
          ),
        ),
      );
      expect(
        const HWNumberFormat.currency(currency: HWCurrency.code('EUR')),
        isNot(
          equals(
            const HWNumberFormat.currency(
              currency: HWCurrency.code('EUR'),
              decimalDigits: 2,
            ),
          ),
        ),
      );
    });

    test('HWDateFormat variants compare by every field', () {
      expect(HWDateFormat.yMMMd, const HWDateFormat.skeleton('yMMMd'));
      expect(
        HWDateFormat.yMMMd.hashCode,
        const HWDateFormat.skeleton('yMMMd').hashCode,
      );
      expect(HWDateFormat.yMMMd, isNot(equals(HWDateFormat.yMd)));
      expect(
        const HWDateFormat.pattern('dd'),
        const HWDateFormat.pattern('dd'),
      );
      expect(
        const HWDateFormat.skeleton('dd'),
        isNot(equals(const HWDateFormat.pattern('dd'))),
      );
      expect(
        HWDateFormat.defaultFormat,
        const HWDateFormat.styled(
          date: HWFormatStyle.medium,
          time: HWFormatStyle.short,
        ),
      );
      expect(
        HWDateFormat.defaultFormat,
        isNot(equals(const HWDateFormat.styled(date: HWFormatStyle.medium))),
      );
    });

    test('HWTimeZone compares by variant and by id or field', () {
      expect(HWTimeZone.local, const HWLocalTimeZone());
      expect(HWTimeZone.local.hashCode, const HWLocalTimeZone().hashCode);
      expect(HWTimeZone.utc, const HWTimeZone.named('UTC'));
      expect(
        const HWTimeZone.named('UTC'),
        isNot(equals(const HWTimeZone.named('Europe/Berlin'))),
      );
      expect(
        const HWTimeZone.data(HWString('tz')),
        const HWTimeZone.data(HWString('tz')),
      );
      expect(
        HWTimeZone.local,
        isNot(equals(const HWTimeZone.data(HWString('tz')))),
      );
      expect(HWTimeZone.local, isNot(equals(HWTimeZone.utc)));
    });

    test('none of the format types equal a value of another type', () {
      expect(const HWNumberFormat.compact() == Object(), isFalse);
      expect(HWDateFormat.yMd == Object(), isFalse);
      expect(HWTimeZone.local == Object(), isFalse);
      expect(const HWCurrency.code('EUR') == Object(), isFalse);
    });

    test('hashCode agrees with == for every format variant', () {
      void expectSameHash(Object a, Object b) {
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      }

      expectSameHash(
        HWNumberFormat.percent(maximumFractionDigits: 0),
        HWNumberFormat.percent(maximumFractionDigits: 0),
      );
      expectSameHash(
        HWNumberFormat.currency(
          currency: HWCurrency.code('EUR'),
          decimalDigits: 2,
        ),
        HWNumberFormat.currency(
          currency: HWCurrency.code('EUR'),
          decimalDigits: 2,
        ),
      );
      expectSameHash(HWNumberFormat.compact(), HWNumberFormat.compact());
      expectSameHash(
          HWNumberFormat.pattern('#0'), HWNumberFormat.pattern('#0'));
      expectSameHash(HWDateFormat.pattern('dd'), HWDateFormat.pattern('dd'));
      expectSameHash(
        HWDateFormat.styled(date: HWFormatStyle.full),
        HWDateFormat.styled(date: HWFormatStyle.full),
      );
      expectSameHash(HWTimeZone.named('UTC'), HWTimeZone.named('UTC'));
      expectSameHash(
        HWTimeZone.data(HWString('tz')),
        HWTimeZone.data(HWString('tz')),
      );
      expectSameHash(
        HWCurrency.data(HWString('cur')),
        HWCurrency.data(HWString('cur')),
      );

      expect(
        HWNumberFormat.pattern('#0').hashCode,
        isNot(HWNumberFormat.pattern('#0.0').hashCode),
      );
      expect(
        HWTimeZone.named('UTC').hashCode,
        isNot(HWTimeZone.named('Europe/Berlin').hashCode),
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

  group('flavor annotation ==', () {
    test('HomeWidgetIOSFlavor compares its override', () {
      const a = HomeWidgetIOSFlavor(groupId: 'g');
      expect(a, const HomeWidgetIOSFlavor(groupId: 'g'));
      expect(a.hashCode, const HomeWidgetIOSFlavor(groupId: 'g').hashCode);
      expect(a, isNot(equals(const HomeWidgetIOSFlavor(groupId: 'h'))));
      expect(a, isNot(equals(const HomeWidgetIOSFlavor())));
      expect(const HomeWidgetIOSFlavor(), const HomeWidgetIOSFlavor());
    });

    test('HomeWidgetFlavor compares the nested iOS overrides', () {
      const a =
          HomeWidgetFlavor(iOS: HomeWidgetIOSFlavor(groupId: 'group.dev'));
      const b =
          HomeWidgetFlavor(iOS: HomeWidgetIOSFlavor(groupId: 'group.dev'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          equals(
            const HomeWidgetFlavor(
              iOS: HomeWidgetIOSFlavor(groupId: 'group.stg'),
            ),
          ),
        ),
      );
      expect(const HomeWidgetFlavor(), isNot(equals(a)));
      expect(const HomeWidgetFlavor(), const HomeWidgetFlavor());
    });

    test('HomeWidget equality includes the flavor map', () {
      const dev = HomeWidgetFlavor(iOS: HomeWidgetIOSFlavor(groupId: 'g.dev'));
      HomeWidget make(Map<String, HomeWidgetFlavor>? flavors) =>
          HomeWidget(name: 'n', flavors: flavors);

      final a = make(const {'dev': dev, 'stg': HomeWidgetFlavor()});
      expect(a, make(const {'dev': dev, 'stg': HomeWidgetFlavor()}));
      // A dropped flavor, a renamed one and a changed override all differ.
      expect(a, isNot(equals(make(const {'dev': dev}))));
      expect(
        a,
        isNot(equals(make(const {'dev': dev, 'prod': HomeWidgetFlavor()}))),
      );
      expect(
        a,
        isNot(
          equals(
            make(const {
              'dev': HomeWidgetFlavor(
                iOS: HomeWidgetIOSFlavor(groupId: 'g.stg'),
              ),
              'stg': HomeWidgetFlavor(),
            }),
          ),
        ),
      );
      expect(a, isNot(equals(make(null))));
      expect(make(null), isNot(equals(a)));
      // Literal ordering is not part of the map's identity.
      expect(a, make(const {'stg': HomeWidgetFlavor(), 'dev': dev}));
    });

    test('HomeWidget hashCode ignores flavor ordering', () {
      expect(
        HomeWidget(
          name: 'n',
          flavors: const {
            'dev': HomeWidgetFlavor(iOS: HomeWidgetIOSFlavor(groupId: 'g.dev')),
            'stg': HomeWidgetFlavor(),
          },
        ).hashCode,
        HomeWidget(
          name: 'n',
          flavors: const {
            'stg': HomeWidgetFlavor(),
            'dev': HomeWidgetFlavor(iOS: HomeWidgetIOSFlavor(groupId: 'g.dev')),
          },
        ).hashCode,
      );
      expect(
        HomeWidget(name: 'n').hashCode,
        isNot(
          HomeWidget(
            name: 'n',
            flavors: const {'dev': HomeWidgetFlavor()},
          ).hashCode,
        ),
      );
    });
  });
}
