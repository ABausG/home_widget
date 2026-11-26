import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:material_ui/material_ui.dart';

/// Inline UI demo: a centred two-line layout reading an `HWInt('count')` value
/// that follows the system appearance.
///
/// - The background is an `HWAppearanceData` of two `HWColor.fixed` colors,
///   one for light and one for dark mode.
/// - The count is drawn in an accent color the app sets at runtime: an
///   `HWAppearanceData` of the stored colors `accentLight` and `accentDark`,
///   saved together via `saveData(accentLight: ..., accentDark: ...)`. Their
///   `defaultValue`s keep the widget readable before the app has run.
/// - The icon next to the caption is an `HWAppearanceData` of two fixed icons,
///   a sun in light and a moon in dark mode, tinted with a role color.
/// - The caption is an `HWAppearanceAdaptive` with one layout per appearance,
///   including an `iosAccented` one for a Tinted or Clear iOS Home Screen.
/// - On Android 12+ the background, the accent and the icon switch live when
///   dark mode is toggled, while the caption follows at the next widget
///   update. On iOS everything switches live.
/// - Text styles stay role-based (`HWRoleTextStyle`, `HWDefaultColor`).
@HomeWidget(
  name: 'Themed Counter',
  description:
      'A counter in an accent color the app picks, themed per appearance.',
  android: HomeWidgetAndroidConfiguration(
    backgroundColor: HWAppearanceData(
      light: HWColor.fixed(0xFFEFF6FF),
      dark: HWColor.fixed(0xFF0B1220),
    ),
  ),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
    backgroundColor: HWAppearanceData(
      light: HWColor.fixed(0xFFEFF6FF),
      dark: HWColor.fixed(0xFF0B1220),
    ),
  ),
  widget: HWSizedBox.expand(
    child: HWColumn(
      mainAxisAlignment: HWMainAxisAlignment.center,
      crossAxisAlignment: HWCrossAxisAlignment.center,
      spacing: 4,
      children: [
        HWRow(
          mainAxisAlignment: HWMainAxisAlignment.center,
          crossAxisAlignment: HWCrossAxisAlignment.center,
          spacing: 4,
          children: [
            HWIcon(
              HWAppearanceData(
                light: HWIconData.fixed(Icons.light_mode),
                dark: HWIconData.fixed(Icons.dark_mode),
              ),
              size: 14,
              color: HWDefaultColor(HWColorRole.contentSecondary),
            ),
            HWAppearanceAdaptive(
              light: HWText(
                HWString.fixed('Light mode'),
                style: HWRoleTextStyle(
                  role: HWTextStyleRole.caption,
                  color: HWDefaultColor(HWColorRole.contentSecondary),
                ),
              ),
              dark: HWText(
                HWString.fixed('Dark mode'),
                style: HWRoleTextStyle(
                  role: HWTextStyleRole.caption,
                  color: HWDefaultColor(HWColorRole.contentSecondary),
                ),
              ),
              iosAccented: HWText(
                HWString.fixed('Tinted / Clear'),
                style: HWRoleTextStyle(
                  role: HWTextStyleRole.caption,
                  color: HWDefaultColor(HWColorRole.contentSecondary),
                ),
              ),
            ),
          ],
        ),
        HWText(
          HWInt('count', defaultValue: 0),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.title,
            color: HWAppearanceData(
              light: HWColor('accentLight', defaultValue: 0xFF1D4ED8),
              dark: HWColor('accentDark', defaultValue: 0xFF93C5FD),
            ),
            fontWeight: HWFontWeight.bold,
          ),
        ),
      ],
    ),
  ),
)
class ThemedCounter {}
