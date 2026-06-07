# home_widget_cli

[![Pub](https://img.shields.io/pub/v/home_widget_cli.svg)](https://pub.dev/packages/home_widget_cli)
[![likes](https://img.shields.io/pub/likes/home_widget_cli)](https://pub.dev/packages/home_widget_cli/score)
[![pub points](https://img.shields.io/pub/points/home_widget_cli)](https://pub.dev/packages/home_widget_cli/score)
[![GitHub-sponsors](https://img.shields.io/badge/Sponsor-30363D?style=flat&logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/abausg)

A Dart command-line tool that helps you set up the native parts of a HomeScreen widget for the [`home_widget`](https://pub.dev/packages/home_widget) Flutter plugin.

It can:
- **Scaffold** placeholder native widget code for iOS and/or Android.
- **Generate** native widget code and a typed Dart helper from [`home_widget_generator`](https://pub.dev/packages/home_widget_generator) schemas.

## Documentation
Full command reference and options are available on [docs.page](https://docs.page/ABausG/home_widget/cli).

## Installation

Install globally so it's available as `home_widget` on your `PATH`:

```bash
dart pub global activate home_widget_cli
```

Or add it as a dev dependency in your Flutter app and invoke it via `dart run`:

```yaml
dev_dependencies:
  home_widget_cli: ^0.0.1
```

## Usage

The examples below use `dart run home_widget_cli`. If you installed the CLI globally, you can drop the prefix and call `home_widget` directly.

Scaffold a new widget for every detected platform:

```bash
dart run home_widget_cli create Example
```

Generate native code and a typed Dart helper from your annotated schemas in `home_widget/`. For example, given:

```dart
import 'package:home_widget_generator/home_widget_generator.dart';

@HomeWidget(
  name: 'Counter',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(groupId: 'group.com.example.app'),
  widget: HWText(HWInt('count', defaultValue: 0)),
)
class Counter {}
```

run:

```bash
dart run home_widget_cli generate
```

This produces the iOS and Android widget sources plus a typed helper you can drive from Dart:

```dart
await CounterHomeWidget.saveData(count: 42);
await CounterHomeWidget.updateWidget();
```

See the [`create`](https://docs.page/ABausG/home_widget/cli/create) and [`generate`](https://docs.page/ABausG/home_widget/cli/generate) command docs for all options.

## Sponsors

I develop this package in my free time. If you or your company benefits from home_widget, it would mean a lot to me if you considered supporting me on [GitHub Sponsors](https://github.com/sponsors/abausg)
<p align="center">
  <a href="https://github.com/ABausG/sponsorkit/blob/main/sponsorkit/sponsors.svg">
    <img alt="Github Sponsors of ABausG" src="https://raw.githubusercontent.com/ABausG/sponsorkit/main/sponsorkit/sponsors.svg"/>
  </a>
</p>
