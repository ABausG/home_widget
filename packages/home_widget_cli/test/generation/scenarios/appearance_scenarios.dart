import 'build_scenario.dart';

/// The appearance-aware values the scenarios below render, one of every
/// kind, with stored, constant and wrapped sides and the iOS rendering-mode
/// sides.
const _values = '''
const color = HWAppearanceData(
  light: HWColor('dayColor'),
  dark: HWDefaultColor(HWColorRole.contentSecondary),
  iosAccented: HWColor.fixed(0xFFFFFFFF),
  iosVibrant: HWDefaultColor(HWColorRole.contentPrimary),
);
const fixedColors = HWAppearanceData(
  light: HWColor.fixed(0xFF000000),
  dark: HWColor.fixed(0xFFFFFFFF),
);
const storedColors = HWAppearanceData(
  light: HWJson('brand', HWColor('brandDay', defaultValue: 0xFF6750A4)),
  dark: HWTimedData(HWColor('brandNight')),
);
const image = HWAppearanceData(
  light: HWImageData('dayLogo'),
  dark: HWImageData('nightLogo'),
  iosAccented: HWImageData.asset('assets/logo.png'),
);
const assetImage = HWAppearanceData(
  light: HWImageData('dayLogo'),
  dark: HWImageData('nightLogo'),
  iosVibrant: HWImageData.asset('assets/logo.png'),
);
const icon = HWAppearanceData(
  light: HWIconData('dayMood', icons: [Icons.wb_sunny, Icons.cloud]),
  dark: HWIconData('nightMood', icons: [Icons.nightlight_round, Icons.star]),
  iosVibrant: HWIconData.fixed(Icons.star),
);
const fixedIcons = HWAppearanceData(
  light: HWIconData.fixed(Icons.wb_sunny),
  dark: HWIconData.fixed(Icons.nightlight_round),
);
const text = HWAppearanceData(
  light: HWString('dayText'),
  dark: HWJson('brand', HWString('nightText', defaultValue: 'Night')),
  iosAccented: HWString.fixed('Tinted'),
  iosVibrant: HWTimedData(
    HWString.localized('lockText', defaultTranslations: {'en': 'Lock'}),
  ),
);
const number = HWAppearanceData(
  light: HWInt('dayCount', defaultValue: 0),
  dark: HWTimedData(HWInt('nightCount')),
  iosAccented: HWInt.fixed(7),
);
const flag = HWAppearanceData(
  light: HWBool('dayFlag', defaultValue: false),
  dark: HWBool.fixed(true),
  iosVibrant: HWBool.fixed(false),
);
const date = HWAppearanceData(
  light: HWDateTime('dayDate'),
  dark: HWDateTime.fixed('2026-01-01T00:00:00Z'),
  iosAccented: HWTimedData(HWDateTime('accentDate')),
);
const storedColor = HWAppearanceData(
  light: HWColor('dayColor'),
  dark: HWColor('nightColor'),
  iosAccented: HWColor.fixed(0xFFFFFFFF),
  iosVibrant: HWDefaultColor(HWColorRole.contentPrimary),
);
const storedDate = HWAppearanceData(
  light: HWDateTime('dayDate'),
  dark: HWTimedData(HWDateTime('nightDate')),
  iosVibrant: HWDateTime.fixed('2026-01-01T00:00:00Z'),
);
''';

/// What a value is rendered as, by the shape its native code takes: a
/// picture, a glyph, a text, a condition and a layout picked by the
/// appearance.
const _leaves = [
  'HWImage(image, width: 24, height: 24)',
  'HWIcon(icon, color: color)',
  'HWText(text, style: HWTextStyle(color: storedColors))',
  'HWBoolConditional(data: flag, whenTrue: HWImage(image), '
      'whenFalse: HWIcon(fixedIcons))',
  'HWDataExists(data: assetImage, whenPresent: HWImage(assetImage), '
      'whenAbsent: HWIcon(icon))',
  'HWAppearanceAdaptive(light: HWImage(image), dark: HWIcon(icon), '
      'iosAccented: HWText(text), iosVibrant: HWText.number(number))',
];

/// The number the next link or button id ends in: an id is unique within a
/// widget.
var _ids = 0;

/// Every widget wrapping a child, each a function of the child's source.
final _wrappers = <String Function(String child)>[
  (child) => 'HWSizedBox(width: 48, height: 48, child: $child)',
  (child) => 'HWPadding(padding: HWEdgeInsets.all(4), child: $child)',
  (child) => 'HWColoredBox(color: color, child: $child)',
  (child) => 'HWDecoratedBox(decoration: HWBoxDecoration(color: color, '
      'borderRadius: HWBorderRadius.circular(6)), child: $child)',
  (child) => 'HWDecoratedBox(decoration: HWBoxDecoration(color: storedColors, '
      'border: HWBoxBorder(thickness: 1, color: fixedColors), '
      'borderRadius: HWBorderRadius.circular(6)), child: $child)',
  (child) {
    final id = _ids++;
    return "HWLink('open$id', url: 'cliTest://open/$id', child: $child)";
  },
  (child) => "HWButton('tap${_ids++}', child: $child)",
  (child) => 'HWAlign(alignment: HWAlignment.bottomEnd, child: $child)',
  (child) =>
      'HWRow(children: [HWSizedBox(width: double.infinity, child: $child)])',
  (child) => 'HWSizedBox.expand(child: $child)',
  (child) => 'HWStack(children: [$child])',
  (child) => 'HWAppearanceAdaptive(light: $child, '
      'dark: HWPadding(padding: HWEdgeInsets.all(2), child: $child))',
];

/// [children] in columns of at most [perColumn], since a SwiftUI view builder
/// and a Glance column take ten children each.
String _columns(List<String> children, {int perColumn = 8}) {
  final columns = <String>[];
  for (var start = 0; start < children.length; start += perColumn) {
    final column = StringBuffer()..writeln('HWColumn(children: [');
    for (final child in children.skip(start).take(perColumn)) {
      column.writeln('  $child,');
    }
    column.write('])');
    columns.add(column.toString());
  }
  if (columns.length == 1) return columns.single;
  return _columns(columns, perColumn: perColumn);
}

String _schema({
  required String className,
  required String widget,
  bool interactive = false,
  bool fillWidgetContent = true,
}) {
  final buffer = StringBuffer();
  if (interactive) {
    buffer.writeln("import 'package:cli_test/appearance_interaction.dart';");
  }
  buffer
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln(
      "import 'package:home_widget_generator/home_widget_generator.dart';",
    )
    ..writeln()
    ..writeln(_values)
    ..writeln('@HomeWidget(')
    ..writeln("  name: '$className',");
  if (interactive) buffer.writeln('  onInteraction: onAppearanceInteraction,');
  buffer.write('''
  localization: HomeWidgetLocalization(
    defaultLocale: 'en',
    supportedLocales: ['en'],
  ),
  android: HomeWidgetAndroidConfiguration(
    backgroundColor: storedColors,
    fillWidgetContent: $fillWidgetContent,
  ),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.com.example.cliTest',
    backgroundColor: color,
  ),
  widget: $widget,
)
class $className {}
''');
  return buffer.toString();
}

Map<String, String> _files(String className) => {
      'lib/appearance_interaction.dart': '''
import 'package:cli_test/src/home_widget/widget.home_widget.dart';

Future<void> onAppearanceInteraction(${className}Interaction interaction) async {
  await ${className}HomeWidget.updateWidget();
}
''',
      'lib/main.dart': '''
import 'package:cli_test/src/home_widget/widget.home_widget.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ${className}HomeWidget.registerInteractivity();
  runApp(const SizedBox());
}
''',
    };

/// Every value inside every wrapper, and the wrappers inside a layout picked
/// by the appearance.
final _inWrappers = _schema(
  className: 'AppearanceWrapped',
  interactive: true,
  widget: _columns([
    for (final wrap in _wrappers)
      _columns([for (final leaf in _leaves) wrap(leaf)]),
    'HWAppearanceAdaptive(light: ${_wrappers[1](_leaves[0])}, '
        'dark: ${_wrappers[4](_leaves[1])}, '
        'iosAccented: ${_wrappers[0](_leaves[2])})',
  ]),
);

/// Every kind of value tested for being there and every flag tested for being
/// true, constant and rendering-mode sides included.
final _asConditions = _schema(
  className: 'AppearanceConditions',
  widget: _columns([
    for (final value in [
      'storedColor',
      'storedColors',
      'image',
      'assetImage',
      'icon',
      'text',
      'number',
      'storedDate',
    ])
      'HWDataExists(data: $value, '
          "whenPresent: HWText(HWString.fixed('$value')), "
          "whenAbsent: HWText(HWString.fixed('no $value')))",
    "HWBoolConditional(data: flag, whenTrue: HWText(HWString.fixed('yes')), "
        "whenFalse: HWText(HWString.fixed('no')))",
    'HWText.number(number)',
    "HWText.dateTime(date, format: HWDateFormat.skeleton('yMMMd'))",
    'HWText(number)',
    'HWIcon(fixedIcons, color: fixedColors)',
    'HWPadding(padding: HWEdgeInsets.all(4), '
        'child: HWDataExists(data: icon, whenPresent: HWIcon(icon), '
        'whenAbsent: HWImage(image)))',
  ]),
);

/// Colors and icons tested for being there, with nothing else in the widget
/// picking a value as it renders.
final _presenceOnly = _schema(
  className: 'AppearancePresence',
  widget: _columns([
    for (final value in ['storedColor', 'icon'])
      'HWDataExists(data: $value, '
          "whenPresent: HWText(HWString.fixed('$value')), "
          "whenAbsent: HWText(HWString.fixed('no $value')))",
  ]),
);

/// A picture picked by the appearance as the whole widget, which then sizes
/// itself.
final _rootImage = _schema(
  className: 'AppearanceRoot',
  fillWidgetContent: false,
  widget: 'HWImage(image)',
);

/// The fields of each item of a list picked by the appearance: a color, an
/// image and a text.
final _itemFields = _schema(
  className: 'AppearanceItems',
  widget: '''
HWColumn.builder(
  'rows',
  maxItems: 3,
  item: HWRow(children: [
    HWImage(
      HWAppearanceData(
        light: HWItemData(HWImageData('dayIcon')),
        dark: HWItemData(HWImageData('nightIcon')),
      ),
      width: 16,
      height: 16,
    ),
    HWText(
      HWAppearanceData(
        light: HWItemData(HWString('dayLabel')),
        dark: HWItemData(HWString('nightLabel', defaultValue: 'Night')),
        iosAccented: HWString.fixed('Tinted'),
      ),
      style: HWTextStyle(
        color: HWAppearanceData(
          light: HWItemData(HWColor('dayTint')),
          dark: HWItemData(HWColor('nightTint', defaultValue: 0xFFFFFFFF)),
        ),
      ),
    ),
  ]),
)''',
);

/// A text whose every side is written into the widget.
final _fixedText = _schema(
  className: 'AppearanceFixedText',
  widget: 'HWText(HWAppearanceData('
      "light: HWString.fixed('**Day**'), "
      "dark: HWString.fixed('**Night**'), "
      "iosAccented: HWString.fixed('Tinted')))",
);

/// A box sizing one axis of two constant icons picked by the appearance, with
/// nothing else in the widget sizing the other axis.
String _oneAxisBox(String className, String axis) => _schema(
      className: className,
      widget: 'HWSizedBox($axis: 48, child: HWAppearanceAdaptive('
          'light: HWIcon(HWIconData.fixed(Icons.wb_sunny)), '
          'dark: HWIcon(HWIconData.fixed(Icons.nightlight_round))))',
    );

/// Build scenarios for values picked by the appearance, run on every platform
/// integration test suite.
final List<BuildScenario> appearanceBuildScenarios = [
  for (final (description, className, source) in [
    (
      'picks the fields of a list item by the appearance',
      'AppearanceItems',
      _itemFields
    ),
    (
      'renders a text of constant appearance sides',
      'AppearanceFixedText',
      _fixedText
    ),
    (
      'sizes the width alone of icons picked by the appearance',
      'AppearanceIconWidth',
      _oneAxisBox('AppearanceIconWidth', 'width')
    ),
    (
      'sizes the height alone of icons picked by the appearance',
      'AppearanceIconHeight',
      _oneAxisBox('AppearanceIconHeight', 'height')
    ),
    (
      'renders appearance values inside every wrapper',
      'AppearanceWrapped',
      _inWrappers
    ),
    (
      'tests appearance values in conditions',
      'AppearanceConditions',
      _asConditions
    ),
    (
      'tests appearance colors and icons alone for being there',
      'AppearancePresence',
      _presenceOnly
    ),
    (
      'renders an appearance image as the whole widget',
      'AppearanceRoot',
      _rootImage
    ),
  ])
    BuildScenario(
      description: description,
      className: className,
      widgetSource: source,
      files: className == 'AppearanceWrapped' ? _files(className) : const {},
      assetPaths: const ['assets/logo.png'],
      hasLinks: className == 'AppearanceWrapped',
      hasButtons: className == 'AppearanceWrapped',
      expectsScheduledUpdateWiring: true,
    ),
];
