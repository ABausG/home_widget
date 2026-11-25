import 'build_scenario.dart';

/// Translations only iOS renders: a list item and a JSON leaf on the iOS side
/// of an `HWAdaptive`, and a JSON leaf in the accented slot of an
/// `HWAppearanceAdaptive`, while Android shows fixed text.
const _iosOnly = '''
HWColumn(children: [
  HWAdaptive(
    ios: HWColumn.builder(
      'rows',
      maxItems: 3,
      item: HWText(HWItemData(
        HWString.localized('label', defaultTranslations: {'en': 'Day'}),
      )),
    ),
    android: HWText(HWString.fixed('rows')),
  ),
  HWAdaptive(
    ios: HWText(HWJson(
      'info',
      HWString.localized('title', defaultTranslations: {'en': 'Title'}),
    )),
    android: HWText(HWString.fixed('info')),
  ),
  HWAppearanceAdaptive(
    light: HWText(HWString.fixed('light')),
    dark: HWText(HWString.fixed('dark')),
    iosAccented: HWText(HWJson(
      'accent',
      HWString.localized('caption', defaultTranslations: {'en': 'Tinted'}),
    )),
  ),
])''';

/// The mirror image of [_iosOnly]: translations only Android renders, on the
/// Android side of an `HWAdaptive` and in an Android size range of an
/// `HWSizeAdaptive`, while iOS shows fixed text.
const _androidOnly = '''
HWColumn(children: [
  HWAdaptive(
    ios: HWText(HWString.fixed('rows')),
    android: HWColumn.builder(
      'rows',
      maxItems: 3,
      item: HWText(HWItemData(
        HWString.localized('label', defaultTranslations: {'en': 'Day'}),
      )),
    ),
  ),
  HWSizeAdaptive(
    small: HWText(HWString.fixed('small')),
    androidSizeRanges: [
      HWAndroidSizeRange(
        minWidth: 300,
        child: HWText(HWJson(
          'info',
          HWString.localized('title', defaultTranslations: {'en': 'Wide'}),
        )),
      ),
    ],
  ),
])''';

String _schema({
  required String name,
  required String className,
  required String widget,
  required bool autoUpdatePreview,
}) =>
    '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: '$name',
  localization: HomeWidgetLocalization(
    defaultLocale: 'en',
    supportedLocales: ['en'],
  ),
  android: HomeWidgetAndroidConfiguration(
    autoUpdatePreview: $autoUpdatePreview,
  ),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: $widget,
)
class $className {}
''';

/// Build scenarios for a translation only one platform renders, which only
/// that platform may read the device's locales for.
final List<BuildScenario> platformSplitBuildScenarios = [
  for (final (description, name, widget) in [
    ('translations only iOS renders', 'Ios Locales', _iosOnly),
    ('translations only Android renders', 'Android Locales', _androidOnly),
  ])
    for (final (autoUpdatePreview, variant) in [
      (false, 'Static'),
      (true, 'Previewed'),
    ])
      BuildScenario(
        description: '$description, '
            '${autoUpdatePreview ? 'with' : 'without'} preview updates',
        className: '${name.replaceAll(' ', '')}$variant',
        widgetSource: _schema(
          name: '$name $variant',
          className: '${name.replaceAll(' ', '')}$variant',
          widget: widget,
          autoUpdatePreview: autoUpdatePreview,
        ),
      ),
];
