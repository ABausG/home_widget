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
];
