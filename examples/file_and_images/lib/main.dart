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
        body: ListView(children: [ImageWidget()]),
      ),
    );
  }
}

class ImageWidget extends StatefulWidget {
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
