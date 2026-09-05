import 'package:home_widget_generator/home_widget_generator.dart';

/// Formatting demo: every number and date below is stored raw and rendered by
/// the widget itself, so the same data follows a language, region or time-zone
/// change on the device without the app running.
///
/// - `HWText.number(HWInt('orderNumber'), format: HWNumberFormat.decimal(useGrouping: false))`
///   keeps an identifier free of thousands separators.
/// - `HWText(HWInt('items'))` uses the default decimal format — `1,204` in
///   en-US, `1.204` in de-DE.
/// - `HWNumberFormat.currency(currency: HWCurrency.data(...))` reads the ISO
///   4217 code from the `currency` field, so each order renders in its own.
/// - `HWNumberFormat.percent()` takes a fraction: `0.15` shows as `15%`.
/// - `HWNumberFormat.compact()` shortens the points balance to `12K`.
/// - `HWText.fixedNumber(25000)` is hardcoded but still localized.
/// - `HWDateFormat.yMMMd` orders and spells the date the way the locale does.
/// - `HWTimeZone.data(HWString('deliveryZone'))` shows the delivery time on the
///   destination's wall clock, not the viewer's.
@HomeWidget(
  name: 'Number Date Formatting',
  description:
      'An order total, discount and delivery time, formatted on the '
      'device.',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemMedium],
  ),
  widget: HWColumn(
    crossAxisAlignment: HWCrossAxisAlignment.start,
    children: [
      HWRow(
        children: [
          HWText.fixed(
            'Order #',
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
          HWText.number(
            HWInt('orderNumber', defaultValue: 0),
            format: HWNumberFormat.decimal(useGrouping: false),
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
          HWText.fixed(
            ' · ',
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
          HWText.dateTime(
            HWDateTime('placedAt'),
            format: HWDateFormat.yMMMd,
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
        ],
      ),
      HWText.number(
        HWDouble('total', defaultValue: 0),
        format: HWNumberFormat.currency(
          currency: HWCurrency.data(HWString('currency', defaultValue: 'EUR')),
        ),
        style: HWRoleTextStyle(
          role: HWTextStyleRole.title,
          fontWeight: HWFontWeight.bold,
        ),
      ),
      HWRow(
        children: [
          HWText.number(
            HWDouble('discount', defaultValue: 0),
            format: HWNumberFormat.percent(),
          ),
          HWText.fixed(' off · '),
          HWText(HWInt('items', defaultValue: 0)),
          HWText.fixed(' items'),
        ],
      ),
      HWRow(
        children: [
          HWText.fixed(
            'Delivery ',
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
          HWText.dateTime(
            HWDateTime('deliveryAt'),
            format: HWDateFormat.jm,
            timeZone: HWTimeZone.data(
              HWString('deliveryZone', defaultValue: ''),
            ),
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
        ],
      ),
      HWRow(
        children: [
          HWText.number(
            HWInt('points', defaultValue: 0),
            format: HWNumberFormat.compact(),
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
          HWText.fixed(
            ' of ',
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
          HWText.fixedNumber(
            25000,
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
          HWText.fixed(
            ' points',
            style: HWRoleTextStyle(role: HWTextStyleRole.caption),
          ),
        ],
      ),
    ],
  ),
)
class NumberDateFormatting {}
