import 'dart:io';

import 'package:path/path.dart' as p;

import 'logger.dart';
import 'fnv_hash.dart';
import 'naming.dart';
import 'xcconfig.dart';

/// Ensures an iOS Widget Extension target exists inside the given Xcode
/// `project.pbxproj` file.
///
/// This uses the "File System Synchronized" group approach (modern Xcode)
/// similar to the repo's `examples/lockscreen_widgets` sample, because it avoids
/// having to list every Swift file explicitly in the pbxproj.
///
/// Every Runner build configuration is mirrored onto the extension, flavored
/// ones (`Debug-dev`) included: a flavored scheme builds the extension with the
/// configuration of the same name, and without it Xcode silently falls back to
/// the default one and signs the extension with the wrong bundle id.
/// [flavorEntitlements] maps a flavor to the entitlements file its
/// configurations use, relative to `ios/`; flavors it does not list and the
/// unflavored configurations use `<widgetClassName>.entitlements`.
Future<void> ensureWidgetExtensionTargetInXcodeProject({
  required File pbxprojFile,
  required String widgetClassName,
  Map<String, String> flavorEntitlements = const {},
}) async {
  final text = await pbxprojFile.readAsString();
  final projectDir = _projectDirOf(pbxprojFile);

  final hasFileSystemSynchronizedSections =
      _projectSupportsSynchronizedGroups(text);

  final extensionConfigs = _desiredExtensionConfigurations(
    text,
    widgetClassName: widgetClassName,
    flavorEntitlements: flavorEntitlements,
    projectDir: projectDir,
  );

  // Idempotency: if a target with this name already exists, only reconcile the
  // build configurations — a flavor may have been added to the project since.
  if (RegExp(
    r'isa\s*=\s*PBXNativeTarget;[\s\S]*?\n\s*name\s*=\s*' +
        RegExp.escape(widgetClassName) +
        r';',
  ).hasMatch(text)) {
    final synced = _syncExtensionBuildConfigurations(
      text,
      widgetClassName: widgetClassName,
      configs: extensionConfigs,
    );
    if (synced != text) {
      await pbxprojFile.writeAsString(synced);
      logger.detail('Updated Xcode project: ${pbxprojFile.path}');
      logger.detail(
        'Synced the build configurations of "$widgetClassName" with Runner.',
      );
    }
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

  final extBundleId = extensionConfigs.first.bundleId;

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

  final xcBuildConfigs =
      extensionConfigs.map(_renderExtensionBuildConfiguration).join('\n');

  final configListEntries = extensionConfigs
      .map((c) => '\t\t\t\t${c.id} /* ${c.name} */,')
      .join('\n');
  final configList = '''
\t\t${ids.configListId} /* Build configuration list for PBXNativeTarget "$widgetClassName" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
$configListEntries
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

/// The Flutter flavors the Xcode project defines, in first-seen order.
///
/// Flutter models a flavor as a trio of Runner build configurations named
/// `Debug-<flavor>` / `Release-<flavor>` / `Profile-<flavor>`; a project without
/// flavors only has the three plain ones, so this returns an empty list.
///
/// [projectDir] is the `ios/` directory. Passing it lets the settings an
/// `.xcconfig` file holds take part; without it only what the pbxproj itself
/// spells out is read.
List<String> detectXcodeFlavors(String pbxproj, {Directory? projectDir}) {
  final flavors = <String>[];
  for (final config
      in _runnerBuildConfigurations(pbxproj, projectDir: projectDir)) {
    final flavor = config.flavor;
    if (flavor != null && !flavors.contains(flavor)) flavors.add(flavor);
  }
  return flavors;
}

/// Every `CODE_SIGN_ENTITLEMENTS` build setting Runner's configurations for
/// [flavor] resolve to, in configuration order (Debug, Release, Profile) and
/// without duplicates.
///
/// [flavor] `null` asks for the unflavored configurations. The three of a
/// flavor may well sign with different files — splitting `aps-environment` over
/// Debug and Release is routine — so a caller that has to reach all of them
/// cannot settle for one. Configurations setting nothing are left out, which
/// makes an empty list mean "none of them signs with a file".
///
/// A value can name a build variable (`$(SRCROOT)/Runner/Runner.entitlements`),
/// so these are what to show the user rather than what to open — see
/// [runnerEntitlementsPathsForFlavor] for that.
List<String> runnerEntitlementsSettingsForFlavor(
  String pbxproj,
  String? flavor, {
  Directory? projectDir,
}) {
  final settings = <String>[];
  for (final config
      in _runnerBuildConfigurations(pbxproj, projectDir: projectDir)) {
    if (config.flavor != flavor) continue;
    final entitlements = config.entitlements;
    if (entitlements == null || settings.contains(entitlements)) continue;
    settings.add(entitlements);
  }
  return settings;
}

/// The entitlements files Runner's configurations for [flavor] sign with, as
/// paths relative to `ios/`.
///
/// A value naming a build variable this cannot resolve is dropped —
/// `$(SRCROOT)` and `$(PROJECT_DIR)` are the project directory itself and are
/// stripped, anything else is only known to Xcode. Callers that need to name
/// the unresolvable value read it through [runnerEntitlementsSettingsForFlavor].
List<String> runnerEntitlementsPathsForFlavor(
  String pbxproj,
  String? flavor, {
  Directory? projectDir,
}) {
  final paths = <String>[];
  for (final setting in runnerEntitlementsSettingsForFlavor(
    pbxproj,
    flavor,
    projectDir: projectDir,
  )) {
    final path = resolveProjectRelativePath(setting);
    if (path == null || paths.contains(path)) continue;
    paths.add(path);
  }
  return paths;
}

/// [value] as a path relative to `ios/`, or `null` when it is not one.
///
/// The two build variables that resolve to the project directory are stripped;
/// a value holding any other reference cannot be resolved without Xcode.
String? resolveProjectRelativePath(String value) {
  var path = _unquotePbxprojValue(value).trim();
  for (final prefix in const [
    r'$(SRCROOT)/',
    r'${SRCROOT}/',
    r'$(PROJECT_DIR)/',
    r'${PROJECT_DIR}/',
  ]) {
    if (path.startsWith(prefix)) {
      path = path.substring(prefix.length);
      break;
    }
  }
  if (path.contains(r'$(') || path.contains(r'${')) return null;
  return path.isEmpty ? null : path;
}

/// A Runner build configuration, reduced to what the extension mirrors.
final class _RunnerBuildConfiguration {
  const _RunnerBuildConfiguration({
    required this.id,
    required this.name,
    required this.bundleId,
    required this.developmentTeam,
    required this.entitlements,
    this.deploymentTarget,
  });

  final String id;
  final String name;
  final String? bundleId;
  final String? developmentTeam;
  final String? entitlements;
  final String? deploymentTarget;

  String? get flavor => _flavorOfConfigurationName(name);
}

/// A build configuration the extension target should have.
final class _ExtensionBuildConfiguration {
  const _ExtensionBuildConfiguration({
    required this.id,
    required this.name,
    required this.widgetClassName,
    required this.bundleId,
    required this.developmentTeam,
    required this.entitlements,
    required this.flavor,
  });

  final String id;
  final String name;
  final String widgetClassName;
  final String bundleId;
  final String? developmentTeam;
  final String entitlements;
  final String? flavor;

  String? get compilationConditions => flavor == null
      ? null
      : '"\$(inherited) ${flavorCompilationCondition(flavor!)}"';
}

String? _flavorOfConfigurationName(String name) =>
    RegExp(r'^(?:Debug|Release|Profile)-(.+)$').firstMatch(name)?.group(1);

/// Strips the quotes Xcode puts around a value that is not a bare identifier.
///
/// A flavored configuration is stored as `name = "Debug-dev";`, so a raw
/// capture carries quotes the name itself does not have.
String _unquotePbxprojValue(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

/// [value] written the way Xcode writes it: bare when it can be, quoted when it
/// holds anything else — `Debug` stays bare, `Debug-dev` becomes `"Debug-dev"`.
String _quotePbxprojValue(String value) =>
    RegExp(r'^[A-Za-z0-9_$./]+$').hasMatch(value) ? value : '"$value"';

/// Matches an `XCBuildConfiguration` object, capturing id, the id of the
/// `.xcconfig` it is based on, the buildSettings body and the name. The name
/// capture keeps the quotes Xcode writes around a flavored one
/// (`name = "Debug-dev";`), so read it through [_unquotePbxprojValue].
final RegExp _buildConfigurationScanRe = RegExp(
  r'\t\t([0-9A-F]{24}) /\* [^*\n]*? \*/ = \{\n'
  r'\t\t\tisa = XCBuildConfiguration;\n'
  r'(?:\t\t\tbaseConfigurationReference = ([0-9A-F]{24})[^\n]*\n)?'
  r'\t\t\tbuildSettings = \{\n'
  r'([\s\S]*?)'
  r'\n\t\t\t\};\n\t\t\tname = ([^;\n]+);',
);

/// One `XCBuildConfiguration` object as scanned out of the project.
final class _XcBuildConfiguration {
  const _XcBuildConfiguration({
    required this.id,
    required this.baseConfigurationReferenceId,
    required this.settings,
    required this.name,
  });

  final String id;
  final String? baseConfigurationReferenceId;
  final String settings;
  final String name;
}

List<_XcBuildConfiguration> _scanBuildConfigurations(String pbxproj) => [
      for (final m in _buildConfigurationScanRe.allMatches(pbxproj))
        _XcBuildConfiguration(
          id: m.group(1)!,
          baseConfigurationReferenceId: m.group(2),
          settings: m.group(3)!,
          name: _unquotePbxprojValue(m.group(4)!),
        ),
    ];

/// The same object, split into the three pieces a rewrite needs.
final RegExp _buildConfigurationBlockRe = RegExp(
  r'(\t\t[0-9A-F]{24} /\* [^*\n]*? \*/ = \{\n'
  r'\t\t\tisa = XCBuildConfiguration;\n'
  r'(?:\t\t\tbaseConfigurationReference = [^\n]*\n)?'
  r'\t\t\tbuildSettings = \{\n)'
  r'([\s\S]*?)'
  r'(\n\t\t\t\};\n\t\t\tname = ([^;\n]+);\n\t\t\};)',
);

/// Runner's build configurations, ordered base-first and then flavor by flavor.
///
/// The Runner target's `XCConfigurationList` is the authority on which
/// configurations belong to Runner; projects too reduced to have a target at
/// all (test fixtures, hand-written snippets) fall back to the
/// `INFOPLIST_FILE = Runner/Info.plist` marker.
///
/// Each configuration is read the way Xcode reads it, so a setting a flavor
/// keeps in its `.xcconfig` or at project level is seen as well — passing
/// [projectDir], the `ios/` directory, is what makes the first of those two
/// reachable.
List<_RunnerBuildConfiguration> _runnerBuildConfigurations(
  String pbxproj, {
  Directory? projectDir,
}) {
  final all = _scanBuildConfigurations(pbxproj);
  bool looksLikeRunner(_XcBuildConfiguration c) =>
      c.settings.contains('INFOPLIST_FILE = Runner/Info.plist;');

  var selected = <_XcBuildConfiguration>[];
  final listedIds = _runnerConfigurationIds(pbxproj);
  if (listedIds != null) {
    final byId = {for (final c in all) c.id: c};
    selected = listedIds
        .map((id) => byId[id])
        .whereType<_XcBuildConfiguration>()
        .toList(growable: false);
  }
  if (selected.isEmpty) {
    selected = all.where(looksLikeRunner).toList(growable: false);
  }

  final projectConfigs = _projectConfigurationsByName(pbxproj);
  final xcconfigPaths = projectDir == null
      ? const <String, String>{}
      : _fileReferencePaths(pbxproj);
  final configs = <_RunnerBuildConfiguration>[];
  for (final config in selected) {
    final resolved = _resolvedBuildSettings(
      config: config,
      inherited: projectConfigs[config.name],
      projectDir: projectDir,
      xcconfigPaths: xcconfigPaths,
    );

    configs.add(
      _RunnerBuildConfiguration(
        id: config.id,
        name: config.name,
        bundleId: resolved['PRODUCT_BUNDLE_IDENTIFIER'],
        developmentTeam: resolved['DEVELOPMENT_TEAM'],
        entitlements: resolved['CODE_SIGN_ENTITLEMENTS'],
        deploymentTarget: resolved['IPHONEOS_DEPLOYMENT_TARGET'],
      ),
    );
  }
  return _orderConfigurations(configs);
}

/// Everything a build configuration resolves to, unquoted and with references
/// to other settings expanded.
///
/// The four layers Xcode reads, weakest first: the project's `.xcconfig`, the
/// project configuration of the same name, the target's `.xcconfig`, and the
/// target configuration's own settings.
Map<String, String> _resolvedBuildSettings({
  required _XcBuildConfiguration config,
  required _XcBuildConfiguration? inherited,
  required Directory? projectDir,
  required Map<String, String> xcconfigPaths,
}) {
  Map<String, String> xcconfigOf(_XcBuildConfiguration? c) =>
      _xcconfigSettings(c, projectDir, xcconfigPaths);

  final merged = <String, String>{
    ...xcconfigOf(inherited),
    if (inherited != null) ..._parseBuildSettings(inherited.settings),
    ...xcconfigOf(config),
    ..._parseBuildSettings(config.settings),
  };
  return {
    for (final entry in merged.entries)
      entry.key: _expandSettingReferences(entry.value, merged),
  };
}

/// The settings the `.xcconfig` [config] is based on defines, or nothing when
/// it has none, when the reference cannot be resolved to a file, or when the
/// caller did not say where the project lives.
Map<String, String> _xcconfigSettings(
  _XcBuildConfiguration? config,
  Directory? projectDir,
  Map<String, String> xcconfigPaths,
) {
  final refId = config?.baseConfigurationReferenceId;
  if (refId == null || projectDir == null) return const {};
  final path = xcconfigPaths[refId];
  if (path == null) return const {};
  return readXcconfigSettings(File(p.join(projectDir.path, path)));
}

/// Replaces `$(KEY)` / `${KEY}` in [value] with what [settings] resolves them
/// to, leaving `$(inherited)` and anything the project does not define alone.
String _expandSettingReferences(
  String value,
  Map<String, String> settings, [
  int depth = 0,
]) {
  if (depth > 4 || !value.contains(r'$')) return value;
  return value.replaceAllMapped(
    RegExp(r'\$[({]([A-Za-z_][A-Za-z0-9_]*)[)}]'),
    (m) {
      final replacement = settings[m.group(1)!];
      if (replacement == null || replacement == m.group(0)) return m.group(0)!;
      return _expandSettingReferences(replacement, settings, depth + 1);
    },
  );
}

/// The project-level configurations, by name.
///
/// A target configuration inherits every setting it does not define itself, and
/// flutter_flavorizr writes a flavor's bundle id at project level: the Runner
/// target's own `Debug-dev` is left with nothing but `PRODUCT_NAME`.
Map<String, _XcBuildConfiguration> _projectConfigurationsByName(
  String pbxproj,
) {
  final listId = _findProjectFieldId(pbxproj, 'buildConfigurationList');
  if (listId == null) return const {};
  final listed = _configurationListIds(pbxproj, listId)?.toSet();
  if (listed == null) return const {};

  return {
    for (final config in _scanBuildConfigurations(pbxproj))
      if (listed.contains(config.id)) config.name: config,
  };
}

/// The ids listed by the Runner target's `XCConfigurationList`, or null when
/// the project does not have one to read.
List<String>? _runnerConfigurationIds(String pbxproj) {
  final targetId = _findTargetIdByName(pbxproj, 'Runner');
  if (targetId == null) return null;
  final targetBlock = _extractPbxObjectBlock(
    pbxproj,
    objectId: targetId,
    expectedComment: 'Runner',
  );
  if (targetBlock == null) return null;

  final listId = RegExp(r'buildConfigurationList = ([0-9A-F]{24})')
      .firstMatch(targetBlock)
      ?.group(1);
  if (listId == null) return null;

  return _configurationListIds(pbxproj, listId);
}

/// The build configuration ids an `XCConfigurationList` lists, in order.
List<String>? _configurationListIds(String pbxproj, String listId) {
  final listBlock = RegExp(
    RegExp.escape(listId) + r'(?: /\* [^*\n]*? \*/)? = \{[\s\S]*?\n\s*\};',
  ).firstMatch(pbxproj)?.group(0);
  if (listBlock == null) return null;

  final inner = RegExp(r'buildConfigurations = \(([\s\S]*?)\);')
      .firstMatch(listBlock)
      ?.group(1);
  if (inner == null) return null;

  return RegExp(r'[0-9A-F]{24}')
      .allMatches(inner)
      .map((m) => m.group(0)!)
      .toList();
}

/// The id of the configuration named [name] in the list [listId], whatever id
/// the project gave it.
///
/// Matching by name rather than by our own derived id keeps a configuration
/// that Xcode (or an older version of this patcher) created from being
/// duplicated under a second id.
String? _configurationIdNamed(
  String pbxproj, {
  required String listId,
  required String name,
}) {
  final listed = _configurationListIds(pbxproj, listId);
  if (listed == null) return null;

  final nameById = {
    for (final config in _scanBuildConfigurations(pbxproj))
      config.id: config.name,
  };
  for (final id in listed) {
    if (nameById[id] == name) return id;
  }
  return null;
}

/// Rewrites the `/* … */` comments of [id] to the name Xcode would show.
String _retitlePbxObject(
  String pbxproj, {
  required String id,
  required String name,
}) =>
    pbxproj.replaceAll(
      RegExp(RegExp.escape(id) + r' /\* [^*\n]*? \*/'),
      '$id /* $name */',
    );

/// Groups configurations by flavor (unflavored first) and orders each group
/// Debug, Release, Profile, so the generated objects land in a stable order
/// whatever order the project happens to list them in.
List<_RunnerBuildConfiguration> _orderConfigurations(
  List<_RunnerBuildConfiguration> configs,
) {
  const baseRank = {'Debug': 0, 'Release': 1, 'Profile': 2};
  final flavorOrder = <String>[];
  for (final config in configs) {
    final flavor = config.flavor;
    if (flavor != null && !flavorOrder.contains(flavor)) {
      flavorOrder.add(flavor);
    }
  }

  final indexed = configs.asMap().entries.toList();
  indexed.sort((a, b) {
    final groupA =
        a.value.flavor == null ? -1 : flavorOrder.indexOf(a.value.flavor!);
    final groupB =
        b.value.flavor == null ? -1 : flavorOrder.indexOf(b.value.flavor!);
    if (groupA != groupB) return groupA.compareTo(groupB);

    final rankA = baseRank[a.value.name.split('-').first] ?? 3;
    final rankB = baseRank[b.value.name.split('-').first] ?? 3;
    if (rankA != rankB) return rankA.compareTo(rankB);

    return a.key.compareTo(b.key);
  });
  return [for (final entry in indexed) entry.value];
}

List<_ExtensionBuildConfiguration> _desiredExtensionConfigurations(
  String pbxproj, {
  required String widgetClassName,
  required Map<String, String> flavorEntitlements,
  Directory? projectDir,
}) {
  final fallbackBundleId =
      _detectRunnerBundleIdentifier(pbxproj) ?? 'com.example.app';
  final fallbackTeam = _detectRunnerDevelopmentTeam(pbxproj);
  final defaultEntitlements = '$widgetClassName.entitlements';

  var runnerConfigs =
      _runnerBuildConfigurations(pbxproj, projectDir: projectDir);
  if (runnerConfigs.isEmpty) {
    runnerConfigs = [
      for (final name in const ['Debug', 'Release', 'Profile'])
        _RunnerBuildConfiguration(
          id: xcodeObjectId('cfg:$name:$widgetClassName'),
          name: name,
          bundleId: null,
          developmentTeam: null,
          entitlements: null,
        ),
    ];
  }

  return [
    for (final config in runnerConfigs)
      _ExtensionBuildConfiguration(
        id: xcodeObjectId('cfg:${config.name}:$widgetClassName'),
        name: config.name,
        widgetClassName: widgetClassName,
        bundleId: '${config.bundleId ?? fallbackBundleId}.$widgetClassName',
        developmentTeam: config.developmentTeam ?? fallbackTeam,
        entitlements: config.flavor == null
            ? defaultEntitlements
            : flavorEntitlements[config.flavor] ?? defaultEntitlements,
        flavor: config.flavor,
      ),
  ];
}

String _renderExtensionBuildConfiguration(_ExtensionBuildConfiguration config) {
  final teamLine = _developmentTeamBuildSettingLine(config.developmentTeam);
  final conditions = config.compilationConditions;
  final conditionsLine = conditions == null
      ? ''
      : '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = $conditions;\n';
  return '''
\t\t${config.id} /* ${config.name} */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = ${_quotePbxprojValue(config.entitlements)};
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
$teamLine\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tINFOPLIST_FILE = ${config.widgetClassName}/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = ${config.widgetClassName};
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"\$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = ${_quotePbxprojValue(config.bundleId)};
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
$conditionsLine\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = ${_quotePbxprojValue(config.name)};
\t\t};
'''
      .trimRight();
}

/// Reconciles an existing extension target's build configurations with
/// [configs]: missing ones are added, existing ones have the settings this
/// patcher owns rewritten to the desired value.
String _syncExtensionBuildConfigurations(
  String pbxproj, {
  required String widgetClassName,
  required List<_ExtensionBuildConfiguration> configs,
}) {
  final ids = _WidgetExtensionIds(widgetClassName);
  var out = pbxproj;
  final missing = <_ExtensionBuildConfiguration>[];

  for (final config in configs) {
    final existingId = _configurationIdNamed(
          out,
          listId: ids.configListId,
          name: config.name,
        ) ??
        config.id;
    out = _retitlePbxObject(out, id: existingId, name: config.name);
    final block = _extractPbxObjectBlock(
      out,
      objectId: existingId,
      expectedComment: config.name,
    );
    if (block == null) {
      missing.add(config);
      continue;
    }
    final updated = _applyExtensionBuildSettings(block, config);
    if (updated != block) out = out.replaceFirst(block, updated);
  }

  if (missing.isNotEmpty) {
    out = _insertIntoSection(
      out,
      section: 'XCBuildConfiguration',
      content: missing.map(_renderExtensionBuildConfiguration).join('\n'),
    );
    for (final config in missing) {
      out = _patchNativeTargetListAddId(
        out,
        targetId: ids.configListId,
        listKey: 'buildConfigurations',
        idToAdd: '${config.id} /* ${config.name} */',
      );
    }
  }

  return out;
}

String _applyExtensionBuildSettings(
  String block,
  _ExtensionBuildConfiguration config,
) {
  final match = RegExp(r'(buildSettings = \{\n)([\s\S]*?)(\n\t\t\t\};)')
      .firstMatch(block);
  if (match == null) return block;

  var settings = match.group(2)!;
  final reset = <String>[];
  void owned(String key, String? value) {
    if (value == null || value.isEmpty) return;
    final before = _buildSettingValue(settings, key);
    settings = _upsertBuildSetting(settings, key, _quotePbxprojValue(value));
    if (before != null && _unquotePbxprojValue(before) != value) {
      reset.add(key);
    }
  }

  owned('PRODUCT_BUNDLE_IDENTIFIER', config.bundleId);
  owned('CODE_SIGN_ENTITLEMENTS', config.entitlements);
  owned('DEVELOPMENT_TEAM', config.developmentTeam);

  const conditionsKey = 'SWIFT_ACTIVE_COMPILATION_CONDITIONS';
  final existingConditions = _buildSettingValue(settings, conditionsKey);
  final conditions = _mergedCompilationConditions(
    existingConditions,
    config.flavor,
  );
  if (conditions == null) {
    if (existingConditions != null) {
      settings = _removeBuildSetting(settings, conditionsKey);
    }
  } else {
    settings = _upsertBuildSetting(settings, conditionsKey, conditions);
  }

  if (reset.isNotEmpty) {
    logger.info(
      'Reset ${reset.join(', ')} on the "${config.name}" configuration of '
      '${config.widgetClassName} to match Runner.',
    );
  }

  return block.replaceRange(
    match.start,
    match.end,
    '${match.group(1)!}$settings${match.group(3)!}',
  );
}

/// `SWIFT_ACTIVE_COMPILATION_CONDITIONS` for a configuration that already has
/// [existing], or `null` when the setting should not be there at all.
///
/// Only the `HW_FLAVOR_` conditions belong to this patcher: every other token
/// is a flag the developer added and is kept in place, so re-running the
/// generator never drops one.
String? _mergedCompilationConditions(String? existing, String? flavor) {
  final desired = flavor == null ? null : flavorCompilationCondition(flavor);
  final tokens =
      existing == null ? [r'$(inherited)'] : _valueTokens(existing).toList();

  final hadFlavorConditions = tokens.any((t) => t.startsWith('HW_FLAVOR_'));
  if (desired == null && !hadFlavorConditions) return existing;

  tokens.removeWhere((token) => token.startsWith('HW_FLAVOR_'));
  if (desired != null) tokens.add(desired);

  if (tokens.isEmpty) return null;
  if (hadFlavorConditions &&
      tokens.length == 1 &&
      tokens.single == r'$(inherited)') {
    return null;
  }
  return '"${tokens.join(' ')}"';
}

/// The words of a build setting value, whether it was written as one string or
/// as the multi-line list Xcode writes when it is edited in the UI.
Iterable<String> _valueTokens(String value) => _unquotePbxprojValue(value)
    .split(RegExp(r'\s+'))
    .map((token) => _unquotePbxprojValue(token.replaceAll(',', '')))
    .where((token) => token.isNotEmpty);

RegExp _singleLineSettingRe(String key) => RegExp(
      '^[ \\t]*${RegExp.escape(key)} = ([^;\\n]*);\$',
      multiLine: true,
    );

/// Xcode writes a list value across several lines, which no single-line pattern
/// can see — and a key it cannot see is a key that gets written a second time.
RegExp _listSettingRe(String key) => RegExp(
      '^[ \\t]*${RegExp.escape(key)} = \\(\\n([\\s\\S]*?)^[ \\t]*\\);\$',
      multiLine: true,
    );

/// The value of [key], list values joined into the single string they stand
/// for. Quotes are left on, the way the project spells them.
String? _buildSettingValue(String settings, String key) {
  final single = _singleLineSettingRe(key).firstMatch(settings);
  if (single != null) return single.group(1)!.trim();

  final list = _listSettingRe(key).firstMatch(settings);
  if (list == null) return null;
  return _valueTokens(list.group(1)!).join(' ');
}

/// Sets `key = value;` in a `buildSettings` body, replacing a list value whole.
///
/// A new line goes in alphabetically, which is where Xcode itself sorts it.
String _upsertBuildSetting(String settings, String key, String value) {
  final desired = '\t\t\t\t$key = $value;';
  final single = _singleLineSettingRe(key);
  if (single.hasMatch(settings)) {
    return settings.replaceAll(single, desired);
  }
  final list = _listSettingRe(key);
  if (list.hasMatch(settings)) {
    return settings.replaceAll(list, desired);
  }

  final lines = settings.split('\n');
  final keyRe = RegExp(r'^\t\t\t\t([A-Za-z_0-9]+) = ');
  var insertAt = lines.length;
  for (var i = 0; i < lines.length; i++) {
    final name = keyRe.firstMatch(lines[i])?.group(1);
    if (name == null) continue;
    if (name.compareTo(key) > 0) {
      insertAt = i;
      break;
    }
  }
  lines.insert(insertAt, desired);
  return lines.join('\n');
}

String _removeBuildSetting(String settings, String key) {
  final singleRe = RegExp('^[ \\t]*${RegExp.escape(key)} = [^;\\n]*;\$');
  final listStartRe = RegExp('^[ \\t]*${RegExp.escape(key)} = \\(\$');
  final listEndRe = RegExp(r'^[ \t]*\);$');

  final kept = <String>[];
  var inList = false;
  for (final line in settings.split('\n')) {
    if (inList) {
      inList = !listEndRe.hasMatch(line);
      continue;
    }
    if (singleRe.hasMatch(line)) continue;
    if (listStartRe.hasMatch(line)) {
      inList = true;
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n');
}

/// The build settings [body] spells out, unquoted.
Map<String, String> _parseBuildSettings(String body) {
  final settings = <String, String>{};
  for (final m in RegExp(
    r'^[ \t]*([A-Za-z_][A-Za-z0-9_]*)(\[[^\]]*\])? = ([^;\n]*);$',
    multiLine: true,
  ).allMatches(body)) {
    if (m.group(2) != null) continue;
    settings[m.group(1)!] = _unquotePbxprojValue(m.group(3)!);
  }
  for (final m in RegExp(
    r'^[ \t]*([A-Za-z_][A-Za-z0-9_]*) = \(\n([\s\S]*?)^[ \t]*\);$',
    multiLine: true,
  ).allMatches(body)) {
    settings[m.group(1)!] = _valueTokens(m.group(2)!).join(' ');
  }
  return settings;
}

/// Wires `<widgetClassName>/Localizable.xcstrings` into the extension target.
///
/// The catalog only ships if it is a resource of the extension, and its
/// translations only apply if the project lists their locales in
/// `knownRegions`. Both are patched in place and both are idempotent: a second
/// run over the same project changes nothing.
///
/// Projects using file-system-synchronized groups (Xcode 16 `flutter create`)
/// already build every file in the extension folder, so only `knownRegions`
/// needs patching there — adding an explicit reference on top of the synced
/// folder would make Xcode copy the catalog twice and fail the build.
Future<void> ensureLocalizableCatalogInXcodeProject({
  required File pbxprojFile,
  required String widgetClassName,
  required List<String> locales,
}) async {
  final text = await pbxprojFile.readAsString();
  var updated = text;

  final ids = _WidgetExtensionIds(widgetClassName);
  final usesSynchronizedGroups = _widgetUsesSynchronizedGroup(text, ids);

  if (!usesSynchronizedGroups) {
    final fileRefId = xcodeObjectId(
      'fileref:Localizable.xcstrings:$widgetClassName',
    );
    final buildFileId = xcodeObjectId(
      'buildfile:Localizable.xcstrings:$widgetClassName',
    );

    if (!updated.contains(fileRefId)) {
      updated = _insertIntoSection(
        updated,
        section: 'PBXFileReference',
        content:
            '\t\t$fileRefId /* Localizable.xcstrings */ = {isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = Localizable.xcstrings; sourceTree = "<group>"; };',
      );
      updated = _insertIntoSection(
        updated,
        section: 'PBXBuildFile',
        content:
            '\t\t$buildFileId /* Localizable.xcstrings in Resources */ = {isa = PBXBuildFile; fileRef = $fileRefId /* Localizable.xcstrings */; };',
      );
    }

    updated = _patchNativeTargetListAddId(
      updated,
      targetId: ids.resourcesPhaseId,
      listKey: 'files',
      idToAdd: '$buildFileId /* Localizable.xcstrings in Resources */',
    );
    updated = _patchGroupChildrenAddId(
      updated,
      groupId: ids.widgetGroupId,
      idToAdd: '$fileRefId /* Localizable.xcstrings */',
    );
  }

  updated = _patchKnownRegions(updated, locales: locales);

  if (updated == text) return;

  await pbxprojFile.writeAsString(updated);
  logger.detail('Updated Xcode project: ${pbxprojFile.path}');
  logger.detail(
    'Wired $widgetClassName/Localizable.xcstrings into the extension target.',
  );
}

/// Whether the scaffolder would give a new extension a synchronized root group.
///
/// Both sections have to exist: `_insertIntoSection` silently does nothing for
/// an absent section, which would leave the group referencing a membership
/// exception set that was never written.
bool _projectSupportsSynchronizedGroups(String pbxproj) =>
    pbxproj
        .contains('/* Begin PBXFileSystemSynchronizedRootGroup section */') &&
    pbxproj.contains(
      '/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */',
    );

/// Whether *this widget's* extension folder is a synchronized group.
///
/// Per-widget, not per-project: a project can hold both kinds at once, and a
/// project-global guess that disagrees with the group the scaffolder actually
/// created wires the catalog into nothing while still reporting success.
bool _widgetUsesSynchronizedGroup(String pbxproj, _WidgetExtensionIds ids) {
  if (pbxproj.contains(ids.fsRootGroupId)) return true;
  if (pbxproj.contains(ids.widgetGroupId)) return false;
  // Neither group exists yet, so nothing has been decided: answer the same way
  // the scaffolder will when it creates one.
  return _projectSupportsSynchronizedGroups(pbxproj);
}

/// Adds any missing [locales] to the project's `knownRegions`.
///
/// Xcode quotes anything that is not a bare identifier, so `pt-BR` has to be
/// written `"pt-BR"` — and matched that way when checking for duplicates.
String _patchKnownRegions(String pbxproj, {required List<String> locales}) {
  final listRegex = RegExp(
    r'(^\s*knownRegions\s*=\s*\(\s*$)([\s\S]*?)(^\s*\);\s*$)',
    multiLine: true,
  );
  final match = listRegex.firstMatch(pbxproj);
  if (match == null) return pbxproj;

  final before = match.group(1)!;
  var inner = match.group(2)!;
  final after = match.group(3)!;

  final existing = inner
      .split('\n')
      .map((line) => line.trim().replaceAll(',', '').replaceAll('"', ''))
      .where((line) => line.isNotEmpty)
      .toSet();

  final missing =
      locales.where((locale) => !existing.contains(locale)).toList();
  if (missing.isEmpty) return pbxproj;

  if (!inner.endsWith('\n')) inner = '$inner\n';
  for (final locale in missing) {
    final entry =
        RegExp(r'^[A-Za-z0-9_]+$').hasMatch(locale) ? locale : '"$locale"';
    inner = '$inner\t\t\t\t$entry,\n';
  }

  return pbxproj.replaceRange(
    match.start,
    match.end,
    '$before$inner$after',
  );
}

/// Ensures every Runner build configuration signs with an entitlements file.
///
/// The iOS scaffolder creates `ios/Runner/Runner.entitlements`, but Xcode only
/// applies it if `CODE_SIGN_ENTITLEMENTS` is set for the Runner target configs.
///
/// A configuration that already resolves to a file keeps it — through its own
/// settings, its `.xcconfig` or the project level: a flavored project routinely
/// gives each flavor its own entitlements, and forcing them all onto
/// `Runner/Runner.entitlements` would put every flavor in the same App Group.
Future<void> ensureRunnerEntitlementsInXcodeProject({
  required File pbxprojFile,
}) async {
  var text = await pbxprojFile.readAsString();

  final runnerConfigs = _runnerBuildConfigurations(
    text,
    projectDir: _projectDirOf(pbxprojFile),
  );
  if (runnerConfigs.isEmpty) {
    // Don't fail the whole command, but let the user know scaffolding might
    // require manual intervention for non-standard pbxproj layouts.
    logger.warn(
      'Warning: Could not auto-set CODE_SIGN_ENTITLEMENTS for Runner in '
      '${pbxprojFile.path}. You may need to set it manually to Runner/Runner.entitlements.',
    );
    return;
  }

  final needsEntitlements = {
    for (final config in runnerConfigs)
      if (config.entitlements == null) config.id,
  };
  if (needsEntitlements.isEmpty) return;

  var didChange = false;
  text = text.replaceAllMapped(_buildConfigurationBlockRe, (m) {
    final header = m.group(1)!;
    final settings = m.group(2)!;
    final footer = m.group(3)!;

    final id = RegExp(r'[0-9A-F]{24}').firstMatch(header)?.group(0);
    if (id == null || !needsEntitlements.contains(id)) return m.group(0)!;

    didChange = true;
    return '$header'
        '${_upsertBuildSetting(settings, 'CODE_SIGN_ENTITLEMENTS', 'Runner/Runner.entitlements')}'
        '$footer';
  });

  if (!didChange) return;

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

  final runnerConfigs = {
    for (final config in _runnerBuildConfigurations(
      text,
      projectDir: _projectDirOf(pbxprojFile),
    ))
      config.id: config,
  };

  var didChange = false;
  text = text.replaceAllMapped(_buildConfigurationBlockRe, (m) {
    final header = m.group(1)!;
    var settings = m.group(2)!;
    final footer = m.group(3)!;

    final id = RegExp(r'[0-9A-F]{24}').firstMatch(header)?.group(0);
    final config = id == null ? null : runnerConfigs[id];
    if (config == null) return m.group(0)!;

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
      // Nothing of its own: an inherited value that is already high enough
      // stands, anything else gets the minimum written onto the configuration.
      final inherited = double.tryParse(config.deploymentTarget ?? '');
      if (inherited == null || inherited < minimumVersion) {
        settings = _upsertBuildSetting(
          settings,
          'IPHONEOS_DEPLOYMENT_TARGET',
          '$minimumVersion',
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
/// even if the main app target is already signed. An extension configuration
/// takes the team of the Runner configuration of the same name, so a flavor
/// signed by a different team stays signed by it.
Future<void> ensureWidgetExtensionDevelopmentTeamInXcodeProject({
  required File pbxprojFile,
}) async {
  var text = await pbxprojFile.readAsString();
  final fallbackTeam = _detectRunnerDevelopmentTeam(text);
  final teamByConfigName = {
    for (final config in _runnerBuildConfigurations(
      text,
      projectDir: _projectDirOf(pbxprojFile),
    ))
      if (config.developmentTeam != null && config.developmentTeam!.isNotEmpty)
        config.name: config.developmentTeam!,
  };
  if (teamByConfigName.isEmpty &&
      (fallbackTeam == null || fallbackTeam.isEmpty)) {
    return;
  }

  var didChange = false;
  text = text.replaceAllMapped(_buildConfigurationBlockRe, (m) {
    final header = m.group(1)!;
    var settings = m.group(2)!;
    final footer = m.group(3)!;
    final name = _unquotePbxprojValue(m.group(4)!);

    if (!settings.contains('APPLICATION_EXTENSION_API_ONLY = YES;')) {
      return m.group(0)!;
    }

    final team = teamByConfigName[name] ?? fallbackTeam;
    if (team == null || team.isEmpty) return m.group(0)!;

    final patched = _upsertBuildSetting(
      settings,
      'DEVELOPMENT_TEAM',
      _quotePbxprojValue(team),
    );
    if (patched == settings) return m.group(0)!;
    settings = patched;
    didChange = true;
    return '$header$settings$footer';
  });

  if (!didChange) return;

  await pbxprojFile.writeAsString(text);
  logger.detail('Updated Xcode project: ${pbxprojFile.path}');
  logger.detail('Ensured widget extensions use the Runner DEVELOPMENT_TEAM.');
}

String _developmentTeamBuildSettingLine(String? team) {
  if (team == null || team.isEmpty) return '';
  return '\t\t\t\tDEVELOPMENT_TEAM = ${_quotePbxprojValue(team)};\n';
}

/// The `ios/` directory holding `Runner.xcodeproj/project.pbxproj`.
Directory _projectDirOf(File pbxprojFile) => pbxprojFile.parent.parent;

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

  // Fall back to whatever comment the object carries, or none at all.
  if (startIdx == -1) {
    startIdx = RegExp(
          RegExp.escape(objectId) + r'(?: /\* [^*\n]*? \*/)? = \{',
        ).firstMatch(pbxproj)?.start ??
        -1;
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
  final value = m?.group(1);
  return value == null ? null : _unquotePbxprojValue(value);
}

String? _detectRunnerDevelopmentTeam(String pbxproj) {
  final configBlockRe = RegExp(
    r'isa = XCBuildConfiguration;[\s\S]*?buildSettings = \{([\s\S]*?)\};\s*name = [^;\n]+;',
  );
  for (final match in configBlockRe.allMatches(pbxproj)) {
    final settings = match.group(1)!;
    if (!settings.contains('INFOPLIST_FILE = Runner/Info.plist;')) continue;
    final teamMatch = RegExp(
      r'DEVELOPMENT_TEAM = ([^;]+);',
    ).firstMatch(settings);
    if (teamMatch != null) return _unquotePbxprojValue(teamMatch.group(1)!);
  }
  return null;
}

/// Every `PBXFileReference` the project holds, as a path relative to `ios/`.
///
/// A file's own `path` is relative to the group that holds it, so the answer is
/// only knowable by walking down from the project's `mainGroup` — groups
/// without a `path` (the `Flutter` group Xcode writes) add nothing, a group
/// rooted at `SOURCE_ROOT` starts over from `ios/`, and anything rooted
/// somewhere only Xcode knows (`SDKROOT`, `BUILT_PRODUCTS_DIR`) is left out.
Map<String, String> _fileReferencePaths(String pbxproj) {
  final mainGroupId = _findProjectFieldId(pbxproj, 'mainGroup');
  if (mainGroupId == null) return const {};

  final paths = <String, String>{};
  final visited = <String>{};

  void walk(String groupId, String prefix) {
    if (!visited.add(groupId)) return;
    final block = _extractPbxObjectBlock(pbxproj, objectId: groupId);
    if (block == null || !block.contains('isa = PBXGroup;')) return;

    final groupPath = _objectFieldValue(block, 'path');
    final groupPrefix = groupPath == null
        ? prefix
        : _joinRelative(
            _objectFieldValue(block, 'sourceTree') == '<group>' ? prefix : '',
            groupPath,
          );

    final children = RegExp(r'children = \(([\s\S]*?)\);').firstMatch(block);
    if (children == null) return;
    for (final child in RegExp(r'[0-9A-F]{24}')
        .allMatches(children.group(1)!)
        .map((m) => m.group(0)!)) {
      final childBlock = _extractPbxObjectBlock(pbxproj, objectId: child);
      if (childBlock == null) continue;
      if (childBlock.contains('isa = PBXGroup;')) {
        walk(child, groupPrefix);
        continue;
      }
      if (!childBlock.contains('isa = PBXFileReference;')) continue;

      final path = _objectFieldValue(childBlock, 'path');
      if (path == null) continue;
      final sourceTree = _objectFieldValue(childBlock, 'sourceTree');
      if (sourceTree == '<group>') {
        paths[child] = _joinRelative(groupPrefix, path);
      } else if (sourceTree == 'SOURCE_ROOT' || sourceTree == 'SRCROOT') {
        paths[child] = path;
      }
    }
  }

  walk(mainGroupId, '');
  return paths;
}

String _joinRelative(String prefix, String path) =>
    prefix.isEmpty ? path : '$prefix/$path';

/// The value of `field = …;` inside a pbxproj object, unquoted.
String? _objectFieldValue(String block, String field) {
  final m = RegExp(
    r'(?:^|[\s{])' + RegExp.escape(field) + r' = ([^;\n]*);',
  ).firstMatch(block);
  return m == null ? null : _unquotePbxprojValue(m.group(1)!);
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
  // The comment is optional: the project's main group carries none, while named
  // groups such as `/* Products */` or a widget's own folder do.
  final groupBlockRegex = RegExp(
    r'^\s*' +
        RegExp.escape(groupId) +
        r'(?: /\* .*? \*/)?\s*=\s*\{[\s\S]*?\n\s*\};\s*$',
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
