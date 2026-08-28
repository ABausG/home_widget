import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

WidgetSpec _spec({
  String name = 'TestWidget',
  List<HWDataType<dynamic>> dataFields = const [],
  HWWidget? widgetTree,
}) {
  return WidgetSpec(
    data: HomeWidget(name: name),
    className: name,
    dataFields: dataFields,
    widgetTree: widgetTree,
  );
}

void main() {
  group('WidgetSpec.effectiveWidgetTree', () {
    test('returns provided widgetTree when set and not HWDataOnly', () {
      final tree = HWText.fixed('hello');
      final spec = _spec(widgetTree: tree);
      expect(identical(spec.effectiveWidgetTree, tree), isTrue);
    });

    test('builds default tree when widgetTree is null', () {
      final spec = _spec(
        name: 'MyWidget',
        dataFields: const [HWString('label'), HWInt('count')],
      );

      final tree = spec.effectiveWidgetTree;
      expect(tree, isA<HWColumn>());
      final children = (tree as HWColumn).children;
      expect(children.length, 3);
      expect(children.first, isA<HWText>());
      expect(children[1], isA<HWRow>());
      expect(children[2], isA<HWRow>());
    });

    test('builds default tree when widgetTree is HWDataOnly', () {
      final spec = _spec(
        widgetTree: const HWDataOnly([]),
        dataFields: const [HWString('label')],
      );
      expect(spec.effectiveWidgetTree, isA<HWColumn>());
    });
  });

  group('WidgetSpec.primitiveDataFields', () {
    test('filters out HWJson fields', () {
      const string = HWString('label');
      const int_ = HWInt('count');
      const json = HWJson('root', HWString('inner'));
      final spec = _spec(dataFields: const [string, int_, json]);

      expect(spec.primitiveDataFields, equals([string, int_]));
    });

    test('returns empty when only HWJson fields are present', () {
      const json = HWJson('root', HWString('inner'));
      final spec = _spec(dataFields: const [json]);
      expect(spec.primitiveDataFields, isEmpty);
    });
  });

  group('WidgetSpec.jsonDataGroups', () {
    test('returns empty when no HWJson fields', () {
      final spec = _spec(dataFields: const [HWString('label')]);
      expect(spec.jsonDataGroups, isEmpty);
    });

    test('groups multiple json fields under the same root key', () {
      const a = HWJson('user', HWString('name'));
      const b = HWJson('user', HWInt('age'));
      final spec = _spec(dataFields: const [a, b]);

      final groups = spec.jsonDataGroups;
      expect(groups.length, 1);
      expect(groups.single.key, 'user');
      expect(groups.single.children.length, 2);
      expect(groups.single.children[0].path, ['name']);
      expect(groups.single.children[1].path, ['age']);
    });

    test('preserves insertion order across distinct root keys', () {
      const a = HWJson('b_root', HWString('x'));
      const b = HWJson('a_root', HWString('y'));
      final spec = _spec(dataFields: const [a, b]);

      final groups = spec.jsonDataGroups;
      expect(groups.map((g) => g.key).toList(), ['b_root', 'a_root']);
    });

    test('deduplicates identical paths with identical leaf types', () {
      const a = HWJson('user', HWString('name'));
      const b = HWJson('user', HWString('name'));
      final spec = _spec(dataFields: const [a, b]);

      final groups = spec.jsonDataGroups;
      expect(groups.single.children.length, 1);
    });

    test('captures nested path segments', () {
      const nested = HWJson('user', HWJson('address', HWString('city')));
      final spec = _spec(dataFields: const [nested]);

      final group = spec.jsonDataGroups.single;
      expect(group.key, 'user');
      expect(group.children.single.path, ['address', 'city']);
    });
  });

  group('WidgetSpec localized strings', () {
    const leaf = HWLocalizedString(
      'name',
      defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
    );
    const top = HWLocalizedString(
      'greeting',
      defaultTranslations: {'en': 'Hi', 'de': 'Hi'},
    );

    test('surfaces localized JSON leaves alongside top-level fields', () {
      final spec = _spec(
        dataFields: const [top, HWJson('profile', leaf)],
      );

      expect(spec.localizedStrings, const [top]);
      expect(spec.jsonLocalizedStrings, const [leaf]);
      expect(spec.allLocalizedStrings, const [top, leaf]);
    });

    test('a JSON leaf needs the resolver but not the blob reader', () {
      final spec = _spec(dataFields: const [HWJson('profile', leaf)]);

      expect(spec.needsLocaleHelpers, isTrue);
      expect(spec.needsLocalizedRead, isFalse);
      expect(spec.rendersLocalizedContent, isTrue);
      // A JSON leaf is never a data field of its own.
      expect(spec.keyedLocalizedStrings, isEmpty);
    });

    test('a plain JSON leaf pulls in nothing', () {
      final spec = _spec(dataFields: const [HWJson('profile', HWString('a'))]);

      expect(spec.jsonLocalizedStrings, isEmpty);
      expect(spec.needsLocaleHelpers, isFalse);
      expect(spec.rendersLocalizedContent, isFalse);
    });

    test('surfaces a timed localized field without keying it', () {
      final spec = _spec(dataFields: const [HWTimedData(top)]);

      expect(spec.timedLocalizedStrings, const [top]);
      expect(spec.allLocalizedStrings, const [top]);
      // Its value arrives inside the timed entry, so the per-key blob read
      // must stay out of the generated code...
      expect(spec.localizedStrings, isEmpty);
      expect(spec.keyedLocalizedStrings, isEmpty);
      expect(spec.needsLocalizedRead, isFalse);
      // ...while the resolver, the locale argument and the re-render on a
      // language change are all still needed.
      expect(spec.needsTimedLocalizedRead, isTrue);
      expect(spec.resolvesLocalizedOnRead, isTrue);
      expect(spec.needsLocaleHelpers, isTrue);
      expect(spec.rendersLocalizedContent, isTrue);
    });

    test('surfaces a localized leaf of a timed JSON group', () {
      final spec =
          _spec(dataFields: const [HWTimedData(HWJson('profile', leaf))]);

      expect(spec.timedJsonLocalizedStrings, const [leaf]);
      expect(spec.allLocalizedStrings, const [leaf]);
      // A leaf is never a data field of its own, timed or not, so nothing
      // reads a stored translation map for it.
      expect(spec.jsonLocalizedStrings, isEmpty);
      expect(spec.timedLocalizedStrings, isEmpty);
      expect(spec.needsTimedLocalizedRead, isFalse);
      expect(spec.resolvesLocalizedOnRead, isFalse);
      expect(spec.needsLocaleHelpers, isTrue);
      expect(spec.rendersLocalizedContent, isTrue);
    });

    test('an untimed keyed string keeps driving the per-key read', () {
      final spec = _spec(dataFields: const [top, HWTimedData(HWInt('count'))]);

      expect(spec.keyedLocalizedStrings, const [top]);
      expect(spec.needsLocalizedRead, isTrue);
      expect(spec.needsTimedLocalizedRead, isFalse);
      expect(spec.resolvesLocalizedOnRead, isTrue);
    });

    test('a plain timed field pulls in nothing', () {
      final spec = _spec(dataFields: const [HWTimedData(HWString('label'))]);

      expect(spec.allLocalizedStrings, isEmpty);
      expect(spec.needsLocaleHelpers, isFalse);
      expect(spec.resolvesLocalizedOnRead, isFalse);
      expect(spec.rendersLocalizedContent, isFalse);
    });
  });

  group('WidgetSpec gallery text', () {
    WidgetSpec gallerySpec({
      String name = 'Greeting',
      String? description,
      HomeWidgetLocalization? localization,
    }) =>
        WidgetSpec(
          data: HomeWidget(
            name: name,
            description: description,
            localization: localization,
          ),
          className: 'Greeting',
        );

    test('the default-locale entry outranks the top-level text', () {
      final spec = gallerySpec(
        description: 'Base',
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
          name: {'en': 'Daily greeting', 'de': 'Begruessung'},
          description: {'en': 'Shows a greeting', 'de': 'Zeigt etwas'},
        ),
      );

      expect(spec.galleryName, 'Daily greeting');
      expect(spec.galleryDescription, 'Shows a greeting');
    });

    test('falls back to the top-level text', () {
      final spec = gallerySpec(
        description: 'Base',
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
          name: {'de': 'Begruessung'},
        ),
      );

      expect(spec.galleryName, 'Greeting');
      expect(spec.galleryDescription, 'Base');
    });

    test('reports no description when neither source has one', () {
      expect(gallerySpec().galleryDescription, isNull);
    });

    test('galleryTranslations drops the default locale', () {
      final spec = gallerySpec(
        localization: const HomeWidgetLocalization(
          defaultLocale: 'en',
          supportedLocales: ['en', 'de'],
        ),
      );

      expect(
        spec.galleryTranslations(const {'en': 'Greeting', 'de': 'Gruss'}),
        const {'de': 'Gruss'},
      );
      expect(spec.galleryTranslations(null), isNull);
    });
  });

  group('WidgetSpec timed data', () {
    test('timedPrimitiveDataFields unwraps non-json timed fields', () {
      const label = HWString('label');
      const count = HWInt('count');
      final spec = _spec(
        dataFields: const [
          HWString('plain'),
          HWTimedData(label),
          HWTimedData(count),
          HWTimedData(HWJson('weather', HWString('condition'))),
        ],
      );

      expect(spec.timedPrimitiveDataFields, equals([label, count]));
      expect(spec.primitiveDataFields, equals(const [HWString('plain')]));
    });

    // One HWTimedData declaration per JSON root: two of them sharing a root are
    // rejected by validateWidgetData, so nested paths are the only way down.
    test('timedJsonDataGroups groups timed json fields by root key', () {
      final spec = _spec(
        dataFields: const [
          HWTimedData(HWJson('weather', HWJson('wind', HWInt('speed')))),
          HWTimedData(HWJson('other', HWString('x'))),
        ],
      );

      final groups = spec.timedJsonDataGroups;
      expect(groups.map((g) => g.key).toList(), ['weather', 'other']);
      expect(groups.first.children.single.path, ['wind', 'speed']);
      expect(groups.last.children.single.path, ['x']);
    });

    test('timed json groups do not leak into jsonDataGroups', () {
      final spec = _spec(
        dataFields: const [
          HWTimedData(HWJson('weather', HWString('condition'))),
        ],
      );

      expect(spec.jsonDataGroups, isEmpty);
      expect(spec.timedJsonDataGroups, hasLength(1));
    });

    test('returns empty timed collections without timed fields', () {
      final spec = _spec(
        dataFields: const [
          HWString('label'),
          HWJson('root', HWString('inner')),
        ],
      );

      expect(spec.timedDataFields, isEmpty);
      expect(spec.timedPrimitiveDataFields, isEmpty);
      expect(spec.timedJsonDataGroups, isEmpty);
    });
  });

  group('WidgetSpec equality', () {
    test('equal specs are equal and share hashCode', () {
      final a = _spec();
      final b = _spec();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different className breaks equality', () {
      final a = _spec(name: 'A');
      final b = _spec(name: 'B');
      expect(a, isNot(equals(b)));
    });
  });
}
