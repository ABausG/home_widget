import 'build_scenario.dart';

/// Build scenarios that should run only on the Android integration test
/// suite (not yet validated on iOS).
const List<BuildScenario> androidBuildScenarios = [
  BuildScenario(
    description: 'sizes one axis of a choice at the widget root',
    className: 'OneAxisChoice',
    widgetSource: '''
import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'One Axis Choice',
  android: HomeWidgetAndroidConfiguration(),
  widget: HWSizedBox(
    width: 48,
    child: HWBoolConditional(
      data: HWBool('flag', defaultValue: true),
      whenTrue: HWIcon(HWIconData.fixed(Icons.favorite)),
      whenFalse: HWSizedBox.expand(child: HWText(HWString.fixed('-'))),
    ),
  ),
)
class OneAxisChoice {}
''',
  ),
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
