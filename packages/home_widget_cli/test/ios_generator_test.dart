import 'dart:io';

import 'package:home_widget_cli/src/generators/ios_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'package:home_widget_generator/home_widget_generator.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hw_ios_gen_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('generate creates correct files', () async {
    // Setup minimal iOS structure
    final iosDir = Directory(p.join(tempDir.path, 'ios'));
    await iosDir.create(recursive: true);

    // Create pbxproj
    final xcodeprojDir = Directory(p.join(iosDir.path, 'Runner.xcodeproj'));
    await xcodeprojDir.create(recursive: true);
    final pbxproj = File(p.join(xcodeprojDir.path, 'project.pbxproj'));
    await pbxproj.writeAsString('// project.pbxproj placeholder');

    final spec = WidgetSpec(
      data: const HomeWidget(
        name: 'Test Widget',
        iOS: HomeWidgetIOSConfiguration(groupId: 'group.test.app'),
      ),
      className: 'TestWidget', // This will become TestWidgetHomeWidget
    );

    final generator = IosGenerator(spec: spec, projectRoot: tempDir);
    await generator.generate();

    // Verify files
    final extensionDir = Directory(p.join(iosDir.path, 'TestWidgetHomeWidget'));
    final widgetSwift = File(p.join(extensionDir.path, 'Widget.swift'));
    final widgetBundleSwift =
        File(p.join(extensionDir.path, 'WidgetBundle.swift'));
    final infoPlist = File(p.join(extensionDir.path, 'Info.plist'));
    final extensionEntitlements =
        File(p.join(iosDir.path, 'TestWidgetHomeWidget.entitlements'));
    final runnerEntitlements =
        File(p.join(iosDir.path, 'Runner', 'Runner.entitlements'));

    expect(widgetSwift.existsSync(), isTrue);
    expect(widgetBundleSwift.existsSync(), isTrue);
    expect(infoPlist.existsSync(), isTrue);

    final swiftContent = await widgetSwift.readAsString();
    expect(swiftContent, contains('struct TestWidgetHomeWidget: Widget'));
    expect(swiftContent, contains('App Group ID used here: group.test.app'));

    final bundleContent = await widgetBundleSwift.readAsString();
    expect(bundleContent,
        contains('struct TestWidgetHomeWidgetBundle: WidgetBundle'));
    expect(bundleContent, contains('TestWidgetHomeWidget()'));

    // Check entitlements creation (stubbed by ensuring path exists in test logic of generator, assuming utils work)
    expect(extensionEntitlements.existsSync(), isTrue);
    expect(runnerEntitlements.existsSync(), isTrue);

    final entitlementContent = await extensionEntitlements.readAsString();
    expect(entitlementContent, contains('group.test.app'));
  });
}
