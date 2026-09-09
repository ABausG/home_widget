import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('validateWidgetData', () {
    test('rejects Kotlin-reserved identifiers for JSON roots (e.g. file)', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('file', HWString('title')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"file"'),
              contains('Kotlin'),
            ),
          ),
        ),
      );
    });

    test('accepts a widget URL on every level', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          widgetUrl: 'myapp://widget',
          android: HomeWidgetAndroidConfiguration(
            widgetUrl: 'myapp://widget/android?a=b',
          ),
          iOS: HomeWidgetIOSConfiguration(
            groupId: 'group.t',
            widgetUrl: 'myapp://widget/ios#part',
          ),
        ),
        className: 'T',
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('rejects an empty widget URL', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T', widgetUrl: '   '),
        className: 'T',
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(contains('"T"'), contains('widgetUrl'), contains('empty')),
          ),
        ),
      );
    });

    test('names the platform of an empty widget URL', () {
      final android = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          android: HomeWidgetAndroidConfiguration(widgetUrl: ''),
        ),
        className: 'T',
      );
      expect(
        () => validateWidgetData(android),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('Android widgetUrl'),
          ),
        ),
      );

      final ios = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          iOS: HomeWidgetIOSConfiguration(groupId: 'group.t', widgetUrl: ''),
        ),
        className: 'T',
      );
      expect(
        () => validateWidgetData(ios),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('iOS widgetUrl'),
          ),
        ),
      );
    });

    test('rejects a widget URL that cannot be parsed', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T', widgetUrl: 'my app://:://not a url'),
        className: 'T',
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('is not a valid URL'),
          ),
        ),
      );
    });

    test('rejects a widget URL without a scheme', () {
      for (final url in ['details', '/details', '//host/details']) {
        final spec = WidgetSpec(
          data: HomeWidget(name: 'T', widgetUrl: url),
          className: 'T',
        );

        expect(
          () => validateWidgetData(spec),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('is not a valid URL'),
                contains('absolute URI'),
                contains('myapp://details'),
              ),
            ),
          ),
          reason: url,
        );
      }
    });

    test('rejects a scheme-less widget URL on every platform', () {
      final android = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          android: HomeWidgetAndroidConfiguration(widgetUrl: 'details'),
        ),
        className: 'T',
      );
      expect(
        () => validateWidgetData(android),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('Android widgetUrl'),
          ),
        ),
      );

      final ios = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          iOS: HomeWidgetIOSConfiguration(
            groupId: 'group.t',
            widgetUrl: 'details',
          ),
        ),
        className: 'T',
      );
      expect(
        () => validateWidgetData(ios),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('iOS widgetUrl'),
          ),
        ),
      );
    });

    test('accepts an absolute widget URL with a scheme', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T', widgetUrl: 'myapp://details'),
        className: 'T',
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('accepts flavors overriding the platforms the widget configures', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          android: const HomeWidgetAndroidConfiguration(),
          iOS: const HomeWidgetIOSConfiguration(groupId: 'group.t'),
          flavors: const {
            'dev': HomeWidgetFlavor(
              iOS: HomeWidgetIOSFlavor(groupId: 'group.dev'),
            ),
            'stg': HomeWidgetFlavor(),
          },
        ),
        className: 'T',
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('throws when the flavor map is empty', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T', flavors: const {}),
        className: 'T',
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"T"'),
              contains('flavors is empty'),
              contains('no flavor'),
            ),
          ),
        ),
      );
    });

    test('throws when a flavor name is blank', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          flavors: const {'  ': HomeWidgetFlavor()},
        ),
        className: 'T',
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(contains('"T"'), contains('flavor name is empty')),
          ),
        ),
      );
    });

    test('throws when a flavor overrides iOS on a widget without iOS', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          android: const HomeWidgetAndroidConfiguration(),
          flavors: const {
            'dev': HomeWidgetFlavor(
              iOS: HomeWidgetIOSFlavor(groupId: 'group.dev'),
            ),
          },
        ),
        className: 'T',
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"dev"'),
              contains('iOS overrides'),
              contains('HomeWidgetIOSConfiguration'),
            ),
          ),
        ),
      );
    });

    test('throws when a flavor groupId is empty', () {
      final spec = WidgetSpec(
        data: HomeWidget(
          name: 'T',
          iOS: const HomeWidgetIOSConfiguration(groupId: 'group.t'),
          flavors: const {
            'dev': HomeWidgetFlavor(iOS: HomeWidgetIOSFlavor(groupId: '  ')),
          },
        ),
        className: 'T',
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"dev"'),
              contains('empty iOS groupId'),
            ),
          ),
        ),
      );
    });

    test('accepts image fields with distinct derived keys', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWImageData('avatar'),
          HWImageData.asset('assets/logo.png'),
          HWImageData.asset('assets/icons/logo.png'),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('throws when two asset paths derive the same image key', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWImageData.asset('assets/logo.png'),
          HWImageData.asset('assets-logo.png'),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"assetsLogoPng"'),
              contains('assets/logo.png'),
              contains('assets-logo.png'),
            ),
          ),
        ),
      );
    });

    test('names the package when a package asset collides', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWImageData.asset('assets/logo.png', package: 'my_icons'),
          // Different package spelling, same derived key.
          HWImageData.asset('packages/my-icons/assets/logo.png'),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"packagesMyIconsAssetsLogoPng"'),
              contains('asset "assets/logo.png" of package "my_icons"'),
              contains('asset "packages/my-icons/assets/logo.png"'),
            ),
          ),
        ),
      );
    });

    test('accepts a package asset and its manual packages/ spelling', () {
      // Both spell the same asset, so the shared key is not a conflict.
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWImageData.asset('assets/logo.png', package: 'my_icons'),
          HWImageData.asset('packages/my_icons/assets/logo.png'),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('throws when a runtime image key collides with an asset key', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWImageData('assetsLogoPng'),
          HWImageData.asset('assets/logo.png'),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('runtime image "assetsLogoPng"'),
          ),
        ),
      );
    });

    test('rejects identifiers with underscores', () {
      void expectRejected(String key) {
        final spec = WidgetSpec(
          data: HomeWidget(name: 'T'),
          className: 'T',
          dataFields: [HWString(key)],
        );
        expect(
          () => validateWidgetData(spec),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              contains('letters and digits'),
            ),
          ),
          reason: key,
        );
      }

      expectRejected('_private');
      expectRejected('foo_bar');
    });

    test('throws on reserved identifiers for primitive keys', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: [
          HWString('let'),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('reserved keyword in Swift'),
          ),
        ),
      );
    });

    test('allows duplicate identical JSON declarations', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('fileKey', HWString('title')),
          HWJson('fileKey', HWString('title')),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('throws on conflicting leaf types at the same JSON path', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('fileKey', HWString('enabled')),
          HWJson('fileKey', HWBool('enabled', defaultValue: false)),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('throws on scalar vs nested object at same JSON segment', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('fileKey', HWString('user')),
          HWJson(
            'fileKey',
            HWJson('user', HWBool('enabled', defaultValue: true)),
          ),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('throws when data name is empty', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: [
          HWString(''),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('reports multiple platforms for cross-language reserved names', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: [
          HWString('class'),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf([
              contains('"class"'),
              contains('Dart'),
              contains('Swift'),
              contains('Kotlin'),
            ]),
          ),
        ),
      );
    });

    test('throws when nested JSON path collides with primitive at same segment',
        () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson(
            'fileKey',
            HWJson('user', HWBool('enabled', defaultValue: true)),
          ),
          HWJson('fileKey', HWString('user')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('rejects the reserved "timedData" key when the spec has timed fields',
        () {
      void expectRejected(List<HWDataType<dynamic>> fields) {
        final spec = WidgetSpec(
          data: HomeWidget(name: 'T'),
          className: 'T',
          dataFields: fields,
        );

        expect(
          () => validateWidgetData(spec),
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('"timedData"'),
                contains('reserved'),
              ),
            ),
          ),
          reason: '$fields',
        );
      }

      expectRejected(const [
        HWTimedData(HWString('label')),
        HWString('timedData'),
      ]);
      expectRejected(const [
        HWTimedData(HWString('label')),
        HWJson('timedData', HWString('title')),
      ]);
      expectRejected(const [HWTimedData(HWString('timedData'))]);
    });

    test('allows the "timedData" key when the spec has no timed fields', () {
      void expectAccepted(List<HWDataType<dynamic>> fields) {
        final spec = WidgetSpec(
          data: HomeWidget(name: 'T'),
          className: 'T',
          dataFields: fields,
        );

        expect(
          () => validateWidgetData(spec),
          returnsNormally,
          reason: '$fields',
        );
      }

      expectAccepted(const [HWString('timedData')]);
      expectAccepted(const [HWJson('timedData', HWString('title'))]);
    });

    test('rejects the same key used as timed and untimed data', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWTimedData(HWString('label')),
          HWString('label', defaultValue: 'x'),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"label"'),
              contains('HWTimedData'),
            ),
          ),
        ),
      );
    });

    test('rejects a JSON root key that is also used as timed data', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWTimedData(HWJson('weather', HWString('condition'))),
          HWJson('weather', HWString('condition')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('"weather"'),
          ),
        ),
      );
    });

    test('merges two timed declarations of the same JSON root', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWTimedData(HWJson('weather', HWString('condition'))),
          HWTimedData(HWJson('weather', HWInt('temperature'))),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
      expect(spec.timedJsonDataGroups, hasLength(1));
      expect(
        spec.timedJsonDataGroups.single.children.map((c) => c.path),
        [
          ['condition'],
          ['temperature'],
        ],
      );
    });

    test('rejects conflicting paths under a merged timed JSON root', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWTimedData(HWJson('weather', HWString('wind'))),
          HWTimedData(HWJson('weather', HWJson('wind', HWInt('speed')))),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Conflicting JSON paths in JSON group "weather"'),
              contains('already mapped to a primitive leaf'),
            ),
          ),
        ),
      );
    });

    test('allows one timed declaration with a nested JSON path', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWTimedData(HWJson('weather', HWJson('wind', HWInt('speed')))),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('rejects HWTimedData nested inside HWJson', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('weather', HWTimedData(HWString('condition'))),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            'HWTimedData must be a root-level data field and cannot be nested '
                'inside HWJson.',
          ),
        ),
      );
    });

    test('rejects a timed asset image', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWTimedData(HWImageData.asset('assets/logo.png')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(
                'HWTimedData cannot wrap HWImageData.asset("assets/logo.png")',
              ),
              contains('an asset ships with the app and never changes'),
            ),
          ),
        ),
      );
    });

    test('allows a timed runtime image', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [HWTimedData(HWImageData('slide'))],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('allows a runtime image at a JSON leaf, timed or not', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('profile', HWJson('user', HWImageData('avatar'))),
          HWTimedData(HWJson('slot', HWImageData('picture'))),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('rejects an asset image at a JSON leaf', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('profile', HWImageData.asset('assets/logo.png')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(
                'HWJson cannot carry HWImageData.asset("assets/logo.png")',
              ),
              contains('"profile"'),
            ),
          ),
        ),
      );
    });

    test('allows timed and untimed fields with distinct keys', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWString('title'),
          HWTimedData(HWString('label')),
          HWTimedData(HWJson('weather', HWString('condition'))),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('validates identifiers inside timed data fields', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWTimedData(HWJson('weather', HWString('foo_bar'))),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('letters and digits'),
          ),
        ),
      );
    });

    // A time-based localized field is the only localized content in these
    // specs, so the locale map is checked only if the timed wrapper is seen
    // through.
    test('validates the locale map of a timed localized field', () {
      WidgetSpec specFor(HWDataType<dynamic> field) => WidgetSpec(
            data: const HomeWidget(
              name: 'T',
              localization: HomeWidgetLocalization(
                defaultLocale: 'en',
                supportedLocales: ['en', 'de'],
              ),
            ),
            className: 'T',
            dataFields: [field],
          );

      const incomplete = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello'},
      );
      expect(
        () => validateWidgetData(specFor(const HWTimedData(incomplete))),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('missing translations for de'),
          ),
        ),
      );

      expect(
        () => validateWidgetData(
          specFor(const HWTimedData(HWJson('weather', incomplete))),
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('missing translations for de'),
          ),
        ),
      );

      expect(
        () => validateWidgetData(
          specFor(
            const HWTimedData(
              HWLocalizedString(
                'greeting',
                defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('requires a localization block for a timed localized field', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWTimedData(
            HWLocalizedString(
              'greeting',
              defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
            ),
          ),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('has no localization'),
          ),
        ),
      );
    });

    test('throws when duplicate JSON leaves differ only by default value', () {
      final spec = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWJson('fileKey', HWString('leaf', defaultValue: 'a')),
          HWJson('fileKey', HWString('leaf', defaultValue: 'b')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('rejects HWDataExists over a localized string', () {
      const localized = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      );
      const tree = HWDataExists(
        data: localized,
        whenPresent: HWText.fixed('present'),
        whenAbsent: HWText.fixed('absent'),
      );
      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'T',
          widget: tree,
          localization: HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
          ),
        ),
        className: 'T',
        dataFields: const [localized],
        widgetTree: tree,
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('HWDataExists cannot test HWString.localized'),
              contains('its compiled default'),
              contains('plain HWString'),
            ),
          ),
        ),
      );
    });

    test('rejects HWDataExists over a timed localized string', () {
      const localized = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      );
      const timed = HWTimedData(localized);
      const tree = HWDataExists(
        data: timed,
        whenPresent: HWText.fixed('present'),
        whenAbsent: HWText.fixed('absent'),
      );
      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'T',
          widget: tree,
          localization: HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
          ),
        ),
        className: 'T',
        dataFields: const [timed],
        widgetTree: tree,
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('HWDataExists cannot test HWString.localized'),
              contains('"greeting"'),
              contains('its compiled default'),
            ),
          ),
        ),
      );
    });

    test('finds a nested HWDataExists over a localized string', () {
      const localized = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      );
      const tree = HWColumn(
        children: [
          HWText.fixed('header'),
          HWPadding(
            padding: HWEdgeInsets.all(4),
            child: HWDataExists(
              data: localized,
              whenPresent: HWText.fixed('present'),
              whenAbsent: HWText.fixed('absent'),
            ),
          ),
        ],
      );
      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'T',
          widget: tree,
          localization: HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
          ),
        ),
        className: 'T',
        dataFields: const [localized],
        widgetTree: tree,
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            contains('HWDataExists cannot test'),
          ),
        ),
      );
    });

    test('throws when one key is declared with two different types', () {
      const localized = HWLocalizedString(
        'greeting',
        defaultTranslations: {'en': 'Hello', 'de': 'Hallo'},
      );
      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'T',
          localization: HomeWidgetLocalization(
            defaultLocale: 'en',
            supportedLocales: ['en', 'de'],
          ),
        ),
        className: 'T',
        dataFields: const [HWString('greeting'), localized],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('"greeting"'),
              contains('HWString'),
              contains('HWString.localized'),
            ),
          ),
        ),
      );
    });

    test('throws when one key is declared as both primitive and JSON', () {
      final spec = WidgetSpec(
        data: const HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWString('profile'),
          HWJson('profile', HWString('title')),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(contains('"profile"'), contains('HWJson')),
          ),
        ),
      );
    });

    test('throws when one key carries two different defaults', () {
      final spec = WidgetSpec(
        data: const HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWInt('count', defaultValue: 1),
          HWInt('count', defaultValue: 2),
        ],
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(contains('"count"'), contains('defaultValue')),
          ),
        ),
      );
    });

    test('allows identical duplicates and JSON groups sharing a root key', () {
      final spec = WidgetSpec(
        data: const HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [
          HWString('title'),
          HWString('title'),
          HWJson('profile', HWString('first')),
          HWJson('profile', HWString('last')),
        ],
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('rejects HWDataExists over an asset image', () {
      const asset = HWImageData.asset('assets/logo.png');
      const tree = HWDataExists(
        data: asset,
        whenPresent: HWImage.asset('assets/logo.png'),
        whenAbsent: HWText.fixed('absent'),
      );
      final spec = WidgetSpec(
        data: const HomeWidget(name: 'T', widget: tree),
        className: 'T',
        dataFields: const [asset],
        widgetTree: tree,
      );

      expect(
        () => validateWidgetData(spec),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('HWDataExists cannot test HWImageData.asset'),
              contains('assets/logo.png'),
              contains('HWImage.asset'),
            ),
          ),
        ),
      );
    });

    test('allows HWDataExists over a runtime image', () {
      const tree = HWDataExists(
        data: HWImageData('avatar'),
        whenPresent: HWImage(HWImageData('avatar')),
        whenAbsent: HWText.fixed('absent'),
      );
      final spec = WidgetSpec(
        data: const HomeWidget(name: 'T', widget: tree),
        className: 'T',
        dataFields: const [HWImageData('avatar')],
        widgetTree: tree,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('allows HWDataExists over a plain HWString', () {
      const tree = HWDataExists(
        data: HWString('greeting'),
        whenPresent: HWText.fixed('present'),
        whenAbsent: HWText.fixed('absent'),
      );
      final spec = WidgetSpec(
        data: const HomeWidget(name: 'T', widget: tree),
        className: 'T',
        dataFields: const [HWString('greeting')],
        widgetTree: tree,
      );

      expect(() => validateWidgetData(spec), returnsNormally);
    });

    test('allows a number bound to HWText.number, however it is wrapped', () {
      expect(
        () => validateWidgetData(_spec(const HWText.number(HWInt('steps')))),
        returnsNormally,
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText.number(HWTimedData(HWDouble('progress')))),
        ),
        returnsNormally,
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText.number(HWJson('stats', HWInt('steps')))),
        ),
        returnsNormally,
      );
    });

    test('allows a date bound to HWText.dateTime, however it is wrapped', () {
      expect(
        () => validateWidgetData(
          _spec(const HWText.dateTime(HWDateTime('lastSync'))),
        ),
        returnsNormally,
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText.dateTime(HWTimedData(HWDateTime('slot')))),
        ),
        returnsNormally,
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText.dateTime(HWJson('event', HWDateTime('startsAt')))),
        ),
        returnsNormally,
      );
    });

    test('allows a date bound to a plain HWText', () {
      expect(
        () => validateWidgetData(_spec(const HWText(HWDateTime('lastSync')))),
        returnsNormally,
      );
    });

    test('validates the key of an HWDateTime like any other field', () {
      expect(
        () => validateWidgetData(
          _spec(const HWText.dateTime(HWDateTime('class'))),
        ),
        _throwsMessage(
          allOf(contains('Invalid data name "class"'), contains('Dart')),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(const HWText.dateTime(HWJson('event', HWDateTime('1st')))),
        ),
        _throwsMessage(contains('Invalid data name "1st"')),
      );
    });

    test('rejects negative fraction digits', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWInt('steps'),
              format: HWNumberFormat.decimal(minimumFractionDigits: -1),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWNumberFormat.decimal'),
            contains('minimumFractionDigits -1'),
            contains('cannot be negative'),
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWInt('steps'),
              format: HWNumberFormat.percent(maximumFractionDigits: -2),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWNumberFormat.percent'),
            contains('maximumFractionDigits -2'),
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWInt('steps'),
              format: HWNumberFormat.currency(
                currency: HWCurrency.code('EUR'),
                decimalDigits: -1,
              ),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWNumberFormat.currency'),
            contains('decimalDigits -1'),
          ),
        ),
      );
    });

    test('rejects a minimum fraction digit count above the maximum', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.fixedNumber(
              1,
              format: HWNumberFormat.decimal(
                minimumFractionDigits: 3,
                maximumFractionDigits: 2,
              ),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('minimumFractionDigits 3'),
            contains('maximumFractionDigits 2'),
          ),
        ),
      );

      expect(
        () => validateWidgetData(
          _spec(
            const HWText.fixedNumber(
              1,
              format: HWNumberFormat.decimal(
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects an empty number pattern', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWInt('steps'),
              format: HWNumberFormat.pattern('  '),
            ),
          ),
        ),
        _throwsMessage(
          allOf(contains('HWNumberFormat.pattern is empty'), contains('#,##0')),
        ),
      );

      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWInt('steps'),
              format: HWNumberFormat.pattern('#,##0.00'),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects a currency code that is not three upper-case ASCII letters',
        () {
      for (final code in ['', 'EU', 'EURO', 'EU1', '€€€', 'eur', 'Eur']) {
        expect(
          () => validateWidgetData(
            _spec(
              HWText.number(
                const HWInt('total'),
                format: HWNumberFormat.currency(
                  currency: HWCurrency.code(code),
                ),
              ),
            ),
          ),
          _throwsMessage(
            allOf(
              contains('HWCurrency.code("$code")'),
              contains('ISO 4217'),
              contains('upper-case'),
            ),
          ),
          reason: 'accepted "$code"',
        );
      }

      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWInt('total'),
              format: HWNumberFormat.currency(
                currency: HWCurrency.code('EUR'),
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('allows a currency code read from a plain string field', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWDouble('total'),
              format: HWNumberFormat.currency(
                currency: HWCurrency.data(HWJson('cart', HWString('currency'))),
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects a localized currency code', () {
      final tree = HWText.number(
        const HWDouble('total'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(
            HWString.localized(
              'currency',
              defaultTranslations: const {'en': 'EUR'},
            ),
          ),
        ),
      );

      expect(
        () => validateWidgetData(
          _spec(
            tree,
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: ['en'],
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWCurrency.data("currency") reads a localized string'),
            contains('plain HWString'),
          ),
        ),
      );
    });

    test('rejects an empty date skeleton or pattern', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              format: HWDateFormat.skeleton(''),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWDateFormat.skeleton is empty'),
            contains('yMMMd'),
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              format: HWDateFormat.pattern('   '),
            ),
          ),
        ),
        _throwsMessage(contains('HWDateFormat.pattern is empty')),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              format: HWDateFormat.pattern('dd.MM.yyyy'),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects a styled date format with neither a date nor a time', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              format: HWDateFormat.styled(),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWDateFormat.styled'),
            contains('neither a date nor a time style'),
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              format: HWDateFormat.styled(time: HWFormatStyle.short),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects an empty time zone id', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              timeZone: HWTimeZone.named(' '),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWTimeZone.named is empty'),
            contains('Europe/Berlin'),
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              timeZone: HWTimeZone.utc,
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('allows a time zone read from a plain string field', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              timeZone: HWTimeZone.data(HWTimedData(HWString('zone'))),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects a time zone read from a localized field', () {
      final localized = HWText.dateTime(
        const HWDateTime('startsAt'),
        timeZone: HWTimeZone.data(
          HWString.localized(
            'zone',
            defaultTranslations: const {'en': 'Europe/Berlin'},
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            localized,
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: ['en'],
            ),
          ),
        ),
        _throwsMessage(
          contains('HWTimeZone.data("zone") reads a localized string'),
        ),
      );
    });

    test('points a rejected placeholder at the formatting texts', () {
      final tree = HWText(
        HWString.localized(
          'summary',
          defaultTranslations: const {'en': 'Steps: {count}'},
        ),
      );

      expect(
        () => validateWidgetData(
          _spec(
            tree,
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: ['en'],
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('contains a placeholder'),
            contains('HWText.number'),
            contains('HWText.dateTime'),
            isNot(contains('format the string in your app')),
          ),
        ),
      );
    });
  });
}

/// A spec whose data fields are exactly what [tree] binds, the way the parser
/// builds one.
WidgetSpec _spec(HWWidget tree, {HomeWidgetLocalization? localization}) =>
    WidgetSpec(
      data: HomeWidget(name: 'T', widget: tree, localization: localization),
      className: 'T',
      dataFields: tree.dataDependencies.toList(),
      widgetTree: tree,
    );

Matcher _throwsMessage(Matcher message) => throwsA(
      isA<GeneratorError>().having((e) => e.message, 'message', message),
    );
