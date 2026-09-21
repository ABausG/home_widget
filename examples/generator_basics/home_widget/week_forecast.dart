import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

/// List demo: `HWRow.builder` renders its `item` once per day the app saves,
/// at most `maxItems` of them, spread out by `spaceBetween`.
///
///   await WeekForecastHomeWidget.saveData(
///     city: 'Berlin',
///     days: [
///       WeekForecastDaysItem(
///         day: DateTime.now(),
///         condition: WeekForecastConditionIcon.wbSunny,
///         temperature: 21,
///       ),
///     ],
///   );
///   await WeekForecastHomeWidget.updateWidget();
///
/// Fields wrapped in `HWItemData` read the day being rendered; `unit` is not
/// wrapped, so every day reads the same `unit` of the widget's own data. The
/// row shows `whenEmpty` until the app saves a day, and again for an empty
/// list. Until the app has saved a list, the widget gallery shows five sample
/// days built from `previewValues`.
@HomeWidget(
  name: 'Week Forecast',
  description: 'A five-day forecast, one column per day the app saves.',
  android: HomeWidgetAndroidConfiguration(
    targetCellWidth: 4,
    targetCellHeight: 2,
  ),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemMedium],
  ),
  widget: HWColumn(
    crossAxisAlignment: HWCrossAxisAlignment.start,
    mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
    children: [
      HWText(
        HWString('city', defaultValue: 'Nowhere', previewValue: 'Berlin'),
        style: HWRoleTextStyle(role: HWTextStyleRole.headline),
      ),
      HWRow.builder(
        'days',
        maxItems: 5,
        mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
        spacing: 4,
        item: HWColumn(
          spacing: 4,
          children: [
            HWText.dateTime(
              HWItemData(
                HWDateTime('day'),
                previewValues: [
                  '2026-09-21T12:00:00Z',
                  '2026-09-22T12:00:00Z',
                  '2026-09-23T12:00:00Z',
                  '2026-09-24T12:00:00Z',
                  '2026-09-25T12:00:00Z',
                ],
              ),
              format: HWDateFormat.skeleton('E'),
              style: HWRoleTextStyle(
                role: HWTextStyleRole.caption,
                color: HWDefaultColor(HWColorRole.contentSecondary),
              ),
            ),
            HWIcon(
              HWItemData(
                HWIconData(
                  'condition',
                  icons: [
                    Icons.wb_sunny,
                    Icons.cloud,
                    Icons.umbrella,
                    Icons.thunderstorm,
                    Icons.ac_unit,
                  ],
                  defaultValue: Icons.cloud,
                ),
                previewValues: [
                  Icons.wb_sunny,
                  Icons.cloud,
                  Icons.umbrella,
                  Icons.thunderstorm,
                  Icons.wb_sunny,
                ],
              ),
            ),
            HWRow(
              children: [
                HWText.number(
                  HWItemData(
                    HWInt('temperature', defaultValue: 0),
                    previewValues: [21, 18, 14, 16, 22],
                  ),
                  style: HWRoleTextStyle(role: HWTextStyleRole.body),
                ),
                HWText(
                  HWString('unit', defaultValue: '°'),
                  style: HWRoleTextStyle(role: HWTextStyleRole.body),
                ),
              ],
            ),
          ],
        ),
        whenEmpty: HWText.fixed(
          'Open the app to load the forecast',
          style: HWRoleTextStyle(
            role: HWTextStyleRole.caption,
            color: HWDefaultColor(HWColorRole.contentSecondary),
          ),
        ),
      ),
    ],
  ),
)
class WeekForecast {}
