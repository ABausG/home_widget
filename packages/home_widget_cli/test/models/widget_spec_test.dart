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

  group('WidgetSpec image fields', () {
    test('default tree renders image fields with HWImage', () {
      final spec = _spec(
        dataFields: const [HWString('label'), HWImageData('avatar')],
      );

      final children = (spec.effectiveWidgetTree as HWColumn).children;
      expect(children.length, 3);
      expect(children[1], isA<HWRow>());
      expect(children[2], isA<HWImage>());
      expect((children[2] as HWImage).dataType.key, 'avatar');
    });

    test('collects image leaves of JSON groups with their storage keys', () {
      final spec = _spec(
        dataFields: const [
          HWJson('contact', HWString('name')),
          HWJson('contact', HWJson('photos', HWImageData('main'))),
          HWTimedData(HWJson('slot', HWImageData('picture'))),
        ],
      );

      expect(
        spec.jsonImageFields.map((f) => f.storageKey).toList(),
        ['contact.photos.main'],
      );
      expect(
        spec.timedJsonImageFields.map((f) => f.storageKey).toList(),
        ['slot.picture'],
      );
      // A JSON leaf is not a root-level image, but it still needs the
      // ImageProvider plumbing in the generated Dart helper.
      expect(spec.imageDataFields, isEmpty);
      expect(spec.hasRuntimeImages, isTrue);
    });

    test('default tree renders a timed image with HWImage', () {
      final spec = _spec(
        dataFields: const [HWTimedData(HWImageData('slide'))],
      );

      final children = (spec.effectiveWidgetTree as HWColumn).children;
      final image = children[1] as HWImage;
      expect(image.imageData, const HWImageData('slide'));
      // The wrapper survives, so the field stays time-based.
      expect(image.dataType, isA<HWTimedData<dynamic>>());
    });

    test('splits runtime and asset images, keeping assets out of storage', () {
      const runtime = HWImageData('avatar');
      const asset = HWImageData.asset('assets/logo.png');
      final spec = _spec(
        dataFields: const [HWString('label'), runtime, asset],
      );

      expect(spec.imageDataFields, equals([runtime, asset]));
      expect(spec.runtimeImageFields, equals([runtime]));
      expect(spec.assetImageFields, equals([asset]));
      // Asset images are read from the app bundle, never stored.
      expect(
        spec.primitiveDataFields,
        equals([const HWString('label'), runtime]),
      );
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

    test('timedImageFields unwraps timed runtime images', () {
      const untimed = HWImageData('avatar');
      const slide = HWImageData('slide');
      final spec = _spec(
        dataFields: const [
          untimed,
          HWTimedData(slide),
          HWTimedData(HWInt('n')),
        ],
      );

      expect(spec.timedImageFields, equals([slide]));
      // A timed image is still an image field, so the Dart helper knows to
      // import ImageProvider for it.
      expect(spec.imageDataFields, equals([untimed, slide]));
      expect(spec.runtimeImageFields, equals([untimed, slide]));
      // ...but never a `saveData` parameter of its own.
      expect(spec.primitiveDataFields, equals(const [untimed]));
      expect(spec.timedPrimitiveDataFields, equals(const [slide, HWInt('n')]));
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

  group('WidgetSpec widget URLs', () {
    WidgetSpec urlSpec({
      String? widgetUrl,
      String? androidWidgetUrl,
      String? iosWidgetUrl,
      bool openAppOnTap = true,
      bool configureAndroid = true,
      bool configureIos = true,
    }) =>
        WidgetSpec(
          data: HomeWidget(
            name: 'UrlWidget',
            widgetUrl: widgetUrl,
            android: configureAndroid
                ? HomeWidgetAndroidConfiguration(
                    widgetUrl: androidWidgetUrl,
                    openAppOnTap: openAppOnTap,
                  )
                : null,
            iOS: configureIos
                ? HomeWidgetIOSConfiguration(
                    groupId: 'group.url',
                    widgetUrl: iosWidgetUrl,
                  )
                : null,
          ),
          className: 'UrlWidget',
        );

    test('no URL configured', () {
      final spec = urlSpec();
      expect(spec.effectiveAndroidWidgetUrl, isNull);
      expect(spec.effectiveIosWidgetUrl, isNull);
      expect(spec.androidWidgetUrl, isNull);
      expect(spec.iosWidgetUrl, isNull);
      expect(spec.hasAndroidWidgetUrl, isFalse);
      expect(spec.hasIosWidgetUrl, isFalse);
      expect(spec.hasWidgetUrl, isFalse);
    });

    test('the top-level URL reaches both platforms', () {
      final spec = urlSpec(widgetUrl: 'myapp://widget');
      expect(spec.effectiveAndroidWidgetUrl, 'myapp://widget');
      expect(spec.effectiveIosWidgetUrl, 'myapp://widget');
      expect(spec.hasWidgetUrl, isTrue);
    });

    test('the top-level URL stays off iOS without an iOS configuration', () {
      final spec = urlSpec(widgetUrl: 'myapp://widget', configureIos: false);
      expect(spec.effectiveAndroidWidgetUrl, 'myapp://widget');
      expect(spec.effectiveIosWidgetUrl, isNull);
      expect(spec.iosWidgetUrl, isNull);
      expect(spec.hasIosWidgetUrl, isFalse);
      expect(spec.hasAndroidWidgetUrl, isTrue);
      expect(spec.hasWidgetUrl, isTrue);
    });

    test('the top-level URL stays off Android without an Android configuration',
        () {
      final spec =
          urlSpec(widgetUrl: 'myapp://widget', configureAndroid: false);
      expect(spec.effectiveIosWidgetUrl, 'myapp://widget');
      expect(spec.effectiveAndroidWidgetUrl, isNull);
      expect(spec.androidWidgetUrl, isNull);
      expect(spec.hasAndroidWidgetUrl, isFalse);
      expect(spec.hasIosWidgetUrl, isTrue);
      expect(spec.hasWidgetUrl, isTrue);
    });

    test('a platform URL wins over the top-level one', () {
      final spec = urlSpec(
        widgetUrl: 'myapp://shared',
        androidWidgetUrl: 'myapp://android',
        iosWidgetUrl: 'myapp://ios',
      );
      expect(spec.effectiveAndroidWidgetUrl, 'myapp://android');
      expect(spec.effectiveIosWidgetUrl, 'myapp://ios');
    });

    test('one platform may override while the other keeps the top-level URL',
        () {
      final spec = urlSpec(
        widgetUrl: 'myapp://shared',
        androidWidgetUrl: 'myapp://android',
      );
      expect(spec.effectiveAndroidWidgetUrl, 'myapp://android');
      expect(spec.effectiveIosWidgetUrl, 'myapp://shared');
      expect(spec.hasAndroidWidgetUrl, isTrue);
      expect(spec.hasIosWidgetUrl, isTrue);
    });

    test('openAppOnTap false drops the Android URL, keeping the iOS one', () {
      final spec = urlSpec(widgetUrl: 'myapp://widget', openAppOnTap: false);
      expect(spec.androidOpensAppOnTap, isFalse);
      expect(spec.androidWidgetUrl, isNull);
      expect(spec.hasAndroidWidgetUrl, isFalse);
      expect(spec.iosWidgetUrl, 'myapp://widget?homeWidget');
      expect(spec.hasWidgetUrl, isTrue);
    });

    test('the homeWidget parameter is appended to a URL without a query', () {
      final spec = urlSpec(widgetUrl: 'myapp://widget');
      expect(spec.androidWidgetUrl, 'myapp://widget?homeWidget');
      expect(spec.iosWidgetUrl, 'myapp://widget?homeWidget');
    });

    test('an existing query is preserved', () {
      final spec = urlSpec(widgetUrl: 'myapp://widget?message=hi%20there');
      expect(
        spec.androidWidgetUrl,
        'myapp://widget?message=hi%20there&homeWidget',
      );
    });

    test('the URL is spliced, not normalized', () {
      final spec = urlSpec(widgetUrl: 'myApp://Widget/Path');
      expect(spec.androidWidgetUrl, 'myApp://Widget/Path?homeWidget');
    });

    test('a fragment stays behind the query', () {
      final spec = urlSpec(widgetUrl: 'myapp://widget?a=b#part');
      expect(spec.iosWidgetUrl, 'myapp://widget?a=b&homeWidget#part');
    });

    test('a URL that already carries the parameter is left untouched', () {
      final flag = urlSpec(widgetUrl: 'myapp://widget?message=hi&homeWidget');
      expect(flag.androidWidgetUrl, 'myapp://widget?message=hi&homeWidget');

      final valued = urlSpec(widgetUrl: 'myapp://widget?homeWidget=1');
      expect(valued.iosWidgetUrl, 'myapp://widget?homeWidget=1');
    });
  });

  group('WidgetSpec flavors', () {
    WidgetSpec flavorSpec({
      String iosGroupId = 'group.base',
      Map<String, HomeWidgetFlavor>? flavors,
    }) =>
        WidgetSpec(
          data: HomeWidget(
            name: 'FlavorWidget',
            android: const HomeWidgetAndroidConfiguration(),
            iOS: HomeWidgetIOSConfiguration(groupId: iosGroupId),
            flavors: flavors,
          ),
          className: 'FlavorWidget',
        );

    test('a widget without flavors declares none', () {
      final spec = flavorSpec();
      expect(spec.declaredFlavors, isEmpty);
      expect(spec.hasFlavors, isFalse);
      expect(spec.flavor('dev'), isNull);
    });

    test('declaredFlavors keeps the declaration order', () {
      final spec = flavorSpec(
        flavors: const {
          'dev': HomeWidgetFlavor(),
          'stg': HomeWidgetFlavor(),
          'prod': HomeWidgetFlavor(),
        },
      );
      expect(spec.declaredFlavors, ['dev', 'stg', 'prod']);
      expect(spec.hasFlavors, isTrue);
      expect(spec.flavor('stg'), const HomeWidgetFlavor());
      expect(spec.flavor('Dev'), isNull);
    });

    test('an empty flavor entry resolves to the base values', () {
      final spec = flavorSpec(flavors: const {'stg': HomeWidgetFlavor()});
      expect(spec.iosGroupIdFor('stg'), 'group.base');
    });

    test('an unknown flavor name falls back to the base values', () {
      final spec = flavorSpec(
        flavors: const {
          'dev': HomeWidgetFlavor(iOS: HomeWidgetIOSFlavor(groupId: 'g.dev')),
        },
      );
      expect(spec.iosGroupIdFor('nope'), 'group.base');
    });

    test('a flavor groupId overrides the base App Group', () {
      final spec = flavorSpec(
        flavors: const {
          'dev': HomeWidgetFlavor(iOS: HomeWidgetIOSFlavor(groupId: 'g.dev')),
          'stg': HomeWidgetFlavor(),
        },
      );
      expect(spec.iosGroupIdFor(null), 'group.base');
      expect(spec.iosGroupIdFor('dev'), 'g.dev');
      expect(spec.iosGroupIdFor('stg'), 'group.base');
    });
  });

  group('WidgetSpec.nativeHelpers', () {
    List<String> namesOf(WidgetSpec spec) =>
        spec.nativeHelpers.map((h) => h.name).toList();

    test('a widget with no numbers and no dates needs none', () {
      final spec = _spec(
        dataFields: const [HWString('label')],
        widgetTree: const HWText(HWString('label')),
      );
      expect(spec.nativeHelpers, isEmpty);
    });

    test('a decimal number pulls in the locale helper it calls', () {
      expect(
        namesOf(_spec(widgetTree: const HWText(HWInt('count')))),
        ['hwFormatLocale', 'hwFormatDecimal'],
      );
      expect(
        namesOf(_spec(widgetTree: const HWText(HWDouble('ratio')))),
        ['hwFormatLocale', 'hwFormatDecimal'],
      );
      expect(
        namesOf(_spec(widgetTree: const HWText.fixedNumber(1))),
        ['hwFormatLocale', 'hwFormatDecimal'],
      );
      expect(
        namesOf(
          _spec(
            widgetTree: const HWText.number(
              HWInt('c'),
              format: HWNumberFormat.compact(),
            ),
          ),
        ),
        ['hwFormatLocale', 'hwFormatCompact'],
      );
    });

    test('a date pulls in the parser, the zone resolver and the format', () {
      expect(
        namesOf(
          _spec(
            dataFields: const [HWDateTime('when')],
            widgetTree: const HWText(HWDateTime('when')),
          ),
        ),
        [
          'hwFormatLocale',
          'hwParseIsoDate',
          'hwResolveTimeZone',
          'hwFormatDateStyled',
        ],
      );
    });

    test('a date nobody renders still needs the parser', () {
      final spec = _spec(
        dataFields: const [HWDateTime('when')],
        widgetTree: const HWDataExists(
          data: HWDateTime('when'),
          whenPresent: HWText.fixed('soon'),
          whenAbsent: HWText.fixed('never'),
        ),
      );
      expect(namesOf(spec), ['hwParseIsoDate']);
    });

    test('a number reached only through a container or a branch counts', () {
      final nested = _spec(
        widgetTree: const HWColumn(
          children: [
            HWPadding(
              padding: HWEdgeInsets.all(4),
              child: HWDataExists(
                data: HWString('label'),
                whenPresent: HWText.fixed('none'),
                whenAbsent: HWText(HWInt('count')),
              ),
            ),
          ],
        ),
      );
      expect(namesOf(nested), ['hwFormatLocale', 'hwFormatDecimal']);

      final adaptive = _spec(
        widgetTree: const HWAdaptive(
          ios: HWText.fixed('x'),
          android: HWText(HWDateTime('when')),
        ),
      );
      expect(
        namesOf(adaptive),
        [
          'hwFormatLocale',
          'hwParseIsoDate',
          'hwResolveTimeZone',
          'hwFormatDateStyled',
        ],
      );
    });

    test('a number that never reaches a text needs no helpers', () {
      final spec = _spec(
        dataFields: const [HWInt('count')],
        widgetTree: const HWText.fixed('static'),
      );
      expect(spec.nativeHelpers, isEmpty);
    });

    test('every helper comes after the ones it calls', () {
      final spec = _spec(
        dataFields: const [HWInt('count'), HWDateTime('when')],
      );
      final ordered = spec.nativeHelpers;
      for (var i = 0; i < ordered.length; i++) {
        for (final dependency in ordered[i].dependencies) {
          expect(
            ordered.sublist(0, i),
            contains(dependency),
            reason: '${ordered[i].name} before ${dependency.name}',
          );
        }
      }
      expect(ordered.map((h) => h.name).toSet(), hasLength(ordered.length));
    });

    test('a tree using every helper resolves all of them, deps first', () {
      final spec = _spec(
        dataFields: const [HWDateTime('when'), HWString('zone')],
        widgetTree: const HWColumn(
          children: [
            HWText.number(HWInt('count')),
            HWText.number(
              HWDouble('share'),
              format: HWNumberFormat.percent(),
            ),
            HWText.number(
              HWDouble('total'),
              format: HWNumberFormat.currency(
                currency: HWCurrency.code('EUR'),
              ),
            ),
            HWText.number(HWInt('views'), format: HWNumberFormat.compact()),
            HWText.number(
              HWInt('id'),
              format: HWNumberFormat.pattern('0'),
            ),
            HWText.dateTime(HWDateTime('when'), format: HWDateFormat.yMMMd),
            HWText.dateTime(
              HWDateTime('when'),
              format: HWDateFormat.pattern('dd.MM.yyyy'),
              timeZone: HWTimeZone.data(HWString('zone')),
            ),
            HWText.dateTime(
              HWDateTime('when'),
              format: HWDateFormat.styled(date: HWFormatStyle.long),
            ),
          ],
        ),
      );

      final ordered = spec.nativeHelpers;
      expect(ordered.toSet(), HWNativeHelper.values.toSet());
      expect(ordered, hasLength(HWNativeHelper.values.length));
      for (var i = 0; i < ordered.length; i++) {
        for (final dependency in ordered[i].dependencies) {
          expect(
            ordered.sublist(0, i),
            contains(dependency),
            reason: '${ordered[i].name} before ${dependency.name}',
          );
        }
      }
    });

    test('the default tree surfaces the declared number and date fields', () {
      final spec =
          _spec(dataFields: const [HWInt('count'), HWDateTime('when')]);
      expect(
        namesOf(spec),
        [
          'hwFormatLocale',
          'hwFormatDecimal',
          'hwParseIsoDate',
          'hwResolveTimeZone',
          'hwFormatDateStyled',
        ],
      );
    });

    test('every spelling of a date field asks for the parser', () {
      for (final field in const <HWDataType<dynamic>>[
        HWDateTime('when'),
        HWTimedData(HWDateTime('next')),
        HWJson('event', HWDateTime('start')),
        HWTimedData(HWJson('slot', HWDateTime('at'))),
      ]) {
        final spec = _spec(
          dataFields: [const HWString('label'), field],
          widgetTree: const HWText.fixed('static'),
        );
        expect(namesOf(spec), ['hwParseIsoDate'], reason: '$field');
      }
    });

    test('a date field the widget never renders still has to be parsed', () {
      final spec = _spec(
        dataFields: const [HWDateTime('when')],
        widgetTree: const HWText.fixed('static'),
      );
      expect(namesOf(spec), ['hwParseIsoDate']);
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

  group('WidgetSpec.dataFields', () {
    test('folds two declarations of one key into a single field', () {
      final spec = _spec(
        dataFields: const [
          HWString('title', defaultValue: 'Hello'),
          HWString('title', previewValue: 'Preview'),
        ],
      );

      expect(spec.declaredDataFields, hasLength(2));
      expect(spec.dataFields, hasLength(1));
      final merged = spec.dataFields.single as HWString;
      expect(merged.defaultValue, 'Hello');
      expect(merged.previewValue, 'Preview');
    });

    test('keeps first-seen order across merges', () {
      final spec = _spec(
        dataFields: const [
          HWString('title'),
          HWInt('count', defaultValue: 1),
          HWString('title', previewValue: 'Preview'),
        ],
      );

      expect(spec.dataFields.map((f) => f.key), ['title', 'count']);
    });

    test('merges the leaf of a JSON path', () {
      final spec = _spec(
        dataFields: const [
          HWJson('profile', HWString('name', defaultValue: 'Anon')),
          HWJson(
            'profile',
            HWString('name', defaultValue: 'Anon', previewValue: 'Ada'),
          ),
        ],
      );

      expect(spec.dataFields, hasLength(1));
      final leaf = (spec.dataFields.single as HWJson).leafType as HWString;
      expect(leaf.defaultValue, 'Anon');
      expect(leaf.previewValue, 'Ada');
    });

    test('leaves a JSON leaf apart when only one side declares a defaultValue',
        () {
      final spec = _spec(
        dataFields: const [
          HWJson('profile', HWString('name', defaultValue: 'Anon')),
          HWJson('profile', HWString('name', previewValue: 'Ada')),
        ],
      );

      expect(spec.dataFields, hasLength(2));
    });

    test('merges the data of a time-based field', () {
      final spec = _spec(
        dataFields: const [
          HWTimedData(HWInt('score', defaultValue: 0)),
          HWTimedData(HWInt('score', previewValue: 42)),
        ],
      );

      expect(spec.dataFields, hasLength(1));
      final inner = spec.dataFields.single.unwrapped as HWInt;
      expect(inner.defaultValue, 0);
      expect(inner.previewValue, 42);
    });

    test('leaves declarations that disagree apart for the validator', () {
      final spec = _spec(
        dataFields: const [
          HWString('title', previewValue: 'A'),
          HWString('title', previewValue: 'B'),
        ],
      );

      expect(
        spec.dataFields.map((f) => (f as HWString).previewValue),
        ['A', 'B'],
      );
    });

    test('a merged JSON group carries one child per path', () {
      final spec = _spec(
        dataFields: const [
          HWJson('profile', HWString('name', defaultValue: 'Anon')),
          HWJson(
            'profile',
            HWString('name', defaultValue: 'Anon', previewValue: 'Ada'),
          ),
          HWJson('profile', HWInt('age', previewValue: 36)),
        ],
      );

      final group = spec.jsonDataGroups.single;
      expect(group.children.map((c) => c.path.single), ['name', 'age']);
      expect((group.children.first.type as HWString).defaultValue, 'Anon');
      expect((group.children.first.type as HWString).previewValue, 'Ada');
    });

    test('a timed JSON group merges its leaf the same way', () {
      final spec = _spec(
        dataFields: const [
          HWTimedData(HWJson('weather', HWString('condition'))),
          HWTimedData(
            HWJson('weather', HWString('condition', previewValue: 'Sunny')),
          ),
        ],
      );

      final group = spec.timedJsonDataGroups.single;
      expect(group.children, hasLength(1));
      expect((group.children.single.type as HWString).previewValue, 'Sunny');
    });

    test('a leaf default set on one side only stays a second child', () {
      // Such a spec never reaches a generator: validateWidgetData reports the
      // conflict off the very children this getter hands its path trie, which
      // is why the two declarations arrive here unmerged.
      final spec = _spec(
        dataFields: const [
          HWJson('profile', HWString('name', defaultValue: 'Anon')),
          HWJson('profile', HWString('name', previewValue: 'Ada')),
        ],
      );

      final group = spec.jsonDataGroups.single;
      expect(group.children.map((c) => c.path.single), ['name', 'name']);
    });
  });

  group('WidgetSpec preview configuration', () {
    test('platform values override the top-level one', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          useLiveDataInPreview: false,
          android: HomeWidgetAndroidConfiguration(
            useLiveDataInPreview: true,
            autoUpdatePreview: false,
          ),
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.t'),
        ),
        className: 'T',
      );

      expect(spec.androidUsesLiveDataInPreview, isTrue);
      expect(spec.iosUsesLiveDataInPreview, isFalse);
      expect(spec.androidAutoUpdatePreview, isFalse);
    });

    test('defaults to live data and automatic registration', () {
      final spec = _spec();
      expect(spec.androidUsesLiveDataInPreview, isTrue);
      expect(spec.iosUsesLiveDataInPreview, isTrue);
      expect(spec.androidAutoUpdatePreview, isTrue);
    });
  });

  group('WidgetSpec.hasPreviewValues', () {
    test('is false without any preview value', () {
      final spec = _spec(
        dataFields: const [HWString('title', defaultValue: 'Hi')],
      );
      expect(spec.hasPreviewValues, isFalse);
    });

    test('finds preview values wherever they are declared', () {
      const fields = <HWDataType<dynamic>>[
        HWString('a', previewValue: 'x'),
        HWDateTime('b', previewValue: '2024-03-08T09:41:00Z'),
        HWImageData('c', previewAsset: 'assets/preview.png'),
        HWJson('d', HWInt('inner', previewValue: 3)),
        HWTimedData(HWDouble('e', previewValue: 1.5)),
        HWString.localized(
          'f',
          defaultTranslations: {'en': 'Hi'},
          previewTranslations: {'en': 'Sample'},
        ),
      ];

      for (final field in fields) {
        expect(
          _spec(dataFields: [field]).hasPreviewValues,
          isTrue,
          reason: '$field',
        );
      }
    });
  });

  group('WidgetSpec.previewAssetImageFields', () {
    test('lists runtime images with a preview asset, nested ones included', () {
      final spec = _spec(
        dataFields: const [
          HWImageData('plain'),
          HWImageData('avatar', previewAsset: 'assets/avatar.png'),
          HWJson('contact', HWImageData('photo', previewAsset: 'assets/p.png')),
          HWTimedData(HWImageData('slide', previewAsset: 'assets/s.png')),
        ],
      );

      expect(
        spec.previewAssetImageFields.map((i) => i.previewAsset),
        ['assets/avatar.png', 'assets/p.png', 'assets/s.png'],
      );
    });
  });

  group('WidgetSpec.previewContentHash', () {
    test('is a stable 8-digit hex digest', () {
      final spec = _spec(dataFields: const [HWString('title')]);
      expect(spec.previewContentHash, matches(RegExp(r'^[0-9a-f]{8}$')));
      final same = _spec(dataFields: const [HWString('title')]);
      expect(spec.previewContentHash, same.previewContentHash);
    });

    test('changes with every value the preview renders', () {
      final base = _spec(dataFields: const [HWString('title')]);

      final variants = <String, WidgetSpec>{
        'previewValue': _spec(
          dataFields: const [HWString('title', previewValue: 'Sample')],
        ),
        'defaultValue': _spec(
          dataFields: const [HWString('title', defaultValue: 'Hi')],
        ),
        'preview asset': _spec(
          dataFields: const [
            HWString('title'),
            HWImageData('a', previewAsset: 'assets/a.png'),
          ],
        ),
        'widget tree': _spec(
          dataFields: const [HWString('title')],
          widgetTree: const HWText.fixed('other'),
        ),
        'preview instant': _spec(
          dataFields: const [
            HWString('title'),
            HWDateTime('when', previewValue: '2024-03-08T09:41:00Z'),
          ],
        ),
      };

      for (final entry in variants.entries) {
        expect(
          entry.value.previewContentHash,
          isNot(base.previewContentHash),
          reason: entry.key,
        );
      }
    });

    test('changes when the preview configuration changes', () {
      final live = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
      );
      final frozen = WidgetSpec(
        data: HomeWidget(name: 'T', useLiveDataInPreview: false),
        className: 'T',
      );

      expect(live.previewContentHash, isNot(frozen.previewContentHash));
    });

    test('ignores the order translations are written in', () {
      WidgetSpec specFor(Map<String, String> preview) => WidgetSpec(
            data: HomeWidget(
              name: 'T',
              localization: const HomeWidgetLocalization(
                defaultLocale: 'en',
                supportedLocales: ['en', 'de'],
              ),
            ),
            className: 'T',
            dataFields: [
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
                previewTranslations: preview,
              ),
            ],
          );

      expect(
        specFor({'en': 'Sample', 'de': 'Beispiel'}).previewContentHash,
        specFor({'de': 'Beispiel', 'en': 'Sample'}).previewContentHash,
      );
    });
  });
}
