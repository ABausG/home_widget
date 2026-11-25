import 'package:home_widget_generator/home_widget_generator.dart';

/// Widget click demo: a tap opens the app, and the generated launch helpers
/// say which part of the widget was tapped:
///
///   WidgetLinkHomeWidget.launches().listen((launch) => switch (launch) {
///     WidgetLinkWidgetTap() => ...,
///     WidgetLinkTopicLink(:final name) => ...,
///   });
///
/// `widgetUrl` covers the widget as a whole and each `HWLink` one region of
/// it. The `data` of a link travels in its URL and comes back as the fields of
/// its launch class. The generator appends the `homeWidget` query parameter
/// and wires the `es.antonborri.home_widget.action.LAUNCH` intent-filter into
/// the Android manifest.
@HomeWidget(
  name: 'Widget Link',
  widgetUrl: 'generatorBasics://link',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemMedium],
  ),
  widget: HWColumn(
    crossAxisAlignment: HWCrossAxisAlignment.start,
    spacing: 8,
    children: [
      HWText(
        HWString.fixed('Tap me'),
        style: HWRoleTextStyle(role: HWTextStyleRole.caption),
      ),
      HWText(
        HWString.fixed('Opens the app'),
        style: HWRoleTextStyle(
          role: HWTextStyleRole.title,
          fontWeight: HWFontWeight.bold,
        ),
      ),
      HWRow(
        spacing: 16,
        children: [
          HWLink(
            'topic',
            url: 'generatorBasics://topic',
            data: [
              HWString('topic', defaultValue: 'Widgets'),
              HWPayload('position', HWInt.fixed(1)),
            ],
            child: HWText(HWString('topic', defaultValue: 'Widgets')),
          ),
          HWLink(
            'settings',
            url: 'generatorBasics://settings',
            child: HWText(HWString.fixed('Settings')),
          ),
        ],
      ),
    ],
  ),
)
class WidgetLink {}
