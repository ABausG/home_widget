import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/widget_spec.dart';
import '../util/cli_io.dart';
import '../util/entitlements.dart';
import '../util/fs.dart';
import '../util/ios_templates.dart';
import '../util/xcode_pbxproj_patcher.dart';

class IosGenerator {
  final WidgetSpec spec;
  final Directory projectRoot;

  IosGenerator({
    required this.spec,
    required this.projectRoot,
  });

  Future<void> generate() async {
    final iosDir = Directory(p.join(projectRoot.path, 'ios'));
    if (!iosDir.existsSync()) {
      cliIO.writelnErr(
        'Warning: ios/ not found. Skipping iOS generation for ${spec.name}.',
      );
      return;
    }

    final xcodeproj = File(
      p.join(iosDir.path, 'Runner.xcodeproj', 'project.pbxproj'),
    );
    if (!xcodeproj.existsSync()) {
      cliIO.writelnErr(
        'Warning: ios/Runner.xcodeproj/project.pbxproj not found. '
        'Skipping iOS Widget Extension target wiring.',
      );
    }

    if (spec.ios == null) {
      return;
    }

    final widgetClassName = '${spec.className}HomeWidget';
    final groupId = spec.ios!.groupId;

    // Create the Widget Extension folder and files.
    final extensionDir = Directory(p.join(iosDir.path, widgetClassName));
    await ensureDir(extensionDir);

    final widgetSwift = File(p.join(extensionDir.path, 'Widget.swift'));
    final widgetBundleSwift = File(
      p.join(extensionDir.path, 'WidgetBundle.swift'),
    );
    final infoPlist = File(p.join(extensionDir.path, 'Info.plist'));
    final extensionEntitlements = File(
      p.join(iosDir.path, '$widgetClassName.entitlements'),
    );

    // 1. Generate Widget.swift
    await widgetSwift.writeAsString(
      iosWidgetSwiftTemplate(
          widgetClassName: widgetClassName, appGroupId: groupId),
    );
    cliIO.writelnOut('Generated: ${widgetSwift.path}');

    // 2. Generate WidgetBundle.swift
    await widgetBundleSwift.writeAsString(
      iosWidgetBundleSwiftTemplate(widgetClassName: widgetClassName),
    );
    cliIO.writelnOut('Generated: ${widgetBundleSwift.path}');

    // 3. Generate Info.plist
    await infoPlist.writeAsString(iosInfoPlistTemplate());
    cliIO.writelnOut('Generated: ${infoPlist.path}');

    // 4. Ensure App Group entitlement is present for the extension and Runner.
    await ensureAppGroupEntitlement(
      entitlementsFile: extensionEntitlements,
      appGroupId: groupId,
    );
    cliIO.writelnOut('Updated: ${extensionEntitlements.path}');

    final runnerEntitlements = File(
      p.join(iosDir.path, 'Runner', 'Runner.entitlements'),
    );
    // Flutter templates usually have this file; if not, we still create it.
    await ensureAppGroupEntitlement(
      entitlementsFile: runnerEntitlements,
      appGroupId: groupId,
    );
    cliIO.writelnOut('Updated: ${runnerEntitlements.path}');

    // 5. Patch the Xcode project so the extension can actually be built.
    if (xcodeproj.existsSync()) {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: xcodeproj,
        widgetClassName: widgetClassName,
      );

      // Ensure Runner is signed with Runner/Runner.entitlements (App Groups apply).
      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: xcodeproj);
      cliIO.writelnOut('Updated: ${xcodeproj.path}');
    }
  }
}
