import 'package:home_widget_generator/home_widget_generator.dart';

/// Time-based content demo: the two `HWTimedData` fields swap their values on
/// their own at the times passed to `saveData(timedData: {...})` — on iOS via a
/// WidgetKit timeline, on Android via scheduled updates.
///
///   await ForecastHomeWidget.saveData(
///     city: 'Berlin',
///     timedData: {
///       DateTime.now(): const ForecastTimedData(condition: 'Sunny', temperature: 18),
///     },
///   );
///   await ForecastHomeWidget.updateWidget();
///
/// Every field also carries a `previewValue`, so the widget gallery shows
/// "Berlin", "Sunny" and 21° before the app has ever saved anything.
@HomeWidget(
  name: 'Forecast',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWColumn(
    crossAxisAlignment: HWCrossAxisAlignment.start,
    children: [
      HWText(
        HWString('city', defaultValue: 'Nowhere', previewValue: 'Berlin'),
        style: HWRoleTextStyle(role: HWTextStyleRole.caption),
      ),
      HWText(
        HWTimedData(
          HWString(
            'condition',
            defaultValue: 'No forecast',
            previewValue: 'Sunny',
          ),
        ),
        style: HWRoleTextStyle(
          role: HWTextStyleRole.title,
          fontWeight: HWFontWeight.bold,
        ),
      ),
      HWText(
        HWTimedData(HWInt('temperature', defaultValue: 0, previewValue: 21)),
      ),
    ],
  ),
)
class Forecast {}
