import 'package:configurable_widget/main.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

class AndroidConfigurationPage extends StatefulWidget {
  const AndroidConfigurationPage({super.key, required this.widgetId});

  final String widgetId;

  @override
  State<AndroidConfigurationPage> createState() =>
      _AndroidConfigurationPageState();
}

class _AndroidConfigurationPageState extends State<AndroidConfigurationPage> {
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  bool _initialized = false;
  String? _punctuation;
  final TextEditingController _textEditingController = TextEditingController();

  String get _nameId => 'name.${widget.widgetId}';
  String get _punctuationId => 'punctuation.${widget.widgetId}';

  Future<void> _loadInitialData() async {
    final storedName = await HomeWidget.getWidgetData(_nameId);
    final storedPunctuation = await HomeWidget.getWidgetData(_punctuationId);

    setState(() {
      _textEditingController.text = storedName ?? 'World';
      _punctuation =
          storedPunctuation != null && punctuations.contains(storedPunctuation)
          ? storedPunctuation
          : punctuations.first;
      _initialized = true;
    });
  }

  Future<void> _saveConfiguration() async {
    await HomeWidget.saveWidgetData(_nameId, _textEditingController.text);
    await HomeWidget.saveWidgetData(_punctuationId, _punctuation);
    await HomeWidget.updateWidget(
      qualifiedAndroidName:
          'es.antonborri.configurable_widget.ConfigurableWidgetHomeWidgetReceiver',
    );
    await HomeWidget.finishHomeWidgetConfigure();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configure widget')),
      body: _initialized
          ? ListView(
              children: [
                ListTile(
                  title: const Text('Widget ID'),
                  subtitle: Text(widget.widgetId),
                ),
                ListTile(
                  title: const Text('Name'),
                  subtitle: TextField(
                    controller: _textEditingController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your name',
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Punctuation'),
                  trailing: DropdownButton(
                    value: _punctuation,
                    onChanged: (value) {
                      setState(() {
                        _punctuation = value;
                      });
                    },
                    items: punctuations
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: _initialized
          ? Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _saveConfiguration,
                child: const Text('Save'),
              ),
            )
          : null,
    );
  }
}
