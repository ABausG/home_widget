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
  widget: HWSizedBox.expand(
    child: HWColoredBox(
      color: HWColor.fixed(0xFF0000FF),
      child: HWSizedBox.expand(
        child: HWColumn(
          children: [
            HWText(HWString.fixed('No Color')),
            HWText(
              HWString.fixed('Fixed Color'),
              style: HWTextStyle(color: HWFixedColor(0xFFFF0000)),
            ),
            HWText(
              HWString.fixed('Themed'),
              style: HWTextStyle(
                color: HWAppearanceData(
                  light: HWFixedColor(0xFFFFFF00),
                  dark: HWFixedColor(0xFF00FFFF),
                ),
              ),
            ),
            HWText(
              HWString.fixed('Stored or role'),
              style: HWTextStyle(
                color: HWAppearanceData(
                  light: HWColor('accent', defaultValue: 0xFF6750A4),
                  dark: HWDefaultColor(HWColorRole.contentSecondary),
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
