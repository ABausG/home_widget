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
];
