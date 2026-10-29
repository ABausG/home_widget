# home_widget_generator examples

A gallery of widget schemas, ordered from the simplest possible widget to one rendering a list the app saves. Each section shows the full `@HomeWidget`-annotated class you would drop into your project's `home_widget/` folder, then run:

```bash
dart run home_widget_cli generate
```

to produce the iOS, Android, and Dart helper sources.

Runnable copies of every schema below live in the [`examples/generator_basics` Flutter app](https://github.com/ABausG/home_widget/tree/main/examples/generator_basics/home_widget) in the repository. Please note that you need to update the iOS App Group to one you can sign the app with to enable Data Transfer between the App and the Widgets.

---

## Greeting

The walkthrough widget from the package README: a caption plus a dynamic `name` field.

[Full source on GitHub](https://github.com/ABausG/home_widget/blob/main/examples/generator_basics/home_widget/greeting.dart)

```dart
import 'package:home_widget_generator/home_widget_generator.dart';

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
        HWString('name', defaultValue: 'world'),
        style: HWRoleTextStyle(
          role: HWTextStyleRole.title,
          fontWeight: HWFontWeight.bold,
        ),
      ),
    ],
  ),
)
class Greeting {}
```

| iOS | Android |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/greeting.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/greeting.jpg" width="200"/> |

Drive it from your app:

```dart
await GreetingHomeWidget.saveData(name: 'Anton');
await GreetingHomeWidget.updateWidget();
```

---

## Basic Creation

The smallest possible widget — no data, no UI overrides. The generator still emits a fully wired native target (AppWidgetProvider on Android, WidgetKit extension on iOS) plus a Dart helper class with an `updateWidget()` method.

[Full source on GitHub](https://github.com/ABausG/home_widget/blob/main/examples/generator_basics/home_widget/basic_creation.dart)

```dart
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Basic Creation',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
  ),
)
class BasicCreation {}
```

| iOS | Android |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/basic_creation.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/basic_creation.jpg" width="200"/> |

---

## Adaptive Greeting

Shows how `HWAdaptive` picks a different child for each platform. On iOS the widget renders "Hello iOS", on Android it renders "Hello Android". Neither branch depends on data, so no Dart-side `saveData` call is needed.

[Full source on GitHub](https://github.com/ABausG/home_widget/blob/main/examples/generator_basics/home_widget/adaptive_greeting.dart)

```dart
import 'package:home_widget_generator/home_widget_generator.dart';

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
```

| iOS | Android |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/adaptive_greeting.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/adaptive_greeting.jpg" width="200"/> |

---

## Themed Counter

An inline UI demo: a centred two-line layout reading an `HWInt('count')` value. Showcases role-based text styles (`HWRoleTextStyle`), role-based colors (`HWDefaultColor`) and a themed background that flips with the system appearance.

[Full source on GitHub](https://github.com/ABausG/home_widget/blob/main/examples/generator_basics/home_widget/themed_counter.dart)

```dart
import 'package:home_widget_generator/home_widget_generator.dart';

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
  widget: HWSizedBox.expand(
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
```

| iOS | Android |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/counter.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/counter.jpg" width="200"/> |

Drive it from your app:

```dart
await ThemedCounterHomeWidget.saveData(count: 42);
await ThemedCounterHomeWidget.updateWidget();
```

---

## Simple Data

A data-only widget: declares two typed fields and lets the generator render a default layout. The generated Dart helper exposes typed `saveData` and `update` methods.

[Full source on GitHub](https://github.com/ABausG/home_widget/blob/main/examples/generator_basics/home_widget/simple_data.dart)

```dart
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Simple Data',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWDataOnly([HWString('label'), HWInt('value')]),
)
class SimpleData {}
```

| iOS | Android |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/simple_data.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/simple_data.jpg" width="200"/> |

Drive it from your app:

```dart
await SimpleDataHomeWidget.saveData(label: 'Hello', value: 42);
await SimpleDataHomeWidget.updateWidget();
```

---

## Conditional Status

A three-state widget showing both `HWDataExists` (does the key exist?) and `HWBoolConditional` (true/false branch):

- `hasData` absent → "No Data — Open App"
- `hasData` present, `enabled` true → green "Enabled"
- `hasData` present, `enabled` false → red "Disabled"

[Full source on GitHub](https://github.com/ABausG/home_widget/blob/main/examples/generator_basics/home_widget/conditional_status.dart)

```dart
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Conditional Status',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWSizedBox.expand(
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
              style: HWRoleTextStyle.headline(
                color: HWColor.fixed(0xFF16A34A),
              ),
            ),
          ],
        ),
        whenFalse: HWColumn(
          mainAxisAlignment: HWMainAxisAlignment.center,
          crossAxisAlignment: HWCrossAxisAlignment.center,
          children: [
            HWText.fixed(
              'Disabled',
              style: HWRoleTextStyle.headline(
                color: HWColor.fixed(0xFFDC2626),
              ),
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
```

| iOS — No Data | iOS — Enabled | iOS — Disabled | Android — No Data | Android — Enabled | Android — Disabled |
| :---: | :---: | :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/data_no_data.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/data_enabled.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/data_disabled.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/data_no_data.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/data_enabled.jpg" width="200"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/data_disabled.jpg" width="200"/> |

---

## Week Forecast

A list the app saves: `HWRow.builder` renders its `item` once per saved day, at most `maxItems` of them, and its `whenEmpty` prompt while there is none. Fields wrapped in `HWItemData` read the day being rendered; the unwrapped `unit` reads the widget's own data, the same in every day. `previewValues` give the widget gallery five sample days.

[Full source on GitHub](https://github.com/ABausG/home_widget/blob/main/examples/generator_basics/home_widget/week_forecast.dart)

```dart
import 'package:flutter/material.dart';
import 'package:home_widget_generator/home_widget_generator.dart';

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
```

Drive it from your app with the generated item class and icon enum:

```dart
await WeekForecastHomeWidget.saveData(
  city: 'Berlin',
  days: [
    WeekForecastDaysItem(
      day: DateTime(2026, 9, 21),
      condition: WeekForecastConditionIcon.wbSunny,
      temperature: 21,
    ),
    WeekForecastDaysItem(
      day: DateTime(2026, 9, 22),
      condition: WeekForecastConditionIcon.cloud,
      temperature: 18,
    ),
  ],
);
await WeekForecastHomeWidget.updateWidget();
```
