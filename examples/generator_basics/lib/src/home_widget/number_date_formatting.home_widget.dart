// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class NumberDateFormattingHomeWidget {
  const NumberDateFormattingHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.NumberDateFormatting';

  static Future<void> saveData({
    int? orderNumber,
    DateTime? placedAt,
    double? total,
    String? currency,
    double? discount,
    int? items,
    DateTime? deliveryAt,
    String? deliveryZone,
    int? points,
  }) {
    return Future.wait([
      if (orderNumber != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.orderNumber', orderNumber, appGroupId: _$appGroupId),
      if (placedAt != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.placedAt', placedAt.toUtc().toIso8601String(), appGroupId: _$appGroupId),
      if (total != null) HomeWidget.saveWidgetData<double>('${_$paramPrefix}.total', total, appGroupId: _$appGroupId),
      if (currency != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.currency', currency, appGroupId: _$appGroupId),
      if (discount != null) HomeWidget.saveWidgetData<double>('${_$paramPrefix}.discount', discount, appGroupId: _$appGroupId),
      if (items != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.items', items, appGroupId: _$appGroupId),
      if (deliveryAt != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.deliveryAt', deliveryAt.toUtc().toIso8601String(), appGroupId: _$appGroupId),
      if (deliveryZone != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.deliveryZone', deliveryZone, appGroupId: _$appGroupId),
      if (points != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.points', points, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool orderNumber = false,
    bool placedAt = false,
    bool total = false,
    bool currency = false,
    bool discount = false,
    bool items = false,
    bool deliveryAt = false,
    bool deliveryZone = false,
    bool points = false,
  }) {
    return Future.wait([
      if (orderNumber) HomeWidget.saveWidgetData('${_$paramPrefix}.orderNumber', null, appGroupId: _$appGroupId),
      if (placedAt) HomeWidget.saveWidgetData('${_$paramPrefix}.placedAt', null, appGroupId: _$appGroupId),
      if (total) HomeWidget.saveWidgetData('${_$paramPrefix}.total', null, appGroupId: _$appGroupId),
      if (currency) HomeWidget.saveWidgetData('${_$paramPrefix}.currency', null, appGroupId: _$appGroupId),
      if (discount) HomeWidget.saveWidgetData('${_$paramPrefix}.discount', null, appGroupId: _$appGroupId),
      if (items) HomeWidget.saveWidgetData('${_$paramPrefix}.items', null, appGroupId: _$appGroupId),
      if (deliveryAt) HomeWidget.saveWidgetData('${_$paramPrefix}.deliveryAt', null, appGroupId: _$appGroupId),
      if (deliveryZone) HomeWidget.saveWidgetData('${_$paramPrefix}.deliveryZone', null, appGroupId: _$appGroupId),
      if (points) HomeWidget.saveWidgetData('${_$paramPrefix}.points', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({int? orderNumber, DateTime? placedAt, double? total, String? currency, double? discount, int? items, DateTime? deliveryAt, String? deliveryZone, int? points})> getData() async {
    return (
      orderNumber: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.orderNumber', defaultValue: 0, appGroupId: _$appGroupId),
      placedAt: _readDateTime(await HomeWidget.getWidgetData<String>('${_$paramPrefix}.placedAt', appGroupId: _$appGroupId)),
      total: await HomeWidget.getWidgetData<double>('${_$paramPrefix}.total', defaultValue: 0.0, appGroupId: _$appGroupId),
      currency: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.currency', defaultValue: 'EUR', appGroupId: _$appGroupId),
      discount: await HomeWidget.getWidgetData<double>('${_$paramPrefix}.discount', defaultValue: 0.0, appGroupId: _$appGroupId),
      items: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.items', defaultValue: 0, appGroupId: _$appGroupId),
      deliveryAt: _readDateTime(await HomeWidget.getWidgetData<String>('${_$paramPrefix}.deliveryAt', appGroupId: _$appGroupId)),
      deliveryZone: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.deliveryZone', defaultValue: '', appGroupId: _$appGroupId),
      points: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.points', defaultValue: 0, appGroupId: _$appGroupId),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'NumberDateFormattingHomeWidgetReceiver',
      iOSName: 'NumberDateFormattingHomeWidget',
    );
  }
}

DateTime? _readDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
