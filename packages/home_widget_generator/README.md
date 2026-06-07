# home_widget_generator

[![Pub](https://img.shields.io/pub/v/home_widget_generator.svg)](https://pub.dev/packages/home_widget_generator)
[![likes](https://img.shields.io/pub/likes/home_widget_generator)](https://pub.dev/packages/home_widget_generator/score)
[![pub points](https://img.shields.io/pub/points/home_widget_generator)](https://pub.dev/packages/home_widget_generator/score)
[![GitHub-sponsors](https://img.shields.io/badge/Sponsor-30363D?style=flat&logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/abausg)

Describe a HomeScreen widget once in Dart and have the matching native widget code generated for you. Instead of writing SwiftUI and Jetpack Glance by hand, you author a small annotated Dart class.

This package provides the `@HomeWidget` annotation and the DSL widgets (`HWColumn`, `HWText`, ...) used to describe the UI. The code generation itself is performed by the companion [`home_widget_cli`](https://pub.dev/packages/home_widget_cli) tool, and the generated widget continues to be driven at runtime by [`home_widget`](https://pub.dev/packages/home_widget).

## Documentation
Read the full reference, including all annotation options, layout primitives, and styling helpers, on [docs.page](https://docs.page/ABausG/home_widget/generator).

## Installation

Add this package and `home_widget_cli` as dev dependencies, and `home_widget` as a runtime dependency:

```yaml
dependencies:
  home_widget: ^0.9.0

dev_dependencies:
  home_widget_generator: ^0.0.1
  home_widget_cli: ^0.0.1
```

## Usage

Define a widget schema in `home_widget/greeting.dart`:

```dart
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Greeting',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.com.example.app',
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

Run the CLI to generate the iOS, Android, and Dart helper sources:

```bash
dart run home_widget_cli generate
```

Then drive the widget from your app:

```dart
import 'src/home_widget/greeting.home_widget.dart';

await GreetingHomeWidget.saveData(name: 'Anton');
await GreetingHomeWidget.updateWidget();
```

See the [Getting Started](https://docs.page/ABausG/home_widget/generator/getting-started) guide for a full walkthrough.

## Examples

Screenshots from the [`generator_basics`](https://github.com/ABausG/home_widget/tree/main/examples/generator_basics) example app (install name: **home_widget_generator**). Each row is one `@HomeWidget` `name` as shown in the iOS and Android widget pickers.

| Name | iOS | Android |
| --- | :---: | :---: |
| Greeting | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/greeting.jpg" width="160"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/greeting.jpg" width="160"/> |
| Basic Creation | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/basic_creation.jpg" width="160"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/basic_creation.jpg" width="160"/> |
| Adaptive Greeting | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/adaptive_greeting.jpg" width="160"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/adaptive_greeting.jpg" width="160"/> |
| Themed Counter | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/counter.jpg" width="160"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/counter.jpg" width="160"/> |
| Simple Data | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/simple_data.jpg" width="160"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/simple_data.jpg" width="160"/> |
| Conditional Status | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/ios/data_no_data.jpg" width="160"/> | <img src="https://raw.githubusercontent.com/ABausG/home_widget/main/.github/assets/generator_examples/android/data_no_data.jpg" width="160"/> |

See more examples with full `@HomeWidget` source in the [example README](example/README.md). Runnable schemas and a demo app live in [`examples/generator_basics`](https://github.com/ABausG/home_widget/tree/main/examples/generator_basics/home_widget).

## Sponsors

I develop this package in my free time. If you or your company benefits from home_widget, it would mean a lot to me if you considered supporting me on [GitHub Sponsors](https://github.com/sponsors/abausg)
<p align="center">
  <a href="https://github.com/ABausG/sponsorkit/blob/main/sponsorkit/sponsors.svg">
    <img alt="Github Sponsors of ABausG" src="https://raw.githubusercontent.com/ABausG/sponsorkit/main/sponsorkit/sponsors.svg"/>
  </a>
</p>
