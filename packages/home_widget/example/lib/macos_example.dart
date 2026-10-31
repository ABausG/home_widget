import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

@pragma('vm:entry-point')
Future<void> macOSBackgroundCallback(Uri? uri) async {
  if (uri?.host != 'increment') return;
  final count =
      await HomeWidget.getWidgetData<int>('example_counter', defaultValue: 0) ??
      0;
  await HomeWidget.saveWidgetData('example_counter', count + 1);
  await HomeWidget.saveWidgetData('example_callback_uri', uri.toString());
  await _refreshMacOSWidgets();
}

Future<void> _refreshMacOSWidgets() async {
  await HomeWidget.updateWidget(name: 'HomeWidgetMacOSExample');
  await HomeWidget.updateWidget(name: 'HomeWidgetMacOSConfigurableExample');
}

/// Saves an ImageProvider and a Flutter screenshot through the public APIs.
Future<String> saveMacOSExampleImages(String group) async {
  await HomeWidget.setAppGroupId(group);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 96, 96),
    Paint()..color = Colors.blue,
  );
  canvas.drawCircle(const Offset(48, 48), 30, Paint()..color = Colors.orange);
  final picture = recorder.endRecording();
  final image = await picture.toImage(96, 96);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not encode the sample image');
    await HomeWidget.saveImage(
      'example_image',
      MemoryImage(bytes.buffer.asUint8List()),
      appGroupId: group,
    );
  } finally {
    image.dispose();
    picture.dispose();
  }
  await HomeWidget.renderFlutterWidget(
    const ColoredBox(
      color: Colors.teal,
      child: SizedBox(
        width: 180,
        height: 96,
        child: Center(
          child: Text(
            'Flutter',
            style: TextStyle(color: Colors.white, fontSize: 28),
          ),
        ),
      ),
    ),
    key: 'example_screenshot',
    logicalSize: const Size(180, 96),
    pixelRatio: 1,
    appGroupId: group,
  );
  final token = 'Example-${DateTime.now().millisecondsSinceEpoch}';
  await HomeWidget.saveWidgetData('example_token', token, appGroupId: group);
  await _refreshMacOSWidgets();
  return token;
}

class MacOSExample extends StatefulWidget {
  const MacOSExample({super.key});

  @override
  State<MacOSExample> createState() => _MacOSExampleState();
}

class _MacOSExampleState extends State<MacOSExample> {
  static const _configuration = MethodChannel('home_widget_example/config');
  String? _group;
  String? _image;
  String? _screenshot;
  String? _token;
  int _counter = 0;
  String? _error;
  List<HomeWidgetInfo>? _widgets;
  StreamSubscription<Uri?>? _urlSubscription;
  String? _initialUrl;
  String? _latestUrl;
  int _urlEvents = 0;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _urlSubscription = HomeWidget.widgetClicked.listen((url) {
      if (!mounted || url == null) return;
      setState(() {
        _latestUrl = url.toString();
        _urlEvents++;
      });
      unawaited(_readInitialUrl());
    });
    _initialize();
  }

  @override
  void dispose() {
    _urlSubscription?.cancel();
    super.dispose();
  }

  Future<void> _readInitialUrl() async {
    final url = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (mounted) setState(() => _initialUrl = url?.toString());
  }

  Future<void> _readImages() async {
    final image = await HomeWidget.getWidgetData<String>(
      'example_image',
      appGroupId: _group,
    );
    final screenshot = await HomeWidget.getWidgetData<String>(
      'example_screenshot',
      appGroupId: _group,
    );
    final token = await HomeWidget.getWidgetData<String>(
      'example_token',
      appGroupId: _group,
    );
    final counter = await HomeWidget.getWidgetData<int>(
      'example_counter',
      defaultValue: 0,
      appGroupId: _group,
    );
    if (mounted) {
      setState(() {
        _image = image;
        _screenshot = screenshot;
        _token = token;
        _counter = counter ?? 0;
      });
    }
  }

  Future<void> _initialize() async {
    try {
      await _readInitialUrl();
      _group = await _configuration.invokeMethod<String>('appGroupId');
      if (_group != null) {
        await HomeWidget.setAppGroupId(_group!);
        await HomeWidget.registerInteractivityCallback(macOSBackgroundCallback);
        await _readImages();
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await saveMacOSExampleImages(_group!);
      await _readImages();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeCounter({required bool reset}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (reset) {
        await HomeWidget.saveWidgetData(
          'example_counter',
          0,
          appGroupId: _group,
        );
        await _refreshMacOSWidgets();
      } else {
        await macOSBackgroundCallback(
          Uri.parse('homewidget-macos://increment'),
        );
      }
      await _readImages();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readWidgets() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final widgets = await HomeWidget.getInstalledWidgets();
      if (mounted) setState(() => _widgets = widgets);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readSharedData() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _readImages();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _preview(String path) => Image.file(
    File(path),
    width: 120,
    height: 80,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const Text('Image unavailable'),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Widget',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.widgets_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text('Home Widget', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 12),
                  if (_image != null && _screenshot != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [_preview(_image!), _preview(_screenshot!)],
                    ),
                    Text(_token ?? ''),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) Text(_error!),
                  if (_group == null && !_busy)
                    const Text(
                      'Configure one matching App Group for the app and widget '
                      'to share data and images. See the example README.',
                      textAlign: TextAlign.center,
                    ),
                  FilledButton(
                    onPressed: _busy || _group == null ? null : _save,
                    child: Text(_busy ? 'Loading…' : 'Save and refresh'),
                  ),
                  TextButton(
                    onPressed: _busy || _group == null ? null : _readSharedData,
                    child: const Text('Read shared data'),
                  ),
                  Text('Widget counter: $_counter'),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy || _group == null
                            ? null
                            : () => _changeCounter(reset: false),
                        icon: const Icon(Icons.add),
                        label: const Text('Increment counter'),
                      ),
                      TextButton(
                        onPressed: _busy || _group == null
                            ? null
                            : () => _changeCounter(reset: true),
                        child: const Text('Reset counter'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _busy ? null : _readWidgets,
                    child: const Text('Read widget configurations'),
                  ),
                  Text('Initial widget URI: ${_initialUrl ?? 'none'}'),
                  Text('Latest widget URI: ${_latestUrl ?? 'none'}'),
                  Text('URL events: $_urlEvents'),
                  if (_widgets case final widgets?) ...[
                    if (widgets.isEmpty) const Text('No widget configurations'),
                    for (final widget in widgets)
                      Text(
                        '${widget.iOSKind} / ${widget.iOSFamily}'
                        '${widget.configuration == null ? '' : '\n${widget.configuration}'}',
                        textAlign: TextAlign.center,
                      ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Add HomeWidget macOS from your Mac’s widget gallery. '
                    'On macOS 14+, try HomeWidget macOS Configurable and edit '
                    'its Name, then read its configuration here. '
                    'Click Count in either widget, then read shared data '
                    'to see the updated counter.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
