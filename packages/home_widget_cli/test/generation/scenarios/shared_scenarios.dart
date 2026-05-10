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
];
