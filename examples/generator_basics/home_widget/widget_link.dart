import 'package:home_widget_generator/home_widget_generator.dart';

/// Widget click demo: `widgetUrl` makes a tap on the widget open the app with
/// that URL, which the app reads back through the generated launch helpers:
///
///   WidgetLinkHomeWidget.launchedFromWidget().listen((uri) => print(uri));
///
/// The generator appends the `homeWidget` query parameter for you and wires the
/// `es.antonborri.home_widget.action.LAUNCH` intent-filter into the Android
/// manifest, so the app sees `generatorBasics://link?homeWidget` on both
/// platforms.
@HomeWidget(
  name: 'Widget Link',
  widgetUrl: 'generatorBasics://link',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWColumn(
    crossAxisAlignment: HWCrossAxisAlignment.start,
    children: [
      HWText.fixed(
        'Tap me',
        style: HWRoleTextStyle(role: HWTextStyleRole.caption),
      ),
      HWText.fixed(
        'Opens the app',
        style: HWRoleTextStyle(
          role: HWTextStyleRole.title,
          fontWeight: HWFontWeight.bold,
        ),
      ),
    ],
  ),
)
class WidgetLink {}
