import 'package:home_widget_generator/home_widget_generator.dart';

/// Greeting widget from the package README — caption + dynamic name field.
/// `name` carries a `previewValue`, so the gallery shows "Anton" instead of
/// the fallback "world".
@HomeWidget(
  name: 'Greeting',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWColumn(
    crossAxisAlignment: HWCrossAxisAlignment.start,
    children: [
      HWText.fixed(
        'Hello',
        style: HWRoleTextStyle(role: HWTextStyleRole.caption),
      ),
      HWText(
        HWString('name', defaultValue: 'world', previewValue: 'Anton'),
        style: HWRoleTextStyle(
          role: HWTextStyleRole.title,
          fontWeight: HWFontWeight.bold,
        ),
      ),
    ],
  ),
)
class Greeting {}
