import 'package:home_widget_generator/home_widget_generator.dart';

/// The smallest possible widget: no data, no UI overrides.
///
/// The generator still emits a fully wired native target (AppWidgetProvider on
/// Android, WidgetKit extension on iOS) plus a Dart helper class with an
/// `updateWidget()` method.
@HomeWidget(
  name: 'Basic Creation',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
  ),
)
class BasicCreation {}
