# Home Widget

[![Pub](https://img.shields.io/pub/v/home_widget.svg)](https://pub.dartlang.org/packages/home_widget)
[![likes](https://img.shields.io/pub/likes/home_widget)](https://pub.dev/packages/home_widget/score)
[![downloads](https://img.shields.io/pub/dm/home_widget)](https://pub.dev/packages/home_widget/score)
[![pub points](https://img.shields.io/pub/points/home_widget)](https://pub.dev/packages/home_widget/score)
[![Build](https://github.com/abausg/home_widget/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/ABausG/home_widget/actions/workflows/main.yml?query=branch%3Amain)
[![Codemagic iOS Integration Tests](https://api.codemagic.io/apps/68dc0fab9b1f2358cb1af76b/68dc0fab9b1f2358cb1af76a/status_badge.svg)](https://codemagic.io/app/68dc0fab9b1f2358cb1af76b/68dc0fab9b1f2358cb1af76a/latest_build)
[![codecov](https://codecov.io/gh/ABausG/home_widget/branch/main/graph/badge.svg?token=ZXTZOL6KFO)](https://codecov.io/gh/ABausG/home_widget)
[![GitHub-sponsors](https://img.shields.io/badge/Sponsor-30363D?style=flat&logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/abausg)

HomeWidget is a plugin to make it easier to create HomeScreen Widgets on Android and iOS.
HomeWidget does **not** allow writing Widgets with Flutter itself. It still requires writing the Widgets with native code. However, it provides a unified interface for sending data, retrieving data, and updating the Widgets.

| iOS                                                                                                            |  Android                                                                                                           |
|----------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| <img src="https://github.com/ABausG/home_widget/blob/main/.github/assets/demo_ios.png?raw=true" width="500px"> | <img src="https://github.com/ABausG/home_widget/blob/main/.github/assets/demo_android.png?raw=true" width="500px"> |

## Features
- Help setting up widgets on the native side
- Send data from Flutter to the HomeScreen widget and update them
- Render and display Flutter widgets on HomeScreen widgets
- Interactive widgets that call Dart Code

## Documentation
Check out the [documentation](https://docs.page/abausg/home_widget) to learn how to setup home_widget and HomeScreen Widgets on your desired Platforms.

## Usage
Once you wrote your Widgets on the native side, it is super easy to send data to the Widget and update it.

### Save Data

To save data, call:
```dart
HomeWidget.saveWidgetData<String>('id', data);
```

### Update Widget

To initiate a reload of the Home Screen Widget, you need to call:
```dart
HomeWidget.updateWidget(
    name: 'HomeWidgetExampleProvider',
);
```

## Contributing

Contributions are welcome!
Here is how you can help:
- Report bugs and request features via [GitHub Issues](https://github.com/ABausG/home_widget/issues)
- Engage in discussions and help users solve their problems/questions in the [Discussions](https://github.com/ABausG/home_widget/discussions)
- Fix typos and grammar mistakes
- Update the documentation
- Implement new features by making a pull-request

## Show your Widgets

Have you added HomeScreen widgets to your App? Feel free to share them in the [GitHub Discussions](https://github.com/ABausG/home_widget/discussions/categories/show-and-tell)

## Sponsors

I develop this package in my free time. If you or your company benefits from home_widget, it would mean a lot to me if you considered supporting me on [GitHub Sponsors](https://github.com/sponsors/abausg)
<p align="center">
  <a href="https://github.com/ABausG/sponsorkit/blob/main/sponsorkit/sponsors.svg">
    <img alt="Github Sponsors of ABausG" src="https://raw.githubusercontent.com/ABausG/sponsorkit/main/sponsorkit/sponsors.svg"/>
  </a>
</p>
