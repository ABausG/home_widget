import 'dart:io';

import 'logger.dart';
import 'fnv_hash.dart';

/// Ensures an iOS Widget Extension target exists inside the given Xcode
/// `project.pbxproj` file.
///
/// This uses the "File System Synchronized" group approach (modern Xcode)
/// similar to the repo's `examples/lockscreen_widgets` sample, because it avoids
/// having to list every Swift file explicitly in the pbxproj.
Future<void> ensureWidgetExtensionTargetInXcodeProject({
  required File pbxprojFile,
  required String widgetClassName,
}) async {
  final text = await pbxprojFile.readAsString();

  final hasFileSystemSynchronizedSections =
      text.contains('/* Begin PBXFileSystemSynchronizedRootGroup section */') &&
          text.contains(
            '/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */',
          );

  // Idempotency: if a target with this name already exists, do nothing.
  if (RegExp(
    r'isa\s*=\s*PBXNativeTarget;[\s\S]*?\n\s*name\s*=\s*' +
        RegExp.escape(widgetClassName) +
        r';',
  ).hasMatch(text)) {
    // Even if the Widget Extension target already exists, the Runner target may
    // still be missing the entitlements build setting (App Groups won't apply).
    await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);
    await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
      pbxprojFile: pbxprojFile,
    );
    return;
  }

  final runnerTargetId = _findTargetIdByName(text, 'Runner');
  final projectObjectId = _findProjectObjectId(text);
  final mainGroupId = _findProjectFieldId(text, 'mainGroup');
  final productsGroupId = _findProjectFieldId(text, 'productRefGroup');

  if (runnerTargetId == null ||
      projectObjectId == null ||
      mainGroupId == null ||
      productsGroupId == null) {
    logger.warn(
      'Warning: Could not locate required Xcode project IDs in '
      '${pbxprojFile.path}. Skipping Widget Extension wiring.',
    );
    return;
  }

  final baseBundleId = _detectRunnerBundleIdentifier(text) ?? 'com.example.app';
  final developmentTeam = _detectRunnerDevelopmentTeam(text);
  final extBundleId = '$baseBundleId.$widgetClassName';
  final developmentTeamLine = _developmentTeamBuildSettingLine(developmentTeam);

  final ids = _WidgetExtensionIds(widgetClassName);

  // Build the objects we will inject.
  final pbxBuildFiles = <String>[
    '\t\t${ids.embedBuildFileId} /* $widgetClassName.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = ${ids.productFileRefId} /* $widgetClassName.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };',
    '\t\t${ids.widgetKitBuildFileId} /* WidgetKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${ids.widgetKitFileRefId} /* WidgetKit.framework */; };',
    '\t\t${ids.swiftUIBuildFileId} /* SwiftUI.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${ids.swiftUIFileRefId} /* SwiftUI.framework */; };',
    if (!hasFileSystemSynchronizedSections)
      '\t\t${ids.widgetSwiftBuildFileId} /* Widget.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${ids.widgetSwiftFileRefId} /* Widget.swift */; };',
    if (!hasFileSystemSynchronizedSections)
      '\t\t${ids.widgetBundleSwiftBuildFileId} /* WidgetBundle.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${ids.widgetBundleSwiftFileRefId} /* WidgetBundle.swift */; };',
  ].join('\n');

  final pbxContainerProxy = '''
\t\t${ids.containerProxyId} /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = $projectObjectId /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = ${ids.targetId};
\t\t\tremoteInfo = $widgetClassName;
\t\t};
'''
      .trimRight();

  final pbxCopyPhase = '''
\t\t${ids.copyFilesPhaseId} /* Embed Foundation Extensions */ = {
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t${ids.embedBuildFileId} /* $widgetClassName.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
'''
      .trimRight();

  final pbxFileReferences = <String>[
    '\t\t${ids.productFileRefId} /* $widgetClassName.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = $widgetClassName.appex; sourceTree = BUILT_PRODUCTS_DIR; };',
    '\t\t${ids.widgetKitFileRefId} /* WidgetKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; };',
    '\t\t${ids.swiftUIFileRefId} /* SwiftUI.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = SwiftUI.framework; path = System/Library/Frameworks/SwiftUI.framework; sourceTree = SDKROOT; };',
    '\t\t${ids.entitlementsFileRefId} /* $widgetClassName.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = $widgetClassName.entitlements; sourceTree = "<group>"; };',
    if (!hasFileSystemSynchronizedSections)
      '\t\t${ids.widgetSwiftFileRefId} /* Widget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Widget.swift; sourceTree = "<group>"; };',
    if (!hasFileSystemSynchronizedSections)
      '\t\t${ids.widgetBundleSwiftFileRefId} /* WidgetBundle.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WidgetBundle.swift; sourceTree = "<group>"; };',
    if (!hasFileSystemSynchronizedSections)
      '\t\t${ids.infoPlistFileRefId} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };',
  ].join('\n');

  final fsExceptionSet = hasFileSystemSynchronizedSections
      ? '''
\t\t${ids.fsExceptionId} /* Exceptions for "$widgetClassName" folder in "$widgetClassName" target */ = {
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t);
\t\t\ttarget = ${ids.targetId} /* $widgetClassName */;
\t\t};
'''
          .trimRight()
      : null;

  final fsRootGroup = hasFileSystemSynchronizedSections
      ? '''
\t\t${ids.fsRootGroupId} /* $widgetClassName */ = {
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\texceptions = (
\t\t\t\t${ids.fsExceptionId} /* Exceptions for "$widgetClassName" folder in "$widgetClassName" target */,
\t\t\t);
\t\t\texplicitFileTypes = {
\t\t\t};
\t\t\texplicitFolders = (
\t\t\t);
\t\t\tpath = $widgetClassName;
\t\t\tsourceTree = "<group>";
\t\t};
'''
          .trimRight()
      : null;

  final widgetGroup = !hasFileSystemSynchronizedSections
      ? '''
\t\t${ids.widgetGroupId} /* $widgetClassName */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t${ids.widgetSwiftFileRefId} /* Widget.swift */,
\t\t\t\t${ids.widgetBundleSwiftFileRefId} /* WidgetBundle.swift */,
\t\t\t\t${ids.infoPlistFileRefId} /* Info.plist */,
\t\t\t);
\t\t\tpath = $widgetClassName;
\t\t\tsourceTree = "<group>";
\t\t};
'''
          .trimRight()
      : null;

  final extFrameworkPhase = '''
\t\t${ids.frameworksPhaseId} /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t${ids.swiftUIBuildFileId} /* SwiftUI.framework in Frameworks */,
\t\t\t\t${ids.widgetKitBuildFileId} /* WidgetKit.framework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
'''
      .trimRight();

  final extSourcesPhase = '''
\t\t${ids.sourcesPhaseId} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t${!hasFileSystemSynchronizedSections ? '${ids.widgetSwiftBuildFileId} /* Widget.swift in Sources */,' : ''}
\t\t\t\t${!hasFileSystemSynchronizedSections ? '${ids.widgetBundleSwiftBuildFileId} /* WidgetBundle.swift in Sources */,' : ''}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
'''
      .trimRight();

  final extResourcesPhase = '''
\t\t${ids.resourcesPhaseId} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
'''
      .trimRight();

  final extTarget = '''
\t\t${ids.targetId} /* $widgetClassName */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = ${ids.configListId} /* Build configuration list for PBXNativeTarget "$widgetClassName" */;
\t\t\tbuildPhases = (
\t\t\t\t${ids.sourcesPhaseId} /* Sources */,
\t\t\t\t${ids.frameworksPhaseId} /* Frameworks */,
\t\t\t\t${ids.resourcesPhaseId} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\t${hasFileSystemSynchronizedSections ? '''
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t${ids.fsRootGroupId} /* $widgetClassName */,
\t\t\t);
''' : ''}
\t\t\tname = $widgetClassName;
\t\t\tproductName = $widgetClassName;
\t\t\tproductReference = ${ids.productFileRefId} /* $widgetClassName.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t};
'''
      .trimRight();

  final targetDependency = '''
\t\t${ids.targetDependencyId} /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = ${ids.targetId} /* $widgetClassName */;
\t\t\ttargetProxy = ${ids.containerProxyId} /* PBXContainerItemProxy */;
\t\t};
'''
      .trimRight();

  final xcBuildConfigs = '''
\t\t${ids.configDebugId} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = $widgetClassName.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
$developmentTeamLine\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tINFOPLIST_FILE = $widgetClassName/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = $widgetClassName;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"\$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $extBundleId;
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${ids.configReleaseId} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = $widgetClassName.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
$developmentTeamLine\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tINFOPLIST_FILE = $widgetClassName/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = $widgetClassName;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"\$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $extBundleId;
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\t${ids.configProfileId} /* Profile */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = $widgetClassName.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
$developmentTeamLine\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tINFOPLIST_FILE = $widgetClassName/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = $widgetClassName;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"\$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $extBundleId;
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Profile;
\t\t};
'''
      .trimRight();

  final configList = '''
\t\t${ids.configListId} /* Build configuration list for PBXNativeTarget "$widgetClassName" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${ids.configDebugId} /* Debug */,
\t\t\t\t${ids.configReleaseId} /* Release */,
\t\t\t\t${ids.configProfileId} /* Profile */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
'''
      .trimRight();

  // Apply section inserts.
  var updated = text;
  updated = _insertIntoSection(
    updated,
    section: 'PBXBuildFile',
    content: pbxBuildFiles,
  );
  updated = _insertIntoSection(
    updated,
    section: 'PBXContainerItemProxy',
    content: pbxContainerProxy,
  );
  updated = _insertIntoSection(
    updated,
    section: 'PBXCopyFilesBuildPhase',
    content: pbxCopyPhase,
  );
  updated = _insertIntoSection(
    updated,
    section: 'PBXFileReference',
    content: pbxFileReferences,
  );
  if (hasFileSystemSynchronizedSections) {
    updated = _insertIntoSection(
      updated,
      section: 'PBXFileSystemSynchronizedBuildFileExceptionSet',
      content: fsExceptionSet!,
    );
    updated = _insertIntoSection(
      updated,
      section: 'PBXFileSystemSynchronizedRootGroup',
      content: fsRootGroup!,
    );
  } else {
    updated =
        _insertIntoSection(updated, section: 'PBXGroup', content: widgetGroup!);
  }
  updated = _insertIntoSection(
    updated,
    section: 'PBXFrameworksBuildPhase',
    content: extFrameworkPhase,
  );
  updated = _insertIntoSection(
    updated,
    section: 'PBXSourcesBuildPhase',
    content: extSourcesPhase,
  );
  updated = _insertIntoSection(
    updated,
    section: 'PBXResourcesBuildPhase',
    content: extResourcesPhase,
  );
  updated = _insertIntoSection(
    updated,
    section: 'PBXNativeTarget',
    content: extTarget,
  );
  updated = _insertIntoSection(
    updated,
    section: 'PBXTargetDependency',
    content: targetDependency,
  );
  updated = _insertIntoSection(
    updated,
    section: 'XCBuildConfiguration',
    content: xcBuildConfigs,
  );
  updated = _insertIntoSection(
    updated,
    section: 'XCConfigurationList',
    content: configList,
  );

  // Patch "Runner" target: embed extension + target dependency.
  updated = _ensureRunnerEmbedsWidgetExtensionInSafeOrder(
    updated,
    runnerTargetId: runnerTargetId,
    embedCopyPhaseId: ids.copyFilesPhaseId,
  );
  updated = _patchNativeTargetListAddId(
    updated,
    targetId: runnerTargetId,
    listKey: 'dependencies',
    idToAdd: '${ids.targetDependencyId} /* PBXTargetDependency */',
  );

  // Patch PBXProject targets list.
  updated = _patchProjectTargetsListAddId(
    updated,
    projectObjectId: projectObjectId,
    idToAdd: '${ids.targetId} /* $widgetClassName */',
  );

  // Add extension product to Products group.
  updated = _patchGroupChildrenAddId(
    updated,
    groupId: productsGroupId,
    idToAdd: '${ids.productFileRefId} /* $widgetClassName.appex */',
  );

  // Add the file-system-synchronized group and entitlements file to the main
  // group so it shows up in Xcode.
  updated = _patchGroupChildrenAddId(
    updated,
    groupId: mainGroupId,
    idToAdd: '${ids.entitlementsFileRefId} /* $widgetClassName.entitlements */',
  );
  updated = _patchGroupChildrenAddId(
    updated,
    groupId: mainGroupId,
    idToAdd: hasFileSystemSynchronizedSections
        ? '${ids.fsRootGroupId} /* $widgetClassName */'
        : '${ids.widgetGroupId} /* $widgetClassName */',
  );

  // Ensure Runner embeds the extension product (copy phase exists already now)
  // and that Runner depends on the extension (dependency object exists now).
  // We also need to ensure the copy phase is added to Runner build phases.

  if (updated != text) {
    await pbxprojFile.writeAsString(updated);
    logger.detail('Updated Xcode project: ${pbxprojFile.path}');
    logger.detail(
      'Added Widget Extension target "$widgetClassName" (bundle id: $extBundleId).',
    );
  }

  // Ensure the main app target is actually signed with Runner/Runner.entitlements.
  // Without this, the App Group entitlement won't be applied even if the file exists.
  await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);
  await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
    pbxprojFile: pbxprojFile,
  );
}

/// Ensures the Runner target uses `Runner/Runner.entitlements` for code signing.
///
/// The iOS scaffolder creates `ios/Runner/Runner.entitlements`, but Xcode only
/// applies it if `CODE_SIGN_ENTITLEMENTS` is set for the Runner target configs.
Future<void> ensureRunnerEntitlementsInXcodeProject({
  required File pbxprojFile,
}) async {
  var text = await pbxprojFile.readAsString();

  const desiredLine =
      '\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;';
  if (text.contains(desiredLine)) return;

  final configBlockRe = RegExp(
    r'(\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile) \*/ = \{\n'
    r'\t\t\tisa = XCBuildConfiguration;\n'
    r'(?:\t\t\tbaseConfigurationReference = [^\n]*\n)?'
    r'\t\t\tbuildSettings = \{\n)'
    r'([\s\S]*?)'
    r'(\n\t\t\t\};\n\t\t\tname = (?:Debug|Release|Profile);\n\t\t\};)',
  );

  var didChange = false;
  text = text.replaceAllMapped(configBlockRe, (m) {
    final header = m.group(1)!;
    var settings = m.group(2)!;
    final footer = m.group(3)!;

    if (!settings.contains('INFOPLIST_FILE = Runner/Info.plist;')) {
      return m.group(0)!;
    }

    // If some other entitlements line exists, replace it; otherwise insert.
    final existingEntitlementsRe = RegExp(
      r'^\t\t\t\tCODE_SIGN_ENTITLEMENTS = [^;]+;$',
      multiLine: true,
    );
    if (existingEntitlementsRe.hasMatch(settings)) {
      settings = settings.replaceAll(existingEntitlementsRe, desiredLine);
      didChange = true;
      return '$header$settings$footer';
    }

    final anchor = 'INFOPLIST_FILE = Runner/Info.plist;\n';
    if (settings.contains(anchor)) {
      settings = settings.replaceFirst(anchor, '$anchor$desiredLine\n');
      didChange = true;
      return '$header$settings$footer';
    }

    return m.group(0)!;
  });

  if (!didChange) {
    // Don't fail the whole command, but let the user know scaffolding might
    // require manual intervention for non-standard pbxproj layouts.
    logger.warn(
      'Warning: Could not auto-set CODE_SIGN_ENTITLEMENTS for Runner in '
      '${pbxprojFile.path}. You may need to set it manually to Runner/Runner.entitlements.',
    );
    return;
  }

  await pbxprojFile.writeAsString(text);
  logger.detail('Updated Xcode project: ${pbxprojFile.path}');
  logger.detail('Ensured Runner uses Runner/Runner.entitlements.');
}

/// Ensures that the Runner target's `IPHONEOS_DEPLOYMENT_TARGET` is at least
/// [minimumVersion] (defaults to `14.0`).
///
/// The `home_widget` plugin requires iOS 14.0+. If the app targets an older
/// version, `pod install` will fail. This function bumps the deployment target
/// in all Runner build configurations when it is below the minimum.
Future<void> ensureMinimumDeploymentTargetInXcodeProject({
  required File pbxprojFile,
  double minimumVersion = 14.0,
}) async {
  var text = await pbxprojFile.readAsString();

  final configBlockRe = RegExp(
    r'(\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile) \*/ = \{\n'
    r'\t\t\tisa = XCBuildConfiguration;\n'
    r'(?:\t\t\tbaseConfigurationReference = [^\n]*\n)?'
    r'\t\t\tbuildSettings = \{\n)'
    r'([\s\S]*?)'
    r'(\n\t\t\t\};\n\t\t\tname = (?:Debug|Release|Profile);\n\t\t\};)',
  );

  var didChange = false;
  text = text.replaceAllMapped(configBlockRe, (m) {
    final header = m.group(1)!;
    var settings = m.group(2)!;
    final footer = m.group(3)!;

    // Only patch Runner configs (identified by the Runner Info.plist).
    if (!settings.contains('INFOPLIST_FILE = Runner/Info.plist;')) {
      return m.group(0)!;
    }

    final deployTargetRe = RegExp(
      r'^\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);$',
      multiLine: true,
    );
    final match = deployTargetRe.firstMatch(settings);

    if (match != null) {
      final currentVersion = double.tryParse(match.group(1)!) ?? 0.0;
      if (currentVersion < minimumVersion) {
        settings = settings.replaceFirst(
          deployTargetRe,
          '\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = $minimumVersion;',
        );
        didChange = true;
      }
    } else {
      // No IPHONEOS_DEPLOYMENT_TARGET at all – insert it after INFOPLIST_FILE.
      const anchor = 'INFOPLIST_FILE = Runner/Info.plist;\n';
      if (settings.contains(anchor)) {
        settings = settings.replaceFirst(
          anchor,
          '$anchor\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = $minimumVersion;\n',
        );
        didChange = true;
      }
    }

    return '$header$settings$footer';
  });

  if (!didChange) return;

  await pbxprojFile.writeAsString(text);
  logger.detail('Updated Xcode project: ${pbxprojFile.path}');
  logger.detail(
    'Ensured Runner IPHONEOS_DEPLOYMENT_TARGET >= $minimumVersion.',
  );
}

/// Ensures widget extension targets use the same [DEVELOPMENT_TEAM] as Runner.
///
/// Physical device builds fail when extension targets lack a development team
/// even if the main app target is already signed.
Future<void> ensureWidgetExtensionDevelopmentTeamInXcodeProject({
  required File pbxprojFile,
}) async {
  var text = await pbxprojFile.readAsString();
  final team = _detectRunnerDevelopmentTeam(text);
  if (team == null || team.isEmpty) return;

  final desiredLine = '\t\t\t\tDEVELOPMENT_TEAM = $team;';

  final configBlockRe = RegExp(
    r'(\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile) \*/ = \{\n'
    r'\t\t\tisa = XCBuildConfiguration;\n'
    r'(?:\t\t\tbaseConfigurationReference = [^\n]*\n)?'
    r'\t\t\tbuildSettings = \{\n)'
    r'([\s\S]*?)'
    r'(\n\t\t\t\};\n\t\t\tname = (?:Debug|Release|Profile);\n\t\t\};)',
  );

  var didChange = false;
  text = text.replaceAllMapped(configBlockRe, (m) {
    final header = m.group(1)!;
    var settings = m.group(2)!;
    final footer = m.group(3)!;

    if (!settings.contains('APPLICATION_EXTENSION_API_ONLY = YES;')) {
      return m.group(0)!;
    }

    final existingTeamRe = RegExp(
      r'^\t\t\t\tDEVELOPMENT_TEAM = [^;]+;$',
      multiLine: true,
    );
    if (existingTeamRe.hasMatch(settings)) {
      if (settings.contains(desiredLine)) return m.group(0)!;
      settings = settings.replaceAll(existingTeamRe, desiredLine);
      didChange = true;
      return '$header$settings$footer';
    }

    const anchor = 'CODE_SIGN_STYLE = Automatic;\n';
    if (settings.contains(anchor)) {
      settings = settings.replaceFirst(anchor, '$anchor$desiredLine\n');
      didChange = true;
      return '$header$settings$footer';
    }

    return m.group(0)!;
  });

  if (!didChange) return;

  await pbxprojFile.writeAsString(text);
  logger.detail('Updated Xcode project: ${pbxprojFile.path}');
  logger.detail('Ensured widget extensions use DEVELOPMENT_TEAM = $team.');
}

String _developmentTeamBuildSettingLine(String? team) {
  if (team == null || team.isEmpty) return '';
  return '\t\t\t\tDEVELOPMENT_TEAM = $team;\n';
}

String _ensureRunnerEmbedsWidgetExtensionInSafeOrder(
  String pbxproj, {
  required String runnerTargetId,
  required String embedCopyPhaseId,
}) {
  // coverage:ignore-start
  // We must avoid an Xcode build cycle:
  // - If "Thin Binary" runs before embedding the extension, Xcode can detect a
  //   copy-phase ↔ script-phase cycle.
  //
  // This matches the ordering used by our examples:
  // - "Embed Foundation Extensions" should run before "[CP] Embed Pods Frameworks"
  // - "Thin Binary" should be last
  const thinBinaryComment = '/* Thin Binary */';
  const embedPodsComment = '/* [CP] Embed Pods Frameworks */';

  final idWithComment = '$embedCopyPhaseId /* Embed Foundation Extensions */';

  final targetBlockRegex = RegExp(
    r'^\s*' +
        RegExp.escape(runnerTargetId) +
        r' /\* .*? \*/ = \{[\s\S]*?\n\s*\};\s*$',
    multiLine: true,
  );
  final block = targetBlockRegex.firstMatch(pbxproj)?.group(0);
  if (block == null) return pbxproj;

  final listRegex = RegExp(
    r'(^\s*buildPhases\s*=\s*\(\s*$)([\s\S]*?)(^\s*\);\s*$)',
    multiLine: true,
  );
  final m = listRegex.firstMatch(block);
  if (m == null) return pbxproj;

  final before = m.group(1)!;
  final inner = m.group(2)!;
  final after = m.group(3)!;

  // Split into lines but keep original formatting as much as possible.
  final lines = inner.split('\n');

  bool isEmbedLine(String line) => line.contains(embedCopyPhaseId);
  bool isEmbedPodsLine(String line) => line.contains(embedPodsComment);
  bool isThinBinaryLine(String line) => line.contains(thinBinaryComment);

  String? embedLine;
  String? thinLine;

  final remaining = <String>[];
  for (final line in lines) {
    if (embedLine == null && isEmbedLine(line)) {
      embedLine = line.trim().isEmpty ? null : line;
      continue;
    }
    if (thinLine == null && isThinBinaryLine(line)) {
      thinLine = line.trim().isEmpty ? null : line;
      continue;
    }
    remaining.add(line);
  }

  // Choose indentation based on existing list entries; fallback to 4 tabs which
  // matches typical pbxproj formatting.
  final indent = remaining.firstWhere(
    (l) => l.trim().isNotEmpty,
    orElse: () => '\t\t\t\t',
  );
  final indentPrefix =
      RegExp(r'^\s*').firstMatch(indent)?.group(0) ?? '\t\t\t\t';

  embedLine ??= '$indentPrefix$idWithComment,';

  // Insert embedLine before "[CP] Embed Pods Frameworks" if present, else before
  // Thin Binary if present, else append.
  final rebuilt = <String>[];
  var insertedEmbed = false;
  for (final line in remaining) {
    if (!insertedEmbed &&
        line.trim().isNotEmpty &&
        (isEmbedPodsLine(line) || isThinBinaryLine(line))) {
      rebuilt.add(embedLine);
      insertedEmbed = true;
    }
    rebuilt.add(line);
  }
  if (!insertedEmbed) {
    // Append before trailing empty line (if any)
    if (rebuilt.isNotEmpty && rebuilt.last.trim().isEmpty) {
      rebuilt.insert(rebuilt.length - 1, embedLine);
    } else {
      rebuilt.add(embedLine);
    }
  }

  // Ensure Thin Binary is last (if it exists in the list).
  if (thinLine != null) {
    // Remove any other Thin Binary occurrences (just in case).
    rebuilt.removeWhere((l) => isThinBinaryLine(l));

    // Append it at the end, but preserve a trailing empty line if present.
    if (rebuilt.isNotEmpty && rebuilt.last.trim().isEmpty) {
      rebuilt.insert(rebuilt.length - 1, thinLine);
    } else {
      rebuilt.add(thinLine);
    }
  }

  final newInner = rebuilt.join('\n');
  final newBlock = block.replaceRange(m.start, m.end, '$before$newInner$after');
  var out = pbxproj.replaceFirst(block, newBlock);

  // If the embed phase didn't exist at all, ensure it’s also present in buildPhases.
  // (The list rewrite above already inserted it, but this is extra safety if the
  // list parsing ever fails in some edge case.)
  if (!out.contains(idWithComment)) {
    out = _patchNativeTargetListAddId(
      out,
      targetId: runnerTargetId,
      listKey: 'buildPhases',
      idToAdd: idWithComment,
    );
  }

  return out;
  // coverage:ignore-end
}

final class _WidgetExtensionIds {
  _WidgetExtensionIds(String widgetClassName)
      : targetId = xcodeObjectId('target:$widgetClassName'),
        productFileRefId = xcodeObjectId('fileref:product:$widgetClassName'),
        entitlementsFileRefId =
            xcodeObjectId('fileref:entitlements:$widgetClassName'),
        widgetGroupId = xcodeObjectId('group:$widgetClassName'),
        widgetSwiftFileRefId =
            xcodeObjectId('fileref:Widget.swift:$widgetClassName'),
        widgetBundleSwiftFileRefId =
            xcodeObjectId('fileref:WidgetBundle.swift:$widgetClassName'),
        infoPlistFileRefId =
            xcodeObjectId('fileref:Info.plist:$widgetClassName'),
        widgetSwiftBuildFileId =
            xcodeObjectId('buildfile:Widget.swift:$widgetClassName'),
        widgetBundleSwiftBuildFileId =
            xcodeObjectId('buildfile:WidgetBundle.swift:$widgetClassName'),
        sourcesPhaseId = xcodeObjectId('phase:sources:$widgetClassName'),
        frameworksPhaseId = xcodeObjectId('phase:frameworks:$widgetClassName'),
        resourcesPhaseId = xcodeObjectId('phase:resources:$widgetClassName'),
        copyFilesPhaseId = xcodeObjectId('phase:copy:$widgetClassName'),
        embedBuildFileId = xcodeObjectId('buildfile:embed:$widgetClassName'),
        containerProxyId = xcodeObjectId('proxy:$widgetClassName'),
        targetDependencyId = xcodeObjectId('dep:$widgetClassName'),
        swiftUIFileRefId = xcodeObjectId('fileref:SwiftUI:$widgetClassName'),
        widgetKitFileRefId =
            xcodeObjectId('fileref:WidgetKit:$widgetClassName'),
        swiftUIBuildFileId =
            xcodeObjectId('buildfile:SwiftUI:$widgetClassName'),
        widgetKitBuildFileId =
            xcodeObjectId('buildfile:WidgetKit:$widgetClassName'),
        fsExceptionId = xcodeObjectId('fsex:$widgetClassName'),
        fsRootGroupId = xcodeObjectId('fsgroup:$widgetClassName'),
        configDebugId = xcodeObjectId('cfg:Debug:$widgetClassName'),
        configReleaseId = xcodeObjectId('cfg:Release:$widgetClassName'),
        configProfileId = xcodeObjectId('cfg:Profile:$widgetClassName'),
        configListId = xcodeObjectId('cfglist:$widgetClassName');

  final String targetId;
  final String productFileRefId;
  final String entitlementsFileRefId;
  final String widgetGroupId;
  final String widgetSwiftFileRefId;
  final String widgetBundleSwiftFileRefId;
  final String infoPlistFileRefId;
  final String widgetSwiftBuildFileId;
  final String widgetBundleSwiftBuildFileId;
  final String sourcesPhaseId;
  final String frameworksPhaseId;
  final String resourcesPhaseId;
  final String copyFilesPhaseId;
  final String embedBuildFileId;
  final String containerProxyId;
  final String targetDependencyId;
  final String swiftUIFileRefId;
  final String widgetKitFileRefId;
  final String swiftUIBuildFileId;
  final String widgetKitBuildFileId;
  final String fsExceptionId;
  final String fsRootGroupId;
  final String configDebugId;
  final String configReleaseId;
  final String configProfileId;
  final String configListId;
}

String? _findProjectObjectId(String pbxproj) {
  final m = RegExp(
    r'^\s*([A-F0-9]{24}) /\* Project object \*/ = \{\s*\n\s*isa = PBXProject;',
    multiLine: true,
  ).firstMatch(pbxproj);
  return m?.group(1);
}

String? _findProjectFieldId(String pbxproj, String fieldName) {
  final projectObjectId = _findProjectObjectId(pbxproj);
  if (projectObjectId == null) return null;

  // Extract the PBXProject object block.
  //
  // IMPORTANT: A PBXProject object contains nested `{}` (e.g. `attributes = { ... };`)
  // so a non-greedy regex like `{[\s\S]*?\n\s*\};` will stop at the *first* `};`
  // and truncate the object. We therefore use simple brace matching to find the
  // correct end of the PBXProject object.
  final projectBlock = _extractPbxObjectBlock(
    pbxproj,
    objectId: projectObjectId,
    expectedComment: 'Project object',
  );
  if (projectBlock == null) return null;

  final m = RegExp(
    r'^\s*' + RegExp.escape(fieldName) + r'\s*=\s*([A-F0-9]{24})',
    multiLine: true,
  ).firstMatch(projectBlock);
  return m?.group(1);
}

String? _extractPbxObjectBlock(
  String pbxproj, {
  required String objectId,
  String? expectedComment,
}) {
  // Try the common "id /* Comment */ = {" form first.
  final withCommentNeedle =
      expectedComment == null ? null : '$objectId /* $expectedComment */ = {';
  var startIdx =
      withCommentNeedle == null ? -1 : pbxproj.indexOf(withCommentNeedle);

  // Fall back to "id = {" form (rare, but safe).
  if (startIdx == -1) {
    // coverage:ignore-start
    final withoutCommentNeedle = '$objectId = {';
    startIdx = pbxproj.indexOf(withoutCommentNeedle);
    // coverage:ignore-end
  }
  if (startIdx == -1) return null;

  // Find the first `{` for the object, then scan until its matching `}`.
  final braceStart = pbxproj.indexOf('{', startIdx);
  if (braceStart == -1) return null;

  var depth = 0;
  for (var i = braceStart; i < pbxproj.length; i++) {
    final ch = pbxproj.codeUnitAt(i);
    if (ch == 0x7B) {
      // {
      depth++;
    } else if (ch == 0x7D) {
      // }
      depth--;
      if (depth == 0) {
        // Include trailing `;` if present (Xcode uses `};`).
        var end = i + 1;
        if (end < pbxproj.length && pbxproj.codeUnitAt(end) == 0x3B) {
          // ;
          end++;
        }
        return pbxproj.substring(startIdx, end);
      }
    }
  }
  return null;
}

String? _findTargetIdByName(String pbxproj, String name) {
  final m = RegExp(
    r'^\s*([A-F0-9]{24}) /\* ' +
        RegExp.escape(name) +
        r' \*/ = \{\s*\n\s*isa = PBXNativeTarget;',
    multiLine: true,
  ).firstMatch(pbxproj);
  return m?.group(1);
}

String? _detectRunnerBundleIdentifier(String pbxproj) {
  // Find an XCBuildConfiguration that belongs to Runner by looking for
  // INFOPLIST_FILE = Runner/Info.plist.
  final m = RegExp(
    r'isa = XCBuildConfiguration;[\s\S]*?buildSettings = \{[\s\S]*?INFOPLIST_FILE = Runner/Info\.plist;[\s\S]*?PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
  ).firstMatch(pbxproj);
  return m?.group(1)?.trim();
}

String? _detectRunnerDevelopmentTeam(String pbxproj) {
  final configBlockRe = RegExp(
    r'isa = XCBuildConfiguration;[\s\S]*?buildSettings = \{([\s\S]*?)\};\s*name = (?:Debug|Release|Profile);',
  );
  for (final match in configBlockRe.allMatches(pbxproj)) {
    final settings = match.group(1)!;
    if (!settings.contains('INFOPLIST_FILE = Runner/Info.plist;')) continue;
    final teamMatch = RegExp(
      r'DEVELOPMENT_TEAM = ([^;]+);',
    ).firstMatch(settings);
    if (teamMatch != null) return teamMatch.group(1)?.trim();
  }
  return null;
}

String _insertIntoSection(
  String pbxproj, {
  required String section,
  required String content,
}) {
  final begin = '/* Begin $section section */';
  final end = '/* End $section section */';

  final beginIdx = pbxproj.indexOf(begin);
  final endIdx = pbxproj.indexOf(end);
  if (beginIdx == -1 || endIdx == -1 || endIdx <= beginIdx) return pbxproj;

  // Insert just before the end marker.
  final insertAt = endIdx;
  final prefix = pbxproj.substring(0, insertAt);
  final suffix = pbxproj.substring(insertAt);

  // Ensure we separate by a newline.
  final needsNewline = !prefix.endsWith('\n');
  final toInsert = '${needsNewline ? '\n' : ''}$content\n';
  return '$prefix$toInsert$suffix';
}

String _patchNativeTargetListAddId(
  String pbxproj, {
  required String targetId,
  required String listKey,
  required String idToAdd,
}) {
  final targetBlockRegex = RegExp(
    r'^\s*' +
        RegExp.escape(targetId) +
        r' /\* .*? \*/ = \{[\s\S]*?\n\s*\};\s*$',
    multiLine: true,
  );
  final block = targetBlockRegex.firstMatch(pbxproj)?.group(0);
  if (block == null) return pbxproj;
  if (block.contains(idToAdd.split(' ').first)) return pbxproj;

  final listRegex = RegExp(
    r'(^\s*' +
        RegExp.escape(listKey) +
        r'\s*=\s*\(\s*$)([\s\S]*?)(^\s*\);\s*$)',
    multiLine: true,
  );
  final m = listRegex.firstMatch(block);
  if (m == null) return pbxproj;

  final before = m.group(1)!;
  final inner = m.group(2)!;
  final after = m.group(3)!;

  // Insert at end of list.
  final insertion = inner.endsWith('\n') ? '' : '\n';
  final newInner = '$inner$insertion\t\t\t\t$idToAdd,\n';
  final newBlock = block.replaceRange(m.start, m.end, '$before$newInner$after');
  return pbxproj.replaceFirst(block, newBlock);
}

String _patchProjectTargetsListAddId(
  String pbxproj, {
  required String projectObjectId,
  required String idToAdd,
}) {
  final block = _extractPbxObjectBlock(
    pbxproj,
    objectId: projectObjectId,
    expectedComment: 'Project object',
  );
  if (block == null) return pbxproj;
  if (block.contains(idToAdd.split(' ').first)) return pbxproj;

  final listRegex = RegExp(
    r'(^\s*targets\s*=\s*\(\s*$)([\s\S]*?)(^\s*\);\s*$)',
    multiLine: true,
  );
  final m = listRegex.firstMatch(block);
  if (m == null) return pbxproj;

  final before = m.group(1)!;
  final inner = m.group(2)!;
  final after = m.group(3)!;

  final insertion = inner.endsWith('\n') ? '' : '\n';
  final newInner = '$inner$insertion\t\t\t\t$idToAdd,\n';
  final newBlock = block.replaceRange(m.start, m.end, '$before$newInner$after');
  return pbxproj.replaceFirst(block, newBlock);
}

String _patchGroupChildrenAddId(
  String pbxproj, {
  required String groupId,
  required String idToAdd,
}) {
  final groupBlockRegex = RegExp(
    r'^\s*' + RegExp.escape(groupId) + r'\s*=\s*\{[\s\S]*?\n\s*\};\s*$',
    multiLine: true,
  );
  final block = groupBlockRegex.firstMatch(pbxproj)?.group(0);
  if (block == null) return pbxproj;
  if (block.contains(idToAdd.split(' ').first)) return pbxproj;

  final listRegex = RegExp(
    r'(^\s*children\s*=\s*\(\s*$)([\s\S]*?)(^\s*\);\s*$)',
    multiLine: true,
  );
  final m = listRegex.firstMatch(block);
  if (m == null) return pbxproj;

  final before = m.group(1)!;
  final inner = m.group(2)!;
  final after = m.group(3)!;
  final insertion = inner.endsWith('\n') ? '' : '\n';
  final newInner = '$inner$insertion\t\t\t\t$idToAdd,\n';
  final newBlock = block.replaceRange(m.start, m.end, '$before$newInner$after');
  return pbxproj.replaceFirst(block, newBlock);
}
