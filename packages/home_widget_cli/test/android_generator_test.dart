import 'dart:io';

import 'package:home_widget_cli/src/generators/android_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'package:home_widget_generator/home_widget_generator.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hw_android_gen_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('generate creates correct files', () async {
    // Setup minimal android structure
    final appDir = Directory(p.join(tempDir.path, 'android', 'app'));
    await appDir.create(recursive: true);

    // Create manifest
    final manifestFile =
        File(p.join(appDir.path, 'src', 'main', 'AndroidManifest.xml'));
    await manifestFile.create(recursive: true);
    await manifestFile.writeAsString('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.test.app">
    <application>
    </application>
</manifest>
''');

    // Create build.gradle
    final gradleFile = File(p.join(appDir.path, 'build.gradle'));
    await gradleFile.create(recursive: true);
    await gradleFile.writeAsString('// build.gradle');

    final spec = WidgetSpec(
      data: const HomeWidget(
        name: 'Test Widget',
        android: HomeWidgetAndroidConfiguration(packageName: 'com.test.app'),
      ),
      className: 'TestWidget', // This will become TestWidgetHomeWidget
    );

    final generator = AndroidGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    // Verify files
    final kotlinDir =
        p.join(appDir.path, 'src', 'main', 'kotlin', 'com', 'test', 'app');
    final widgetFile = File(p.join(kotlinDir, 'TestWidgetHomeWidget.kt'));
    final receiverFile =
        File(p.join(kotlinDir, 'TestWidgetHomeWidgetReceiver.kt'));
    final xmlFile = File(p.join(appDir.path, 'src', 'main', 'res', 'xml',
        'test_widget_home_widget.xml'));

    expect(widgetFile.existsSync(), isTrue);
    expect(receiverFile.existsSync(), isTrue);
    expect(xmlFile.existsSync(), isTrue);

    final widgetContent = await widgetFile.readAsString();
    expect(widgetContent,
        contains('class TestWidgetHomeWidget : GlanceAppWidget()'));
    expect(widgetContent, contains('package com.test.app'));

    final receiverContent = await receiverFile.readAsString();
    expect(
        receiverContent,
        contains(
            'class TestWidgetHomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TestWidgetHomeWidget>()'));

    final xmlContent = await xmlFile.readAsString();
    expect(
        xmlContent,
        contains(
            'android:initialLayout="@layout/glance_default_loading_layout"'));

    // Verify manifest update
    final manifestContent = await manifestFile.readAsString();
    expect(manifestContent, contains('TestWidgetHomeWidgetReceiver'));
    expect(manifestContent, contains('@xml/test_widget_home_widget'));
  });
}
