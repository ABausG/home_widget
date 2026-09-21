import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

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

    test('accepts an icon field whose enum is well formed', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWIconData.resolved(
              'mood',
              entries: [
                HWIconEntry('happy', 0xE88A),
                HWIconEntry('sad', 0xE25B),
              ],
              iconFont: HWIconFont(family: 'BrandIcons'),
            ),
          ]),
        ),
        returnsNormally,
      );
    });

    test('rejects an icon field naming one icon twice', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWIconData.resolved(
              'mood',
              entries: [
                HWIconEntry('happy', 0xE88A),
                HWIconEntry('happy', 0xE25B),
              ],
              iconFont: HWIconFont(family: 'BrandIcons'),
            ),
          ]),
        ),
        _throwsMessage(allOf(contains('"mood"'), contains('"happy"'))),
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

    test('throws on JSON path segments the generated class already declares',
        () {
      for (final key in [
        'toJson',
        'hashCode',
        'toString',
        'runtimeType',
        'noSuchMethod',
      ]) {
        final spec = WidgetSpec(
          data: HomeWidget(name: 'T'),
          className: 'T',
          dataFields: [HWJson('group', HWString(key))],
        );

        expect(
          () => validateWidgetData(spec),
          _throwsMessage(
            'Invalid data name "$key" (JSON path segment in "group"): the '
            'generated data class already has a member named "$key".',
          ),
          reason: key,
        );
      }

      final nested = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [HWJson('group', HWJson('toJson', HWString('a')))],
      );
      expect(
        () => validateWidgetData(nested),
        _throwsMessage(contains('(JSON path segment in "group")')),
      );

      final allowed = WidgetSpec(
        data: HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [HWJson('group', HWString('fromJson'))],
      );
      expect(() => validateWidgetData(allowed), returnsNormally);
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

    test('accepts a compact number format', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWInt('steps'),
              format: HWNumberFormat.compact(),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects a currency code read from a field that is not text', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWDouble('total'),
              format: HWNumberFormat.currency(
                currency: HWCurrency.data(HWImageData('logo')),
              ),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWCurrency.data needs an HWString'),
            contains('"logo" is HWImageData'),
            contains('An ISO 4217 code is stored as text'),
          ),
        ),
      );
    });

    test('names the JSON leaf when a time zone reads a non-text path', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.dateTime(
              HWDateTime('startsAt'),
              format: HWDateFormat.skeleton('yMMMd'),
              timeZone: HWTimeZone.data(HWJson('trip', HWImageData('zone'))),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWTimeZone.data needs an HWString'),
            contains('"trip" is HWImageData at its JSON leaf'),
          ),
        ),
      );
    });

    test('rejects empty supportedLocales', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi'},
              ),
            ],
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: [],
            ),
          ),
        ),
        _throwsMessage(contains('supportedLocales must not be empty')),
      );
    });

    test('rejects two locales mapping to one Dart identifier', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              HWString.localized(
                'title',
                defaultTranslations: const {
                  'en': 'Hi',
                  'pt-BR': 'Oi',
                  'pt_BR': 'Oi',
                },
              ),
            ],
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: ['en', 'pt-BR', 'pt_BR'],
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('locales "pt-BR" and "pt_BR"'),
            contains('Dart identifier "ptBR"'),
          ),
        ),
      );
    });

    test('names HWText.localized when a constant map misses a locale', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              // ignore: invalid_use_of_internal_member
              const HWLocalizedString.resolved(
                '',
                defaultTranslations: {'en': 'Hi'},
                isConstant: true,
                defaultLocale: 'en',
              ),
            ],
            localization: _localization,
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWText.localized in "T"'),
            contains('de'),
          ),
        ),
      );
    });

    test('rejects a key declared both time-based and as a constant string', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              const HWTimedData(HWInt('steps')),
              // ignore: invalid_use_of_internal_member
              const HWLocalizedString.resolved(
                'steps',
                defaultTranslations: {'en': 'Hi', 'de': 'Hallo'},
                isConstant: true,
                defaultLocale: 'en',
              ),
            ],
            localization: _localization,
          ),
        ),
        _throwsMessage(
          allOf(
            contains('Conflicting data name "steps"'),
            contains('HWTimedData'),
          ),
        ),
      );
    });
  });

  group('merging duplicate declarations', () {
    test('accepts a default and a preview value written apart', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWString('title', defaultValue: 'Hello'),
            HWString('title', previewValue: 'Sample'),
          ]),
        ),
        returnsNormally,
      );
    });

    test('accepts them at a JSON leaf', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWJson('profile', HWString('name', defaultValue: 'Anon')),
            HWJson(
              'profile',
              HWString('name', defaultValue: 'Anon', previewValue: 'Ada'),
            ),
          ]),
        ),
        returnsNormally,
      );
    });

    test('accepts them on a time-based field', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWTimedData(HWInt('score', defaultValue: 0)),
            HWTimedData(HWInt('score', previewValue: 42)),
          ]),
        ),
        returnsNormally,
      );
    });

    test('rejects two different preview values, naming key and both', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWString('title', previewValue: 'A'),
            HWString('title', previewValue: 'B'),
          ]),
        ),
        _throwsMessage(
          allOf(
            contains('"title"'),
            contains('previewValue: "A"'),
            contains('previewValue: "B"'),
          ),
        ),
      );
    });

    test('rejects two different default values, naming both', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWInt('count', defaultValue: 1),
            HWInt('count', defaultValue: 2),
          ]),
        ),
        _throwsMessage(
          allOf(
            contains('"count"'),
            contains('defaultValue: 1'),
            contains('defaultValue: 2'),
          ),
        ),
      );
    });

    test('rejects two different preview assets for one image key', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWImageData('avatar', previewAsset: 'assets/a.png'),
            HWImageData('avatar', previewAsset: 'assets/b.png'),
          ]),
        ),
        _throwsMessage(
          allOf(
            contains('"avatar"'),
            contains('previewAsset: "assets/a.png"'),
            contains('previewAsset: "assets/b.png"'),
          ),
        ),
      );
    });

    test('rejects two different preview values at a JSON leaf', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWJson('profile', HWString('name', previewValue: 'Ada')),
            HWJson('profile', HWString('name', previewValue: 'Grace')),
          ]),
        ),
        _throwsMessage(
          allOf(
            contains('profile'),
            contains('preview="Ada"'),
            contains('preview="Grace"'),
          ),
        ),
      );
    });

    test('rejects two different preview translations', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
                previewTranslations: const {'en': 'A', 'de': 'A'},
              ),
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
                previewTranslations: const {'en': 'B', 'de': 'B'},
              ),
            ],
            localization: _localization,
          ),
        ),
        _throwsMessage(
          allOf(
            contains('"title"'),
            contains('different previewTranslations'),
          ),
        ),
      );
    });

    test('still rejects a timed and an untimed declaration of one key', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWInt('score', defaultValue: 0),
            HWTimedData(HWInt('score')),
          ]),
        ),
        _throwsMessage(contains('"score"')),
      );
    });

    test('still rejects a localized and a plain declaration of one key', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              const HWString('title'),
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
              ),
            ],
            localization: _localization,
          ),
        ),
        _throwsMessage(contains('"title"')),
      );
    });

    test('still rejects a JSON leaf clashing with nested JSON', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWJson('profile', HWString('name')),
            HWJson('profile', HWJson('name', HWString('first'))),
          ]),
        ),
        _throwsMessage(contains('Conflicting JSON paths')),
      );
    });

    test('still rejects two types at one JSON leaf', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWJson('profile', HWString('name')),
            HWJson('profile', HWInt('name')),
          ]),
        ),
        _throwsMessage(contains('conflicting leaves')),
      );
    });

    test('reports previewTranslations when a localized key clashes', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
                previewTranslations: const {'en': 'Sample', 'de': 'Beispiel'},
              ),
              const HWInt('title'),
            ],
            localization: _localization,
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWString.localized(previewTranslations: '),
            contains('HWInt'),
          ),
        ),
      );
    });

    test('reports a plain image field when its key clashes', () {
      expect(
        () => validateWidgetData(
          _declaring(const [HWImageData('logo'), HWInt('logo')]),
        ),
        _throwsMessage(
          allOf(
            contains('the key "logo" is declared as HWImageData and HWInt'),
            isNot(contains('previewAsset')),
          ),
        ),
      );
    });

    test('reports a preview instant as its ISO text when a key clashes', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWDateTime('at', previewValue: '2024-03-08T09:41:00Z'),
            HWInt('at'),
          ]),
        ),
        _throwsMessage(
          contains('HWDateTime(previewValue: "2024-03-08T09:41:00Z")'),
        ),
      );
    });
  });

  group('JSON leaf defaults', () {
    // Every site rendering a JSON path inlines the leaf's default behind the
    // read, so two declarations of one path describe the same leaf only when
    // their defaults agree; a preview value still merges across them.
    HWDataType<dynamic> leafOf(WidgetSpec spec, {bool timed = false}) {
      final groups = timed ? spec.timedJsonDataGroups : spec.jsonDataGroups;
      return groups.single.children.single.type;
    }

    test('rejects a default declared on one side only', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWJson('profile', HWString('name', defaultValue: 'Anon')),
            HWJson('profile', HWString('name')),
          ]),
        ),
        _throwsMessage(
          allOf(
            contains('"profile"'),
            contains('conflicting leaves at "name"'),
            contains('default=Anon'),
            contains('no default'),
          ),
        ),
      );
    });

    test('accepts the same default on both sides', () {
      final spec = _declaring(const [
        HWJson('profile', HWString('name', defaultValue: 'Anon')),
        HWJson('profile', HWString('name', defaultValue: 'Anon')),
      ]);

      expect(() => validateWidgetData(spec), returnsNormally);
      expect((leafOf(spec) as HWString).defaultValue, 'Anon');
    });

    test('merges a preview value declared on one side only', () {
      final spec = _declaring(const [
        HWJson('profile', HWString('name')),
        HWJson('profile', HWString('name', previewValue: 'Ada')),
      ]);

      expect(() => validateWidgetData(spec), returnsNormally);
      final leaf = leafOf(spec) as HWString;
      expect(leaf.defaultValue, isNull);
      expect(leaf.previewValue, 'Ada');
    });

    test('rejects a default declared on one side only of a timed group', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWTimedData(
              HWJson('weather', HWString('condition', defaultValue: 'Sun')),
            ),
            HWTimedData(HWJson('weather', HWString('condition'))),
          ]),
        ),
        _throwsMessage(
          allOf(
            contains('"weather"'),
            contains('conflicting leaves at "condition"'),
            contains('default=Sun'),
            contains('no default'),
          ),
        ),
      );
    });

    test('accepts the same default on both sides of a timed group', () {
      final spec = _declaring(const [
        HWTimedData(
          HWJson('weather', HWString('condition', defaultValue: 'Sun')),
        ),
        HWTimedData(
          HWJson('weather', HWString('condition', defaultValue: 'Sun')),
        ),
      ]);

      expect(() => validateWidgetData(spec), returnsNormally);
      expect((leafOf(spec, timed: true) as HWString).defaultValue, 'Sun');
    });

    test('merges a preview value across a timed group', () {
      final spec = _declaring(const [
        HWTimedData(HWJson('weather', HWString('condition'))),
        HWTimedData(
          HWJson('weather', HWString('condition', previewValue: 'Sunny')),
        ),
      ]);

      expect(() => validateWidgetData(spec), returnsNormally);
      expect((leafOf(spec, timed: true) as HWString).previewValue, 'Sunny');
    });

    test('applies one level deeper down a nested path', () {
      expect(
        () => validateWidgetData(
          _declaring(const [
            HWJson(
              'profile',
              HWJson('user', HWString('name', defaultValue: 'Anon')),
            ),
            HWJson('profile', HWJson('user', HWString('name'))),
          ]),
        ),
        _throwsMessage(
          allOf(
            contains('conflicting leaves at "user.name"'),
            contains('default=Anon'),
            contains('no default'),
          ),
        ),
      );

      final merged = _declaring(const [
        HWJson(
          'profile',
          HWJson('user', HWString('name', defaultValue: 'Anon')),
        ),
        HWJson(
          'profile',
          HWJson(
            'user',
            HWString('name', defaultValue: 'Anon', previewValue: 'Ada'),
          ),
        ),
      ]);

      expect(() => validateWidgetData(merged), returnsNormally);
      final leaf = leafOf(merged) as HWString;
      expect(leaf.defaultValue, 'Anon');
      expect(leaf.previewValue, 'Ada');
    });
  });

  group('preview values', () {
    test('rejects a preview instant that is not ISO 8601', () {
      expect(
        () => validateWidgetData(
          _declaring(const [HWDateTime('startsAt', previewValue: 'tomorrow')]),
        ),
        _throwsMessage(
          allOf(contains('"startsAt"'), contains('"tomorrow"')),
        ),
      );
    });

    test('rejects it at a JSON leaf and inside a timed field too', () {
      const nested = <HWDataType<dynamic>>[
        HWJson('event', HWDateTime('at', previewValue: 'nope')),
        HWTimedData(HWDateTime('at', previewValue: 'nope')),
      ];
      for (final field in nested) {
        expect(
          () => validateWidgetData(_declaring([field])),
          _throwsMessage(contains('"nope"')),
          reason: '$field',
        );
      }
    });

    test('accepts a parseable preview instant', () {
      expect(
        () => validateWidgetData(
          _declaring(
            const [
              HWDateTime('startsAt', previewValue: '2024-03-08T09:41:00Z'),
            ],
          ),
        ),
        returnsNormally,
      );
    });

    test('requires previewTranslations to cover every supported locale', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
                previewTranslations: const {'en': 'Sample'},
              ),
            ],
            localization: _localization,
          ),
        ),
        _throwsMessage(
          allOf(
            contains('previewTranslations'),
            contains('missing translations for de'),
          ),
        ),
      );
    });

    test('rejects an empty previewTranslations map', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
                previewTranslations: const {},
              ),
            ],
            localization: _localization,
          ),
        ),
        _throwsMessage(
          allOf(
            contains('previewTranslations'),
            contains('locale map is empty'),
          ),
        ),
      );
    });

    test('rejects a preview locale outside supportedLocales', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
                previewTranslations: const {'en': 'A', 'de': 'B', 'fr': 'C'},
              ),
            ],
            localization: _localization,
          ),
        ),
        _throwsMessage(
          allOf(contains('previewTranslations'), contains('"fr"')),
        ),
      );
    });

    test('validates previewTranslations of timed and JSON strings alike', () {
      final fields = <HWDataType<dynamic>>[
        HWTimedData(
          HWString.localized(
            'title',
            defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
            previewTranslations: const {'en': 'Sample'},
          ),
        ),
        HWJson(
          'group',
          HWString.localized(
            'title',
            defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
            previewTranslations: const {'en': 'Sample'},
          ),
        ),
      ];

      for (final field in fields) {
        expect(
          () => validateWidgetData(
            _declaring([field], localization: _localization),
          ),
          _throwsMessage(contains('previewTranslations')),
          reason: '$field',
        );
      }
    });

    test('accepts complete previewTranslations', () {
      expect(
        () => validateWidgetData(
          _declaring(
            [
              HWString.localized(
                'title',
                defaultTranslations: const {'en': 'Hi', 'de': 'Hallo'},
                previewTranslations: const {'en': 'Sample', 'de': 'Beispiel'},
              ),
            ],
            localization: _localization,
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects a stack Glance would drop children of', () {
      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'T',
          android: HomeWidgetAndroidConfiguration(),
        ),
        className: 'T',
        widgetTree: HWColumn(
          children: [
            for (var index = 0; index < 11; index++) HWText.fixed('$index'),
          ],
        ),
      );
      expect(
        () => validateWidgetData(spec),
        _throwsMessage(contains('an HWColumn has 11 children')),
      );
    });
  });

  group('lists', () {
    test('accepts a list whose item mixes item and root fields', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWColumn(
              children: [
                HWText(HWString('label')),
                HWRow.builder(
                  'forecast',
                  maxItems: 5,
                  item: HWColumn(
                    children: [
                      HWText(HWItemData(HWString('label'))),
                      HWText(HWString('unit')),
                    ],
                  ),
                  whenEmpty: HWText(HWString('placeholder')),
                ),
              ],
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects an item field read outside the item of a builder', () {
      expect(
        () => validateWidgetData(
          _spec(const HWText(HWItemData(HWString('label')))),
        ),
        _throwsMessage(
          'Widget "T": HWItemData(HWString(\'label\')) reads the item a '
          'builder is rendering, so it only works inside the item of an '
          'HWColumn.builder or HWRow.builder.',
        ),
      );
    });

    test('rejects one read by whenEmpty or data-only outside the item', () {
      final trees = <HWWidget, String>{
        const HWRow.builder(
          'forecast',
          item: HWText.fixed('item'),
          whenEmpty: HWText.number(HWItemData(HWInt('count'))),
        ): "HWItemData(HWInt('count'))",
        HWDataOnly([
          HWTimedData(
            HWItemData(
              HWString.localized(
                'note',
                defaultTranslations: const {'en': 'x'},
              ),
            ),
          ),
        ]): "HWTimedData(HWItemData(HWString.localized('note')))",
      };

      for (final MapEntry(key: tree, value: spelled) in trees.entries) {
        expect(
          () => validateWidgetData(_spec(tree)),
          _throwsMessage(startsWith('Widget "T": $spelled reads the item')),
        );
      }
    });

    test('reports a stray item field before the key it shares', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWColumn(
              children: [
                HWText(HWString('label')),
                HWText.number(HWItemData(HWInt('label'))),
              ],
            ),
          ),
        ),
        _throwsMessage(contains('reads the item a builder is rendering')),
      );
    });

    test('rejects a list read both time-based and not', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWSizeAdaptive(
              small: HWRow.builder(
                'hourly',
                item: HWText.number(
                  HWTimedData(HWItemData(HWInt('temperature'))),
                ),
              ),
              large: HWColumn.builder(
                'hourly',
                item: HWText(HWItemData(HWString('label'))),
              ),
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": the list "hourly" is read both time-based '
          '(temperature) and not (label). A list is time-based as a whole: '
          'wrap every item field of "hourly" in HWTimedData, or none.',
        ),
      );
    });

    test('accepts a list read time-based throughout', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'hourly',
              item: HWColumn(
                children: [
                  HWText.number(HWTimedData(HWItemData(HWInt('temperature')))),
                  HWText(HWTimedData(HWItemData(HWString('label')))),
                ],
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('validates a list key like a data key', () {
      expect(
        () => validateWidgetData(
          _spec(const HWRow.builder('class', item: HWText.fixed('x'))),
        ),
        _throwsMessage(
          'Invalid data name "class" (list "class"): reserved keyword in '
          'Dart, Kotlin and Swift.',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(const HWRow.builder('my-list', item: HWText.fixed('x'))),
        ),
        _throwsMessage(
          'Invalid data name "my-list" (list "my-list"): use ASCII letters and '
          'digits only; must start with a letter.',
        ),
      );
    });

    test('rejects a list key the item class already declares', () {
      for (final key in ['toJson', 'hashCode']) {
        expect(
          () => validateWidgetData(
            _spec(HWRow.builder(key, item: const HWText.fixed('x'))),
          ),
          _throwsMessage(
            'Invalid data name "$key" (list "$key"): the generated data '
            'class already has a member named "$key".',
          ),
          reason: key,
        );
      }

      expect(
        () => validateWidgetData(
          _spec(const HWRow.builder('forecast', item: HWText.fixed('x'))),
        ),
        returnsNormally,
      );
    });

    test('validates an item field key in the namespace of its list', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'forecast',
              item: HWText(HWItemData(HWString('1st'))),
            ),
          ),
        ),
        _throwsMessage(
          'Invalid data name "1st" (item field "1st" of list "forecast"): use '
          'ASCII letters and digits only; must start with a letter.',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWColumn(
              children: [
                HWText(HWString('label')),
                HWRow.builder(
                  'forecast',
                  item: HWText.number(HWItemData(HWInt('label'))),
                ),
                HWRow.builder(
                  'hourly',
                  item: HWText(HWItemData(HWBool('label'))),
                ),
              ],
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects an item field key the item class already declares', () {
      for (final key in [
        'toJson',
        'hashCode',
        'toString',
        'runtimeType',
        'noSuchMethod',
      ]) {
        expect(
          () => validateWidgetData(
            _spec(
              HWRow.builder(
                'rows',
                maxItems: 3,
                item: HWText(HWItemData(HWString(key))),
              ),
            ),
          ),
          _throwsMessage(
            'Invalid data name "$key" (item field "$key" of list "rows"): the '
            'generated data class already has a member named "$key".',
          ),
          reason: key,
        );
      }

      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'rows',
              maxItems: 3,
              item: HWText(HWItemData(HWString('fromJson'))),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects a list key another data field takes', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWColumn(
              children: [
                HWText(HWString('forecast')),
                HWRow.builder('forecast', item: HWText.fixed('x')),
              ],
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": the key "forecast" is declared as the list of '
          "HWRow.builder('forecast') and as HWString. Both would generate the "
          'same field, so give them distinct keys.',
        ),
      );

      final others = <HWDataType<dynamic>, String>{
        const HWJson('forecast', HWString('city')): 'HWJson',
        const HWTimedData(HWInt('forecast')): 'HWTimedData(HWInt)',
      };
      for (final MapEntry(key: field, value: described) in others.entries) {
        expect(
          () => validateWidgetData(
            _spec(
              HWColumn(
                children: [
                  HWText(field),
                  const HWColumn.builder('forecast', item: HWText.fixed('x')),
                ],
              ),
            ),
          ),
          _throwsMessage(
            contains(
              "the list of HWColumn.builder('forecast') and as $described.",
            ),
          ),
        );
      }
    });

    test('reserves timedData for a list once the widget has timed data', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWColumn(
              children: [
                HWText.number(HWTimedData(HWInt('score'))),
                HWRow.builder('timedData', item: HWText.fixed('x')),
              ],
            ),
          ),
        ),
        _throwsMessage(
          'Invalid data name "timedData" (list "timedData"): reserved for the '
          'generated timed data parameter.',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(const HWRow.builder('timedData', item: HWText.fixed('x'))),
        ),
        returnsNormally,
      );
    });

    test('a time-based list reserves timedData for the data fields', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWColumn(
              children: [
                HWText(HWString('timedData')),
                HWRow.builder(
                  'hourly',
                  item: HWText.number(HWTimedData(HWItemData(HWInt('t')))),
                ),
              ],
            ),
          ),
        ),
        _throwsMessage(
          'Invalid data name "timedData" (field "timedData"): reserved for the '
          'generated timed data parameter.',
        ),
      );
    });

    test('rejects two lists generating one item class', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWColumn(
              children: [
                HWRow.builder('forecast', item: HWText.fixed('x')),
                HWRow.builder('Forecast', item: HWText.fixed('y')),
              ],
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": the lists "forecast" and "Forecast" both generate the '
          'item class TForecastItem. Rename one of them.',
        ),
      );
    });

    test('rejects two reads of one item field that disagree', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWSizeAdaptive(
              small: HWRow.builder(
                'forecast',
                item: HWText.number(
                  HWItemData(HWInt('temperature', defaultValue: 0)),
                ),
              ),
              large: HWRow.builder(
                'forecast',
                item: HWText.number(HWItemData(HWDouble('temperature'))),
              ),
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": conflicting item fields in list "forecast": '
          '"temperature" is declared as HWInt(defaultValue: 0) and as '
          'HWDouble. Both describe the same member of the item class, so '
          'declare them alike or give them distinct keys.',
        ),
      );
    });

    test('describes what two reads of one item field disagree on', () {
      final conflicts = <List<HWDataType<dynamic>>, String>{
        const [
          HWItemData(HWString('label'), previewValues: ['Mon', 'Tue']),
          HWItemData(HWString('label'), previewValues: ['Mon']),
        ]: 'HWString with previewValues ["Mon", "Tue"] and as HWString with '
            'previewValues ["Mon"]',
        const [
          HWItemData(HWInt('high', defaultValue: 0)),
          HWItemData(HWInt('high', previewValue: 3), previewValues: [1, 2]),
          HWItemData(HWInt('high', defaultValue: 1)),
        ]: 'HWInt(defaultValue: 0, previewValue: 3) with previewValues [1, 2] '
            'and as HWInt(defaultValue: 1)',
        [
          HWItemData(
            HWString.localized('label', defaultTranslations: const {'en': 'A'}),
          ),
          HWItemData(
            HWString.localized(
              'label',
              defaultTranslations: const {'en': 'B'},
              previewTranslations: const {'en': 'C'},
            ),
          ),
        ]: 'HWString.localized(defaultTranslations: {en: A}) and as '
            'HWString.localized(defaultTranslations: {en: B}, '
            'previewTranslations: {en: C})',
        const [
          HWItemData(
            HWIconData.resolved(
              'condition',
              entries: [HWIconEntry('wbSunny', 0xE430)],
              iconFont: HWIconFont(family: 'MaterialIcons'),
            ),
          ),
          HWItemData(
            HWIconData.resolved(
              'condition',
              entries: [HWIconEntry('cloud', 0xE2BD)],
              iconFont: HWIconFont(family: 'MaterialIcons'),
            ),
          ),
        ]: 'HWIconData of icons [wbSunny] and as HWIconData of icons [cloud]',
      };

      for (final MapEntry(key: reads, value: described) in conflicts.entries) {
        expect(
          () => validateWidgetData(
            _spec(HWRow.builder('forecast', item: HWDataOnly(reads))),
          ),
          _throwsMessage(contains('is declared as $described.')),
        );
      }
    });

    test('rejects an item preview instant that is not ISO 8601', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'forecast',
              item: HWText.dateTime(
                HWItemData(HWDateTime('day', previewValue: 'tomorrow')),
              ),
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": HWDateTime("day") of list "forecast" has previewValue '
          '"tomorrow", which is not an ISO 8601 date. Write the instant as '
          'e.g. "2024-03-08T09:41:00Z".',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'forecast',
              item: HWText.dateTime(
                HWItemData(
                  HWDateTime('day'),
                  previewValues: ['2026-09-21T12:00:00Z', 'Tuesday'],
                ),
              ),
            ),
          ),
        ),
        _throwsMessage(
          'Widget "T": previewValues[1] of HWItemData "day" in list "forecast" '
          'is "Tuesday", which is not an ISO 8601 date. Write the instant as '
          'e.g. "2024-03-08T09:41:00Z".',
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'forecast',
              item: HWText.dateTime(
                HWItemData(
                  HWDateTime('day', previewValue: '2026-09-20T12:00:00Z'),
                  previewValues: ['2026-09-21T12:00:00Z'],
                ),
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    group('previewValues of different lengths', () {
      List<String> warningsFor(List<HWDataType<dynamic>> reads) {
        final mock = useMockLogger();
        validateLists(
          _spec(HWRow.builder('forecast', item: HWDataOnly(reads))),
        );
        return [
          for (final call in verify(() => mock.warn(captureAny())).captured)
            call as String,
        ];
      }

      test('warn with the fallback past the shorter ones', () {
        final warnings = warningsFor(const [
          HWItemData(
            HWString('label'),
            previewValues: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          ),
          HWItemData(
            HWInt('temperature', previewValue: 20),
            previewValues: [21, 17, 19],
          ),
          HWItemData(
            HWInt('low', defaultValue: 0),
            previewValues: [1, 2, 3, 4],
          ),
          HWItemData(HWString('note'), previewValues: ['a', 'b', 'c']),
        ]);

        expect(warnings, [
          'Warning: Widget "T": in list "forecast", previewValues of "label" '
              'has 5 entries, of "temperature" 3; items 4–5 fall back to '
              "temperature's previewValue.",
          'Warning: Widget "T": in list "forecast", previewValues of "label" '
              'has 5 entries, of "low" 4; item 5 falls back to '
              "low's defaultValue.",
          'Warning: Widget "T": in list "forecast", previewValues of "label" '
              'has 5 entries, of "note" 3; items 4–5 leave note empty.',
        ]);
      });

      test('name the preview of a localized string or an image', () {
        final warnings = warningsFor([
          const HWItemData(HWString('label'), previewValues: ['a', 'b', 'c']),
          HWItemData(
            HWString.localized(
              'title',
              defaultTranslations: const {'en': 'Day'},
              previewTranslations: const {'en': 'Monday'},
            ),
            previewValues: const ['x', 'y'],
          ),
          HWItemData(
            HWString.localized(
              'subtitle',
              defaultTranslations: const {'en': 'Day'},
            ),
            previewValues: const ['x', 'y'],
          ),
          const HWItemData(
            HWImageData('avatar', previewAsset: 'assets/a.png'),
            previewValues: ['assets/b.png', 'assets/c.png'],
          ),
          const HWItemData(
            HWImageData('cover'),
            previewValues: ['assets/b.png', 'assets/c.png'],
          ),
        ]);

        expect(warnings.map((w) => w.substring(w.indexOf(';') + 2)), [
          "item 3 falls back to title's previewTranslations.",
          "item 3 falls back to subtitle's defaultTranslations.",
          "item 3 falls back to avatar's previewAsset.",
          'item 3 leaves cover empty.',
        ]);
      });

      test('stay quiet while every field lists as many', () {
        final mock = useMockLogger();
        validateLists(
          _spec(
            const HWRow.builder(
              'forecast',
              item: HWDataOnly([
                HWItemData(HWString('label'), previewValues: ['a', 'b']),
                HWItemData(HWInt('high'), previewValues: [1, 2]),
                HWItemData(HWInt('low', previewValue: 3)),
              ]),
            ),
          ),
        );
        verifyNever(() => mock.warn(any()));
      });
    });

    test('lets an item currency and time zone come from plain strings', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'orders',
              item: HWColumn(
                children: [
                  HWText.number(
                    HWItemData(HWDouble('total')),
                    format: HWNumberFormat.currency(
                      currency:
                          HWCurrency.data(HWItemData(HWString('currency'))),
                    ),
                  ),
                  HWText.dateTime(
                    HWItemData(HWDateTime('placedAt')),
                    timeZone: HWTimeZone.data(HWItemData(HWString('zone'))),
                  ),
                ],
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects an item currency read from a localized string', () {
      expect(
        () => validateWidgetData(
          _spec(
            HWRow.builder(
              'orders',
              item: HWText.number(
                const HWItemData(HWDouble('total')),
                format: HWNumberFormat.currency(
                  currency: HWCurrency.data(
                    HWItemData(
                      HWString.localized(
                        'currency',
                        defaultTranslations: const {'en': 'EUR'},
                      ),
                    ),
                  ),
                ),
              ),
            ),
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: ['en'],
            ),
          ),
        ),
        _throwsMessage(
          contains('HWCurrency.data("currency") reads a localized string'),
        ),
      );
    });

    test('names the item field a time zone reads that is not text', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'trips',
              item: HWText.dateTime(
                HWItemData(HWDateTime('startsAt')),
                timeZone: HWTimeZone.data(HWItemData(HWImageData('zone'))),
              ),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('HWTimeZone.data needs an HWString'),
            contains('"zone" is HWImageData.'),
          ),
        ),
      );
    });

    test('lets HWDataExists test an item field that may be missing', () {
      expect(
        () => validateWidgetData(
          _spec(
            HWRow.builder(
              'forecast',
              item: HWDataExists(
                data: HWItemData(
                  HWString.localized(
                    'label',
                    defaultTranslations: const {'en': 'Day'},
                  ),
                ),
                whenPresent: const HWText.fixed('present'),
                whenAbsent: const HWText.fixed('absent'),
              ),
            ),
            localization: const HomeWidgetLocalization(
              defaultLocale: 'en',
              supportedLocales: ['en'],
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('validates the translations of an item localized string', () {
      const tree = HWRow.builder(
        'forecast',
        item: HWText(
          HWItemData(
            HWString.localized('label', defaultTranslations: {'en': 'Day'}),
          ),
        ),
      );

      expect(
        () => validateWidgetData(_spec(tree)),
        _throwsMessage(contains('uses localized strings but has no')),
      );
      expect(
        () => validateWidgetData(_spec(tree, localization: _localization)),
        _throwsMessage(
          contains('HWString.localized("label"): missing translations for de'),
        ),
      );
    });

    test('validates the enum an item icon field generates', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'forecast',
              item: HWIcon(
                HWItemData(
                  HWIconData.resolved(
                    'condition',
                    entries: [
                      HWIconEntry('sun', 0xE430),
                      HWIconEntry('sun', 0xE2BD),
                    ],
                    iconFont: HWIconFont(family: 'MaterialIcons'),
                  ),
                ),
              ),
            ),
          ),
        ),
        _throwsMessage(contains('names the icon "sun" twice')),
      );
    });
  });
}

const HomeWidgetLocalization _localization = HomeWidgetLocalization(
  defaultLocale: 'en',
  supportedLocales: ['en', 'de'],
);

/// A spec declaring [dataFields] verbatim, without going through a tree, so a
/// test can write the same key twice.
WidgetSpec _declaring(
  List<HWDataType<dynamic>> dataFields, {
  HomeWidgetLocalization? localization,
}) =>
    WidgetSpec(
      data: HomeWidget(name: 'T', localization: localization),
      className: 'T',
      dataFields: dataFields,
    );

/// A spec whose data fields are exactly what [tree] binds, the way the parser
/// builds one.
WidgetSpec _spec(HWWidget tree, {HomeWidgetLocalization? localization}) =>
    WidgetSpec(
      data: HomeWidget(name: 'T', widget: tree, localization: localization),
      className: 'T',
      dataFields: tree.dataDependencies.toList(),
      widgetTree: tree,
    );

Matcher _throwsMessage(Object message) => throwsA(
      isA<GeneratorError>().having((e) => e.message, 'message', message),
    );
