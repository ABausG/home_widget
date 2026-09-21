import 'build_scenario.dart';

/// Build scenarios that should run on every platform integration test suite.
const List<BuildScenario> sharedBuildScenarios = [
  BuildScenario(
    description: 'reuses const widget definition with mixed enum syntax',
    className: 'ConstReuse',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

const variableTestWidget = HWColoredBox(
  color: HWColor.fixed(0xFFFF0000),
  child: HWText.fixed('textData'),
);

@HomeWidget(
  name: 'Const Reuse',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWPadding(
    padding: .all(8),
    child: HWColumn(
      mainAxisAlignment: HWMainAxisAlignment.start,
      crossAxisAlignment: .stretch,
      children: [
        variableTestWidget,
        HWText.fixed('Some other'),
        variableTestWidget,
      ],
    ),
  ),
)
class ConstReuse {}
''',
  ),
  BuildScenario(
    description: 'aligns rows and columns on both axes',
    className: 'AlignedTree',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Aligned Tree',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWColumn(
    mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
    crossAxisAlignment: HWCrossAxisAlignment.start,
    children: [
      HWRow(
        crossAxisAlignment: HWCrossAxisAlignment.baseline,
        children: [
          HWText(HWInt('streak'), style: HWTextStyle(fontSize: 34)),
          HWText.fixed('days', style: HWTextStyle(fontSize: 12)),
        ],
      ),
      HWRow(
        crossAxisAlignment: HWCrossAxisAlignment.end,
        mainAxisAlignment: HWMainAxisAlignment.spaceEvenly,
        children: [
          HWPadding(
            padding: .all(2),
            child: HWText(HWString('label')),
          ),
          HWText.fixed('·'),
          HWImage.asset('assets/logo.png', width: 16, height: 16),
        ],
      ),
      HWRow(
        crossAxisAlignment: HWCrossAxisAlignment.start,
        mainAxisAlignment: HWMainAxisAlignment.center,
        children: [HWText.fixed('top')],
      ),
    ],
  ),
)
class AlignedTree {}
''',
    assetPaths: ['assets/logo.png'],
  ),
  BuildScenario(
    description: 'builds time-based content with primitive and json values',
    className: 'TimedContent',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Timed Content',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWColumn(
    children: [
      HWText(HWString('headline')),
      HWText(HWTimedData(HWString('label'))),
      HWText(HWTimedData(HWInt('temperature'))),
      HWText(HWTimedData(HWJson('weather', HWString('condition')))),
    ],
  ),
)
class TimedContent {}
''',
    expectsScheduledUpdateWiring: true,
  ),
  BuildScenario(
    description: 'renders runtime and asset images',
    className: 'ImageTree',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Image Tree',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWColumn(
    children: [
      HWImage(
        HWImageData('avatar'),
        width: 64,
        height: 64,
        semanticLabel: 'Avatar',
      ),
      HWImage.asset('assets/logo.png', fit: HWImageFit.cover),
      HWImage(
        HWTimedData(HWImageData('slide')),
        width: 32,
        height: 32,
        fit: HWImageFit.cover,
      ),
      HWDataExists(
        data: HWJson('contact', HWImageData('avatar')),
        whenPresent: HWImage(HWJson('contact', HWImageData('avatar')), width: 24),
        whenAbsent: HWText.fixed('no avatar'),
      ),
      HWImage(HWTimedData(HWJson('slot', HWImageData('picture'))), width: 24),
    ],
  ),
)
class ImageTree {}
''',
    expectsScheduledUpdateWiring: true,
    assetPaths: ['assets/logo.png'],
  ),
  BuildScenario(
    description: 'formats numbers in every supported format',
    className: 'NumberFormats',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Number Formats',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWColumn(
    children: [
      HWText(HWInt('items')),
      HWText.number(
        HWInt('orderNumber', defaultValue: 0),
        format: HWNumberFormat.decimal(useGrouping: false),
      ),
      HWText.number(
        HWDouble('total', defaultValue: 0),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWString('currency', defaultValue: 'EUR')),
        ),
      ),
      HWText.number(
        HWDouble('fee'),
        format: HWNumberFormat.currency(
          currency: HWCurrency.code('USD'),
          decimalDigits: 0,
        ),
      ),
      HWText.number(
        HWDouble('discount'),
        format: HWNumberFormat.percent(maximumFractionDigits: 1),
      ),
      HWText.number(HWInt('points'), format: HWNumberFormat.compact()),
      HWText.number(
        HWJson('stats', HWInt('visits')),
        format: HWNumberFormat.pattern('#,##0.00'),
      ),
      HWText.number(
        HWTimedData(HWDouble('load')),
        format: HWNumberFormat.decimal(
          minimumFractionDigits: 1,
          maximumFractionDigits: 3,
        ),
      ),
      HWText.fixedNumber(25000),
      HWText.fixedNumber(0.42, format: HWNumberFormat.percent()),
    ],
  ),
)
class NumberFormats {}
''',
    expectsScheduledUpdateWiring: true,
  ),
  BuildScenario(
    description: 'formats dates in every supported format and time zone',
    className: 'DateFormats',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Date Formats',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWColumn(
    children: [
      HWText(HWDateTime('createdAt')),
      HWText.dateTime(
        HWDateTime('deliveryAt'),
        format: HWDateFormat.yMMMd,
        timeZone: HWTimeZone.data(HWString('deliveryZone', defaultValue: '')),
      ),
      HWText.dateTime(
        HWDateTime('boardingAt'),
        format: HWDateFormat.pattern('dd.MM.yyyy HH:mm'),
        timeZone: HWTimeZone.named('Europe/Berlin'),
      ),
      HWText.dateTime(
        HWDateTime('closesAt'),
        format: HWDateFormat.styled(
          date: HWFormatStyle.full,
          time: HWFormatStyle.short,
        ),
        timeZone: HWTimeZone.utc,
      ),
      HWText.dateTime(HWDateTime('opensAt'), format: HWDateFormat.jm),
      HWText.dateTime(HWTimedData(HWDateTime('slotAt'))),
      HWText.dateTime(
        HWJson('trip', HWDateTime('departsAt')),
        format: HWDateFormat.yMdjm,
      ),
      HWDataExists(
        data: HWDateTime('cancelledAt'),
        whenPresent: HWText.dateTime(
          HWDateTime('cancelledAt'),
          format: HWDateFormat.Hm,
        ),
        whenAbsent: HWText.fixed('active'),
      ),
    ],
  ),
)
class DateFormats {}
''',
    expectsScheduledUpdateWiring: true,
  ),
  BuildScenario(
    description: 'opens a top-level widget URL on tap',
    className: 'SharedUrl',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Shared Url',
  widgetUrl: 'cliTest://widget',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWText.fixed('Tap me'),
)
class SharedUrl {}
''',
    expectedAndroidWidgetUrl: 'cliTest://widget?homeWidget',
    expectedIosWidgetUrl: 'cliTest://widget?homeWidget',
  ),
  BuildScenario(
    description: 'lets each platform override the widget URL',
    className: 'PlatformUrl',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Platform Url',
  widgetUrl: 'cliTest://shared',
  android: HomeWidgetAndroidConfiguration(widgetUrl: 'cliTest://android'),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.com.example.cliTest',
    widgetUrl: 'cliTest://ios',
  ),
  widget: HWText.fixed('Tap me'),
)
class PlatformUrl {}
''',
    expectedAndroidWidgetUrl: 'cliTest://android?homeWidget',
    expectedIosWidgetUrl: 'cliTest://ios?homeWidget',
  ),
  BuildScenario(
    description: 'keeps a widget URL that already carries homeWidget',
    className: 'ExplicitUrl',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Explicit Url',
  widgetUrl: 'cliTest://widget?section=main&homeWidget',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWText.fixed('Tap me'),
)
class ExplicitUrl {}
''',
    expectedAndroidWidgetUrl: 'cliTest://widget?section=main&homeWidget',
    expectedIosWidgetUrl: 'cliTest://widget?section=main&homeWidget',
  ),
  BuildScenario(
    description: 'renders text in a custom font and draws icons',
    className: 'FontAndIcons',
    widgetSource: '''
import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Font And Icons',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWColumn(
    children: [
      HWText.fixed(
        'Headline',
        style: HWTextStyle(fontFamily: 'Chewy', fontSize: 18),
      ),
      HWText(
        HWString('body'),
        style: HWTextStyle(
          fontFamily: 'Chewy',
          fontWeight: HWFontWeight.bold,
          italic: true,
        ),
      ),
      HWIcon.fixed(Icons.favorite, size: 32),
      HWIcon(
        HWIconData(
          'mood',
          icons: [Icons.wb_sunny, Icons.cloud, Icons.umbrella],
          defaultValue: Icons.wb_sunny,
          previewValue: Icons.cloud,
        ),
        semanticLabel: 'Mood',
      ),
      HWIcon(HWTimedData(HWIconData('next', icons: [Icons.alarm, Icons.done]))),
    ],
  ),
)
class FontAndIcons {}
''',
    expectsScheduledUpdateWiring: true,
    fontFamilies: {'Chewy': 'assets/fonts/Chewy-Regular.ttf'},
  ),
  BuildScenario(
    description: 'renders size-adaptive content per family',
    className: 'SizeAdaptive',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Size Adaptive',
  android: HomeWidgetAndroidConfiguration(
    targetCellWidth: 2,
    targetCellHeight: 2,
    resizeMode: HWAndroidResizeMode.horizontalAndVertical,
  ),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.com.example.cliTest',
    supportedFamilies: [
      HWWidgetFamily.systemSmall,
      HWWidgetFamily.systemMedium,
      HWWidgetFamily.systemLarge,
      HWWidgetFamily.systemExtraLarge,
      HWWidgetFamily.systemExtraLargePortrait,
      HWWidgetFamily.accessoryCircular,
      HWWidgetFamily.accessoryRectangular,
      HWWidgetFamily.accessoryInline,
    ],
  ),
  widget: HWSizeAdaptive(
    small: HWText(HWString('headline')),
    medium: HWRow(
      children: [
        HWText(HWString('headline')),
        HWText.fixed(' · '),
        HWText(HWInt('streak')),
      ],
    ),
    large: HWColumn(
      children: [
        HWText(HWString('headline')),
        HWText(HWString('label')),
        HWText(HWInt('streak')),
      ],
    ),
    extraLargePortrait: HWColumn(
      children: [
        HWText(HWString('headline')),
        HWText(HWString('label')),
        HWText(HWInt('streak')),
        HWText.fixed('portrait'),
      ],
    ),
    accessoryCircular: HWText(HWInt('streak')),
    accessoryRectangular: HWRow(
      children: [
        HWText(HWString('label')),
        HWText(HWInt('streak')),
      ],
    ),
    accessoryInline: HWText(HWString('headline')),
  ),
)
class SizeAdaptive {}
''',
  ),
  BuildScenario(
    description: 'renders saved lists through row and column builders',
    className: 'ListBuilders',
    widgetSource: '''
import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'List Builders',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  localization: HomeWidgetLocalization(
    defaultLocale: 'en',
    supportedLocales: ['en', 'de'],
  ),
  widget: HWColumn(
    crossAxisAlignment: HWCrossAxisAlignment.start,
    children: [
      HWText(HWString('city', previewValue: 'Berlin')),
      HWRow.builder(
        'forecast',
        maxItems: 5,
        spacing: 4,
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        item: HWColumn(
          children: [
            HWText.dateTime(
              HWItemData(
                HWDateTime('day'),
                previewValues: [
                  '2026-09-21T12:00:00Z',
                  '2026-09-22T12:00:00Z',
                  '2026-09-23T12:00:00Z',
                ],
              ),
              format: HWDateFormat.skeleton('E'),
            ),
            HWIcon(
              HWItemData(
                HWIconData(
                  'condition',
                  icons: [Icons.wb_sunny, Icons.cloud, Icons.umbrella],
                  defaultValue: Icons.cloud,
                ),
                previewValues: [Icons.wb_sunny, Icons.cloud, Icons.umbrella],
              ),
              size: 16,
            ),
            HWText.number(
              HWItemData(
                HWInt('temperature', defaultValue: 0),
                previewValues: [21, 17, 19],
              ),
            ),
            HWText.number(
              HWItemData(HWDouble('rain', previewValue: 0.4)),
              format: HWNumberFormat.percent(),
            ),
            HWText(
              HWItemData(
                HWString.localized(
                  'summary',
                  defaultTranslations: {'en': 'Fair', 'de': 'Heiter'},
                  previewTranslations: {'en': 'Sunny', 'de': 'Sonnig'},
                ),
                previewValues: ['Clear'],
              ),
            ),
            HWText(HWString('unit', defaultValue: '°C')),
          ],
        ),
        whenEmpty: HWText.fixed('No forecast yet'),
      ),
      HWRow.builder(
        'scores',
        maxItems: 3,
        spacing: 8,
        crossAxisAlignment: HWCrossAxisAlignment.baseline,
        item: HWBoolConditional(
          data: HWItemData(HWBool('leading', defaultValue: false)),
          whenTrue: HWText(
            HWItemData(HWString('label', previewValue: 'Top')),
            style: HWTextStyle(fontFamily: 'Chewy', fontSize: 24),
          ),
          whenFalse: HWText(
            HWItemData(HWString('label')),
            style: HWTextStyle(fontSize: 12),
          ),
        ),
      ),
      HWRow.builder('dots', maxItems: 3, item: HWText.fixed('·')),
    ],
  ),
)
class ListBuilders {}
''',
    fontFamilies: {'Chewy': 'assets/fonts/Chewy-Regular.ttf'},
  ),
  BuildScenario(
    description: 'renders images inside list items',
    className: 'ListImages',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'List Images',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  widget: HWColumn(
    children: [
      HWImage(
        HWImageData('banner', previewAsset: 'assets/banner.png'),
        height: 24,
      ),
      HWColumn.builder(
        'contacts',
        maxItems: 3,
        spacing: 4,
        item: HWRow(
          children: [
            HWDataExists(
              data: HWItemData(HWImageData('avatar')),
              whenPresent: HWImage(
                HWItemData(
                  HWImageData('avatar', previewAsset: 'assets/avatar.png'),
                  previewValues: ['assets/avatar.png', 'assets/logo.png'],
                ),
                width: 24,
                height: 24,
                fit: HWImageFit.cover,
              ),
              whenAbsent: HWText.fixed('?'),
            ),
            HWText(HWItemData(HWString('name', previewValue: 'Ada'))),
            HWImage(HWItemData(HWImageData('badge')), width: 12, height: 12),
          ],
        ),
        whenEmpty: HWText.fixed('No contacts yet'),
      ),
    ],
  ),
)
class ListImages {}
''',
    assetPaths: ['assets/banner.png', 'assets/avatar.png', 'assets/logo.png'],
  ),
  BuildScenario(
    description: 'renders time-based lists with item images',
    className: 'TimedLists',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Timed Lists',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  localization: HomeWidgetLocalization(
    defaultLocale: 'en',
    supportedLocales: ['en', 'de'],
  ),
  widget: HWColumn(
    children: [
      HWText(HWString('city', previewValue: 'Berlin')),
      HWText(HWTimedData(HWString('summary', previewValue: 'Sunny'))),
      HWRow.builder(
        'hourly',
        maxItems: 4,
        spacing: 4,
        item: HWColumn(
          children: [
            HWText.dateTime(
              HWTimedData(
                HWItemData(
                  HWDateTime('time'),
                  previewValues: ['2026-09-21T09:00:00Z', '2026-09-21T10:00:00Z'],
                ),
              ),
              format: HWDateFormat.jm,
            ),
            HWDataExists(
              data: HWTimedData(HWItemData(HWImageData('icon'))),
              whenPresent: HWImage(
                HWTimedData(
                  HWItemData(
                    HWImageData('icon', previewAsset: 'assets/sun.png'),
                    previewValues: ['assets/sun.png', 'assets/rain.png'],
                  ),
                ),
                width: 16,
                height: 16,
              ),
              whenAbsent: HWText.fixed('-'),
            ),
            HWText.number(
              HWTimedData(
                HWItemData(
                  HWInt('temperature', defaultValue: 0),
                  previewValues: [12, 13],
                ),
              ),
            ),
            HWText(
              HWTimedData(
                HWItemData(
                  HWString.localized(
                    'label',
                    defaultTranslations: {'en': 'Hour', 'de': 'Stunde'},
                    previewTranslations: {'en': 'Now', 'de': 'Jetzt'},
                  ),
                ),
              ),
            ),
          ],
        ),
        whenEmpty: HWText.fixed('No hourly forecast'),
      ),
      HWColumn.builder(
        'alerts',
        maxItems: 2,
        item: HWText(HWItemData(HWString('title', previewValue: 'Wind'))),
      ),
    ],
  ),
)
class TimedLists {}
''',
    expectsScheduledUpdateWiring: true,
    assetPaths: ['assets/sun.png', 'assets/rain.png'],
  ),
  BuildScenario(
    description: 'renders a list as the only time-based data',
    className: 'TimedListOnly',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Timed List Only',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.cliTest'),
  localization: HomeWidgetLocalization(
    defaultLocale: 'en',
    supportedLocales: ['en', 'de'],
  ),
  widget: HWColumn.builder(
    'slots',
    maxItems: 3,
    item: HWText(
      HWTimedData(
        HWItemData(
          HWString.localized(
            'label',
            defaultTranslations: {'en': 'Slot', 'de': 'Termin'},
          ),
        ),
      ),
    ),
    whenEmpty: HWText.fixed('Nothing scheduled'),
  ),
)
class TimedListOnly {}
''',
    expectsScheduledUpdateWiring: true,
  ),
];
