import 'dart:io';

import 'package:path/path.dart' as p;

import '../generator_error.dart';
import 'logger.dart';
import 'fnv_hash.dart';
import 'naming.dart';
import 'pbxproj/pbxproj_editor.dart';
import 'xcconfig.dart';
import 'xcode_project.dart';

export 'pbxproj/pbxproj_document.dart' show Pbxproj;

/// The Xcode project [pbxprojFile], parsed.
///
/// Throws a [GeneratorError] naming the file when it cannot be parsed.
Future<Pbxproj> readXcodeProject(File pbxprojFile) async {
  final text = await pbxprojFile.readAsString();
  try {
    return Pbxproj.parse(text);
  } on FormatException catch (error) {
    throw GeneratorError(
      'Could not read the Xcode project ${pbxprojFile.path}: '
      '${error.message}',
    );
  }
}

/// Checks that [ensureWidgetExtensionTargetInXcodeProject] can wire
/// [widgetClassName] into [pbxprojFile], so a caller can fail before it writes
/// anything, and returns the parsed project.
///
/// Throws the [GeneratorError] that call would: when the file cannot be
/// parsed, or when the project has no such target yet and lacks what a new one
/// is attached to.
Future<Pbxproj> checkWidgetExtensionTargetInXcodeProject({
  required File pbxprojFile,
  required String widgetClassName,
}) async {
  final project = await readXcodeProject(pbxprojFile);
  _checkAnchorsForNewTarget(project, pbxprojFile, widgetClassName);
  return project;
}

/// Ensures an iOS Widget Extension target exists inside the given Xcode
/// `project.pbxproj` file.
///
/// The extension folder becomes a File System Synchronized group when the
/// project already uses them (Xcode 16 `flutter create`), which builds every
/// file in it without listing each one; other projects get a classic group
/// with explicit references to the generated files.
///
/// Every build configuration of the app target (see [detectXcodeFlavors]) is
/// mirrored onto the extension, flavored ones (`Debug-dev`) included: a
/// flavored scheme builds the extension with the configuration of the same
/// name, and without it Xcode silently falls back to the default one and signs
/// the extension with the wrong bundle id.
/// [flavorEntitlements] maps a flavor to the entitlements file its
/// configurations use, relative to `ios/`; flavors it does not list and the
/// unflavored configurations use `<widgetClassName>.entitlements`.
///
/// A configuration this adds starts at the deployment target of the app
/// configuration it mirrors, 14.0 at the least; one that exists keeps its own.
///
/// A target this patcher created is recognized by its id and has whatever part
/// of its wiring went missing restored; a target of that name created in Xcode
/// only has its build configurations synced.
///
/// Throws a [GeneratorError] when the file cannot be parsed, or when a new
/// target has nothing to attach to: no root project, no app target, or no
/// main or products group.
Future<void> ensureWidgetExtensionTargetInXcodeProject({
  required File pbxprojFile,
  required String widgetClassName,
  Map<String, String> flavorEntitlements = const {},
}) async {
  final projectName = xcodeProjectName(pbxprojFile);
  await _updateXcodeProject(pbxprojFile, (editor) {
    final project = editor.project;
    final appTarget = _appTargetName(project, projectName);
    final configs = _desiredExtensionConfigurations(
      project,
      widgetClassName: widgetClassName,
      flavorEntitlements: flavorEntitlements,
      projectDir: _projectDirOf(pbxprojFile),
      projectName: projectName,
    );
    _checkAnchorsForNewTarget(project, pbxprojFile, widgetClassName);

    final ids = _WidgetExtensionIds(widgetClassName);
    final existing = project.nativeTargetNamed(widgetClassName);
    final ownTarget = existing == null || existing.id == ids.targetId;
    final anchors = _projectAnchors(project, projectName).anchors;
    if (ownTarget && anchors != null) {
      _ensureWidgetExtensionObjects(
        editor,
        ids: ids,
        anchors: anchors,
        widgetClassName: widgetClassName,
        configs: configs,
        synchronized: _widgetUsesSynchronizedGroup(project, widgetClassName),
        newTarget: existing == null,
      );
    }
    // A flavor may have been added to the project since the target was.
    _syncExtensionBuildConfigurations(
      editor,
      widgetClassName: widgetClassName,
      configs: configs,
      ownTarget: ownTarget,
      appTarget: appTarget,
    );

    return existing == null
        ? 'Added Widget Extension target "$widgetClassName" '
            '(bundle id: ${configs.first.bundleId}).'
        : 'Synced the Widget Extension target "$widgetClassName" with '
            '$appTarget.';
  });

  await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);
  await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
    pbxprojFile: pbxprojFile,
  );
}

/// The Flutter flavors the Xcode project defines, in first-seen order.
///
/// Flutter models a flavor as a trio of build configurations of the app target
/// named `Debug-<flavor>` / `Release-<flavor>` / `Profile-<flavor>`; a project
/// without flavors only has the three plain ones, so this returns an empty
/// list.
///
/// The app target is the one named `Runner`, as `flutter create` names it,
/// else the one named after the project, [projectName] (`MyApp` for
/// `MyApp.xcodeproj`), else the only application target there is.
///
/// [projectDir] is the `ios/` directory. Passing it lets the settings an
/// `.xcconfig` file holds take part; without it only what the pbxproj itself
/// spells out is read.
List<String> detectXcodeFlavors(
  Pbxproj project, {
  Directory? projectDir,
  String? projectName,
}) {
  final flavors = <String>[];
  for (final config in _runnerBuildConfigurations(
    project,
    projectDir: projectDir,
    projectName: projectName,
  )) {
    final flavor = config.flavor;
    if (flavor != null && !flavors.contains(flavor)) flavors.add(flavor);
  }
  return flavors;
}

/// Every `CODE_SIGN_ENTITLEMENTS` build setting the app target's
/// configurations for [flavor] resolve to, in configuration order (Debug,
/// Release, Profile) and without duplicates.
///
/// [flavor] `null` asks for the unflavored configurations. The three of a
/// flavor may well sign with different files — splitting `aps-environment` over
/// Debug and Release is routine — so a caller that has to reach all of them
/// cannot settle for one. Configurations setting nothing are left out, which
/// makes an empty list mean "none of them signs with a file".
///
/// A value can name a build variable (`$(SRCROOT)/Runner/Runner.entitlements`),
/// so these are what to show the user rather than what to open — see
/// [resolveProjectRelativePath] for that. [projectDir] and [projectName] are
/// read as [detectXcodeFlavors] reads them.
List<String> runnerEntitlementsSettingsForFlavor(
  Pbxproj project,
  String? flavor, {
  Directory? projectDir,
  String? projectName,
}) {
  final settings = <String>[];
  for (final config in _runnerBuildConfigurations(
    project,
    projectDir: projectDir,
    projectName: projectName,
  )) {
    if (config.flavor != flavor) continue;
    final entitlements = config.entitlements;
    if (entitlements == null || settings.contains(entitlements)) continue;
    settings.add(entitlements);
  }
  return settings;
}

/// The entitlements file, relative to `ios/`, the app target signs with where
/// its configurations name none: next to the app's `Info.plist`, named after
/// the folder holding it.
///
/// That is `Runner/Runner.entitlements` in a project made by `flutter create`,
/// and whenever the `Info.plist` is not known to be in a folder inside `ios/`.
/// [projectDir] and [projectName] are read as [detectXcodeFlavors] reads them.
String defaultRunnerEntitlementsPath(
  Pbxproj project, {
  Directory? projectDir,
  String? projectName,
}) =>
    _defaultRunnerEntitlementsPath(
      _runnerBuildConfigurations(
        project,
        projectDir: projectDir,
        projectName: projectName,
      ),
    );

String _defaultRunnerEntitlementsPath(List<_RunnerBuildConfiguration> configs) {
  final folder = _firstInSourceOrder(configs, (config) {
        final infoPlist = config.infoPlist;
        final path =
            infoPlist == null ? null : resolveProjectRelativePath(infoPlist);
        if (path == null) return null;
        final directory = p.posix.dirname(p.posix.normalize(path));
        return p.posix.isRelative(directory) && p.posix.isWithin('.', directory)
            ? directory
            : null;
      }) ??
      'Runner';
  return '$folder/${p.posix.basename(folder)}.entitlements';
}

/// [value] as a path relative to `ios/`, or `null` when it is not one.
///
/// The two build variables that resolve to the project directory are stripped;
/// a value holding any other reference cannot be resolved without Xcode.
String? resolveProjectRelativePath(String value) {
  var path = value.trim();
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

/// A build configuration of the app target, reduced to what the extension
/// mirrors.
final class _RunnerBuildConfiguration {
  const _RunnerBuildConfiguration({
    required this.object,
    required this.name,
    required this.bundleId,
    required this.developmentTeam,
    required this.entitlements,
    required this.deploymentTarget,
    required this.infoPlist,
  });

  final PbxObject object;
  final String name;
  final String? bundleId;

  /// Empty for the team Xcode writes when signing is set to none.
  final String? developmentTeam;
  final String? entitlements;
  final String? deploymentTarget;
  final String? infoPlist;

  String get id => object.id;

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
    required this.deploymentTarget,
  });

  final String id;
  final String name;
  final String widgetClassName;
  final String bundleId;
  final String? developmentTeam;
  final String entitlements;
  final String? flavor;

  /// Only written into a configuration this creates.
  final String deploymentTarget;

  String? get compilationConditions => flavor == null
      ? null
      : '\$(inherited) ${flavorCompilationCondition(flavor!)}';
}

/// The ids a new extension target is attached to.
typedef _ProjectAnchors = ({
  String projectId,
  String runnerTargetId,
  String mainGroupId,
  String productsGroupId,
});

String? _flavorOfConfigurationName(String name) =>
    RegExp(r'^(?:Debug|Release|Profile)-(.+)$').firstMatch(name)?.group(1);

/// Applies [edit] to the project in [pbxprojFile] and writes the result back
/// when the text changed, logging the summary [edit] returns.
///
/// Throws a [GeneratorError] when the file cannot be parsed, and when the
/// edited text does not parse either; the file is left unchanged then.
Future<void> _updateXcodeProject(
  File pbxprojFile,
  String Function(PbxprojEditor editor) edit,
) async {
  final project = await readXcodeProject(pbxprojFile);
  final editor = PbxprojEditor.parsed(project);
  final String summary;
  try {
    summary = edit(editor);
    if (editor.text == project.text) return;
    Pbxproj.parse(editor.text);
  } on FormatException catch (error) {
    throw GeneratorError(
      'home_widget produced an invalid Xcode project while updating '
      '${pbxprojFile.path} and left the file unchanged: ${error.message}',
    );
  }

  await pbxprojFile.writeAsString(editor.text);
  logger.detail('Updated Xcode project: ${pbxprojFile.path}');
  logger.detail(summary);
}

/// The app's target, as [detectXcodeFlavors] describes it.
PbxObject? _appTarget(Pbxproj project, String? projectName) {
  final named = project.nativeTargetNamed('Runner') ??
      (projectName == null ? null : project.nativeTargetNamed(projectName));
  if (named != null) return named;
  final applications = [
    for (final target in project.objectsOfIsa('PBXNativeTarget'))
      if (target.string('productType') == _applicationProductType) target,
  ];
  return applications.length == 1 ? applications.single : null;
}

const _applicationProductType = 'com.apple.product-type.application';

/// The name of the app's target, for messages.
String _appTargetName(Pbxproj project, String? projectName) =>
    _appTarget(project, projectName)?.string('name') ?? 'Runner';

/// The ids an extension target is attached to, or `null` along with what the
/// project is missing of them.
({_ProjectAnchors? anchors, List<String> missing}) _projectAnchors(
  Pbxproj project,
  String? projectName,
) {
  final root = project.rootProject;
  final runner = _appTarget(project, projectName);
  final mainGroup = project.object(root?.string('mainGroup'));
  final productsGroup = project.object(root?.string('productRefGroup'));
  final names = {'Runner', if (projectName != null) projectName}
      .map((name) => '"$name"')
      .join(' or ');

  final missing = [
    if (root == null) 'its root PBXProject object (rootObject)',
    if (runner == null)
      'an app target (a PBXNativeTarget named $names, or the only one of '
          'productType "$_applicationProductType")',
    if (root != null && mainGroup == null) 'the mainGroup of its PBXProject',
    if (root != null && productsGroup == null)
      'the productRefGroup of its PBXProject',
  ];
  if (missing.isNotEmpty) return (anchors: null, missing: missing);
  return (
    anchors: (
      projectId: root!.id,
      runnerTargetId: runner!.id,
      mainGroupId: mainGroup!.id,
      productsGroupId: productsGroup!.id,
    ),
    missing: missing,
  );
}

/// Throws a [GeneratorError] naming what is missing when the project has no
/// [widgetClassName] target yet and lacks what a new one is attached to.
void _checkAnchorsForNewTarget(
  Pbxproj project,
  File pbxprojFile,
  String widgetClassName,
) {
  if (project.nativeTargetNamed(widgetClassName) != null) return;
  final missing =
      _projectAnchors(project, xcodeProjectName(pbxprojFile)).missing;
  if (missing.isEmpty) return;
  throw GeneratorError(
    'Cannot add the Widget Extension target "$widgetClassName" to '
    '${pbxprojFile.path}: the project is missing ${missing.join(', ')}. '
    'home_widget needs the app target and project structure that '
    '`flutter create` generates.',
  );
}

/// The app target's build configurations, ordered base-first and then flavor
/// by flavor.
///
/// The app target's `XCConfigurationList` is the authority on which
/// configurations belong to it; projects too reduced to have a target at all
/// (test fixtures, hand-written snippets) fall back to the
/// `INFOPLIST_FILE = Runner/Info.plist` marker.
///
/// Each configuration is read the way Xcode reads it, so a setting a flavor
/// keeps in its `.xcconfig` or at project level is seen as well — passing
/// [projectDir], the `ios/` directory, is what makes the first of those two
/// reachable.
List<_RunnerBuildConfiguration> _runnerBuildConfigurations(
  Pbxproj project, {
  Directory? projectDir,
  String? projectName,
}) {
  final runner = _appTarget(project, projectName);
  var selected = runner == null
      ? const <PbxObject>[]
      : project.buildConfigurationsOf(runner);
  if (selected.isEmpty) {
    selected = [
      for (final config in project.objectsOfIsa('XCBuildConfiguration'))
        if (ownBuildSettings(config)['INFOPLIST_FILE'] == 'Runner/Info.plist')
          config,
    ];
  }

  final root = project.rootProject;
  final projectConfigs = {
    if (root != null)
      for (final config in project.buildConfigurationsOf(root))
        if (config.string('name') != null) config.string('name')!: config,
  };
  final xcconfigPaths = projectDir == null
      ? const <String, String>{}
      : _fileReferencePaths(project);

  final configs = <_RunnerBuildConfiguration>[];
  for (final config in selected) {
    final name = config.string('name') ?? '';
    final resolved = _resolvedBuildSettings(
      config: config,
      inherited: projectConfigs[name],
      projectDir: projectDir,
      xcconfigPaths: xcconfigPaths,
    );

    configs.add(
      _RunnerBuildConfiguration(
        object: config,
        name: name,
        bundleId: resolved['PRODUCT_BUNDLE_IDENTIFIER'],
        developmentTeam: resolved['DEVELOPMENT_TEAM'],
        entitlements: resolved['CODE_SIGN_ENTITLEMENTS'],
        deploymentTarget: resolved['IPHONEOS_DEPLOYMENT_TARGET'],
        infoPlist: resolved['INFOPLIST_FILE'],
      ),
    );
  }
  return _orderConfigurations(configs);
}

/// The first value [read] gives for [configs] taken in the order the project
/// lists them.
String? _firstInSourceOrder(
  List<_RunnerBuildConfiguration> configs,
  String? Function(_RunnerBuildConfiguration config) read,
) {
  final bySource = [...configs]
    ..sort((a, b) => a.object.entry.start.compareTo(b.object.entry.start));
  for (final config in bySource) {
    final value = read(config);
    if (value != null) return value;
  }
  return null;
}

/// The team the extension configuration named [name] signs with: that of the
/// app configuration of the same name, or, when that one sets no team at all,
/// that of the first unflavored app configuration setting one.
///
/// An empty team is signing turned off, which is kept rather than filled in.
String? _developmentTeamFor(
  String name,
  List<_RunnerBuildConfiguration> runnerConfigs,
) {
  final team =
      runnerConfigs.where((c) => c.name == name).firstOrNull?.developmentTeam ??
          _firstInSourceOrder(
            runnerConfigs,
            (c) => c.flavor == null && c.developmentTeam != ''
                ? c.developmentTeam
                : null,
          );
  return team == null || team.isEmpty ? null : team;
}

/// Everything a build configuration resolves to, unquoted and with references
/// to other settings expanded.
///
/// The four layers Xcode reads, weakest first: the project's `.xcconfig`, the
/// project configuration of the same name, the target's `.xcconfig`, and the
/// target configuration's own settings. `$(inherited)` in a layer stands for
/// what the layers below it resolve the setting to.
Map<String, String> _resolvedBuildSettings({
  required PbxObject config,
  required PbxObject? inherited,
  required Directory? projectDir,
  required Map<String, String> xcconfigPaths,
}) {
  final merged = <String, String>{};
  for (final layer in [
    _xcconfigSettings(inherited, projectDir, xcconfigPaths),
    if (inherited != null) ownBuildSettings(inherited),
    _xcconfigSettings(config, projectDir, xcconfigPaths),
    ownBuildSettings(config),
  ]) {
    for (final MapEntry(:key, :value) in layer.entries) {
      merged[key] =
          value.replaceAll(_inheritedReference, merged[key] ?? '').trim();
    }
  }
  return {
    for (final entry in merged.entries)
      entry.key: _expandSettingReferences(entry.value, merged),
  };
}

final RegExp _inheritedReference = RegExp(r'\$\(inherited\)|\$\{inherited\}');

/// The settings the `.xcconfig` [config] is based on defines, or nothing when
/// it has none, when the reference cannot be resolved to a file, or when the
/// caller did not say where the project lives.
///
/// Xcode 16 can name the file by its path inside a synchronized folder
/// (`baseConfigurationReferenceAnchor`) instead of by a file reference.
Map<String, String> _xcconfigSettings(
  PbxObject? config,
  Directory? projectDir,
  Map<String, String> xcconfigPaths,
) {
  if (config == null || projectDir == null) return const {};
  final String? path;
  if (config.string('baseConfigurationReference') case final refId?) {
    path = xcconfigPaths[refId];
  } else {
    final anchor =
        xcconfigPaths[config.string('baseConfigurationReferenceAnchor')];
    final relative = config.string('baseConfigurationReferenceRelativePath');
    path = anchor == null || relative == null
        ? null
        : _joinRelative(anchor, relative);
  }
  if (path == null) return const {};
  return readXcconfigSettings(File(p.join(projectDir.path, path)));
}

/// Replaces `$(KEY)` / `${KEY}` in [value] with what [settings] resolves them
/// to, leaving anything the project does not define alone.
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
  Pbxproj project, {
  required String widgetClassName,
  required Map<String, String> flavorEntitlements,
  required Directory projectDir,
  required String? projectName,
}) {
  final defaultEntitlements = '$widgetClassName.entitlements';

  final runnerConfigs = _runnerBuildConfigurations(
    project,
    projectDir: projectDir,
    projectName: projectName,
  );
  final fallbackBundleId = _firstInSourceOrder(
        runnerConfigs,
        (c) => c.flavor == null ? c.bundleId : null,
      ) ??
      _firstInSourceOrder(runnerConfigs, (c) => c.bundleId) ??
      'com.example.app';

  _ExtensionBuildConfiguration mirror(
    String name, [
    _RunnerBuildConfiguration? runner,
  ]) {
    final flavor = _flavorOfConfigurationName(name);
    return _ExtensionBuildConfiguration(
      id: xcodeObjectId('cfg:$name:$widgetClassName'),
      name: name,
      widgetClassName: widgetClassName,
      bundleId: '${runner?.bundleId ?? fallbackBundleId}.$widgetClassName',
      developmentTeam: _developmentTeamFor(name, runnerConfigs),
      entitlements: flavor == null
          ? defaultEntitlements
          : flavorEntitlements[flavor] ?? defaultEntitlements,
      flavor: flavor,
      deploymentTarget: _extensionDeploymentTarget(runner?.deploymentTarget),
    );
  }

  if (runnerConfigs.isEmpty) {
    return [
      for (final name in const ['Debug', 'Release', 'Profile']) mirror(name),
    ];
  }
  return [for (final config in runnerConfigs) mirror(config.name, config)];
}

/// [appDeploymentTarget] when it is a version of at least iOS 14.0, the oldest
/// home_widget supports, and 14.0 otherwise.
///
/// A fixed version would not do: Flutter's deployment target migration
/// rewrites every value below its own minimum in the file on the next build.
String _extensionDeploymentTarget(String? appDeploymentTarget) {
  final major = RegExp(r'^(\d+)(?:\.\d+)*$')
      .firstMatch(appDeploymentTarget ?? '')
      ?.group(1);
  return major != null && int.parse(major) >= 14
      ? appDeploymentTarget!
      : '14.0';
}

/// Adds whatever the extension target [ids] names lacks — the target itself,
/// its phases, files, groups and build configurations — and wires it into the
/// Runner target and the project.
///
/// Every object is only inserted when its id is not taken and every list entry
/// only added when missing, so a target that lost part of its wiring, to Xcode
/// deleting it or to an older version of this patcher, is repaired without
/// duplicating what is left. An existing target keeps the Runner build phase
/// order and the Products group it has: neither affects the build, and older
/// projects differ in both.
void _ensureWidgetExtensionObjects(
  PbxprojEditor editor, {
  required _WidgetExtensionIds ids,
  required _ProjectAnchors anchors,
  required String widgetClassName,
  required List<_ExtensionBuildConfiguration> configs,
  required bool synchronized,
  required bool newTarget,
}) {
  void insertMissing(String isa, Map<String, String> objects) {
    final missing = [
      for (final MapEntry(key: id, value: object) in objects.entries)
        if (editor.project.object(id) == null) object,
    ];
    if (missing.isNotEmpty) editor.insertObjects(isa, missing.join());
  }

  insertMissing('PBXBuildFile', {
    ids.embedBuildFileId: '''
\t\t${ids.embedBuildFileId} /* $widgetClassName.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = ${ids.productFileRefId} /* $widgetClassName.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
''',
    ids.widgetKitBuildFileId: '''
\t\t${ids.widgetKitBuildFileId} /* WidgetKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${ids.widgetKitFileRefId} /* WidgetKit.framework */; };
''',
    ids.swiftUIBuildFileId: '''
\t\t${ids.swiftUIBuildFileId} /* SwiftUI.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${ids.swiftUIFileRefId} /* SwiftUI.framework */; };
''',
    if (!synchronized) ...{
      ids.widgetSwiftBuildFileId: '''
\t\t${ids.widgetSwiftBuildFileId} /* Widget.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${ids.widgetSwiftFileRefId} /* Widget.swift */; };
''',
      ids.widgetBundleSwiftBuildFileId: '''
\t\t${ids.widgetBundleSwiftBuildFileId} /* WidgetBundle.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${ids.widgetBundleSwiftFileRefId} /* WidgetBundle.swift */; };
''',
    },
  });

  insertMissing('PBXContainerItemProxy', {
    ids.containerProxyId: '''
\t\t${ids.containerProxyId} /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = ${anchors.projectId} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = ${ids.targetId};
\t\t\tremoteInfo = $widgetClassName;
\t\t};
''',
  });

  insertMissing('PBXCopyFilesBuildPhase', {
    ids.copyFilesPhaseId: '''
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
''',
  });

  insertMissing('PBXFileReference', {
    ids.productFileRefId: '''
\t\t${ids.productFileRefId} /* $widgetClassName.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = $widgetClassName.appex; sourceTree = BUILT_PRODUCTS_DIR; };
''',
    ids.widgetKitFileRefId: '''
\t\t${ids.widgetKitFileRefId} /* WidgetKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; };
''',
    ids.swiftUIFileRefId: '''
\t\t${ids.swiftUIFileRefId} /* SwiftUI.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = SwiftUI.framework; path = System/Library/Frameworks/SwiftUI.framework; sourceTree = SDKROOT; };
''',
    ids.entitlementsFileRefId: '''
\t\t${ids.entitlementsFileRefId} /* $widgetClassName.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = $widgetClassName.entitlements; sourceTree = "<group>"; };
''',
    if (!synchronized) ...{
      ids.widgetSwiftFileRefId: '''
\t\t${ids.widgetSwiftFileRefId} /* Widget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Widget.swift; sourceTree = "<group>"; };
''',
      ids.widgetBundleSwiftFileRefId: '''
\t\t${ids.widgetBundleSwiftFileRefId} /* WidgetBundle.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WidgetBundle.swift; sourceTree = "<group>"; };
''',
      ids.infoPlistFileRefId: '''
\t\t${ids.infoPlistFileRefId} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
''',
    },
  });

  if (synchronized) {
    insertMissing('PBXFileSystemSynchronizedBuildFileExceptionSet', {
      ids.fsExceptionId: '''
\t\t${ids.fsExceptionId} /* Exceptions for "$widgetClassName" folder in "$widgetClassName" target */ = {
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t);
\t\t\ttarget = ${ids.targetId} /* $widgetClassName */;
\t\t};
''',
    });
    insertMissing('PBXFileSystemSynchronizedRootGroup', {
      ids.fsRootGroupId: '''
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
''',
    });
  } else {
    insertMissing('PBXGroup', {
      ids.widgetGroupId: '''
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
''',
    });
  }

  insertMissing('PBXFrameworksBuildPhase', {
    ids.frameworksPhaseId: '''
\t\t${ids.frameworksPhaseId} /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t${ids.swiftUIBuildFileId} /* SwiftUI.framework in Frameworks */,
\t\t\t\t${ids.widgetKitBuildFileId} /* WidgetKit.framework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
''',
  });

  final sources = StringBuffer()..write('''
\t\t${ids.sourcesPhaseId} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
''');
  if (!synchronized) {
    sources
      ..writeln(
        '\t\t\t\t${ids.widgetSwiftBuildFileId} /* Widget.swift in Sources */,',
      )
      ..writeln(
        '\t\t\t\t${ids.widgetBundleSwiftBuildFileId} /* WidgetBundle.swift in Sources */,',
      );
  }
  sources.write('''
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
''');
  insertMissing('PBXSourcesBuildPhase', {
    ids.sourcesPhaseId: sources.toString(),
  });

  insertMissing('PBXResourcesBuildPhase', {
    ids.resourcesPhaseId: '''
\t\t${ids.resourcesPhaseId} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
''',
  });

  final target = StringBuffer()..write('''
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
''');
  if (synchronized) {
    target.write('''
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t${ids.fsRootGroupId} /* $widgetClassName */,
\t\t\t);
''');
  }
  target.write('''
\t\t\tname = $widgetClassName;
\t\t\tproductName = $widgetClassName;
\t\t\tproductReference = ${ids.productFileRefId} /* $widgetClassName.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t};
''');
  insertMissing('PBXNativeTarget', {ids.targetId: target.toString()});

  insertMissing('PBXTargetDependency', {
    ids.targetDependencyId: '''
\t\t${ids.targetDependencyId} /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = ${ids.targetId} /* $widgetClassName */;
\t\t\ttargetProxy = ${ids.containerProxyId} /* PBXContainerItemProxy */;
\t\t};
''',
  });

  // Configurations of a list that is still there are the sync's to reconcile.
  if (editor.project.object(ids.configListId) == null) {
    insertMissing('XCBuildConfiguration', {
      for (final config in configs)
        config.id: _renderExtensionBuildConfiguration(config),
    });

    final configList = StringBuffer()..write('''
\t\t${ids.configListId} /* Build configuration list for PBXNativeTarget "$widgetClassName" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
''');
    for (final config in configs) {
      configList.writeln('\t\t\t\t${config.id} /* ${config.name} */,');
    }
    configList.write('''
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
''');
    editor.insertObjects('XCConfigurationList', configList.toString());
  }

  final runnerPhases =
      editor.project.object(anchors.runnerTargetId)!.strings('buildPhases');
  if (newTarget || !runnerPhases.contains(ids.copyFilesPhaseId)) {
    _ensureRunnerEmbedsWidgetExtensionInSafeOrder(
      editor,
      runnerTargetId: anchors.runnerTargetId,
      embedCopyPhaseId: ids.copyFilesPhaseId,
    );
  }
  editor
    ..addArrayEntry(
      ids.copyFilesPhaseId,
      'files',
      ids.embedBuildFileId,
      comment: '$widgetClassName.appex in Embed Foundation Extensions',
    )
    ..addArrayEntry(
      anchors.runnerTargetId,
      'dependencies',
      ids.targetDependencyId,
      comment: 'PBXTargetDependency',
    )
    ..addArrayEntry(
      anchors.projectId,
      'targets',
      ids.targetId,
      comment: widgetClassName,
    );

  // A file or folder the developer moved to a group of their own stays there.
  void addToGroup(String groupId, String childId, String comment) {
    final grouped = editor.project.objects.values
        .any((object) => object.strings('children').contains(childId));
    if (!grouped) {
      editor.addArrayEntry(groupId, 'children', childId, comment: comment);
    }
  }

  if (newTarget) {
    addToGroup(
      anchors.productsGroupId,
      ids.productFileRefId,
      '$widgetClassName.appex',
    );
  }
  addToGroup(
    anchors.mainGroupId,
    ids.entitlementsFileRefId,
    '$widgetClassName.entitlements',
  );
  addToGroup(
    anchors.mainGroupId,
    synchronized ? ids.fsRootGroupId : ids.widgetGroupId,
    widgetClassName,
  );
}

String _renderExtensionBuildConfiguration(_ExtensionBuildConfiguration config) {
  final team = config.developmentTeam;
  final conditions = config.compilationConditions;
  final buffer = StringBuffer()..write('''
\t\t${config.id} /* ${config.name} */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = ${pbxLiteral(config.entitlements)};
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
''');
  if (team != null) {
    buffer.writeln('\t\t\t\tDEVELOPMENT_TEAM = ${pbxLiteral(team)};');
  }
  buffer.write('''
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = ${config.deploymentTarget};
\t\t\t\tINFOPLIST_FILE = ${config.widgetClassName}/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = ${config.widgetClassName};
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"\$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = ${pbxLiteral(config.bundleId)};
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
''');
  if (conditions != null) {
    buffer.writeln(
      '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = ${pbxLiteral(conditions)};',
    );
  }
  buffer.write('''
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = ${pbxLiteral(config.name)};
\t\t};
''');
  return buffer.toString();
}

/// Reconciles an existing extension target's build configurations with
/// [configs]: missing ones are added, existing ones have the settings this
/// patcher owns rewritten to the desired value.
///
/// Existing configurations are found by name in the target's own
/// configuration list, so one that Xcode (or an older version of this patcher)
/// created under another id is updated rather than duplicated.
///
/// Resetting a setting of a target this patcher did not create, [ownTarget]
/// `false`, is a warning: those values were chosen by hand.
void _syncExtensionBuildConfigurations(
  PbxprojEditor editor, {
  required String widgetClassName,
  required List<_ExtensionBuildConfiguration> configs,
  required bool ownTarget,
  required String appTarget,
}) {
  final listId = editor.project
      .nativeTargetNamed(widgetClassName)
      ?.string('buildConfigurationList');
  final missing = <_ExtensionBuildConfiguration>[];

  for (final config in configs) {
    final project = editor.project;
    final existing = project
            .configurationsInList(listId)
            .where((c) => c.string('name') == config.name)
            .firstOrNull ??
        project.objectOfIsa(config.id, 'XCBuildConfiguration');
    if (existing == null) {
      missing.add(config);
      continue;
    }
    editor.retitle(existing.id, config.name);
    _applyExtensionBuildSettings(
      editor,
      existing.id,
      config,
      ownTarget: ownTarget,
      appTarget: appTarget,
    );
    if (listId != null) {
      editor.addArrayEntry(
        listId,
        'buildConfigurations',
        existing.id,
        comment: config.name,
      );
    }
  }

  if (missing.isNotEmpty && editor.project.object(listId) != null) {
    editor.insertObjects(
      'XCBuildConfiguration',
      missing.map(_renderExtensionBuildConfiguration).join(),
    );
    for (final config in missing) {
      editor.addArrayEntry(
        listId!,
        'buildConfigurations',
        config.id,
        comment: config.name,
      );
    }
  }
}

void _applyExtensionBuildSettings(
  PbxprojEditor editor,
  String configurationId,
  _ExtensionBuildConfiguration config, {
  required bool ownTarget,
  required String appTarget,
}) {
  PbxDictEntry? setting(String key) => editor.project
      .object(configurationId)
      ?.fields
      .dict('buildSettings')
      ?.entry(key);

  final reset = <String>[];
  void owned(String key, String? value) {
    if (value == null) return;
    final before = setting(key);
    editor.setBuildSetting(configurationId, key, value);
    if (before != null && buildSettingValue(before) != value) reset.add(key);
  }

  owned('PRODUCT_BUNDLE_IDENTIFIER', config.bundleId);
  owned('CODE_SIGN_ENTITLEMENTS', config.entitlements);
  owned('DEVELOPMENT_TEAM', config.developmentTeam);

  const conditionsKey = 'SWIFT_ACTIVE_COMPILATION_CONDITIONS';
  final existing = setting(conditionsKey);
  final existingTokens = existing == null
      ? null
      : (buildSettingValue(existing) ?? '')
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList();
  final conditions =
      _mergedCompilationConditions(existingTokens, config.flavor);
  if (conditions == null) {
    editor.removeBuildSetting(configurationId, conditionsKey);
  } else if (!identical(conditions, existingTokens)) {
    editor.setBuildSetting(
      configurationId,
      conditionsKey,
      conditions.join(' '),
    );
  }

  if (reset.isEmpty) return;
  final message = 'Reset ${reset.join(', ')} on the "${config.name}" '
      'configuration of ${config.widgetClassName} to match $appTarget.';
  if (ownTarget) {
    logger.info(message);
  } else {
    logger.warn(
      'Warning: $message home_widget did not create this target, so the '
      'values it replaced were set in Xcode.',
    );
  }
}

/// The `SWIFT_ACTIVE_COMPILATION_CONDITIONS` tokens for a configuration that
/// already has [existing]: `null` when the setting should not be there at all,
/// and [existing] itself when it should stay as it is — which it does whenever
/// it holds the flavor's condition and no other, however it is written.
///
/// Only the `HW_FLAVOR_` conditions belong to this patcher: every other token
/// is a flag the developer added and is kept in place, so re-running the
/// generator never drops one.
List<String>? _mergedCompilationConditions(
  List<String>? existing,
  String? flavor,
) {
  final desired = flavor == null ? null : flavorCompilationCondition(flavor);
  final tokens = existing == null ? [r'$(inherited)'] : [...existing];

  final hadFlavorConditions = tokens.any((t) => t.startsWith('HW_FLAVOR_'));
  final stale = tokens.any((t) => t.startsWith('HW_FLAVOR_') && t != desired);
  if (!stale && (desired == null || tokens.contains(desired))) return existing;

  tokens.removeWhere((token) => token.startsWith('HW_FLAVOR_'));
  if (desired != null) tokens.add(desired);

  if (tokens.isEmpty) return null;
  if (hadFlavorConditions &&
      tokens.length == 1 &&
      tokens.single == r'$(inherited)') {
    return null;
  }
  return tokens;
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
  await _updateXcodeProject(pbxprojFile, (editor) {
    if (!_widgetUsesSynchronizedGroup(editor.project, widgetClassName)) {
      _wireResourceFile(
        editor,
        widgetClassName: widgetClassName,
        name: 'Localizable.xcstrings',
        lastKnownFileType: 'text.json.xcstrings',
      );
    }
    _patchKnownRegions(editor, locales: locales);
    return 'Wired $widgetClassName/Localizable.xcstrings into the extension '
        'target.';
  });
}

/// Wires the files in `<widgetClassName>/` named by [resourceFileNames] into the
/// extension target's Resources build phase, and drops the references of
/// [removedFileNames].
///
/// This is how a copied icon font reaches the widget's bundle in a project with
/// explicit groups — the kind `flutter create` produced before Xcode 16. Each
/// file needs three things: a `PBXFileReference`, a child entry in the widget's
/// own group and a `PBXBuildFile` in the Resources phase. All three are keyed by
/// ids derived from the file name, so a second run over the same project changes
/// nothing, and a file that stops being generated takes its references with it.
/// When no group holds the widget's folder, a warning takes their place.
///
/// Projects using file-system-synchronized groups build every file in the
/// extension folder already, so nothing is patched there at all: an explicit
/// reference on top of the synced folder would have Xcode copy the file twice
/// and fail the build.
Future<void> ensureWidgetResourceFilesInXcodeProject({
  required File pbxprojFile,
  required String widgetClassName,
  required List<String> resourceFileNames,
  List<String> removedFileNames = const [],
}) async {
  await _updateXcodeProject(pbxprojFile, (editor) {
    if (!_widgetUsesSynchronizedGroup(editor.project, widgetClassName)) {
      _removeResourceFiles(
        editor,
        widgetClassName: widgetClassName,
        names: removedFileNames,
      );
      for (final name in resourceFileNames) {
        _wireResourceFile(
          editor,
          widgetClassName: widgetClassName,
          name: name,
          lastKnownFileType: 'file',
        );
      }
    }
    return 'Wired ${resourceFileNames.length} resource file'
        '${resourceFileNames.length == 1 ? '' : 's'} of $widgetClassName into '
        'the extension target.';
  });
}

/// The ids of the file reference and the build file of the extension's
/// resource file [name].
({String fileRefId, String buildFileId}) _resourceFileIds(
  String name,
  String widgetClassName,
) =>
    (
      fileRefId: xcodeObjectId('fileref:$name:$widgetClassName'),
      buildFileId: xcodeObjectId('buildfile:$name:$widgetClassName'),
    );

/// Wires `<widgetClassName>/[name]` into the extension target's Resources
/// build phase and its group; ids are derived from the file name, so a second
/// run over the same project changes nothing. Without a Resources phase to list
/// the file in, nothing is added.
///
/// Without the group of the extension folder nothing is added either: the file
/// reference is relative to its group, and one in no group points at `ios/`
/// and fails the build. The developer is told to add the file in Xcode.
void _wireResourceFile(
  PbxprojEditor editor, {
  required String widgetClassName,
  required String name,
  required String lastKnownFileType,
}) {
  final phaseId = _extensionResourcesPhaseId(editor.project, widgetClassName);
  if (phaseId == null) return;
  final groupId = _extensionGroupId(editor.project, widgetClassName);
  if (groupId == null) {
    logger.warn(
      'Warning: $name could not be wired into $widgetClassName because the '
      'Xcode project has no group for the ios/$widgetClassName folder. Add '
      'ios/$widgetClassName/$name to the $widgetClassName target in Xcode.',
    );
    return;
  }
  final (:fileRefId, :buildFileId) = _resourceFileIds(name, widgetClassName);

  // Unchecking target membership in Xcode drops the build file and keeps the
  // file reference, so each object is looked for on its own.
  if (editor.project.object(fileRefId) == null) {
    editor.insertObjects('PBXFileReference', '''
\t\t$fileRefId /* $name */ = {isa = PBXFileReference; lastKnownFileType = $lastKnownFileType; path = ${pbxLiteral(name)}; sourceTree = "<group>"; };
''');
  }
  if (editor.project.object(buildFileId) == null) {
    editor.insertObjects('PBXBuildFile', '''
\t\t$buildFileId /* $name in Resources */ = {isa = PBXBuildFile; fileRef = $fileRefId /* $name */; };
''');
  }

  editor.addArrayEntry(
    phaseId,
    'files',
    buildFileId,
    comment: '$name in Resources',
  );
  editor.addArrayEntry(groupId, 'children', fileRefId, comment: name);
}

/// Removes the file references and build files of the resource files [names],
/// and every list naming them.
void _removeResourceFiles(
  PbxprojEditor editor, {
  required String widgetClassName,
  required List<String> names,
}) {
  if (names.isEmpty) return;
  final ids = names.map((name) => _resourceFileIds(name, widgetClassName));
  editor.removeObjects({
    for (final (:fileRefId, :buildFileId) in ids) ...[fileRefId, buildFileId],
  });
}

/// The Resources build phase of the extension target, or of the phase id the
/// scaffolder derives when the project has no target of that name.
String? _extensionResourcesPhaseId(Pbxproj project, String widgetClassName) {
  final target = project.nativeTargetNamed(widgetClassName);
  if (target != null) {
    return project
        .buildPhasesOf(target, 'PBXResourcesBuildPhase')
        .firstOrNull
        ?.id;
  }
  final derived = _WidgetExtensionIds(widgetClassName).resourcesPhaseId;
  return project.object(derived)?.id;
}

/// The group of the extension folder: the one the scaffolder created, or else
/// the main group's child group whose path is `<widgetClassName>`.
///
/// A group's `name` is only what Xcode shows, so a group named after the widget
/// can still hold a folder of another name.
String? _extensionGroupId(Pbxproj project, String widgetClassName) {
  final derived = _WidgetExtensionIds(widgetClassName).widgetGroupId;
  if (project.objectOfIsa(derived, 'PBXGroup') != null) return derived;

  final mainGroup = project.object(project.rootProject?.string('mainGroup'));
  for (final childId in mainGroup?.strings('children') ?? const <String>[]) {
    if (project.objectOfIsa(childId, 'PBXGroup')?.string('path') ==
        widgetClassName) {
      return childId;
    }
  }
  return null;
}

/// Whether the scaffolder would give a new extension a synchronized root group.
bool _projectSupportsSynchronizedGroups(Pbxproj project) =>
    project.objectsOfIsa('PBXFileSystemSynchronizedRootGroup').isNotEmpty ||
    project.sections
        .any((section) => section.isa == 'PBXFileSystemSynchronizedRootGroup');

/// Whether *this widget's* extension folder is a synchronized group.
///
/// Per-widget, not per-project: a project can hold both kinds at once, and a
/// project-global guess that disagrees with the group the scaffolder actually
/// created wires the catalog into nothing while still reporting success.
bool _widgetUsesSynchronizedGroup(Pbxproj project, String widgetClassName) {
  final target = project.nativeTargetNamed(widgetClassName);
  if (target != null) {
    return target.strings('fileSystemSynchronizedGroups').isNotEmpty;
  }
  final ids = _WidgetExtensionIds(widgetClassName);
  if (project.object(ids.fsRootGroupId) != null) return true;
  if (project.object(ids.widgetGroupId) != null) return false;
  // Neither group exists yet, so nothing has been decided: answer the same way
  // the scaffolder will when it creates one.
  return _projectSupportsSynchronizedGroups(project);
}

/// Adds any missing [locales] to the root project's `knownRegions`.
///
/// A project without the list gets the one Xcode starts from, the development
/// region and `Base`, ahead of them.
void _patchKnownRegions(PbxprojEditor editor, {required List<String> locales}) {
  final project = editor.project.rootProject;
  if (project == null) return;
  for (final region in [
    if (project.fields.entry('knownRegions') == null) ...[
      project.string('developmentRegion') ?? 'en',
      'Base',
    ],
    ...locales,
  ]) {
    editor.addArrayEntry(project.id, 'knownRegions', region);
  }
}

/// Ensures every build configuration of the app target signs with an
/// entitlements file.
///
/// The iOS scaffolder creates the file [defaultRunnerEntitlementsPath] names,
/// `ios/Runner/Runner.entitlements` in a project made by `flutter create`, but
/// Xcode only applies it if `CODE_SIGN_ENTITLEMENTS` is set for the app
/// target's configurations.
///
/// A configuration that already resolves to a file keeps it — through its own
/// settings, its `.xcconfig` or the project level: a flavored project routinely
/// gives each flavor its own entitlements, and forcing them all onto one file
/// would put every flavor in the same App Group.
Future<void> ensureRunnerEntitlementsInXcodeProject({
  required File pbxprojFile,
}) async {
  final projectName = xcodeProjectName(pbxprojFile);
  await _updateXcodeProject(pbxprojFile, (editor) {
    final appTarget = _appTargetName(editor.project, projectName);
    final runnerConfigs = _runnerBuildConfigurations(
      editor.project,
      projectDir: _projectDirOf(pbxprojFile),
      projectName: projectName,
    );
    final path = _defaultRunnerEntitlementsPath(runnerConfigs);
    if (runnerConfigs.isEmpty) {
      // Don't fail the whole command, but let the user know scaffolding might
      // require manual intervention for non-standard pbxproj layouts.
      logger.warn(
        'Warning: Could not auto-set CODE_SIGN_ENTITLEMENTS for $appTarget in '
        '${pbxprojFile.path}. You may need to set it manually to $path.',
      );
    }
    for (final config in runnerConfigs) {
      if (config.entitlements != null) continue;
      editor.setBuildSetting(config.id, 'CODE_SIGN_ENTITLEMENTS', path);
    }
    return 'Ensured $appTarget uses $path.';
  });
}

/// Ensures that the app target's `IPHONEOS_DEPLOYMENT_TARGET` is at least
/// [minimumVersion] (defaults to `14.0`).
///
/// The `home_widget` plugin requires iOS 14.0+. If the app targets an older
/// version, `pod install` will fail. This function bumps the deployment target
/// in all of the app target's build configurations whose resolved value is
/// below the minimum or cannot be read.
Future<void> ensureMinimumDeploymentTargetInXcodeProject({
  required File pbxprojFile,
  double minimumVersion = 14.0,
}) async {
  final projectName = xcodeProjectName(pbxprojFile);
  await _updateXcodeProject(pbxprojFile, (editor) {
    for (final config in _runnerBuildConfigurations(
      editor.project,
      projectDir: _projectDirOf(pbxprojFile),
      projectName: projectName,
    )) {
      final version = double.tryParse(config.deploymentTarget ?? '');
      if (version != null && version >= minimumVersion) continue;
      editor.setBuildSetting(
        config.id,
        'IPHONEOS_DEPLOYMENT_TARGET',
        '$minimumVersion',
      );
    }
    return 'Ensured ${_appTargetName(editor.project, projectName)} '
        'IPHONEOS_DEPLOYMENT_TARGET >= $minimumVersion.';
  });
}

/// Ensures widget extension targets use the same [DEVELOPMENT_TEAM] as the app
/// target.
///
/// Physical device builds fail when extension targets lack a development team
/// even if the main app target is already signed. An extension configuration
/// takes the team of the app configuration of the same name, so a flavor
/// signed by a different team stays signed by it; only when that configuration
/// sets no team at all does the first unflavored one stand in.
Future<void> ensureWidgetExtensionDevelopmentTeamInXcodeProject({
  required File pbxprojFile,
}) async {
  final projectName = xcodeProjectName(pbxprojFile);
  await _updateXcodeProject(pbxprojFile, (editor) {
    final project = editor.project;
    final runnerConfigs = _runnerBuildConfigurations(
      project,
      projectDir: _projectDirOf(pbxprojFile),
      projectName: projectName,
    );

    for (final config in project.objectsOfIsa('XCBuildConfiguration')) {
      if (ownBuildSettings(config)['APPLICATION_EXTENSION_API_ONLY'] != 'YES') {
        continue;
      }
      final team =
          _developmentTeamFor(config.string('name') ?? '', runnerConfigs);
      if (team == null) continue;
      editor.setBuildSetting(config.id, 'DEVELOPMENT_TEAM', team);
    }
    return 'Ensured widget extensions use the '
        '${_appTargetName(project, projectName)} DEVELOPMENT_TEAM.';
  });
}

/// The `ios/` directory holding the `.xcodeproj` of [pbxprojFile].
Directory _projectDirOf(File pbxprojFile) => pbxprojFile.parent.parent;

/// Puts the extension's embed phase into Runner's build phases in an order
/// that does not create a build cycle.
///
/// If "Thin Binary" runs before embedding the extension, Xcode can detect a
/// copy-phase ↔ script-phase cycle. So the embed phase goes before
/// "[CP] Embed Pods Frameworks", and "Thin Binary" stays last.
void _ensureRunnerEmbedsWidgetExtensionInSafeOrder(
  PbxprojEditor editor, {
  required String runnerTargetId,
  required String embedCopyPhaseId,
}) {
  final project = editor.project;
  const title = 'Embed Foundation Extensions';
  final phases = project.object(runnerTargetId)?.fields.array('buildPhases');
  if (phases == null) {
    editor.addArrayEntry(
      runnerTargetId,
      'buildPhases',
      embedCopyPhaseId,
      comment: title,
    );
    return;
  }

  bool isScriptPhaseNamed(PbxArrayItem item, String name) =>
      project
          .objectOfIsa(item.string, 'PBXShellScriptBuildPhase')
          ?.string('name') ==
      name;

  PbxArrayItem? embed;
  PbxArrayItem? thinBinary;
  final remaining = <PbxArrayItem>[];
  for (final item in phases.items) {
    if (embed == null && item.string == embedCopyPhaseId) {
      embed = item;
    } else if (isScriptPhaseNamed(item, 'Thin Binary')) {
      thinBinary ??= item;
    } else {
      remaining.add(item);
    }
  }

  final podsEmbed = remaining.indexWhere(
    (item) => isScriptPhaseNamed(item, '[CP] Embed Pods Frameworks'),
  );
  final literals = [
    for (final item in remaining) editor.itemText(item),
    if (thinBinary != null) editor.itemText(thinBinary),
  ]..insert(
      podsEmbed == -1 ? remaining.length : podsEmbed,
      embed == null ? '$embedCopyPhaseId /* $title */' : editor.itemText(embed),
    );
  editor.setArrayItems(runnerTargetId, 'buildPhases', literals);
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

/// Every `PBXFileReference` and synchronized folder the project holds, as a
/// path relative to `ios/`.
///
/// A file's own `path` is relative to the group that holds it, so the answer is
/// only knowable by walking down from the project's `mainGroup` — groups
/// without a `path` (the `Flutter` group Xcode writes) add nothing, a group
/// rooted at `SOURCE_ROOT` starts over from `ios/`, and anything rooted
/// somewhere only Xcode knows (`SDKROOT`, `BUILT_PRODUCTS_DIR`) is left out.
Map<String, String> _fileReferencePaths(Pbxproj project) {
  final mainGroupId = project.rootProject?.string('mainGroup');
  if (mainGroupId == null) return const {};

  final paths = <String, String>{};
  final visited = <String>{};

  void walk(String groupId, String prefix) {
    if (!visited.add(groupId)) return;
    final group = project.objectOfIsa(groupId, 'PBXGroup');
    if (group == null) return;

    final groupPath = group.string('path');
    final groupPrefix = groupPath == null
        ? prefix
        : _joinRelative(
            group.string('sourceTree') == '<group>' ? prefix : '',
            groupPath,
          );

    for (final childId in group.strings('children')) {
      final child = project.object(childId);
      if (child == null) continue;
      if (child.isa == 'PBXGroup') {
        walk(childId, groupPrefix);
        continue;
      }
      if (child.isa != 'PBXFileReference' &&
          child.isa != 'PBXFileSystemSynchronizedRootGroup') {
        continue;
      }

      final path = child.string('path');
      if (path == null) continue;
      final sourceTree = child.string('sourceTree');
      if (sourceTree == '<group>') {
        paths[childId] = _joinRelative(groupPrefix, path);
      } else if (sourceTree == 'SOURCE_ROOT' || sourceTree == 'SRCROOT') {
        paths[childId] = path;
      }
    }
  }

  walk(mainGroupId, '');
  return paths;
}

String _joinRelative(String prefix, String path) =>
    prefix.isEmpty ? path : '$prefix/$path';
