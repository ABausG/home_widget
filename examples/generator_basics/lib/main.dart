import 'dart:async';

import 'package:flutter/material.dart';
import 'package:generator_basics/src/home_widget/conditional_status.home_widget.dart';
import 'package:generator_basics/src/home_widget/forecast.home_widget.dart';
import 'package:generator_basics/src/home_widget/greeting.home_widget.dart';
import 'package:generator_basics/src/home_widget/image_showcase.home_widget.dart';
import 'package:generator_basics/src/home_widget/simple_data.home_widget.dart';
import 'package:generator_basics/src/home_widget/themed_counter.home_widget.dart';
import 'package:generator_basics/src/home_widget/widget_link.home_widget.dart';

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
  Uri? _widgetLinkUri;
  StreamSubscription<Uri?>? _widgetLinkSubscription;

  @override
  void initState() {
    super.initState();
    // launchedFromWidget() yields the launch Uri first when a tap on the
    // widget started the app, then every tap while it keeps running.
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
        const _SectionHeader(
          title: 'No-data widgets',
          subtitle:
              'Basic Creation & Adaptive Greeting do not need any Dart-side '
              'calls — just add them to your home screen after running the '
              'generator.',
        ),

        const Divider(),

        // -------------------------------------------------------------------
        // Greeting: HWString name field (README walkthrough widget).
        // -------------------------------------------------------------------
        const _SectionHeader(
          title: 'Greeting',
          subtitle: 'saveData(name) + updateWidget()',
        ),
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

        const Divider(),

        // -------------------------------------------------------------------
        // Simple Data: HWString + HWInt, populated via generated saveData.
        // -------------------------------------------------------------------
        const _SectionHeader(title: 'Simple Data'),
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

        const Divider(),

        // -------------------------------------------------------------------
        // Themed Counter: single HWInt, increment & push.
        // -------------------------------------------------------------------
        const _SectionHeader(title: 'Themed Counter'),
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

        const Divider(),

        // -------------------------------------------------------------------
        // Forecast: HWTimedData, the widget swaps its content on its own.
        // -------------------------------------------------------------------
        const _SectionHeader(
          title: 'Forecast',
          subtitle:
              'saveData(timedData: {...}) + updateWidget(). The widget switches '
              'to the next entry on its own, one per quarter hour — no app '
              'process involved.',
        ),
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
            // saveData only writes the schedule — updateWidget() is what makes
            // the Widget pick up the new timeline (reloadTimelines on iOS).
            await ForecastHomeWidget.updateWidget();
          },
        ),
        ListTile(
          title: const Text('Clear the forecast'),
          subtitle: const Text('deleteData(timedData: true) + updateWidget()'),
          trailing: const Icon(Icons.clear),
          onTap: () async {
            await ForecastHomeWidget.deleteData(timedData: true);
            await ForecastHomeWidget.updateWidget();
          },
        ),

        const Divider(),

        // -------------------------------------------------------------------
        // Conditional Status: HWDataExists + HWBoolConditional.
        // -------------------------------------------------------------------
        const _SectionHeader(title: 'Conditional Status'),
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
                      await ConditionalStatusHomeWidget.saveData(hasData: true);
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

        const Divider(),

        // -------------------------------------------------------------------
        // Image Showcase: HWImage.asset, a runtime HWImage inside
        // HWDataExists, and a timed HWImage swapping pictures on a schedule.
        // -------------------------------------------------------------------
        const _SectionHeader(
          title: 'Image Showcase',
          subtitle:
              'The bundled logo needs no saving at all. The second image comes '
              'from saveData(picture), the third from '
              'saveData(timedData: {...}).',
        ),
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
          subtitle: const Text('deleteData(picture: true) + updateWidget()'),
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

        const Divider(),

        // -------------------------------------------------------------------
        // Widget Link: widgetUrl, so a tap on the widget opens the app with a
        // Uri the generated launch helpers report back.
        // -------------------------------------------------------------------
        const _SectionHeader(
          title: 'Widget Link',
          subtitle:
              'The schema sets widgetUrl, so tapping the widget opens the app '
              'with generatorBasics://link?homeWidget — the generator appends '
              'the homeWidget parameter and wires the Android intent-filter.',
        ),
        ListTile(
          title: Text(
            _widgetLinkUri?.toString() ?? 'Not launched from the widget yet',
          ),
          subtitle: const Text(
            'launchedFromWidget() — launch Uri plus every later tap',
          ),
          leading: const Icon(Icons.link),
        ),
      ],
    );
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
