import 'package:home_widget_generator/home_widget_generator.dart';

/// Shows how `HWSizeAdaptive` renders one tree differently per widget family.
///
/// The three Lock Screen families get their own slots; `extraLarge` is left out
/// on purpose, so the Android 8x4 size falls back to the `large` column (on iOS
/// it is not listed in `supportedFamilies`, so the family is never offered).
///
/// The `medium` row puts the bold score next to a smaller label and lines the
/// two up with `HWCrossAxisAlignment.baseline`; `center` or `end` would align
/// the boxes the two texts sit in and leave their baselines apart by the
/// difference in descent.
@HomeWidget(
  name: 'Size Adaptive Dashboard',
  android: HomeWidgetAndroidConfiguration(
    targetCellWidth: 2,
    targetCellHeight: 2,
    resizeMode: HWAndroidResizeMode.horizontalAndVertical,
  ),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [
      HWWidgetFamily.systemSmall,
      HWWidgetFamily.systemMedium,
      HWWidgetFamily.systemLarge,
      HWWidgetFamily.systemExtraLargePortrait,
      HWWidgetFamily.accessoryCircular,
      HWWidgetFamily.accessoryRectangular,
      HWWidgetFamily.accessoryInline,
    ],
  ),
  widget: HWSizeAdaptive(
    small: HWColumn(
      mainAxisAlignment: HWMainAxisAlignment.center,
      crossAxisAlignment: HWCrossAxisAlignment.center,
      children: [
        HWText(
          HWInt('score', defaultValue: 0),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.title,
            fontWeight: HWFontWeight.bold,
          ),
        ),
      ],
    ),
    medium: HWRow(
      mainAxisAlignment: HWMainAxisAlignment.center,
      crossAxisAlignment: HWCrossAxisAlignment.baseline,
      children: [
        HWText(
          HWInt('score', defaultValue: 0),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.title,
            fontWeight: HWFontWeight.bold,
          ),
        ),
        HWPadding(
          padding: HWEdgeInsets.only(left: 8),
          child: HWText(
            HWString('scoreLabel', defaultValue: 'Points'),
            style: HWRoleTextStyle(
              role: HWTextStyleRole.body,
              color: HWDefaultColor(HWColorRole.contentSecondary),
            ),
          ),
        ),
      ],
    ),
    large: HWColumn(
      crossAxisAlignment: HWCrossAxisAlignment.start,
      children: [
        HWText(
          HWInt('score', defaultValue: 0),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.title,
            fontWeight: HWFontWeight.bold,
          ),
        ),
        HWText(
          HWString('scoreLabel', defaultValue: 'Points'),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.body,
            color: HWDefaultColor(HWColorRole.contentSecondary),
          ),
        ),
        HWPadding(
          padding: HWEdgeInsets.only(top: 8),
          child: HWText(
            HWInt('streak', defaultValue: 0),
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
        ),
      ],
    ),
    extraLargePortrait: HWColumn(
      crossAxisAlignment: HWCrossAxisAlignment.start,
      mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
      children: [
        HWText.fixed(
          'Dashboard',
          style: HWRoleTextStyle(role: HWTextStyleRole.caption),
        ),
        HWText(
          HWInt('score', defaultValue: 0),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.title,
            fontWeight: HWFontWeight.bold,
          ),
        ),
        HWText(
          HWString('scoreLabel', defaultValue: 'Points'),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.body,
            color: HWDefaultColor(HWColorRole.contentSecondary),
          ),
        ),
        HWText(
          HWInt('streak', defaultValue: 0),
          style: HWRoleTextStyle(role: HWTextStyleRole.caption),
        ),
        HWText(
          HWString('motivation', defaultValue: 'Keep it up!'),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.caption,
            color: HWDefaultColor(HWColorRole.contentSecondary),
          ),
        ),
      ],
    ),
    accessoryCircular: HWText(
      HWInt('score', defaultValue: 0),
      style: HWRoleTextStyle(
        role: HWTextStyleRole.title,
        fontWeight: HWFontWeight.bold,
      ),
    ),
    accessoryRectangular: HWColumn(
      crossAxisAlignment: HWCrossAxisAlignment.start,
      children: [
        HWText(
          HWInt('score', defaultValue: 0),
          style: HWRoleTextStyle(
            role: HWTextStyleRole.headline,
            fontWeight: HWFontWeight.bold,
          ),
        ),
        HWText(
          HWString('scoreLabel', defaultValue: 'Points'),
          style: HWRoleTextStyle(role: HWTextStyleRole.caption),
        ),
      ],
    ),
    accessoryInline: HWText(
      HWInt('score', defaultValue: 0),
      style: HWRoleTextStyle(role: HWTextStyleRole.body),
    ),
  ),
)
class SizeAdaptiveDashboard {}
