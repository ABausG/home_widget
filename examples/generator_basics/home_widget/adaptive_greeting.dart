import 'package:home_widget_generator/home_widget_generator.dart';

/// Shows how `HWAdaptive` picks a different child for each platform.
///
/// On iOS the widget renders "Hello iOS", on Android it renders "Hello Android".
/// Neither branch depends on data, so no Dart-side `saveData` call is needed.
@HomeWidget(
  name: 'Adaptive Greeting',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWAdaptive(
    ios: HWText.fixed(
      'Hello iOS',
      style: HWRoleTextStyle(role: HWTextStyleRole.headline),
    ),
    android: HWText.fixed(
      'Hello Android',
      style: HWRoleTextStyle(role: HWTextStyleRole.headline),
    ),
  ),
)
class AdaptiveGreeting {}
