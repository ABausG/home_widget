import 'build_scenario.dart';

/// Build scenarios that should run only on the Android integration test
/// suite (not yet validated on iOS).
const List<BuildScenario> androidBuildScenarios = [
  BuildScenario(
    description: 'simple color widget',
    className: 'SimpleColor',
    widgetSource: '''
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Simple Color',
  android: HomeWidgetAndroidConfiguration(),
  widget: HWFill(
    child: HWColoredBox(
      color: HWColor.fixed(0xFF0000FF),
      child: HWFill(
        child: HWColumn(
          children: [
            HWText.fixed('No Color'),
            HWText.fixed(
              'Fixed Color',
              style: HWTextStyle(color: HWFixedColor(0xFFFF0000)),
            ),
            HWText.fixed(
              'Themed',
              style: HWTextStyle(
                color: HWThemedColor(
                  light: HWFixedColor(0xFFFFFF00),
                  dark: HWFixedColor(0xFF00FFFF),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
)
class SimpleColor {}
''',
  ),
];
