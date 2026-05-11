import 'package:home_widget_generator/home_widget_generator.dart';

/// Inline UI demo: a centred two-line layout reading an `HWInt('count')` value.
///
/// Showcases role-based text styles (`HWRoleTextStyle`), role-based colors
/// (`HWDefaultColor`) and a themed background that flips with the system
/// appearance.
@HomeWidget(
  name: 'Themed Counter',
  description: 'A counter with a themed background and role-based colors.',
  android: HomeWidgetAndroidConfiguration(
    backgroundColor: HWColor.themed(
      light: HWColor.fixed(0xFFEFF6FF),
      dark: HWColor.fixed(0xFF0B1220),
    ),
  ),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
    backgroundColor: HWColor.themed(
      light: HWColor.fixed(0xFFEFF6FF),
      dark: HWColor.fixed(0xFF0B1220),
    ),
  ),
  widget: HWFill(
    child: HWColumn(
      mainAxisAlignment: HWMainAxisAlignment.center,
      crossAxisAlignment: HWCrossAxisAlignment.center,
      children: [
        HWText.fixed(
          'Counter',
          style: HWRoleTextStyle(
            role: HWTextStyleRole.caption,
            color: HWDefaultColor(HWColorRole.contentSecondary),
          ),
        ),
        HWText(
          HWInt('count', defaultValue: 0),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.title,
            color: HWDefaultColor(HWColorRole.contentPrimary),
            fontWeight: HWFontWeight.bold,
          ),
        ),
      ],
    ),
  ),
)
class ThemedCounter {}
