import 'package:home_widget_generator/home_widget_generator.dart';

/// Data-only widget: declares two typed fields and lets the generator render
/// the layout. The generated Dart helper exposes:
///
///   await SimpleDataHomeWidget.saveData(label: 'Hello', value: 42);
///   await SimpleDataHomeWidget.updateWidget();
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
