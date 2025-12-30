import 'dart:io';

import 'cli_io.dart';
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

  // Idempotency: if a target with this name already exists, do nothing.
  if (RegExp(
    r'isa\s*=\s*PBXNativeTarget;[\s\S]*?\n\s*name\s*=\s*' +
        RegExp.escape(widgetClassName) +
        r';',
  ).hasMatch(text)) {
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
    cliIO.writelnErr(
      'Warning: Could not locate required Xcode project IDs in '
      '${pbxprojFile.path}. Skipping Widget Extension wiring.',
    );
    return;
  }

  final baseBundleId = _detectRunnerBundleIdentifier(text) ?? 'com.example.app';
  final extBundleId = '$baseBundleId.$widgetClassName';

  final ids = _WidgetExtensionIds(widgetClassName);

  // Build the objects we will inject.
  final pbxBuildFiles = <String>[
    '\t\t${ids.embedBuildFileId} /* ${widgetClassName}.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = ${ids.productFileRefId} /* ${widgetClassName}.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };',
    '\t\t${ids.widgetKitBuildFileId} /* WidgetKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${ids.widgetKitFileRefId} /* WidgetKit.framework */; };',
    '\t\t${ids.swiftUIBuildFileId} /* SwiftUI.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${ids.swiftUIFileRefId} /* SwiftUI.framework */; };',
  ].join('\n');

  final pbxContainerProxy = '''
\t\t${ids.containerProxyId} /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = $projectObjectId /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = ${ids.targetId};
\t\t\tremoteInfo = $widgetClassName;
\t\t};
'''.trimRight();

  final pbxCopyPhase = '''
\t\t${ids.copyFilesPhaseId} /* Embed Foundation Extensions */ = {
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t${ids.embedBuildFileId} /* ${widgetClassName}.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
'''.trimRight();

  final pbxFileReferences = <String>[
    '\t\t${ids.productFileRefId} /* ${widgetClassName}.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = ${widgetClassName}.appex; sourceTree = BUILT_PRODUCTS_DIR; };',
    '\t\t${ids.widgetKitFileRefId} /* WidgetKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; };',
    '\t\t${ids.swiftUIFileRefId} /* SwiftUI.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = SwiftUI.framework; path = System/Library/Frameworks/SwiftUI.framework; sourceTree = SDKROOT; };',
    '\t\t${ids.entitlementsFileRefId} /* $widgetClassName.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = $widgetClassName.entitlements; sourceTree = "<group>"; };',
  ].join('\n');

  final fsExceptionSet = '''
\t\t${ids.fsExceptionId} /* Exceptions for "$widgetClassName" folder in "$widgetClassName" target */ = {
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t);
\t\t\ttarget = ${ids.targetId} /* $widgetClassName */;
\t\t};
'''.trimRight();

  final fsRootGroup = '''
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
'''.trimRight();

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
'''.trimRight();

  final extSourcesPhase = '''
\t\t${ids.sourcesPhaseId} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
'''.trimRight();

  final extResourcesPhase = '''
\t\t${ids.resourcesPhaseId} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
'''.trimRight();

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
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t${ids.fsRootGroupId} /* $widgetClassName */,
\t\t\t);
\t\t\tname = $widgetClassName;
\t\t\tproductName = $widgetClassName;
\t\t\tproductReference = ${ids.productFileRefId} /* ${widgetClassName}.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t};
'''.trimRight();

  final targetDependency = '''
\t\t${ids.targetDependencyId} /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = ${ids.targetId} /* $widgetClassName */;
\t\t\ttargetProxy = ${ids.containerProxyId} /* PBXContainerItemProxy */;
\t\t};
'''.trimRight();

  final xcBuildConfigs = '''
\t\t${ids.configDebugId} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCODE_SIGN_ENTITLEMENTS = $widgetClassName.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
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
\t\t\t\tCODE_SIGN_ENTITLEMENTS = $widgetClassName.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
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
\t\t\t\tCODE_SIGN_ENTITLEMENTS = $widgetClassName.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = $widgetClassName/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = $widgetClassName;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"\$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
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
'''.trimRight();

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
'''.trimRight();

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
  updated = _insertIntoSection(
    updated,
    section: 'PBXFileSystemSynchronizedBuildFileExceptionSet',
    content: fsExceptionSet,
  );
  updated = _insertIntoSection(
    updated,
    section: 'PBXFileSystemSynchronizedRootGroup',
    content: fsRootGroup,
  );
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
  updated = _patchNativeTargetListAddId(
    updated,
    targetId: runnerTargetId,
    listKey: 'buildPhases',
    idToAdd: '${ids.copyFilesPhaseId} /* Embed Foundation Extensions */',
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
    idToAdd: '${ids.productFileRefId} /* ${widgetClassName}.appex */',
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
    idToAdd: '${ids.fsRootGroupId} /* $widgetClassName */',
  );

  // Ensure Runner embeds the extension product (copy phase exists already now)
  // and that Runner depends on the extension (dependency object exists now).
  // We also need to ensure the copy phase is added to Runner build phases.

  if (updated != text) {
    await pbxprojFile.writeAsString(updated);
    cliIO.writelnOut('Updated Xcode project: ${pbxprojFile.path}');
    cliIO.writelnOut(
      'Added Widget Extension target "$widgetClassName" (bundle id: $extBundleId).',
    );
  }
}

final class _WidgetExtensionIds {
  _WidgetExtensionIds(String widgetClassName)
      : targetId = xcodeObjectId('target:$widgetClassName'),
        productFileRefId = xcodeObjectId('fileref:product:$widgetClassName'),
        entitlementsFileRefId =
            xcodeObjectId('fileref:entitlements:$widgetClassName'),
        sourcesPhaseId = xcodeObjectId('phase:sources:$widgetClassName'),
        frameworksPhaseId = xcodeObjectId('phase:frameworks:$widgetClassName'),
        resourcesPhaseId = xcodeObjectId('phase:resources:$widgetClassName'),
        copyFilesPhaseId = xcodeObjectId('phase:copy:$widgetClassName'),
        embedBuildFileId = xcodeObjectId('buildfile:embed:$widgetClassName'),
        containerProxyId = xcodeObjectId('proxy:$widgetClassName'),
        targetDependencyId = xcodeObjectId('dep:$widgetClassName'),
        swiftUIFileRefId = xcodeObjectId('fileref:SwiftUI:$widgetClassName'),
        widgetKitFileRefId = xcodeObjectId('fileref:WidgetKit:$widgetClassName'),
        swiftUIBuildFileId = xcodeObjectId('buildfile:SwiftUI:$widgetClassName'),
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

  // Extract the PBXProject block for safer parsing.
  final projectBlock = RegExp(
    r'^\s*' +
        RegExp.escape(projectObjectId) +
        r' /\* Project object \*/ = \{[\s\S]*?\n\s*\};\s*$',
    multiLine: true,
  ).firstMatch(pbxproj)?.group(0);
  if (projectBlock == null) return null;

  final m = RegExp(
    r'^\s*' +
        RegExp.escape(fieldName) +
        r'\s*=\s*([A-F0-9]{24})',
    multiLine: true,
  ).firstMatch(projectBlock);
  return m?.group(1);
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
  final newBlock =
      block.replaceRange(m.start, m.end, '$before$newInner$after');
  return pbxproj.replaceFirst(block, newBlock);
}

String _patchProjectTargetsListAddId(
  String pbxproj, {
  required String projectObjectId,
  required String idToAdd,
}) {
  final projectBlockRegex = RegExp(
    r'^\s*' +
        RegExp.escape(projectObjectId) +
        r' /\* Project object \*/ = \{[\s\S]*?\n\s*\};\s*$',
    multiLine: true,
  );
  final block = projectBlockRegex.firstMatch(pbxproj)?.group(0);
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
  final newBlock =
      block.replaceRange(m.start, m.end, '$before$newInner$after');
  return pbxproj.replaceFirst(block, newBlock);
}

String _patchGroupChildrenAddId(
  String pbxproj, {
  required String groupId,
  required String idToAdd,
}) {
  final groupBlockRegex = RegExp(
    r'^\s*' +
        RegExp.escape(groupId) +
        r'\s*=\s*\{[\s\S]*?\n\s*\};\s*$',
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
  final newBlock =
      block.replaceRange(m.start, m.end, '$before$newInner$after');
  return pbxproj.replaceFirst(block, newBlock);
}


