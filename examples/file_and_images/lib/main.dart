import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.setAppGroupId('group.es.antonborri.exampleHomeWidget');
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('File and Images')),
        body: ListView(children: [ImageWidget(), Divider(), FileWidget()]),
      ),
    );
  }
}

class ImageWidget extends StatefulWidget {
  const ImageWidget({super.key});
  @override
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  final _imageTypeKey = 'imageType';
  final _imageKey = 'image';
  bool _initializing = true;
  bool _loading = false;

  ImageType? _imageType;

  /// Decoded from the widget file on each load — avoids [Image.file] / [FileImage] path cache issues.
  Uint8List? _storedImageBytes;

  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final imageTypeString = await HomeWidget.getWidgetData<String>(
      _imageTypeKey,
    );
    final imagePath = await HomeWidget.getWidgetData<String>(_imageKey);

    Uint8List? bytes;
    if (imagePath != null) {
      try {
        bytes = await File(imagePath).readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _initializing = false;
      if (imageTypeString != null) {
        _imageType = ImageType.values.byName(imageTypeString);
      } else {
        _imageType = null;
      }
      _storedImageBytes = bytes;
    });
  }

  Future<void> _updateImage() async {
    setState(() {
      _loading = true;
    });

    try {
      final imageType = _imageType;
      if (imageType == null) {
        await HomeWidget.saveWidgetData(_imageKey, null);
        await HomeWidget.saveWidgetData(_imageTypeKey, null);
      } else {
        final ImageProvider imageProvider = switch (imageType) {
          ImageType.flutter => AssetImage('assets/flutter_logo.png'),
          ImageType.dash => AssetImage('assets/dash.png'),
          ImageType.network => NetworkImage(_imageUrl!),
        };

        await HomeWidget.saveImage(_imageKey, imageProvider);
        await HomeWidget.saveWidgetData(_imageTypeKey, imageType.name);
      }

      await HomeWidget.updateWidget(
        androidName: 'ImageWidgetHomeWidgetReceiver',
        iOSName: 'ImageWidgetHomeWidget',
      );
      await _loadImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return IgnorePointer(
      ignoring: _loading,
      child: Column(
        children: [
          ListTile(
            title: Text('Image Type'),
            trailing: DropdownButton(
              value: _imageType,
              items: [
                DropdownMenuItem(value: null, child: Text('-')),
                DropdownMenuItem(
                  value: ImageType.flutter,
                  child: Text('Flutter'),
                ),
                DropdownMenuItem(value: ImageType.dash, child: Text('Dash')),
                DropdownMenuItem(
                  value: ImageType.network,
                  child: Text('Network'),
                ),
              ],

              onChanged: (value) {
                setState(() {
                  _imageType = value;
                  _imageUrl = null;
                });
              },
            ),
          ),
          if (_imageType == ImageType.network)
            TextField(
              decoration: InputDecoration(labelText: 'Image URL'),
              onChanged: (value) {
                setState(() {
                  _imageUrl = value;
                });
              },
            ),

          if (_storedImageBytes != null)
            ListTile(
              title: Text('Stored Image'),
              trailing: SizedBox.square(
                dimension: 64,
                child: Image.memory(
                  // Use Image from memory to update
                  _storedImageBytes!,
                  fit: BoxFit.scaleDown,
                ),
              ),
            ),

          ElevatedButton(onPressed: _updateImage, child: Text('Update')),
        ],
      ),
    );
  }
}

enum ImageType { flutter, dash, network }

class NameModel {
  const NameModel({required this.name});

  final String name;

  factory NameModel.fromJson(Map<String, dynamic> json) {
    final raw = json['name'];
    return NameModel(name: raw is String && raw.isNotEmpty ? raw : 'World');
  }

  Map<String, dynamic> toJson() => {'name': name};
}

class FileWidget extends StatefulWidget {
  const FileWidget({super.key});
  @override
  State<FileWidget> createState() => _FileWidgetState();
}

class _FileWidgetState extends State<FileWidget> {
  static const _fileJsonKey = 'fileJson';

  final _nameController = TextEditingController();
  bool _initializing = true;
  bool _loading = false;

  String? _storedJsonString;

  String get _effectiveName {
    final t = _nameController.text.trim();
    return t.isEmpty ? 'World' : t;
  }

  String _jsonForName(String name) =>
      jsonEncode(NameModel(name: name).toJson());

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    final path = await HomeWidget.getWidgetData<String>(_fileJsonKey);
    String? text;
    if (path != null) {
      try {
        final bytes = await File(path).readAsBytes();
        text = utf8.decode(bytes);
      } catch (_) {
        text = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _initializing = false;
      _storedJsonString = text;
      if (text != null) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) {
            _nameController.text = NameModel.fromJson(
              Map<String, dynamic>.from(decoded),
            ).name;
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _updateFile() async {
    setState(() {
      _loading = true;
    });

    try {
      final json = _jsonForName(_effectiveName);
      await HomeWidget.saveFile(
        _fileJsonKey,
        Uint8List.fromList(utf8.encode(json)),
        extension: 'json',
      );

      await HomeWidget.updateWidget(
        androidName: 'FileWidgetHomeWidgetReceiver',
        iOSName: 'FileWidgetHomeWidget',
      );
      await _loadFile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    final preview = _storedJsonString ?? _jsonForName(_effectiveName);

    return IgnorePointer(
      ignoring: _loading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'World',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  preview,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          ElevatedButton(onPressed: _updateFile, child: Text('Update')),
        ],
      ),
    );
  }
}
