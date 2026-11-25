import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/widget_data_validator.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _localization = HomeWidgetLocalization(
  defaultLocale: 'en',
  supportedLocales: ['en'],
);

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

HWWidget _exists(HWDataType<dynamic> data) => HWDataExists(
      data: data,
      whenPresent: const HWText(HWString.fixed('yes')),
      whenAbsent: const HWText(HWString.fixed('no')),
    );

void main() {
  group('validateWidgetData with appearance-aware data', () {
    test('accepts every kind of side, stored ones as fields of their own', () {
      const tree = HWColumn(
        children: [
          HWText(
            HWAppearanceData<String>(
              light: HWString.fixed('a'),
              dark: HWString('dark'),
            ),
            style: HWTextStyle(
              color: HWAppearanceData<int>(
                light: HWColor('accentLight'),
                dark: HWDefaultColor(HWColorRole.contentPrimary),
                iosAccented: HWColor.fixed(0xFFFFFFFF),
              ),
            ),
          ),
          HWBoolConditional(
            data: HWAppearanceData<bool>(
              light: HWBool.fixed(false),
              dark: HWBool.fixed(true),
            ),
            whenTrue: HWText(HWString.fixed('dark')),
            whenFalse: HWText(HWString.fixed('light')),
          ),
        ],
      );
      final spec = _spec(tree);
      expect(() => validateWidgetData(spec), returnsNormally);
      expect(
        spec.dataFields,
        unorderedEquals([const HWString('dark'), const HWColor('accentLight')]),
      );
      expect(spec.hasColorFields, isTrue);
    });

    test('accepts an HWDataExists testing stored sides', () {
      expect(
        () => validateWidgetData(
          _spec(
            _exists(
              const HWAppearanceData<String>(
                light: HWImageData('light'),
                dark: HWImageData('dark'),
                iosAccented: HWImageData.asset('assets/mono.png'),
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects an HWDataExists whose light or dark side always has a value',
        () {
      expect(
        () => validateWidgetData(
          _spec(
            _exists(
              const HWAppearanceData<String>(
                light: HWImageData('light'),
                dark: HWImageData.asset('assets/logo.png'),
              ),
            ),
          ),
        ),
        _throwsMessage(
          allOf(
            contains('dark side is HWImageData.asset("assets/logo.png")'),
            contains('the check is always true'),
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            _exists(
              const HWAppearanceData<String>(
                light: HWString.localized(
                  'greeting',
                  defaultTranslations: {'en': 'Hi'},
                ),
                dark: HWString('dark'),
              ),
            ),
            localization: _localization,
          ),
        ),
        _throwsMessage(
          contains('light side is HWString.localized("greeting")'),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            _exists(
              const HWAppearanceData<String>(
                light: HWString('light'),
                dark: HWString.localizedFixed({'en': 'Hi'}),
              ),
            ),
            localization: _localization,
          ),
        ),
        _throwsMessage(contains('dark side is HWString.localizedFixed')),
      );
      expect(
        () => validateWidgetData(
          _spec(
            _exists(
              const HWAppearanceData<String>(
                light: HWString('light'),
                dark: HWTimedData(
                  HWString.localized(
                    'greeting',
                    defaultTranslations: {'en': 'Hi'},
                  ),
                ),
              ),
            ),
            localization: _localization,
          ),
        ),
        _throwsMessage(contains('dark side is HWString.localized("greeting")')),
      );
    });

    test('accepts a side with a default, tested for being stored', () {
      expect(
        () => validateWidgetData(
          _spec(
            _exists(
              const HWAppearanceData<String>(
                light: HWJson('brand', HWString('name', defaultValue: 'x')),
                dark: HWString('dark', defaultValue: 'y'),
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects an HWAppearanceData in HWDataOnly', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWDataOnly([
              HWAppearanceData<int>(
                light: HWColor('light'),
                dark: HWColor('dark'),
              ),
            ]),
          ),
        ),
        _throwsMessage(
          'Widget "T": HWDataOnly cannot declare an HWAppearanceData. It '
          'picks between values rather than storing one, so there is no field '
          'of its own to declare. List the stored fields of its sides in '
          'HWDataOnly instead.',
        ),
      );
    });

    test('checks the fixed sides of a text like fixed values', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWText.number(
              HWAppearanceData<double>(
                light: HWDouble.fixed(double.infinity),
                dark: HWDouble('d'),
              ),
            ),
          ),
        ),
        _throwsMessage(contains('HWDouble.fixed(Infinity) is not a finite')),
      );
    });
  });

  group('validateWidgetData with colors', () {
    test('accepts a stored color in every wrapper', () {
      const tree = HWColumn(
        children: [
          HWColoredBox(
            color: HWJson<int>('brand', HWColor('fill')),
            child: HWText(HWString.fixed('a')),
          ),
          HWColoredBox(
            color: HWTimedData<int>(HWColor('phase')),
            child: HWText(HWString.fixed('b')),
          ),
          HWRow.builder(
            'chips',
            item: HWColoredBox(
              color: HWItemData<int>(HWColor('tint')),
              child: HWText(HWString.fixed('c')),
            ),
          ),
        ],
      );
      final spec = _spec(tree);
      expect(() => validateWidgetData(spec), returnsNormally);
      expect(spec.hasColorFields, isTrue);
    });

    test('rejects a constant color inside a wrapper', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWColoredBox(
              color: HWJson<int>('brand', HWColor.fixed(0xFF000000)),
              child: HWText(HWString.fixed('a')),
            ),
          ),
        ),
        _throwsMessage(
          contains('HWJson cannot carry HWColor.fixed(0xFF000000)'),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWColoredBox(
              color: HWTimedData<int>(
                HWDefaultColor(HWColorRole.contentAccent),
              ),
              child: HWText(HWString.fixed('a')),
            ),
          ),
        ),
        _throwsMessage(
          contains(
            'HWTimedData cannot wrap '
            'HWDefaultColor(HWColorRole.contentAccent)',
          ),
        ),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWRow.builder(
              'chips',
              item: HWColoredBox(
                color: HWItemData<int>(HWColor.fixed(0xFF000000)),
                child: HWText(HWString.fixed('c')),
              ),
            ),
          ),
        ),
        _throwsMessage(
          contains('HWItemData cannot wrap HWColor.fixed(0xFF000000)'),
        ),
      );
    });

    test('rejects a color in a tap payload', () {
      expect(
        () => validateWidgetData(
          _spec(
            const HWLink(
              'go',
              url: 'myapp://go',
              data: [HWColor('accent')],
              child: HWText(HWString.fixed('go')),
            ),
          ),
        ),
        _throwsMessage(contains('cannot send the color "accent"')),
      );
      expect(
        () => validateWidgetData(
          _spec(
            const HWLink(
              'go',
              url: 'myapp://go',
              data: [HWPayload('tint', HWColor.fixed(0xFF000000))],
              child: HWText(HWString.fixed('go')),
            ),
          ),
        ),
        _throwsMessage(contains('cannot send HWColor.fixed(0xFF000000)')),
      );
    });

    test('a widget storing no color needs no Color import', () {
      expect(_spec(const HWText(HWString('a'))).hasColorFields, isFalse);
    });
  });

  group('WidgetSpec with an HWAppearanceAdaptive', () {
    test('renders only the light and dark slots on Android', () {
      const accented = HWText(HWString('accented'));
      const tree = HWAppearanceAdaptive(
        light: HWText(HWString('light')),
        dark: HWText(HWString('dark')),
        iosAccented: accented,
      );
      final spec = WidgetSpec(
        data: const HomeWidget(
          name: 'T',
          widget: tree,
          android: HomeWidgetAndroidConfiguration(),
        ),
        className: 'T',
        dataFields: tree.dataDependencies.toList(),
        widgetTree: tree,
      );
      expect(() => validateWidgetData(spec), returnsNormally);
      expect(
        spec.androidRenderedWidgets.any((w) => identical(w, accented)),
        isFalse,
      );
      expect(spec.dataFields, contains(const HWString('accented')));
    });

    test('lets one link sit in each of its slots', () {
      const tree = HWAppearanceAdaptive(
        light: HWLink(
          'open',
          url: 'myapp://open',
          child: HWText(HWString.fixed('light')),
        ),
        dark: HWLink(
          'open',
          url: 'myapp://open',
          child: HWText(HWString.fixed('dark')),
        ),
      );
      expect(() => validateWidgetData(_spec(tree)), returnsNormally);
    });

    test('a default tree leaves a stored color out', () {
      final spec = WidgetSpec(
        data: const HomeWidget(name: 'T'),
        className: 'T',
        dataFields: const [HWColor('bg'), HWString('label')],
      );
      final tree = spec.effectiveWidgetTree as HWColumn;
      expect(tree.children[1], isA<HWDataOnly>());
      expect(tree.children[2], isA<HWRow>());
    });
  });
}
