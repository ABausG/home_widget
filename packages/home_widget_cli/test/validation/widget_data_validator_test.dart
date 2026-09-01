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
  });
}
