import 'dart:async';

import 'package:flutter/material.dart';
import 'package:generator_basics/src/home_widget/adaptive_greeting.home_widget.dart';
import 'package:generator_basics/src/home_widget/basic_creation.home_widget.dart';
import 'package:generator_basics/src/home_widget/conditional_status.home_widget.dart';
import 'package:generator_basics/src/home_widget/forecast.home_widget.dart';
import 'package:generator_basics/src/home_widget/greeting.home_widget.dart';
import 'package:generator_basics/src/home_widget/image_showcase.home_widget.dart';
import 'package:generator_basics/src/home_widget/localized_greeting.home_widget.dart';
import 'package:generator_basics/src/home_widget/number_date_formatting.home_widget.dart';
import 'package:generator_basics/src/home_widget/simple_data.home_widget.dart';
import 'package:generator_basics/src/home_widget/themed_counter.home_widget.dart';
import 'package:generator_basics/src/home_widget/widget_link.home_widget.dart';
import 'package:generator_basics/src/widget_section.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'home_widget_generator',
      home: Scaffold(
        appBar: AppBar(title: const Text('home_widget_generator')),
        body: const _HomePage(),
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _counter = 0;
  String _currency = 'EUR';
  String _deliveryZone = '';
  Uri? _widgetLinkUri;
  StreamSubscription<Uri>? _widgetLinkSubscription;

  @override
  void initState() {
    super.initState();
    // launchedFromWidget() yields the launch Uri first when a tap on the
    // widget started the app, then every tap while it keeps running. Only
    // this widget's own URL is reported — WidgetLinkHomeWidget.widgetUrl.
    _widgetLinkSubscription = WidgetLinkHomeWidget.launchedFromWidget().listen(
      (uri) => setState(() => _widgetLinkUri = uri),
    );
  }

  @override
  void dispose() {
    _widgetLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // -------------------------------------------------------------------
        // Basic Creation: no data, no UI overrides.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Basic Creation',
          description:
              'The smallest possible widget: no data and no UI overrides. The '
              'generator still emits a fully wired native target plus a Dart '
              'helper with updateWidget().',
          isInstalled: BasicCreationHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              BasicCreationHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: BasicCreationHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: const Text('Refresh the widget'),
              subtitle: const Text('updateWidget()'),
              trailing: const Icon(Icons.refresh),
              onTap: BasicCreationHomeWidget.updateWidget,
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Adaptive Greeting: HWAdaptive picks a child per platform.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Adaptive Greeting',
          description:
              'HWAdaptive picks a different child per platform: "Hello iOS" on '
              'iOS, "Hello Android" on Android. Neither branch depends on '
              'data, so no saveData call is needed.',
          isInstalled: AdaptiveGreetingHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              AdaptiveGreetingHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: AdaptiveGreetingHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: const Text('Refresh the widget'),
              subtitle: const Text('updateWidget()'),
              trailing: const Icon(Icons.refresh),
              onTap: AdaptiveGreetingHomeWidget.updateWidget,
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Greeting: HWString name field (README walkthrough widget).
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Greeting',
          description: 'saveData(name) + updateWidget()',
          isInstalled: GreetingHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              GreetingHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: GreetingHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: const Text('Set name to Anton'),
              trailing: const Icon(Icons.send),
              onTap: () async {
                await GreetingHomeWidget.saveData(name: 'Anton');
                await GreetingHomeWidget.updateWidget();
              },
            ),
            ListTile(
              title: const Text('Reset name to world'),
              trailing: const Icon(Icons.restore),
              onTap: () async {
                await GreetingHomeWidget.saveData(name: 'world');
                await GreetingHomeWidget.updateWidget();
              },
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Simple Data: HWString + HWInt, populated via generated saveData.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Simple Data',
          description:
              'A data-only widget: two typed fields, layout rendered by the '
              'generator.',
          isInstalled: SimpleDataHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              SimpleDataHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: SimpleDataHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: const Text('Send random greeting'),
              subtitle: const Text('saveData(label, value) + updateWidget()'),
              trailing: const Icon(Icons.send),
              onTap: () async {
                final index = DateTime.now().millisecond % _greetings.length;
                await SimpleDataHomeWidget.saveData(
                  label: _greetings[index],
                  value: index,
                );
                await SimpleDataHomeWidget.updateWidget();
              },
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Themed Counter: single HWInt, increment & push.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Themed Counter',
          description:
              'An inline UI reading HWInt(\'count\'), with role-based styles '
              'and a themed background that flips with the system appearance.',
          isInstalled: ThemedCounterHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              ThemedCounterHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: ThemedCounterHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: Text('Current count: $_counter'),
              subtitle: const Text('Increment & push to the widget'),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  setState(() => _counter++);
                  await ThemedCounterHomeWidget.saveData(count: _counter);
                  await ThemedCounterHomeWidget.updateWidget();
                },
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Forecast: HWTimedData, the widget swaps its content on its own.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Forecast',
          description:
              'saveData(timedData: {...}) + updateWidget(). The widget switches '
              'to the next entry on its own, one per quarter hour — no app '
              'process involved.',
          isInstalled: ForecastHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              ForecastHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: ForecastHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: const Text('Save a 2-hour forecast'),
              subtitle: const Text(
                'One entry per quarter hour. Each entry shows the time it was '
                'scheduled for, so the widget states which entry is active.',
              ),
              trailing: const Icon(Icons.schedule_send),
              onTap: () async {
                final now = DateTime.now();
                final firstSlot = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  now.hour,
                ).add(Duration(minutes: (now.minute ~/ 15 + 1) * 15));
                final slots = [
                  now,
                  for (var index = 0; index < 9; index++)
                    firstSlot.add(Duration(minutes: index * 15)),
                ];
                await ForecastHomeWidget.saveData(
                  city: 'Berlin',
                  timedData: {
                    for (final (index, slot) in slots.indexed)
                      slot: ForecastTimedData(
                        condition: _formatSlot(slot),
                        temperature: 10 + index,
                      ),
                  },
                );
                // saveData only writes the schedule — updateWidget() is what
                // makes the Widget pick up the new timeline (reloadTimelines
                // on iOS).
                await ForecastHomeWidget.updateWidget();
              },
            ),
            ListTile(
              title: const Text('Clear the forecast'),
              subtitle: const Text(
                'deleteData(timedData: true) + updateWidget()',
              ),
              trailing: const Icon(Icons.clear),
              onTap: () async {
                await ForecastHomeWidget.deleteData(timedData: true);
                await ForecastHomeWidget.updateWidget();
              },
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Conditional Status: HWDataExists + HWBoolConditional.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Conditional Status',
          description:
              'Three states: no hasData key at all, or hasData present with '
              'enabled true/false picking the green or the red branch.',
          isInstalled: ConditionalStatusHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              ConditionalStatusHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: ConditionalStatusHomeWidget.requestPinWidget,
          children: [
            FutureBuilder(
              future: ConditionalStatusHomeWidget.getData(),
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (data == null) {
                  return const ListTile(title: Text('Loading…'));
                }
                final (hasData: bool? hasData, enabled: bool? enabled) = data;
                return Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Has Data'),
                      subtitle: const Text(
                        'Toggles whether the hasData key exists in storage. '
                        'Off → widget shows "No Data".',
                      ),
                      value: hasData != null,
                      onChanged: (value) async {
                        if (value) {
                          await ConditionalStatusHomeWidget.saveData(
                            hasData: true,
                          );
                        } else {
                          await ConditionalStatusHomeWidget.deleteData(
                            hasData: true,
                          );
                        }
                        await ConditionalStatusHomeWidget.updateWidget();
                        if (mounted) setState(() {});
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Enabled'),
                      subtitle: const Text(
                        'When Has Data is on, controls the green/red branch.',
                      ),
                      value: enabled ?? false,
                      onChanged: hasData == null
                          ? null
                          : (value) async {
                              await ConditionalStatusHomeWidget.saveData(
                                enabled: value,
                              );
                              await ConditionalStatusHomeWidget.updateWidget();
                              if (mounted) setState(() {});
                            },
                    ),
                  ],
                );
              },
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Image Showcase: HWImage.asset, a runtime HWImage inside
        // HWDataExists, and a timed HWImage swapping pictures on a schedule.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Image Showcase',
          description:
              'The bundled logo needs no saving at all. The second image comes '
              'from saveData(picture), the third from '
              'saveData(timedData: {...}).',
          isInstalled: ImageShowcaseHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              ImageShowcaseHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: ImageShowcaseHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: const Text('Save bundled asset as picture'),
              subtitle: const Text(
                'saveData(picture: AssetImage) + updateWidget()',
              ),
              trailing: const Icon(Icons.image_outlined),
              onTap: () async {
                await ImageShowcaseHomeWidget.saveData(
                  picture: const AssetImage('assets/logo.png'),
                );
                await ImageShowcaseHomeWidget.updateWidget();
              },
            ),
            ListTile(
              title: const Text('Clear picture'),
              subtitle: const Text(
                'deleteData(picture: true) + updateWidget()',
              ),
              trailing: const Icon(Icons.delete_outline),
              onTap: () async {
                await ImageShowcaseHomeWidget.deleteData(picture: true);
                await ImageShowcaseHomeWidget.updateWidget();
              },
            ),
            ListTile(
              title: const Text('Alternate two pictures every 15 minutes'),
              subtitle: const Text(
                'saveData(timedData: {...}) + updateWidget(). Each slot carries '
                'its own ImageProvider; the widget swaps them without the app '
                'running.',
              ),
              trailing: const Icon(Icons.burst_mode_outlined),
              onTap: () async {
                final now = DateTime.now();
                final firstSlot = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  now.hour,
                ).add(Duration(minutes: (now.minute ~/ 15 + 1) * 15));
                final slots = [
                  now,
                  for (var index = 0; index < 7; index++)
                    firstSlot.add(Duration(minutes: index * 15)),
                ];
                await ImageShowcaseHomeWidget.saveData(
                  timedData: {
                    for (final (index, slot) in slots.indexed)
                      slot: ImageShowcaseTimedData(
                        slide: index.isEven
                            ? const AssetImage('assets/logo.png')
                            : const AssetImage('assets/dash.png'),
                      ),
                  },
                );
                await ImageShowcaseHomeWidget.updateWidget();
              },
            ),
            ListTile(
              title: const Text('Clear the picture schedule'),
              subtitle: const Text(
                'deleteData(timedData: true) + updateWidget(). Every image saved '
                'for a slot is deleted with it.',
              ),
              trailing: const Icon(Icons.delete_sweep_outlined),
              onTap: () async {
                await ImageShowcaseHomeWidget.deleteData(timedData: true);
                await ImageShowcaseHomeWidget.updateWidget();
              },
            ),
            ListTile(
              title: const Text('Save a contact (name + avatar in one group)'),
              subtitle: const Text(
                'saveData(contact: ContactJsonData(...)). The name and the avatar '
                'travel together in one call.',
              ),
              trailing: const Icon(Icons.account_circle_outlined),
              onTap: () async {
                await ImageShowcaseHomeWidget.saveData(
                  contact: const ContactJsonData(
                    name: 'Dash',
                    avatar: AssetImage('assets/dash.png'),
                  ),
                );
                await ImageShowcaseHomeWidget.updateWidget();
              },
            ),
            ListTile(
              title: const Text('Clear the contact group'),
              subtitle: const Text(
                'deleteData(contact: true) + updateWidget(). The name and the '
                'avatar go together.',
              ),
              trailing: const Icon(Icons.person_off_outlined),
              onTap: () async {
                await ImageShowcaseHomeWidget.deleteData(contact: true);
                await ImageShowcaseHomeWidget.updateWidget();
              },
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Localized Greeting: HWText.localized for fixed text, and a localized
        // HWString the app can override per locale at runtime.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Localized Greeting',
          description:
              'The caption is translated at build time and costs no data '
              'field. The greeting is a localized data field: saveData pushes '
              'one value per locale over the compiled defaults, so the widget '
              'picks the right text when the device language changes.',
          isInstalled: LocalizedGreetingHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              LocalizedGreetingHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: LocalizedGreetingHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: const Text('Push custom translations'),
              subtitle: const Text(
                'saveData(greeting: ...Translations(en, de, ptBR)) + '
                'updateWidget()',
              ),
              trailing: const Icon(Icons.translate),
              onTap: () async {
                await LocalizedGreetingHomeWidget.saveData(
                  greeting: const LocalizedGreetingHomeWidgetTranslations(
                    en: 'Hi there',
                    de: 'Hallo du',
                    ptBR: 'Oi',
                  ),
                );
                await LocalizedGreetingHomeWidget.updateWidget();
              },
            ),
            ListTile(
              title: const Text('Back to the shipped translations'),
              subtitle: const Text(
                'deleteData(greeting: true) + updateWidget(). The widget falls '
                'back to the defaults compiled into it.',
              ),
              trailing: const Icon(Icons.restore),
              onTap: () async {
                await LocalizedGreetingHomeWidget.deleteData(greeting: true);
                await LocalizedGreetingHomeWidget.updateWidget();
              },
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Number & Date Formatting: locale-aware number and date formatting,
        // including a data-bound currency code and a data-bound display time
        // zone.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Number & Date Formatting',
          description:
              'The app pushes raw numbers and DateTimes; the widget formats '
              'them at render time in the device locale. Switch the phone to '
              'another language or region and the same data re-renders — no '
              'app run needed.',
          isInstalled: NumberDateFormattingHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              NumberDateFormattingHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: NumberDateFormattingHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: const Text('Save a sample order'),
              subtitle: const Text(
                'saveData(orderNumber, placedAt, total, currency, discount, '
                'items, deliveryAt, deliveryZone, points) + updateWidget(). '
                'placedAt is DateTime.now(), delivery three hours later.',
              ),
              trailing: const Icon(Icons.receipt_long),
              onTap: _saveOrder,
            ),
            ListTile(
              title: const Text('Currency'),
              subtitle: const Text(
                "HWCurrency.data(HWString('currency')) — the total is formatted in "
                'whichever ISO 4217 code was saved last, symbol and decimals '
                'included.',
              ),
              trailing: DropdownButton<String>(
                value: _currency,
                items: const [
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'JPY', child: Text('JPY')),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _currency = value);
                  await _saveOrder();
                },
              ),
            ),
            ListTile(
              title: const Text('Delivery time zone'),
              subtitle: const Text(
                "HWTimeZone.data(HWString('deliveryZone')) — the stored instant "
                'never changes, only the wall clock it is shown on. An empty id '
                "falls back to the device's own zone.",
              ),
              trailing: DropdownButton<String>(
                value: _deliveryZone,
                items: const [
                  DropdownMenuItem(value: '', child: Text('Device')),
                  DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                  DropdownMenuItem(value: 'Asia/Tokyo', child: Text('Tokyo')),
                  DropdownMenuItem(
                    value: 'America/New_York',
                    child: Text('New York'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _deliveryZone = value);
                  await _saveOrder();
                },
              ),
            ),
            ListTile(
              title: const Text('Clear the order'),
              subtitle: const Text(
                'deleteData(...) + updateWidget(). The numbers fall back to their '
                'defaultValue, the dates render as empty text.',
              ),
              trailing: const Icon(Icons.remove_shopping_cart_outlined),
              onTap: () async {
                await NumberDateFormattingHomeWidget.deleteData(
                  orderNumber: true,
                  placedAt: true,
                  total: true,
                  currency: true,
                  discount: true,
                  items: true,
                  deliveryAt: true,
                  deliveryZone: true,
                  points: true,
                );
                await NumberDateFormattingHomeWidget.updateWidget();
              },
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // Widget Link: widgetUrl, so a tap on the widget opens the app with a
        // Uri the generated launch helpers report back.
        // -------------------------------------------------------------------
        WidgetSection(
          title: 'Widget Link',
          description:
              'The schema sets widgetUrl, so tapping the widget opens the app '
              'with generatorBasics://link?homeWidget — the generator appends '
              'the homeWidget parameter and wires the Android intent-filter.',
          isInstalled: WidgetLinkHomeWidget.isInstalled,
          isRequestPinWidgetSupported:
              WidgetLinkHomeWidget.isRequestPinWidgetSupported,
          requestPinWidget: WidgetLinkHomeWidget.requestPinWidget,
          children: [
            ListTile(
              title: Text(
                _widgetLinkUri?.toString() ??
                    'Not launched from the widget yet',
              ),
              subtitle: const Text(
                'launchedFromWidget() — launch Uri plus every later tap',
              ),
              leading: const Icon(Icons.link),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveOrder() async {
    final now = DateTime.now();
    await NumberDateFormattingHomeWidget.saveData(
      orderNumber: 10248,
      placedAt: now,
      total: 1234.5,
      currency: _currency,
      discount: 0.15,
      items: 1204,
      deliveryAt: now.add(const Duration(hours: 3)),
      deliveryZone: _deliveryZone,
      points: 12400,
    );
    await NumberDateFormattingHomeWidget.updateWidget();
  }

  static const _greetings = [
    'Hello',
    'Hallo',
    'Hola',
    'Bonjour',
    'Ciao',
    'Olá',
  ];

  static String _formatSlot(DateTime slot) =>
      '${slot.hour.toString().padLeft(2, '0')}:'
      '${slot.minute.toString().padLeft(2, '0')}';
}
