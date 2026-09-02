// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class WidgetLinkHomeWidget {
  const WidgetLinkHomeWidget._();


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'WidgetLinkHomeWidgetReceiver',
      iOSName: 'WidgetLinkHomeWidget',
    );
  }

  /// The URL the app was launched with by a tap on the widget, or null
  /// when it was started any other way.
  static Future<Uri?> initiallyLaunchedFromWidget() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();

  /// The URL of every tap on the widget while the app is running.
  ///
  /// A tap that started the app in the first place is not replayed here
  /// — read [initiallyLaunchedFromWidget] for that one, or listen to
  /// [launchedFromWidget] for both.
  static Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;

  /// Every tap on the widget, launch included.
  ///
  /// Yields the launch URL first when the app was started by a tap on
  /// the widget, then every tap that follows while it runs.
  static Stream<Uri?> launchedFromWidget() async* {
    final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initial != null) yield initial;
    yield* HomeWidget.widgetClicked;
  }
}
