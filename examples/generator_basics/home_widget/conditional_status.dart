import 'package:home_widget_generator/home_widget_generator.dart';

/// Three-state conditional widget showing both `HWDataExists` (does the key
/// exist?) and `HWBoolConditional` (true/false branch).
///
/// - `hasData` absent  -> "No Data – Open App"
/// - `hasData` present, `enabled` true  -> green "Enabled"
/// - `hasData` present, `enabled` false -> red "Disabled"
@HomeWidget(
  name: 'Conditional Status',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWFill(
    child: HWDataExists(
      data: HWBool('hasData'),
      whenPresent: HWBoolConditional(
        data: HWBool('enabled', defaultValue: true),
        whenTrue: HWColumn(
          mainAxisAlignment: HWMainAxisAlignment.center,
          crossAxisAlignment: HWCrossAxisAlignment.center,
          children: [
            HWText.fixed(
              'Enabled',
              style: HWRoleTextStyle.headline(color: HWColor.fixed(0xFF16A34A)),
            ),
          ],
        ),
        whenFalse: HWColumn(
          mainAxisAlignment: HWMainAxisAlignment.center,
          crossAxisAlignment: HWCrossAxisAlignment.center,
          children: [
            HWText.fixed(
              'Disabled',
              style: HWRoleTextStyle.headline(color: HWColor.fixed(0xFFDC2626)),
            ),
          ],
        ),
      ),
      whenAbsent: HWColumn(
        mainAxisAlignment: HWMainAxisAlignment.center,
        crossAxisAlignment: HWCrossAxisAlignment.center,
        children: [
          HWText.fixed('No Data', style: HWRoleTextStyle.headline()),
          HWText.fixed(
            'Open the app',
            style: HWRoleTextStyle(
              role: HWTextStyleRole.caption,
              color: HWDefaultColor(HWColorRole.contentSecondary),
            ),
          ),
        ],
      ),
    ),
  ),
)
class ConditionalStatus {}
