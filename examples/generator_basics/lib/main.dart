import 'package:flutter/material.dart';
import 'package:generator_basics/src/home_widget/conditional_status.home_widget.dart';
import 'package:generator_basics/src/home_widget/greeting.home_widget.dart';
import 'package:generator_basics/src/home_widget/simple_data.home_widget.dart';
import 'package:generator_basics/src/home_widget/themed_counter.home_widget.dart';

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
