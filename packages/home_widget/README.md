# Home Widget

[![Pub](https://img.shields.io/pub/v/home_widget.svg)](https://pub.dartlang.org/packages/home_widget)
[![likes](https://img.shields.io/pub/likes/home_widget)](https://pub.dev/packages/home_widget/score)
[![popularity](https://img.shields.io/pub/popularity/home_widget)](https://pub.dev/packages/home_widget/score)
[![pub points](https://img.shields.io/pub/points/home_widget)](https://pub.dev/packages/home_widget/score)
[![Build](https://github.com/abausg/home_widget/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/ABausG/home_widget/actions/workflows/main.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/ABausG/home_widget/branch/main/graph/badge.svg?token=ZXTZOL6KFO)](https://codecov.io/gh/ABausG/home_widget)
[![Github-sponsors](https://img.shields.io/badge/Sponsor-30363D?style=flat&logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/abausg)

HomeWidget is a Plugin to make it easier to create HomeScreen Widgets on Android and iOS.
HomeWidget does **not** allow writing Widgets with Flutter itself. It still requires writing the Widgets with native code. However, it provides a unified Interface for sending data, retrieving data and updating the Widgets

| iOS                                                                                                            |  Android                                                                                                           |
|----------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| <img src="https://github.com/ABausG/home_widget/blob/main/.github/assets/demo_ios.png?raw=true" width="500px"> | <img src="https://github.com/ABausG/home_widget/blob/main/.github/assets/demo_android.png?raw=true" width="500px"> |

## Features
- Help setting up Widget on the native side
- Send Data from Flutter to the HomeScreenWidget and Update them
- Render and Display Flutter Widgets on HomeScreen Widgets
- Interactive Widgets that call Dart Code

## Documentation
Check out the [documentation](https://docs.page/abausg/home_widget) to learn how to setup home_widget and HomeScreen Widgets on your desired Platforms.

## Usage
Once you wrote your Widgets on the native Side it is super easy to send Data to the Widget and update it

### Save Data

In order to save Data call
```dart
HomeWidget.saveWidgetData<String>('id', data);
```

### Update Widget

In order to initiate a reload of the HomeScreenWidget you need to call
```dart
HomeWidget.updateWidget(
    name: 'HomeWidgetExampleProvider',
);
```

## Contributing

Contributions are welcome!
Here is how you can help.
- Report Bugs and request Features via [Github Issues](https://github.com/ABausG/home_widget/issues)
- Engage in Discussions and help Users solve there problems/questions in the [Discussions](https://github.com/ABausG/home_widget/discussions)
- Fix typos/grammar mistakes
- Update the documentation
- Implement new features by making a pull-request

## Sponsors

I develop this package in my free time. If you or your Company benefits from home_widget it would mean a lot to me if you consider supporting me on [Github Sponsors](https://github.com/sponsors/abausg)
<p align="center">
  <a href="https://github.com/ABausG/sponsorkit/blob/main/sponsorkit/sponsors.svg">
    <img alt="Github Sponsors of ABausG" src="https://raw.githubusercontent.com/ABausG/sponsorkit/main/sponsorkit/sponsors.svg"/>
  </a>
</p>

## Resources, Articles, Talks
Please add to this list if you have interesting and helpful resources
- [Google Codelab](https://codelabs.developers.google.com/flutter-home-screen-widgets#0)
- [Interactive HomeScreen Widgets with Flutter using home_widget](https://medium.com/p/83cb0706a417)
- [iOS Lockscreen Widgets with Flutter and home_widget](https://medium.com/p/0dfecc18cfa0)
