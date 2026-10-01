import 'dart:io';

import 'package:home_widget_cli/src/generator_error.dart';
import 'package:home_widget_cli/src/util/export_options.dart';
import 'package:home_widget_cli/src/util/fnv_hash.dart';
import 'package:home_widget_cli/src/util/pbxproj/pbxproj_editor.dart';
import 'package:home_widget_cli/src/util/xcode_pbxproj_patcher.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

/// Project shaped like one the generator has already added an extension to:
/// an empty Resources phase, a group for the extension folder, and the
/// `knownRegions` list `flutter create` produces.
String _buildPbxprojWithExtension() {
  final resourcesPhaseId = xcodeObjectId('phase:resources:GreetingHomeWidget');
  final groupId = xcodeObjectId('group:GreetingHomeWidget');
  return '''
// !\$*UTF8*\$!
{
	objects = {

/* Begin PBXBuildFile section */
		11111111111111111111AAAA /* Widget.swift in Sources */ = {isa = PBXBuildFile; fileRef = 22222222222222222222BBBB /* Widget.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		22222222222222222222BBBB /* Widget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Widget.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		$groupId /* GreetingHomeWidget */ = {
			isa = PBXGroup;
			children = (
				22222222222222222222BBBB /* Widget.swift */,
			);
			path = GreetingHomeWidget;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXResourcesBuildPhase section */
		$resourcesPhaseId /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXProject section */
		97C146E61CF9000F007C117D /* Project object */ = {
			isa = PBXProject;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 97C146E51CF9000F007C117D;
		};
/* End PBXProject section */

	};
}
''';
}

/// Project where the widget's extension folder is a synchronized root group,
/// the shape `flutter create` produces under Xcode 16.
///
/// Every file in the folder is already a member of the target, so the catalog
/// must not be added a second time — Xcode would copy it twice and fail.
String _buildPbxprojWithSynchronizedGroup() {
  final fsRootGroupId = xcodeObjectId('fsgroup:GreetingHomeWidget');
  final fsExceptionId = xcodeObjectId('fsex:GreetingHomeWidget');
  final targetId = xcodeObjectId('target:GreetingHomeWidget');
  return '''
// !\$*UTF8*\$!
{
	objects = {

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
		$fsExceptionId /* Exceptions for "GreetingHomeWidget" folder in "GreetingHomeWidget" target */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				Info.plist,
			);
			target = $targetId /* GreetingHomeWidget */;
		};
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		$fsRootGroupId /* GreetingHomeWidget */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = GreetingHomeWidget;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXProject section */
		97C146E61CF9000F007C117D /* Project object */ = {
			isa = PBXProject;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 97C146E51CF9000F007C117D;
		};
/* End PBXProject section */

	};
}
''';
}

/// The mixed case: the project has a synchronized root group section (some
/// *other* folder uses one), but this widget's extension was scaffolded as a
/// classic `PBXGroup`.
///
/// Deciding from the project-global marker skips the wiring here, so the
/// catalog ends up in no target at all.
String _buildPbxprojWithForeignSynchronizedGroup() {
  final base = _buildPbxprojWithExtension();
  return base.replaceFirst(
    '/* Begin PBXGroup section */',
    '''
/* Begin PBXFileSystemSynchronizedRootGroup section */
		CCCCCCCCCCCCCCCCCCCCCCCC /* SomeOtherFolder */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = SomeOtherFolder;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXGroup section */''',
  );
}

/// [_buildPbxprojWithExtension] with the extension folder's group created in
/// Xcode: its own id, named after the widget, at [path] in the main group.
String _buildPbxprojWithForeignWidgetGroup({required String path}) =>
    _buildPbxprojWithExtension()
        .replaceAll(
          xcodeObjectId('group:GreetingHomeWidget'),
          'C0FFEE000000000000000002',
        )
        .replaceFirst(
          '\t\t\tpath = GreetingHomeWidget;\n',
          '\t\t\tname = GreetingHomeWidget;\n\t\t\tpath = $path;\n',
        )
        .replaceFirst('/* Begin PBXGroup section */\n', '''
/* Begin PBXGroup section */
\t\t97C146E51CF9000F007C117D = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tC0FFEE000000000000000002 /* GreetingHomeWidget */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
''');

/// An Xcode 16 shaped project the widget has never been scaffolded into: both
/// synchronized-group sections are there, holding some other folder, and the
/// widget has no group of either kind.
///
/// Nothing has decided which kind this widget gets, so the answer has to be the
/// one the scaffolder would give it.
String _buildPbxprojWithoutWidgetGroup() => '''
// !\$*UTF8*\$!
{
	objects = {

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		CCCCCCCCCCCCCCCCCCCCCCCC /* SomeOtherFolder */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = SomeOtherFolder;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXProject section */
		97C146E61CF9000F007C117D /* Project object */ = {
			isa = PBXProject;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 97C146E51CF9000F007C117D;
		};
/* End PBXProject section */

	};
}
''';

/// Minimal pbxproj snippet with Runner build configurations.
///
/// Mirrors the structure produced by `flutter create`: each configuration
/// contains `INFOPLIST_FILE = Runner/Info.plist;` which is how the patcher
/// identifies Runner configs.
String _buildPbxproj({required String deploymentTarget}) => '''
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	objectVersion = 54;
	objects = {

/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = Runner/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = $deploymentTarget;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Debug;
		};
		97C147071CF9000F007C117D /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = Runner/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = $deploymentTarget;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Release;
		};
		249021D3217E4FDB00AE95B9 /* Profile */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = Runner/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = $deploymentTarget;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Profile;
		};
/* End XCBuildConfiguration section */

	};
}
''';

/// Variant with no IPHONEOS_DEPLOYMENT_TARGET at all.
String _buildPbxprojWithoutDeploymentTarget() => '''
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	objectVersion = 54;
	objects = {

/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */

	};
}
''';

/// A native flavor, i.e. the trio of Runner build configurations Flutter
/// creates for `--flavor <name>`.
final class _RunnerFlavor {
  const _RunnerFlavor({
    required this.name,
    required this.idPrefix,
    required this.bundleId,
    this.entitlements,
    this.entitlementsByConfiguration = const {},
  });

  final String name;
  final String idPrefix;
  final String bundleId;
  final String? entitlements;

  /// What each of the three configurations signs with, keyed by base name; a
  /// base name it does not list falls back to [entitlements].
  final Map<String, String?> entitlementsByConfiguration;

  String? entitlementsFor(String baseName) =>
      entitlementsByConfiguration.containsKey(baseName)
          ? entitlementsByConfiguration[baseName]
          : entitlements;
}

const _dev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: 'Runner/RunnerDev.entitlements',
);
const _prod = _RunnerFlavor(
  name: 'prod',
  idPrefix: 'BB',
  bundleId: 'com.example.app',
);
const _stg = _RunnerFlavor(
  name: 'stg',
  idPrefix: 'CC',
  bundleId: 'com.example.app.stg',
);

/// A flavor whose values Xcode had to quote, because neither a bundle id with
/// a dash nor a path holding a build variable is a bare identifier.
const _quotedDev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: '"com.example.app-dev"',
  entitlements: r'"$(SRCROOT)/Runner/RunnerDev.entitlements"',
);

/// A flavor signing with a file only Xcode can locate.
const _customPathDev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: r'"$(CUSTOM)/RunnerDev.entitlements"',
);

/// A flavor whose Debug configuration signs with a different file than its
/// Release and Profile ones, the split an app that keeps `aps-environment` per
/// configuration ends up with.
const _splitDev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlements: 'Runner/RunnerDevRelease.entitlements',
  entitlementsByConfiguration: {'Debug': 'Runner/RunnerDevDebug.entitlements'},
);

/// A flavor only its Release configuration gives an entitlements file.
const _releaseOnlyDev = _RunnerFlavor(
  name: 'dev',
  idPrefix: 'AA',
  bundleId: 'com.example.app.dev',
  entitlementsByConfiguration: {
    'Release': 'Runner/RunnerDevRelease.entitlements',
  },
);

const _baseConfigNames = ['Debug', 'Release', 'Profile'];

/// The id of the unflavored Runner configuration at [rank] in
/// [_baseConfigNames].
String _baseConfigId(int rank) => '97C1470${rank}1CF9000F007C117D';

String _flavorConfigId(String prefix, int rank) => '$prefix${'0' * 21}$rank';

String _runnerConfigObject({
  required String id,
  required String name,
  required String bundleId,
  String? entitlements,
  bool infoPlist = true,
}) {
  final entitlementsLine = entitlements == null
      ? ''
      : '\t\t\t\tCODE_SIGN_ENTITLEMENTS = $entitlements;\n';
  final infoPlistLine =
      infoPlist ? '\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n' : '';
  return '''
\t\t$id /* $name */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
$entitlementsLine\t\t\t\tDEVELOPMENT_TEAM = TEAM123;
$infoPlistLine\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $bundleId;
\t\t\t};
\t\t\tname = ${_configName(name)};
\t\t};''';
}

/// A configuration name the way Xcode stores it: quoted unless it is a bare
/// identifier, so a flavored one reads `name = "Debug-dev";`.
String _configName(String name) =>
    RegExp(r'^[A-Za-z0-9_$./]+$').hasMatch(name) ? name : '"$name"';

/// A Runner configuration that leaves everything to the project level, the way
/// flutter_flavorizr writes a flavor's target configuration.
String _bareConfigObject({required String id, required String name}) => '''
\t\t$id /* $name */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t};
\t\t\tname = ${_configName(name)};
\t\t};''';

/// A `flutter create` shaped project with Runner configurations for [flavors].
///
/// Carries the sections the extension scaffolder inserts into, a project-level
/// `Debug` that is *not* a Runner config (it must stay untouched), and a Runner
/// `XCConfigurationList` listing exactly the Runner configurations.
///
/// [flavorSettingsInProject] moves each flavor's settings to the project-level
/// configuration of the same name, which is where flutter_flavorizr puts them.
/// [infoPlistInProjectSettings] keeps the `INFOPLIST_FILE` marker out of those,
/// so nothing but the Runner target's configuration list says which
/// configurations are Runner's.
///
/// [synchronizedGroups] adds the two sections Xcode 16 writes, which is what
/// makes the scaffolder give the extension a synchronized root group instead of
/// a classic `PBXGroup`.
String _buildFlavoredPbxproj({
  List<_RunnerFlavor> flavors = const [_dev, _prod],
  bool flavorSettingsInProject = false,
  bool infoPlistInProjectSettings = true,
  bool synchronizedGroups = false,
  String? baseEntitlements,
}) {
  final configObjects = <String>[];
  final configListEntries = <String>[];
  final projectConfigEntries = <String>[];

  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = _baseConfigNames[rank];
    final id = _baseConfigId(rank);
    configObjects.add(
      _runnerConfigObject(
        id: id,
        name: name,
        bundleId: 'com.example.app',
        entitlements: baseEntitlements,
      ),
    );
    configListEntries.add('\t\t\t\t$id /* $name */,');
  }
  for (final flavor in flavors) {
    for (var rank = 0; rank < _baseConfigNames.length; rank++) {
      final name = '${_baseConfigNames[rank]}-${flavor.name}';
      final id = _flavorConfigId(flavor.idPrefix, rank + 1);
      final settings = _runnerConfigObject(
        id: flavorSettingsInProject ? '${flavor.idPrefix}${'F' * 21}$rank' : id,
        name: name,
        bundleId: flavor.bundleId,
        entitlements: flavor.entitlementsFor(_baseConfigNames[rank]),
        infoPlist: !flavorSettingsInProject || infoPlistInProjectSettings,
      );
      if (flavorSettingsInProject) {
        configObjects.add(_bareConfigObject(id: id, name: name));
        configObjects.add(settings);
        projectConfigEntries.add(
          '\t\t\t\t${flavor.idPrefix}${'F' * 21}$rank /* $name */,',
        );
      } else {
        configObjects.add(settings);
      }
      configListEntries.add('\t\t\t\t$id /* $name */,');
    }
  }

  return '''
// !\$*UTF8*\$!
{
\tarchiveVersion = 1;
\tobjectVersion = 54;
\tobjects = {

/* Begin PBXBuildFile section */
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
\t\t97C146EE1CF9000F007C117D /* Runner.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Runner.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */
${synchronizedGroups ? '''

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
/* End PBXFileSystemSynchronizedRootGroup section */''' : ''}

/* Begin PBXFrameworksBuildPhase section */
\t\t97C146EB1CF9000F007C117D /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t97C146E51CF9000F007C117D = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t97C146EF1CF9000F007C117D /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
\t\t97C146EF1CF9000F007C117D /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t97C146ED1CF9000F007C117D /* Runner */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */;
\t\t\tbuildPhases = (
\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,
\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,
\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,
\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Runner;
\t\t\tproductName = Runner;
\t\t\tproductReference = 97C146EE1CF9000F007C117D /* Runner.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t97C146E61CF9000F007C117D /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tbuildConfigurationList = 97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = 97C146E51CF9000F007C117D;
\t\t\tproductRefGroup = 97C146EF1CF9000F007C117D /* Products */;
\t\t\ttargets = (
\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t97C146EC1CF9000F007C117D /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t97C146EA1CF9000F007C117D /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
\t\t97C147031CF9000F007C117D /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t};
\t\t\tname = Debug;
\t\t};
${configObjects.join('\n')}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t97C147031CF9000F007C117D /* Debug */,
${projectConfigEntries.join('\n')}
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
${configListEntries.join('\n')}
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */

\t};
\trootObject = 97C146E61CF9000F007C117D /* Project object */;
}
''';
}

/// Adds [flavor]'s Runner configurations to an existing project, the way a
/// developer adding a flavor to an app that already has a widget would.
String _addRunnerFlavor(String pbxproj, _RunnerFlavor flavor) {
  final objects = <String>[];
  final entries = <String>[];
  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = '${_baseConfigNames[rank]}-${flavor.name}';
    final id = _flavorConfigId(flavor.idPrefix, rank + 1);
    objects.add(
      _runnerConfigObject(
        id: id,
        name: name,
        bundleId: flavor.bundleId,
        entitlements: flavor.entitlementsFor(_baseConfigNames[rank]),
      ),
    );
    entries.add('\t\t\t\t$id /* $name */,');
  }

  var out = pbxproj.replaceFirst(
    '/* End XCBuildConfiguration section */',
    '${objects.join('\n')}\n/* End XCBuildConfiguration section */',
  );

  const listMarker =
      '/* Build configuration list for PBXNativeTarget "Runner" */ = {';
  final listStart = out.indexOf(listMarker);
  final listEnd = out.indexOf('\t\t\t);', listStart);
  return out.replaceRange(listEnd, listEnd, '${entries.join('\n')}\n');
}

/// Adds Runner configurations called [names] to an existing project, the way a
/// project that renamed or added configurations outside Flutter's trio reads.
String _addRunnerConfigurations(String pbxproj, List<String> names) {
  final objects = <String>[];
  final entries = <String>[];
  for (var rank = 0; rank < names.length; rank++) {
    final id = 'EE${'0' * 21}$rank';
    objects.add(
      _runnerConfigObject(
        id: id,
        name: names[rank],
        bundleId: 'com.example.app',
      ),
    );
    entries.add('\t\t\t\t$id /* ${names[rank]} */,');
  }

  final out = pbxproj.replaceFirst(
    '/* End XCBuildConfiguration section */',
    '${objects.join('\n')}\n/* End XCBuildConfiguration section */',
  );

  const listMarker =
      '/* Build configuration list for PBXNativeTarget "Runner" */ = {';
  final listStart = out.indexOf(listMarker);
  final listEnd = out.indexOf('\t\t\t);', listStart);
  return out.replaceRange(listEnd, listEnd, '${entries.join('\n')}\n');
}

/// The extension's build configuration object named [name], as written text.
String _extensionConfig(String pbxproj, String name) {
  final id = xcodeObjectId('cfg:$name:GreetingHomeWidget');
  final match = RegExp(
    '$id /\\* ${RegExp.escape(name)} \\*/ = \\{[\\s\\S]*?\\n\\t\\t\\};',
  ).firstMatch(pbxproj);
  expect(
    match,
    isNotNull,
    reason: 'no extension build configuration named "$name"',
  );
  return match!.group(0)!;
}

/// The `buildConfigurations` list of the extension's `XCConfigurationList`.
String _extensionConfigList(String pbxproj) {
  final id = xcodeObjectId('cfglist:GreetingHomeWidget');
  return RegExp(
    '$id /\\* [^*]*? \\*/ = \\{[\\s\\S]*?'
    'buildConfigurations = \\(([\\s\\S]*?)\\);',
  ).firstMatch(pbxproj)!.group(1)!;
}

/// A project whose flavored Runner configurations hold nothing themselves and
/// point at `Flutter/Debug-dev.xcconfig` instead, the setup Flutter's own
/// flavor documentation describes.
///
/// The file reference sits in the `Flutter` group, which carries a name but no
/// path, so its own `path` is what the project resolves against `ios/`.
String _xcconfigFlavoredPbxproj() {
  const fileRefId = 'DD0000000000000000000001';
  final configObjects = <String>[];
  final configListEntries = <String>[];

  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = _baseConfigNames[rank];
    final id = _baseConfigId(rank);
    configObjects.add(
      _runnerConfigObject(id: id, name: name, bundleId: 'com.example.app'),
    );
    configListEntries.add('\t\t\t\t$id /* $name */,');
  }
  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = '${_baseConfigNames[rank]}-dev';
    final id = _flavorConfigId('AA', rank + 1);
    configObjects.add('''
\t\t$id /* $name */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = $fileRefId /* Debug-dev.xcconfig */;
\t\t\tbuildSettings = {
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t};
\t\t\tname = ${_configName(name)};
\t\t};''');
    configListEntries.add('\t\t\t\t$id /* $name */,');
  }

  return '''
// !\$*UTF8*\$!
{
\tarchiveVersion = 1;
\tobjectVersion = 54;
\tobjects = {

/* Begin PBXBuildFile section */
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
\t\t$fileRefId /* Debug-dev.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Debug-dev.xcconfig"; path = "Flutter/Debug-dev.xcconfig"; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t97C146E51CF9000F007C117D = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t9740EEB11CF90186004384FC /* Flutter */,
\t\t\t\t97C146EF1CF9000F007C117D /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
\t\t9740EEB11CF90186004384FC /* Flutter */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t$fileRefId /* Debug-dev.xcconfig */,
\t\t\t);
\t\t\tname = Flutter;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t97C146EF1CF9000F007C117D /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t97C146ED1CF9000F007C117D /* Runner */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */;
\t\t\tbuildPhases = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Runner;
\t\t\tproductName = Runner;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t97C146E61CF9000F007C117D /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tbuildConfigurationList = 97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */;
\t\t\tmainGroup = 97C146E51CF9000F007C117D;
\t\t\tproductRefGroup = 97C146EF1CF9000F007C117D /* Products */;
\t\t\ttargets = (
\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
${configObjects.join('\n')}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
${configListEntries.join('\n')}
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */

\t};
\trootObject = 97C146E61CF9000F007C117D /* Project object */;
}
''';
}

/// The build configuration object with [id], as written text.
String _configObjectWithId(String pbxproj, String id) => RegExp(
      '$id /\\* [^*\\n]*? \\*/ = \\{[\\s\\S]*?\\n\\t\\t\\};',
    ).firstMatch(pbxproj)!.group(0)!;

/// Rewrites the extension's `SWIFT_ACTIVE_COMPILATION_CONDITIONS`, standing in
/// for a developer who edited the configuration in Xcode.
String _withCompilationConditions(
  String pbxproj,
  String configName,
  String lines,
) {
  final block = _extensionConfig(pbxproj, configName);
  final existing = RegExp(
    r'\n\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = (?:[^;\n]*;|\([\s\S]*?\n\t\t\t\t\);)',
  );
  final patched = existing.hasMatch(block)
      ? block.replaceFirst(existing, '\n$lines')
      : block.replaceFirst(
          '\n\t\t\t\tSWIFT_VERSION = 5.0;',
          '\n$lines\n\t\t\t\tSWIFT_VERSION = 5.0;',
        );
  return pbxproj.replaceFirst(block, patched);
}

/// [pbxproj] with the Runner configuration [id] signing the way a Flutter
/// release setup commonly does: manually, with the team, the identity and the
/// named [profile] set for device builds only.
String _signManually(String pbxproj, String id, {String? profile}) {
  final editor = PbxprojEditor(pbxproj)
    ..setBuildSetting(id, 'CODE_SIGN_STYLE', 'Manual')
    ..setBuildSetting(id, 'DEVELOPMENT_TEAM', '')
    ..setBuildSetting(id, 'DEVELOPMENT_TEAM[sdk=iphoneos*]', 'ABCDE12345')
    ..setBuildSetting(
      id,
      'CODE_SIGN_IDENTITY[sdk=iphoneos*]',
      'iPhone Distribution',
    );
  if (profile != null) {
    editor.setBuildSetting(
      id,
      'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]',
      profile,
    );
  }
  return editor.text;
}

final RegExp _signingKey = RegExp(
  r'^(CODE_SIGNING_ALLOWED|CODE_SIGN_STYLE|CODE_SIGN_IDENTITY|'
  r'DEVELOPMENT_TEAM|PROVISIONING_PROFILE_SPECIFIER)(\[|$)',
);

/// The signing settings the extension's configuration [name] spells out,
/// conditional variants included.
Map<String, String> _extensionSigning(String pbxproj, String name) {
  final config = Pbxproj.parse(pbxproj)
      .object(xcodeObjectId('cfg:$name:GreetingHomeWidget'))!;
  return {
    for (final MapEntry(:key, :value)
        in ownBuildSettings(config, conditional: true).entries)
      if (_signingKey.hasMatch(key)) key: value,
  };
}

/// An export options plist signing with [signingStyle] and listing
/// [profiles], each an entry rendered by [_profileEntry].
String _exportOptions(String profiles, {String signingStyle = 'manual'}) => '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<!-- Used by flutter build ipa -->
\t<key>method</key>
\t<string>app-store-connect</string>
\t<key>provisioningProfiles</key>
\t<dict>
$profiles\t</dict>
\t<key>signingStyle</key>
\t<string>$signingStyle</string>
</dict>
</plist>
''';

String _profileEntry(String bundleId, String profile) => '''
\t\t<key>$bundleId</key>
\t\t<string>$profile</string>
''';

void main() {
  late Directory tempDir;
  late File pbxprojFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pbxproj_test');
    pbxprojFile = File('${tempDir.path}/project.pbxproj');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('ensureMinimumDeploymentTargetInXcodeProject', () {
    test('bumps deployment target when below minimum', () async {
      pbxprojFile.writeAsStringSync(_buildPbxproj(deploymentTarget: '12.0'));

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
      expect(result, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 12.0;')));
    });

    test('leaves deployment target unchanged when already at minimum',
        () async {
      pbxprojFile.writeAsStringSync(_buildPbxproj(deploymentTarget: '14.0'));

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
    });

    test('leaves deployment target unchanged when above minimum', () async {
      pbxprojFile.writeAsStringSync(_buildPbxproj(deploymentTarget: '16.0'));

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0;'));
      expect(result, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;')));
    });

    test('inserts deployment target when absent', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithoutDeploymentTarget());

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
    });

    test('respects custom minimum version', () async {
      pbxprojFile.writeAsStringSync(_buildPbxproj(deploymentTarget: '14.0'));

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        minimumVersion: 17.0,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 17.0;'));
    });

    test('reads \$(inherited) as what the project level sets', () async {
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(_buildFlavoredPbxproj(flavors: const []))
              ..setBuildSetting(
                '97C147031CF9000F007C117D',
                'IPHONEOS_DEPLOYMENT_TARGET',
                '16.0',
              )
              ..setBuildSetting(
                _baseConfigId(0),
                'IPHONEOS_DEPLOYMENT_TARGET',
                r'$(inherited)',
              )
              ..setBuildSetting(
                _baseConfigId(1),
                'IPHONEOS_DEPLOYMENT_TARGET',
                r'${inherited}',
              ))
            .text,
      );

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      // Debug inherits 16.0 from the project level; there is no project-level
      // Release for Release to inherit anything from.
      expect(
        _configObjectWithId(result, _baseConfigId(0)),
        contains(r'IPHONEOS_DEPLOYMENT_TARGET = "$(inherited)";'),
      );
      expect(
        _configObjectWithId(result, _baseConfigId(1)),
        contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'),
      );
    });

    test('does not modify non-Runner configs', () async {
      // A config that does NOT have INFOPLIST_FILE = Runner/Info.plist
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
		AABBCCDD11223344EEFF5566 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				INFOPLIST_FILE = MyExtension/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 12.0;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);

      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      // Should still be 12.0 — non-Runner config should not be touched.
      expect(result, contains('IPHONEOS_DEPLOYMENT_TARGET = 12.0;'));
    });
  });

  group('ensureLocalizableCatalogInXcodeProject', () {
    Future<String> wire({List<String> locales = const ['en', 'de', 'pt-BR']}) {
      return ensureLocalizableCatalogInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
        locales: locales,
      ).then((_) => pbxprojFile.readAsStringSync());
    }

    test('adds the catalog as a resource of the extension', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final result = await wire();

      expect(
        result,
        contains('lastKnownFileType = text.json.xcstrings; '
            'path = Localizable.xcstrings;'),
      );
      expect(
        result,
        contains('/* Localizable.xcstrings in Resources */ = '
            '{isa = PBXBuildFile;'),
      );
      // Listed in the Resources phase, or it never ships.
      final resourcesPhase = RegExp(
        r'isa = PBXResourcesBuildPhase;[\s\S]*?files = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(resourcesPhase, contains('Localizable.xcstrings in Resources'));
      // And visible in the extension's group in Xcode.
      final group = RegExp(
        r'isa = PBXGroup;[\s\S]*?children = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(group, contains('/* Localizable.xcstrings */'));
    });

    test('adds every configured locale to knownRegions', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final result = await wire();

      final regions = RegExp(
        r'knownRegions = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(regions, contains('de,'));
      // A tag that is not a bare identifier has to be quoted.
      expect(regions, contains('"pt-BR",'));
      // Existing entries are kept, and `en` is not duplicated.
      expect(regions, contains('Base,'));
      expect('en'.allMatches(regions).length, 1);
    });

    test('starts a missing knownRegions list the way Xcode does', () async {
      pbxprojFile.writeAsStringSync(
        _buildPbxprojWithExtension().replaceFirst(
          '\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n',
          '\t\t\tdevelopmentRegion = fr;\n',
        ),
      );

      final result = await wire();

      expect(
        result,
        contains(
          '\t\t\tknownRegions = (\n'
          '\t\t\t\tfr,\n'
          '\t\t\t\tBase,\n'
          '\t\t\t\ten,\n'
          '\t\t\t\tde,\n'
          '\t\t\t\t"pt-BR",\n'
          '\t\t\t);\n',
        ),
      );
    });

    test('is idempotent', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final first = await wire();
      final second = await wire();

      expect(second, first);
    });

    test('only patches knownRegions for a synchronized group', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithSynchronizedGroup());

      final result = await wire();

      // The synced folder already builds the catalog; a second, explicit
      // reference would make Xcode copy it twice and fail the build.
      expect(result, isNot(contains('Localizable.xcstrings')));
      final regions = RegExp(
        r'knownRegions = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(regions, contains('de,'));
      expect(regions, contains('"pt-BR",'));
    });

    test('answers the way the scaffolder will when the widget has no group yet',
        () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithoutWidgetGroup());

      final result = await wire();

      // The scaffolder would give this project a synchronized root group, so
      // an explicit reference would be the second copy of the catalog.
      expect(result, isNot(contains('Localizable.xcstrings')));
      final regions = RegExp(
        r'knownRegions = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(regions, contains('de,'));
    });

    test('wires the catalog when only another folder is synchronized',
        () async {
      pbxprojFile
          .writeAsStringSync(_buildPbxprojWithForeignSynchronizedGroup());

      final result = await wire();

      // The widget itself has a classic PBXGroup, so it needs the explicit
      // reference — deciding from the project-global marker would leave the
      // catalog in no target and every constant rendering as its resource key.
      expect(
        result,
        contains('lastKnownFileType = text.json.xcstrings; '
            'path = Localizable.xcstrings;'),
      );
      final resourcesPhase = RegExp(
        r'isa = PBXResourcesBuildPhase;[\s\S]*?files = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(resourcesPhase, contains('Localizable.xcstrings in Resources'));
      final group = RegExp(
        r'isa = PBXGroup;[\s\S]*?children = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(group, contains('/* Localizable.xcstrings */'));
    });
  });

  group('ensureWidgetResourceFilesInXcodeProject', () {
    Future<String> wire({
      List<String> files = const ['hw_font_icons_materialicons.otf'],
      List<String> removed = const [],
    }) {
      return ensureWidgetResourceFilesInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
        resourceFileNames: files,
        removedFileNames: removed,
      ).then((_) => pbxprojFile.readAsStringSync());
    }

    test('adds the font as a resource of the extension', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final result = await wire();

      expect(
        result,
        contains('lastKnownFileType = file; '
            'path = hw_font_icons_materialicons.otf;'),
      );
      // Copied by the target, or the widget finds no font at runtime.
      final resourcesPhase = RegExp(
        r'isa = PBXResourcesBuildPhase;[\s\S]*?files = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(
        resourcesPhase,
        contains('hw_font_icons_materialicons.otf in Resources'),
      );
      // And visible in the extension's group in Xcode.
      final group = RegExp(
        r'isa = PBXGroup;[\s\S]*?children = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(group, contains('/* hw_font_icons_materialicons.otf */'));
    });

    test('wires every file it is handed', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final result = await wire(
        files: const [
          'hw_font_icons_materialicons.otf',
          'hw_font_icons_cupertinoicons_cupertino_icons.ttf',
        ],
      );

      final resourcesPhase = RegExp(
        r'isa = PBXResourcesBuildPhase;[\s\S]*?files = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(resourcesPhase, contains('hw_font_icons_materialicons.otf'));
      expect(
        resourcesPhase,
        contains('hw_font_icons_cupertinoicons_cupertino_icons.ttf'),
      );
    });

    test('is idempotent', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());

      final first = await wire();
      final second = await wire();

      expect(second, first);
    });

    test('restores a build file that lost its target membership', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());
      final wired = await wire();

      // Unchecking target membership in Xcode drops the PBXBuildFile and keeps
      // the file reference.
      pbxprojFile.writeAsStringSync(
        wired
            .split('\n')
            .where(
              (line) => !(line.contains('isa = PBXBuildFile;') &&
                  line.contains('hw_font_icons_materialicons.otf')),
            )
            .join('\n'),
      );

      final result = await wire();

      expect(
        RegExp(
          r'isa = PBXBuildFile; fileRef = \w+ '
          r'/\* hw_font_icons_materialicons\.otf \*/',
        ).allMatches(result),
        hasLength(1),
      );
      final resourcesPhase = RegExp(
        r'isa = PBXResourcesBuildPhase;[\s\S]*?files = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(
        'hw_font_icons_materialicons.otf in Resources'
            .allMatches(resourcesPhase),
        hasLength(1),
      );
    });

    test('a pruned file loses every reference to it', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithExtension());
      await wire();

      final result = await wire(
        files: const [],
        removed: const ['hw_font_icons_materialicons.otf'],
      );

      expect(result, isNot(contains('hw_font_icons_materialicons.otf')));
      // The project it started from is back, byte for byte.
      expect(result, _buildPbxprojWithExtension());
    });

    test('touches nothing for a synchronized group', () async {
      pbxprojFile.writeAsStringSync(_buildPbxprojWithSynchronizedGroup());

      final result = await wire();

      // The synced folder already copies every file in it; an explicit
      // reference on top would have Xcode copy the font twice.
      expect(result, isNot(contains('hw_font_icons_materialicons.otf')));
      expect(result, _buildPbxprojWithSynchronizedGroup());
    });

    test('wires the font into the group the project made for the folder',
        () async {
      pbxprojFile.writeAsStringSync(
        _buildPbxprojWithForeignWidgetGroup(path: 'GreetingHomeWidget'),
      );

      final result = await wire();

      final group = RegExp(
        r'C0FFEE000000000000000002 /\* GreetingHomeWidget \*/ = \{[\s\S]*?'
        r'children = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(group, contains('/* hw_font_icons_materialicons.otf */'));
    });

    test('warns instead of wiring a file into no group', () async {
      // A group Xcode shows under the widget's name can hold another folder.
      final content = _buildPbxprojWithForeignWidgetGroup(path: 'Greeting');
      pbxprojFile.writeAsStringSync(content);
      final mock = useMockLogger();

      final result = await wire();

      expect(result, content);
      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains('hw_font_icons_materialicons.otf could not be wired'),
              contains(
                'Add ios/GreetingHomeWidget/hw_font_icons_materialicons.otf '
                'to the GreetingHomeWidget target in Xcode.',
              ),
            ),
          ),
        ),
      ).called(1);
    });

    test('wires the font when only another folder is synchronized', () async {
      pbxprojFile
          .writeAsStringSync(_buildPbxprojWithForeignSynchronizedGroup());

      final result = await wire();

      expect(
        result,
        contains('lastKnownFileType = file; '
            'path = hw_font_icons_materialicons.otf;'),
      );
    });
  });

  group('flavors', () {
    Future<String> patch({
      Map<String, String> flavorEntitlements = const {},
    }) async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
        flavorEntitlements: flavorEntitlements,
      );
      return pbxprojFile.readAsStringSync();
    }

    test('detectXcodeFlavors lists the flavors in first-seen order', () {
      expect(
        detectXcodeFlavors(Pbxproj.parse(_buildFlavoredPbxproj())),
        ['dev', 'prod'],
      );
    });

    test('detectXcodeFlavors is empty without flavored configurations', () {
      expect(
        detectXcodeFlavors(
          Pbxproj.parse(_buildPbxproj(deploymentTarget: '14.0')),
        ),
        isEmpty,
      );
      expect(
        detectXcodeFlavors(Pbxproj.parse(_buildFlavoredPbxproj(flavors: []))),
        isEmpty,
      );
    });

    test('runnerEntitlementsSettingsForFlavor reads the per-flavor file', () {
      final pbxproj = Pbxproj.parse(_buildFlavoredPbxproj());

      // All three of dev's configurations name the same file.
      expect(
        runnerEntitlementsSettingsForFlavor(pbxproj, 'dev'),
        ['Runner/RunnerDev.entitlements'],
      );
      // prod and the base configurations do not set it at all.
      expect(runnerEntitlementsSettingsForFlavor(pbxproj, 'prod'), isEmpty);
      expect(runnerEntitlementsSettingsForFlavor(pbxproj, null), isEmpty);
      expect(runnerEntitlementsSettingsForFlavor(pbxproj, 'missing'), isEmpty);
    });

    test('lists every file a flavor signs with, in configuration order', () {
      final pbxproj = Pbxproj.parse(
        _buildFlavoredPbxproj(flavors: const [_splitDev]),
      );

      // Release and Profile share one file, so it is listed once.
      expect(runnerEntitlementsSettingsForFlavor(pbxproj, 'dev'), [
        'Runner/RunnerDevDebug.entitlements',
        'Runner/RunnerDevRelease.entitlements',
      ]);
    });

    test('leaves out the configurations that name no file', () {
      final pbxproj = Pbxproj.parse(
        _buildFlavoredPbxproj(flavors: const [_releaseOnlyDev]),
      );

      expect(
        runnerEntitlementsSettingsForFlavor(pbxproj, 'dev'),
        ['Runner/RunnerDevRelease.entitlements'],
      );
    });

    test('points the named Runner configurations at another file', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      await setRunnerEntitlementsInXcodeProject(
        pbxprojFile: pbxprojFile,
        entitlements: {'Release-prod': 'Runner/Runner-prod.entitlements'},
      );

      final configs = runnerEntitlementsByConfiguration(
        Pbxproj.parse(pbxprojFile.readAsStringSync()),
      );
      expect(
        configs.firstWhere((c) => c.name == 'Release-prod'),
        (
          name: 'Release-prod',
          flavor: 'prod',
          entitlements: 'Runner/Runner-prod.entitlements',
        ),
      );
      expect(
        configs.firstWhere((c) => c.name == 'Debug-prod').entitlements,
        isNull,
      );
      expect(
        configs.firstWhere((c) => c.name == 'Debug-dev').entitlements,
        'Runner/RunnerDev.entitlements',
      );
    });

    test('lists the file the unflavored trio shares once', () {
      final pbxproj = Pbxproj.parse(
        _buildFlavoredPbxproj(
          flavors: const [],
          baseEntitlements: 'Runner/Runner.entitlements',
        ),
      );

      expect(
        runnerEntitlementsSettingsForFlavor(pbxproj, null),
        ['Runner/Runner.entitlements'],
      );
    });

    test('mirrors every Runner configuration onto the extension', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch();

      final list = _extensionConfigList(result);
      for (final name in [
        'Debug',
        'Release',
        'Profile',
        'Debug-dev',
        'Release-dev',
        'Profile-dev',
        'Debug-prod',
        'Release-prod',
        'Profile-prod',
      ]) {
        expect(list, contains('/* $name */'));
        expect(
          _extensionConfig(result, name),
          contains('DEVELOPMENT_TEAM = TEAM123;'),
        );
      }
      // The extension still defaults to Release, like Runner does.
      expect(result, contains('defaultConfigurationName = Release;'));
      // Xcode sorts the build settings, DEVELOPMENT_TEAM included.
      expect(
        _extensionConfig(result, 'Debug'),
        contains(
          '\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
          '\t\t\t\tDEVELOPMENT_TEAM = TEAM123;\n'
          '\t\t\t\tGENERATE_INFOPLIST_FILE = YES;',
        ),
      );
    });

    test('keeps the project order of two configurations it cannot rank',
        () async {
      pbxprojFile.writeAsStringSync(
        _addRunnerConfigurations(
          _buildFlavoredPbxproj(flavors: const []),
          const ['Staging', 'QA'],
        ),
      );

      final list = _extensionConfigList(await patch());

      // Neither name says where it belongs among Debug/Release/Profile, so the
      // only order left is the one the project lists them in.
      expect(
        list.indexOf('/* Staging */'),
        lessThan(list.indexOf('/* QA */')),
      );
    });

    test('spells a flavored configuration name the way Xcode does', () async {
      final fixture = _buildFlavoredPbxproj();
      // Xcode quotes the value but never the object comment.
      expect(fixture, contains('name = "Debug-dev";'));
      expect(fixture, contains('/* Debug-dev */'));
      pbxprojFile.writeAsStringSync(fixture);

      final result = await patch();

      expect(detectXcodeFlavors(Pbxproj.parse(result)), ['dev', 'prod']);
      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains('/* Debug-dev */'),
      );
      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains('name = "Debug-dev";'),
      );
      expect(_extensionConfig(result, 'Debug'), contains('name = Debug;'));
      expect(result, isNot(contains('"Debug-dev" */')));
      expect(_extensionConfigList(result), contains('/* Debug-dev */'));
    });

    test('inherits the settings a flavor keeps at project level', () async {
      final fixture = _buildFlavoredPbxproj(flavorSettingsInProject: true);
      pbxprojFile.writeAsStringSync(fixture);

      expect(detectXcodeFlavors(Pbxproj.parse(fixture)), ['dev', 'prod']);
      expect(
        runnerEntitlementsSettingsForFlavor(Pbxproj.parse(fixture), 'dev'),
        ['Runner/RunnerDev.entitlements'],
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = '
          'com.example.app.dev.GreetingHomeWidget;',
        ),
      );
      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains('DEVELOPMENT_TEAM = TEAM123;'),
      );
    });

    test('reuses a configuration the project already names', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());
      final first = await patch();

      // Xcode – or an earlier version of this patcher – gives the configuration
      // an id of its own and may spell its comment differently.
      const foreignId = 'AB0000000000000000000001';
      final foreign = first
          .replaceAll(
            xcodeObjectId('cfg:Debug-dev:GreetingHomeWidget'),
            foreignId,
          )
          .replaceAll(
            '$foreignId /* Debug-dev */',
            '$foreignId /* "Debug-dev" */',
          );
      pbxprojFile.writeAsStringSync(foreign);

      final result = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      // Runner's configuration and the extension's, and no duplicate of either.
      expect('name = "Debug-dev";'.allMatches(result).length, 2);
      expect(result, contains('$foreignId /* Debug-dev */'));
      expect(result, isNot(contains('"Debug-dev" */')));
      expect(
        result,
        contains(
          'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.dev.entitlements;',
        ),
      );
    });

    test('gives each configuration its own Runner bundle id', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.GreetingHomeWidget;',
        ),
      );
      expect(
        _extensionConfig(result, 'Release-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = '
          'com.example.app.dev.GreetingHomeWidget;',
        ),
      );
      expect(
        _extensionConfig(result, 'Profile-prod'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.GreetingHomeWidget;',
        ),
      );
    });

    test('falls back to the bundle id of an unflavored configuration',
        () async {
      // Profile moves behind the flavor's configurations, so the only
      // unflavored bundle id comes after the flavored ones in the file.
      var pbxproj = _buildFlavoredPbxproj(flavors: const [_dev]);
      final profile = _configObjectWithId(pbxproj, _baseConfigId(2));
      pbxproj = pbxproj.replaceFirst('\t\t$profile\n', '').replaceFirst(
            '/* End XCBuildConfiguration section */',
            '\t\t$profile\n/* End XCBuildConfiguration section */',
          );
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(pbxproj)
              ..removeBuildSetting(
                _baseConfigId(0),
                'PRODUCT_BUNDLE_IDENTIFIER',
              )
              ..removeBuildSetting(
                _baseConfigId(1),
                'PRODUCT_BUNDLE_IDENTIFIER',
              )
              ..setBuildSetting(
                _baseConfigId(2),
                'PRODUCT_BUNDLE_IDENTIFIER',
                'com.example.profile',
              )
              ..removeBuildSetting(
                _flavorConfigId('AA', 1),
                'PRODUCT_BUNDLE_IDENTIFIER',
              ))
            .text,
      );

      final result = await patch();

      for (final name in ['Debug', 'Release', 'Debug-dev']) {
        expect(
          _extensionConfig(result, name),
          contains(
            'PRODUCT_BUNDLE_IDENTIFIER = '
            'com.example.profile.GreetingHomeWidget;',
          ),
          reason: name,
        );
      }
      expect(
        _extensionConfig(result, 'Release-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev.GreetingHomeWidget;',
        ),
      );
    });

    test('falls back to a flavored bundle id when no unflavored one is set',
        () async {
      final editor =
          PbxprojEditor(_buildFlavoredPbxproj(flavors: const [_dev]));
      for (var rank = 0; rank < _baseConfigNames.length; rank++) {
        editor.removeBuildSetting(
          _baseConfigId(rank),
          'PRODUCT_BUNDLE_IDENTIFIER',
        );
      }
      pbxprojFile.writeAsStringSync(editor.text);

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev.GreetingHomeWidget;',
        ),
      );
    });

    test('signs with the team of the same configuration or an unflavored one',
        () async {
      final editor = PbxprojEditor(_buildFlavoredPbxproj())
        ..setBuildSetting(_baseConfigId(0), 'DEVELOPMENT_TEAM', 'BASE7EAM')
        ..removeBuildSetting(_baseConfigId(1), 'DEVELOPMENT_TEAM')
        ..setBuildSetting(_baseConfigId(2), 'DEVELOPMENT_TEAM', '')
        ..setBuildSetting(
          _flavorConfigId('AA', 1),
          'DEVELOPMENT_TEAM',
          'DEV7EAM',
        )
        ..removeBuildSetting(_flavorConfigId('AA', 2), 'DEVELOPMENT_TEAM')
        ..setBuildSetting(_flavorConfigId('AA', 3), 'DEVELOPMENT_TEAM', '');
      for (var rank = 1; rank <= _baseConfigNames.length; rank++) {
        editor.removeBuildSetting(
          _flavorConfigId('BB', rank),
          'DEVELOPMENT_TEAM',
        );
      }
      pbxprojFile.writeAsStringSync(editor.text);

      final result = await patch();

      String? team(String name) => RegExp(r'DEVELOPMENT_TEAM = (\w+);')
          .firstMatch(_extensionConfig(result, name))
          ?.group(1);
      // An empty team is signing turned off, which no fallback overrides.
      expect(
        {
          for (final flavor in ['', '-dev', '-prod'])
            for (final base in _baseConfigNames)
              '$base$flavor': team('$base$flavor'),
        },
        {
          'Debug': 'BASE7EAM',
          'Release': 'BASE7EAM',
          'Profile': null,
          'Debug-dev': 'DEV7EAM',
          'Release-dev': 'BASE7EAM',
          'Profile-dev': null,
          'Debug-prod': 'BASE7EAM',
          'Release-prod': 'BASE7EAM',
          'Profile-prod': 'BASE7EAM',
        },
      );
    });

    test('never signs with the team of a flavor for another configuration',
        () async {
      final editor =
          PbxprojEditor(_buildFlavoredPbxproj(flavors: const [_dev]));
      for (var rank = 0; rank < _baseConfigNames.length; rank++) {
        editor.removeBuildSetting(_baseConfigId(rank), 'DEVELOPMENT_TEAM');
      }
      pbxprojFile.writeAsStringSync(editor.text);

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug'),
        isNot(contains('DEVELOPMENT_TEAM')),
      );
      expect(
        _extensionConfig(result, 'Release-dev'),
        contains('DEVELOPMENT_TEAM = TEAM123;'),
      );
    });

    test('sets a compilation condition on flavored configurations only',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) HW_FLAVOR_DEV";',
        ),
      );
      expect(
        _extensionConfig(result, 'Profile-prod'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) HW_FLAVOR_PROD";',
        ),
      );
      expect(
        _extensionConfig(result, 'Release'),
        isNot(contains('SWIFT_ACTIVE_COMPILATION_CONDITIONS')),
      );
    });

    test('uses the entitlements file mapped to each flavor', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.dev.entitlements;',
        ),
      );
      // An unmapped flavor and the base configurations share the default file.
      expect(
        _extensionConfig(result, 'Debug-prod'),
        contains('CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;'),
      );
      expect(
        _extensionConfig(result, 'Debug'),
        contains('CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;'),
      );
    });

    test('is idempotent', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final first = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );
      final second = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      expect(second, first);
    });

    test('adds a configuration for a flavor introduced later', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      final before = await patch();
      expect(
        () => _extensionConfig(before, 'Debug-stg'),
        throwsA(anything),
      );

      pbxprojFile.writeAsStringSync(_addRunnerFlavor(before, _stg));
      final after = await patch();

      expect(
        _extensionConfig(after, 'Release-stg'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = '
          'com.example.app.stg.GreetingHomeWidget;',
        ),
      );
      expect(
        _extensionConfig(after, 'Release-stg'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) HW_FLAVOR_STG";',
        ),
      );
      expect(_extensionConfigList(after), contains('/* Profile-stg */'));
      // The configurations that were already there are untouched.
      expect(
        _extensionConfig(after, 'Debug-dev'),
        _extensionConfig(before, 'Debug-dev'),
      );
    });

    test('updates an existing configuration to the desired values', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());
      final first = await patch();

      final second = await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      expect(
        _extensionConfig(first, 'Debug-dev'),
        contains('CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;'),
      );
      expect(
        _extensionConfig(second, 'Debug-dev'),
        contains(
          'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.dev.entitlements;',
        ),
      );
    });

    test('keeps a per-flavor Runner entitlements path', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);
      final result = pbxprojFile.readAsStringSync();
      final project = Pbxproj.parse(result);

      expect(
        runnerEntitlementsSettingsForFlavor(project, 'dev'),
        ['Runner/RunnerDev.entitlements'],
      );
      // Configurations without one get the default.
      expect(
        runnerEntitlementsSettingsForFlavor(project, null),
        ['Runner/Runner.entitlements'],
      );
      expect(
        runnerEntitlementsSettingsForFlavor(project, 'prod'),
        ['Runner/Runner.entitlements'],
      );
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/RunnerDev.entitlements;'
            .allMatches(result)
            .length,
        3,
      );
    });

    test('sets CODE_SIGN_ENTITLEMENTS on a bare flavored configuration',
        () async {
      // Nothing but the Runner target's configuration list says that these
      // belong to Runner: the target configuration holds only PRODUCT_NAME and
      // the project-level one carries no Info.plist marker either.
      pbxprojFile.writeAsStringSync(
        _buildFlavoredPbxproj(
          flavors: const [_prod],
          flavorSettingsInProject: true,
          infoPlistInProjectSettings: false,
        ),
      );

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);
      final result = pbxprojFile.readAsStringSync();

      for (var rank = 0; rank < _baseConfigNames.length; rank++) {
        expect(
          _configObjectWithId(result, _flavorConfigId('BB', rank + 1)),
          contains(
            'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
          ),
        );
      }
    });

    test('quotes a bundle id the way Xcode does', () async {
      pbxprojFile.writeAsStringSync(
        _buildFlavoredPbxproj(flavors: const [_quotedDev]),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = "com.example.app-dev.GreetingHomeWidget";',
        ),
      );
      // The quotes belong to the value, not to what was read out of the
      // project: a doubly quoted one would not parse.
      expect(result, isNot(contains('""com.example')));
    });

    test('resolves an entitlements path written with build variables', () {
      final pbxproj = Pbxproj.parse(
        _buildFlavoredPbxproj(flavors: const [_quotedDev]),
      );

      final settings = runnerEntitlementsSettingsForFlavor(pbxproj, 'dev');

      expect(settings, [r'$(SRCROOT)/Runner/RunnerDev.entitlements']);
      expect(
        resolveProjectRelativePath(settings.single),
        'Runner/RunnerDev.entitlements',
      );
    });

    test('has no path for an entitlements file only Xcode can locate', () {
      final pbxproj = Pbxproj.parse(
        _buildFlavoredPbxproj(flavors: const [_customPathDev]),
      );

      final settings = runnerEntitlementsSettingsForFlavor(pbxproj, 'dev');

      expect(settings, [r'$(CUSTOM)/RunnerDev.entitlements']);
      expect(resolveProjectRelativePath(settings.single), isNull);
    });
  });

  group('flavor embedding', () {
    Future<String> patch({
      Iterable<String>? flavors,
      String widgetClassName = 'GreetingHomeWidget',
    }) async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: widgetClassName,
        flavors: flavors,
      );
      return pbxprojFile.readAsStringSync();
    }

    String runnerConfig(String pbxproj, String name) {
      final base = _baseConfigNames.indexOf(name);
      if (base != -1) return _configObjectWithId(pbxproj, _baseConfigId(base));
      final [baseName, flavor] = name.split('-');
      final prefix = {'dev': 'AA', 'prod': 'BB', 'stg': 'CC'}[flavor]!;
      return _configObjectWithId(
        pbxproj,
        _flavorConfigId(prefix, _baseConfigNames.indexOf(baseName) + 1),
      );
    }

    const excludedRunner =
        'EXCLUDED_SOURCE_FILE_NAMES = "\$(inherited) GreetingHomeWidget.appex";';
    const excludedSources = 'EXCLUDED_SOURCE_FILE_NAMES = "*";';
    const signingOff = 'CODE_SIGNING_ALLOWED = NO;';

    test('leaves the extension out of every configuration of another flavor',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch(flavors: ['dev']);

      for (final name in [
        'Debug',
        'Release',
        'Profile',
        'Debug-prod',
        'Release-prod',
        'Profile-prod',
      ]) {
        expect(runnerConfig(result, name), contains(excludedRunner));
        expect(_extensionConfig(result, name), contains(excludedSources));
        expect(_extensionConfig(result, name), contains(signingOff));
      }
      for (final name in ['Debug-dev', 'Release-dev', 'Profile-dev']) {
        expect(
          runnerConfig(result, name),
          isNot(contains('EXCLUDED_SOURCE_FILE_NAMES')),
        );
        expect(
          _extensionConfig(result, name),
          isNot(contains('EXCLUDED_SOURCE_FILE_NAMES')),
        );
        expect(
          _extensionConfig(result, name),
          isNot(contains('CODE_SIGNING_ALLOWED')),
        );
      }
      // The configuration stays, so the prod scheme does not fall back to the
      // default one.
      expect(_extensionConfigList(result), contains('/* Release-prod */'));
      expect(
        _extensionConfig(result, 'Release-prod'),
        contains(
          '\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;\n'
          '\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n'
          '\t\t\t\tCODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;',
        ),
      );
    });

    test('excludes nothing without flavors', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch();

      expect(result, isNot(contains('EXCLUDED_SOURCE_FILE_NAMES')));
      expect(result, isNot(contains('CODE_SIGNING_ALLOWED')));
    });

    test('is idempotent', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final first = await patch(flavors: ['dev']);
      final second = await patch(flavors: ['dev']);

      expect(second, first);
    });

    test('follows the flavors as they change', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());
      final withoutFlavors = await patch();

      final devOnly = await patch(flavors: ['dev']);
      expect(runnerConfig(devOnly, 'Release-prod'), contains(excludedRunner));

      final prodOnly = await patch(flavors: ['prod']);
      expect(
        runnerConfig(prodOnly, 'Release-prod'),
        isNot(contains('EXCLUDED_SOURCE_FILE_NAMES')),
      );
      expect(
        _extensionConfig(prodOnly, 'Release-prod'),
        isNot(contains('CODE_SIGNING_ALLOWED')),
      );
      expect(runnerConfig(prodOnly, 'Release-dev'), contains(excludedRunner));
      expect(_extensionConfig(prodOnly, 'Release-dev'), contains(signingOff));

      expect(await patch(), withoutFlavors);
    });

    test('keeps the tokens it does not own', () async {
      final editor = PbxprojEditor(_buildFlavoredPbxproj());
      editor.setBuildSetting(
        _flavorConfigId('BB', 2),
        'EXCLUDED_SOURCE_FILE_NAMES',
        'Legacy.appex',
      );
      pbxprojFile.writeAsStringSync(editor.text);

      final excluded = await patch(flavors: ['dev']);
      expect(
        runnerConfig(excluded, 'Release-prod'),
        contains(
          'EXCLUDED_SOURCE_FILE_NAMES = "Legacy.appex GreetingHomeWidget.appex";',
        ),
      );

      final restored = await patch();
      expect(
        runnerConfig(restored, 'Release-prod'),
        contains('EXCLUDED_SOURCE_FILE_NAMES = Legacy.appex;'),
      );
    });

    test('keeps a list setting a list, quoted elements included', () async {
      final editor = PbxprojEditor(_buildFlavoredPbxproj());
      editor.setBuildSettingList(
        _flavorConfigId('BB', 2),
        'EXCLUDED_SOURCE_FILE_NAMES',
        [r'$(inherited)', 'My Debug.swift'],
      );
      final original = editor.text;
      pbxprojFile.writeAsStringSync(original);
      final unwired = await patch();

      final excluded = await patch(flavors: ['dev']);
      expect(
        runnerConfig(excluded, 'Release-prod'),
        contains(
          'EXCLUDED_SOURCE_FILE_NAMES = (\n'
          '\t\t\t\t\t"\$(inherited)",\n'
          '\t\t\t\t\t"My Debug.swift",\n'
          '\t\t\t\t\tGreetingHomeWidget.appex,\n'
          '\t\t\t\t);',
        ),
      );

      expect(await patch(), unwired);
      expect(
        runnerConfig(unwired, 'Release-prod'),
        contains(
          'EXCLUDED_SOURCE_FILE_NAMES = (\n'
          '\t\t\t\t\t"\$(inherited)",\n'
          '\t\t\t\t\t"My Debug.swift",\n'
          '\t\t\t\t);',
        ),
      );
    });

    test('keeps a quoted element of a string setting whole', () async {
      final editor = PbxprojEditor(_buildFlavoredPbxproj());
      editor.setBuildSetting(
        _flavorConfigId('BB', 2),
        'EXCLUDED_SOURCE_FILE_NAMES',
        '"My Debug.swift" Legacy.appex',
      );
      final original = editor.text;
      pbxprojFile.writeAsStringSync(original);
      final unwired = await patch();

      final excluded = await patch(flavors: ['dev']);
      expect(
        runnerConfig(excluded, 'Release-prod'),
        contains(
          r'EXCLUDED_SOURCE_FILE_NAMES = "\"My Debug.swift\" Legacy.appex '
          r'GreetingHomeWidget.appex";',
        ),
      );

      expect(await patch(), unwired);
      expect(
        runnerConfig(unwired, 'Release-prod'),
        contains(
          r'EXCLUDED_SOURCE_FILE_NAMES = "\"My Debug.swift\" Legacy.appex";',
        ),
      );
    });

    test('keeps a backslash-escaped space in a string setting element',
        () async {
      final editor = PbxprojEditor(_buildFlavoredPbxproj());
      editor.setBuildSetting(
        _flavorConfigId('BB', 2),
        'EXCLUDED_SOURCE_FILE_NAMES',
        r'My\ Debug.swift Legacy.appex',
      );
      pbxprojFile.writeAsStringSync(editor.text);

      final excluded = await patch(flavors: ['dev']);
      expect(
        runnerConfig(excluded, 'Release-prod'),
        contains(
          r'EXCLUDED_SOURCE_FILE_NAMES = "\"My Debug.swift\" Legacy.appex '
          r'GreetingHomeWidget.appex";',
        ),
      );

      final restored = await patch();
      expect(
        runnerConfig(restored, 'Release-prod'),
        contains(
          r'EXCLUDED_SOURCE_FILE_NAMES = "\"My Debug.swift\" Legacy.appex";',
        ),
      );
    });

    test('lists every widget left out of a configuration', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      await patch(flavors: ['dev']);
      final both = await patch(
        flavors: ['dev'],
        widgetClassName: 'WeatherHomeWidget',
      );
      expect(
        runnerConfig(both, 'Release-prod'),
        contains(
          'EXCLUDED_SOURCE_FILE_NAMES = '
          '"\$(inherited) GreetingHomeWidget.appex WeatherHomeWidget.appex";',
        ),
      );

      final one = await patch(flavors: ['dev', 'prod']);
      expect(
        runnerConfig(one, 'Release-prod'),
        contains(
          'EXCLUDED_SOURCE_FILE_NAMES = "\$(inherited) WeatherHomeWidget.appex";',
        ),
      );
      expect(
        runnerConfig(one, 'Release'),
        contains('GreetingHomeWidget.appex'),
      );
    });

    test(
        'keeps signing off that a developer chose on an embedded configuration',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());
      final created = await patch();
      final block = _extensionConfig(created, 'Release-dev');
      pbxprojFile.writeAsStringSync(
        created.replaceFirst(
          block,
          block.replaceFirst(
            '\t\t\t\tCODE_SIGN_ENTITLEMENTS',
            '\t\t\t\t$signingOff\n\t\t\t\tCODE_SIGN_ENTITLEMENTS',
          ),
        ),
      );

      final result = await patch(flavors: ['dev']);

      expect(_extensionConfig(result, 'Release-dev'), contains(signingOff));
    });

    test('adds a flavor introduced later as left out', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      final before = await patch(flavors: ['dev']);

      pbxprojFile.writeAsStringSync(_addRunnerFlavor(before, _stg));
      final after = await patch(flavors: ['dev']);

      expect(runnerConfig(after, 'Profile-stg'), contains(excludedRunner));
      expect(_extensionConfig(after, 'Profile-stg'), contains(excludedSources));
      expect(_extensionConfig(after, 'Profile-stg'), contains(signingOff));
    });

    test('warns when it turns off signing a foreign target turned on',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      final created = await patch();
      final block = _extensionConfig(created, 'Release');
      final foreign = created
          .replaceAll(
            xcodeObjectId('target:GreetingHomeWidget'),
            'AB00000000000000000000FF',
          )
          .replaceFirst(
            block,
            block.replaceFirst(
              '\t\t\t\tCODE_SIGN_ENTITLEMENTS',
              '\t\t\t\tCODE_SIGNING_ALLOWED = YES;\n'
                  '\t\t\t\tCODE_SIGN_ENTITLEMENTS',
            ),
          );
      pbxprojFile.writeAsStringSync(foreign);
      final mock = useMockLogger();

      final result = await patch(flavors: ['dev']);

      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains('Reset CODE_SIGNING_ALLOWED on the "Release"'),
              contains('home_widget did not create this target'),
            ),
          ),
        ),
      ).called(1);
      expect(_extensionConfig(result, 'Release'), contains(signingOff));
      expect(runnerConfig(result, 'Release'), contains(excludedRunner));
    });

    test(
        'falls back to the conventional product name for a foreign target '
        'with no productReference', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      final created = await patch(flavors: ['dev']);
      final foreign = created
          .replaceAll(
            xcodeObjectId('target:GreetingHomeWidget'),
            'AB00000000000000000000FF',
          )
          .replaceFirst(
            RegExp(
              r'\t\t\tproductReference = [^\n]*GreetingHomeWidget\.appex'
              r'[^\n]*\n',
            ),
            '',
          )
          .replaceFirst(
            'path = GreetingHomeWidget.appex;',
            'path = RenamedWidget.appex;',
          );
      pbxprojFile.writeAsStringSync(foreign);

      final result = await patch(flavors: ['prod']);

      expect(runnerConfig(result, 'Debug'), contains(excludedRunner));
      expect(runnerConfig(result, 'Debug'), isNot(contains('RenamedWidget')));
    });
  });

  group('signing', () {
    Future<String> patch({
      Iterable<String>? flavors,
      String? provisioningProfile,
      Map<String, String> flavorProvisioningProfiles = const {},
    }) async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
        flavors: flavors,
        provisioningProfile: provisioningProfile,
        flavorProvisioningProfiles: flavorProvisioningProfiles,
      );
      return pbxprojFile.readAsStringSync();
    }

    final release = _baseConfigId(1);
    final profile = _baseConfigId(2);
    final releaseDev = _flavorConfigId('AA', 2);
    final releaseProd = _flavorConfigId('BB', 2);

    const manualRelease = {
      'CODE_SIGN_IDENTITY[sdk=iphoneos*]': 'iPhone Distribution',
      'CODE_SIGN_STYLE': 'Manual',
      'DEVELOPMENT_TEAM': '',
      'DEVELOPMENT_TEAM[sdk=iphoneos*]': 'ABCDE12345',
    };

    test('signs automatically where the app does', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());

      final result = await patch();

      for (final flavor in ['', '-dev', '-prod']) {
        for (final base in _baseConfigNames) {
          expect(
            _extensionSigning(result, '$base$flavor'),
            {'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': 'TEAM123'},
            reason: '$base$flavor',
          );
        }
      }
    });

    test('signs manually with a profile named after the app one', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), release, profile: 'App Prod'),
      );
      final mock = useMockLogger();

      final result = await patch();

      expect(_extensionSigning(result, 'Release'), {
        ...manualRelease,
        'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]':
            'App Prod GreetingHomeWidget',
      });
      expect(
        _extensionSigning(result, 'Debug'),
        {'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': 'TEAM123'},
      );
      // Xcode sorts the build settings, conditional variants included.
      expect(
        _extensionConfig(result, 'Release'),
        contains(
          '\t\t\t\tCODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;\n'
          '\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Distribution";\n'
          '\t\t\t\tCODE_SIGN_STYLE = Manual;\n'
          '\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
          '\t\t\t\tDEVELOPMENT_TEAM = "";\n'
          '\t\t\t\t"DEVELOPMENT_TEAM[sdk=iphoneos*]" = ABCDE12345;\n',
        ),
      );
      expect(
        _extensionConfig(result, 'Release'),
        contains(
          '\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";\n'
          '\t\t\t\t"PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]" = '
          '"App Prod GreetingHomeWidget";\n'
          '\t\t\t\tSKIP_INSTALL = YES;\n',
        ),
      );
      verify(
        () => mock.info(
          any(
            that: contains(
              '"App Prod GreetingHomeWidget" '
              '(com.example.app.GreetingHomeWidget)',
            ),
          ),
        ),
      ).called(1);
      verifyNever(() => mock.warn(any()));
    });

    test('copies a conditional team the app sets without a plain one',
        () async {
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(_buildFlavoredPbxproj())
              ..removeBuildSetting(release, 'DEVELOPMENT_TEAM')
              ..setBuildSetting(
                release,
                'DEVELOPMENT_TEAM[sdk=iphoneos*]',
                'ABCDE12345',
              ))
            .text,
      );

      final result = await patch();

      expect(_extensionSigning(result, 'Release'), {
        'CODE_SIGN_STYLE': 'Automatic',
        'DEVELOPMENT_TEAM[sdk=iphoneos*]': 'ABCDE12345',
      });
    });

    test('writes no team where every team setting of the app is empty',
        () async {
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(_buildFlavoredPbxproj())
              ..setBuildSetting(release, 'DEVELOPMENT_TEAM', '')
              ..setBuildSetting(
                release,
                'DEVELOPMENT_TEAM[sdk=iphoneos*]',
                '',
              ))
            .text,
      );

      final result = await patch();

      expect(
        _extensionSigning(result, 'Release'),
        {'CODE_SIGN_STYLE': 'Automatic'},
      );
    });

    test('falls back to every team setting of an unflavored configuration',
        () async {
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(_buildFlavoredPbxproj())
              ..removeBuildSetting(_baseConfigId(0), 'DEVELOPMENT_TEAM')
              ..setBuildSetting(
                _baseConfigId(0),
                'DEVELOPMENT_TEAM[sdk=iphoneos*]',
                'BASE7EAM',
              )
              ..removeBuildSetting(releaseDev, 'DEVELOPMENT_TEAM'))
            .text,
      );

      final result = await patch();

      expect(_extensionSigning(result, 'Release-dev'), {
        'CODE_SIGN_STYLE': 'Automatic',
        'DEVELOPMENT_TEAM[sdk=iphoneos*]': 'BASE7EAM',
      });
    });

    test('signs a configuration the extension is not in automatically',
        () async {
      pbxprojFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          releaseProd,
          profile: 'App Prod',
        ),
      );
      final mock = useMockLogger();

      final result = await patch(flavors: ['dev']);

      expect(_extensionSigning(result, 'Release-prod'), {
        'CODE_SIGNING_ALLOWED': 'NO',
        'CODE_SIGN_STYLE': 'Automatic',
        'DEVELOPMENT_TEAM': '',
        'DEVELOPMENT_TEAM[sdk=iphoneos*]': 'ABCDE12345',
      });
      verifyNever(() => mock.warn(any()));
      verifyNever(() => mock.info(any(that: contains('provisioning'))));
    });

    test('mirrors a signing style set for device builds only', () async {
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(_buildFlavoredPbxproj())
              ..setBuildSetting(release, 'CODE_SIGN_STYLE', 'Automatic')
              ..setBuildSetting(
                release,
                'CODE_SIGN_STYLE[sdk=iphoneos*]',
                'Manual',
              )
              ..setBuildSetting(
                release,
                'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]',
                'App Prod',
              ))
            .text,
      );

      final result = await patch();

      expect(_extensionSigning(result, 'Release'), {
        'CODE_SIGN_STYLE': 'Automatic',
        'CODE_SIGN_STYLE[sdk=iphoneos*]': 'Manual',
        'DEVELOPMENT_TEAM': 'TEAM123',
        'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]':
            'App Prod GreetingHomeWidget',
      });
    });

    test('signs with the profile provisioningProfile names', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), release, profile: 'App Prod'),
      );

      final result = await patch(provisioningProfile: 'Widget Prod');

      expect(_extensionSigning(result, 'Release'), {
        ...manualRelease,
        'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]': 'Widget Prod',
      });
    });

    test('lets a flavor name a profile of its own', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(
          _signManually(
            _buildFlavoredPbxproj(),
            releaseDev,
            profile: 'App Dev',
          ),
          releaseProd,
          profile: 'App Prod',
        ),
      );

      final result = await patch(
        provisioningProfile: 'Widget Base',
        flavorProvisioningProfiles: {'dev': 'Widget Dev'},
      );

      expect(
        _extensionSigning(
          result,
          'Release-dev',
        )['PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]'],
        'Widget Dev',
      );
      expect(
        _extensionSigning(
          result,
          'Release-prod',
        )['PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]'],
        'Widget Base',
      );
    });

    test(
        'signs a configuration it creates automatically and warns without a '
        'profile to name one after', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(
          _signManually(_buildFlavoredPbxproj(), release),
          profile,
        ),
      );
      final mock = useMockLogger();

      final result = await patch();

      for (final name in ['Release', 'Profile']) {
        expect(
          _extensionSigning(result, name),
          {
            'CODE_SIGN_STYLE': 'Automatic',
            'DEVELOPMENT_TEAM': '',
            'DEVELOPMENT_TEAM[sdk=iphoneos*]': 'ABCDE12345',
          },
          reason: name,
        );
      }
      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains('Runner signs manually in Release, Profile'),
              contains('provisioningProfile'),
            ),
          ),
        ),
      ).called(1);
      expect(await patch(), result);
    });

    test('leaves signing set by hand alone without a profile to name',
        () async {
      const uuid = '01234567-89AB-CDEF-0123-456789ABCDEF';
      final extensionRelease = xcodeObjectId('cfg:Release:GreetingHomeWidget');
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(_signManually(_buildFlavoredPbxproj(), release))
              ..setBuildSetting(
                release,
                'PROVISIONING_PROFILE[sdk=iphoneos*]',
                'FEDCBA98-7654-3210-FEDC-BA9876543210',
              ))
            .text,
      );
      final created = await patch();
      final byHand = (PbxprojEditor(created)
            ..setBuildSetting(extensionRelease, 'CODE_SIGN_STYLE', 'Manual')
            ..setBuildSetting(
              extensionRelease,
              'CODE_SIGN_IDENTITY[sdk=iphoneos*]',
              'iPhone Distribution',
            )
            ..setBuildSetting(
              extensionRelease,
              'PROVISIONING_PROFILE[sdk=iphoneos*]',
              uuid,
            ))
          .text;
      pbxprojFile.writeAsStringSync(byHand);
      final mock = useMockLogger();

      final result = await patch();

      expect(result, byHand);
      expect(_extensionSigning(result, 'Release'), manualRelease);
      expect(
        _extensionConfig(result, 'Release'),
        contains('"PROVISIONING_PROFILE[sdk=iphoneos*]" = "$uuid";'),
      );
      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains('Runner signs manually in Release'),
              contains('left as they are'),
            ),
          ),
        ),
      ).called(1);
      verifyNever(() => mock.info(any(that: contains('CODE_SIGN_STYLE'))));
      expect(await patch(), byHand);
    });

    test('still syncs the team without a profile to name', () async {
      final extensionRelease = xcodeObjectId('cfg:Release:GreetingHomeWidget');
      pbxprojFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), release),
      );
      final created = await patch();
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(created)
              ..setBuildSetting(extensionRelease, 'CODE_SIGN_STYLE', 'Manual')
              ..setBuildSetting(
                extensionRelease,
                'PROVISIONING_PROFILE_SPECIFIER',
                'Widget By Hand',
              )
              ..setBuildSetting(extensionRelease, 'DEVELOPMENT_TEAM', 'OTHER'))
            .text,
      );

      final result = await patch();

      expect(_extensionSigning(result, 'Release'), {
        'CODE_SIGN_STYLE': 'Manual',
        'DEVELOPMENT_TEAM': '',
        'DEVELOPMENT_TEAM[sdk=iphoneos*]': 'ABCDE12345',
        'PROVISIONING_PROFILE_SPECIFIER': 'Widget By Hand',
      });
    });

    test('names the profile after the default template', () async {
      final manual =
          _signManually(_buildFlavoredPbxproj(), release, profile: 'App Prod');
      pbxprojFile.writeAsStringSync(manual);
      final byDefault = await patch();
      pbxprojFile.writeAsStringSync(manual);

      final result = await patch(
        provisioningProfile: defaultProvisioningProfileTemplate,
      );

      expect(
        defaultProvisioningProfileTemplate,
        '{appProfile} {extensionName}',
      );
      expect(result, byDefault);
      expect(
        _extensionSigning(
          result,
          'Release',
        )['PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]'],
        'App Prod GreetingHomeWidget',
      );
    });

    test('fills a template in per configuration', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(
          _signManually(
            _buildFlavoredPbxproj(),
            _baseConfigId(0),
            profile: 'App Dev',
          ),
          release,
          profile: 'App Prod',
        ),
      );
      final mock = useMockLogger();

      final result = await patch(
        provisioningProfile: '{appProfile}.{extensionName}',
      );

      expect(_extensionSigning(result, 'Debug'), {
        ...manualRelease,
        'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]':
            'App Dev.GreetingHomeWidget',
      });
      expect(_extensionSigning(result, 'Release'), {
        ...manualRelease,
        'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]':
            'App Prod.GreetingHomeWidget',
      });
      verifyNever(() => mock.warn(any()));
    });

    test('fills in a template naming the extension only', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(
          _signManually(_buildFlavoredPbxproj(), release, profile: 'App Prod'),
          profile,
        ),
      );
      final mock = useMockLogger();

      final result = await patch(provisioningProfile: 'Team {extensionName}');

      expect(_extensionSigning(result, 'Release'), {
        ...manualRelease,
        'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]':
            'Team GreetingHomeWidget',
      });
      expect(_extensionSigning(result, 'Profile'), {
        ...manualRelease,
        'PROVISIONING_PROFILE_SPECIFIER': 'Team GreetingHomeWidget',
      });
      verifyNever(() => mock.warn(any()));
    });

    test('lets a flavor set a template of its own', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(
          _signManually(
            _buildFlavoredPbxproj(),
            releaseDev,
            profile: 'App Dev',
          ),
          releaseProd,
          profile: 'App Prod',
        ),
      );

      final result = await patch(
        provisioningProfile: '{appProfile} {extensionName}',
        flavorProvisioningProfiles: {'dev': '{extensionName} for {appProfile}'},
      );

      expect(
        _extensionSigning(
          result,
          'Release-dev',
        )['PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]'],
        'GreetingHomeWidget for App Dev',
      );
      expect(
        _extensionSigning(
          result,
          'Release-prod',
        )['PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]'],
        'App Prod GreetingHomeWidget',
      );
    });

    test('has no profile for an app profile template the app names none for',
        () async {
      pbxprojFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), release),
      );
      final mock = useMockLogger();

      final result = await patch(
        provisioningProfile: '{appProfile}.{extensionName}',
      );

      expect(_extensionSigning(result, 'Release'), {
        'CODE_SIGN_STYLE': 'Automatic',
        'DEVELOPMENT_TEAM': '',
        'DEVELOPMENT_TEAM[sdk=iphoneos*]': 'ABCDE12345',
      });
      verify(
        () => mock.warn(
          any(that: contains('Runner signs manually in Release,')),
        ),
      ).called(1);
    });

    test('warns once about a profile shared by different bundle ids', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(
          _signManually(
            _signManually(
              _buildFlavoredPbxproj(),
              _flavorConfigId('AA', 1),
              profile: 'App Dev',
            ),
            releaseDev,
            profile: 'App Dev',
          ),
          releaseProd,
          profile: 'App Prod',
        ),
      );
      final mock = useMockLogger();

      await patch(provisioningProfile: 'Widget Shared');

      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains('"Widget Shared"'),
              contains(
                'com.example.app.dev.GreetingHomeWidget, '
                'com.example.app.GreetingHomeWidget',
              ),
              contains('{appProfile}'),
              contains('HomeWidgetIOSFlavor'),
            ),
          ),
        ),
      ).called(1);
    });

    test('does not warn about a profile shared under one bundle id', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(
          _signManually(_buildFlavoredPbxproj(), release, profile: 'App Prod'),
          releaseProd,
          profile: 'App Prod',
        ),
      );
      final mock = useMockLogger();

      final result = await patch(provisioningProfile: 'Widget Shared');

      for (final name in ['Release', 'Release-prod']) {
        expect(
          _extensionSigning(
            result,
            name,
          )['PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]'],
          'Widget Shared',
          reason: name,
        );
      }
      verifyNever(() => mock.warn(any()));
    });

    test('names the profile under the key of the manual signing style',
        () async {
      pbxprojFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), release),
      );
      final mock = useMockLogger();

      final result = await patch(provisioningProfile: 'Widget Prod');

      expect(_extensionSigning(result, 'Release'), {
        ...manualRelease,
        'PROVISIONING_PROFILE_SPECIFIER': 'Widget Prod',
      });
      verifyNever(() => mock.warn(any()));
    });

    test('keeps no empty profile of the app next to the one it names',
        () async {
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(_signManually(_buildFlavoredPbxproj(), release))
              ..setBuildSetting(release, 'PROVISIONING_PROFILE_SPECIFIER', '')
              ..setBuildSetting(
                release,
                'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]',
                '',
              ))
            .text,
      );
      final mock = useMockLogger();

      final result = await patch(provisioningProfile: 'Widget Prod');

      expect(_extensionSigning(result, 'Release'), {
        ...manualRelease,
        'PROVISIONING_PROFILE_SPECIFIER': 'Widget Prod',
      });
      verifyNever(() => mock.warn(any()));
      expect(await patch(provisioningProfile: 'Widget Prod'), result);
    });

    group('settings the project level conditions on an SDK', () {
      const projectDebug = '97C147031CF9000F007C117D';
      final debug = _baseConfigId(0);

      String manualDebug(String pbxproj) => (PbxprojEditor(pbxproj)
            ..setBuildSetting(debug, 'CODE_SIGN_STYLE', 'Manual')
            ..setBuildSetting(debug, 'CODE_SIGN_IDENTITY', 'Apple Distribution')
            ..setBuildSetting(
              debug,
              'PROVISIONING_PROFILE_SPECIFIER',
              'App Dev',
            ))
          .text;

      test('yield to an identity the app target sets unconditionally',
          () async {
        pbxprojFile.writeAsStringSync(
          manualDebug(
            (PbxprojEditor(_buildFlavoredPbxproj())
                  ..setBuildSetting(
                    projectDebug,
                    'CODE_SIGN_IDENTITY[sdk=iphoneos*]',
                    'iPhone Developer',
                  ))
                .text,
          ),
        );

        final result = await patch();

        expect(_extensionSigning(result, 'Debug'), {
          'CODE_SIGN_IDENTITY': 'Apple Distribution',
          'CODE_SIGN_STYLE': 'Manual',
          'DEVELOPMENT_TEAM': 'TEAM123',
          'PROVISIONING_PROFILE_SPECIFIER': 'App Dev GreetingHomeWidget',
        });
      });

      test('yield to a team the app target sets unconditionally', () async {
        pbxprojFile.writeAsStringSync(
          (PbxprojEditor(_buildFlavoredPbxproj())
                ..setBuildSetting(
                  projectDebug,
                  'DEVELOPMENT_TEAM[sdk=iphoneos*]',
                  'ABCDE12345',
                ))
              .text,
        );

        final result = await patch();

        expect(
          _extensionSigning(result, 'Debug'),
          {'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': 'TEAM123'},
        );
      });

      test('stay where the app target conditions the setting as well',
          () async {
        pbxprojFile.writeAsStringSync(
          (PbxprojEditor(
            manualDebug(
              (PbxprojEditor(_buildFlavoredPbxproj())
                    ..setBuildSetting(
                      projectDebug,
                      'CODE_SIGN_IDENTITY[sdk=iphoneos*]',
                      'iPhone Developer',
                    ))
                  .text,
            ),
          )..setBuildSetting(
                  debug,
                  'CODE_SIGN_IDENTITY[sdk=iphoneos*]',
                  'iPhone Distribution',
                ))
              .text,
        );

        final result = await patch();

        final signing = _extensionSigning(result, 'Debug');
        expect(signing['CODE_SIGN_IDENTITY'], 'Apple Distribution');
        expect(
          signing['CODE_SIGN_IDENTITY[sdk=iphoneos*]'],
          'iPhone Distribution',
        );
      });

      test('stand in for what a conditional setting of the app inherits',
          () async {
        pbxprojFile.writeAsStringSync(
          (PbxprojEditor(_buildFlavoredPbxproj())
                ..setBuildSetting(
                  projectDebug,
                  'PROVISIONING_PROFILE_SPECIFIER',
                  'App Dev',
                )
                ..setBuildSetting(debug, 'CODE_SIGN_STYLE', 'Manual')
                ..setBuildSetting(
                  debug,
                  'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]',
                  r'$(inherited) Device',
                ))
              .text,
        );

        final result = await patch();

        expect(
          _extensionSigning(
            result,
            'Debug',
          )['PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]'],
          'App Dev Device GreetingHomeWidget',
        );
      });
    });

    test('changes nothing on a second run', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), release, profile: 'App Prod'),
      );
      final first = await patch();
      final mock = useMockLogger();

      expect(await patch(), first);
      verifyNever(() => mock.info(any()));
    });

    test('drops the identity and profile once the app signs automatically',
        () async {
      pbxprojFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), release, profile: 'App Prod'),
      );
      final signed = await patch();
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(signed)
              ..setBuildSetting(release, 'CODE_SIGN_STYLE', 'Automatic')
              ..setBuildSetting(release, 'DEVELOPMENT_TEAM', 'TEAM123')
              ..removeBuildSetting(release, 'DEVELOPMENT_TEAM[sdk=iphoneos*]')
              ..removeBuildSetting(
                release,
                'CODE_SIGN_IDENTITY[sdk=iphoneos*]',
              )
              ..removeBuildSetting(
                release,
                'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]',
              ))
            .text,
      );
      final mock = useMockLogger();

      final result = await patch();

      expect(
        _extensionSigning(result, 'Release'),
        {'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': 'TEAM123'},
      );
      verify(
        () => mock.info(
          any(
            that: allOf(
              contains('DEVELOPMENT_TEAM[sdk=iphoneos*]'),
              contains('CODE_SIGN_IDENTITY[sdk=iphoneos*]'),
              contains('PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]'),
              contains('CODE_SIGN_STYLE'),
              contains('on the "Release" configuration'),
            ),
          ),
        ),
      ).called(1);
    });

    test('resets a team set by hand that the app does not have', () async {
      pbxprojFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), release, profile: 'App Prod'),
      );
      final signed = await patch();
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(signed)
              ..setBuildSetting(
                xcodeObjectId('cfg:Release:GreetingHomeWidget'),
                'DEVELOPMENT_TEAM',
                'ABCDE12345',
              ))
            .text,
      );

      expect(await patch(), signed);
    });

    test('warns when it resets the signing of a target it did not create',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      final created = await patch();
      final foreign = _signManually(
        created.replaceAll(
          xcodeObjectId('target:GreetingHomeWidget'),
          'AB00000000000000000000FF',
        ),
        release,
        profile: 'App Prod',
      );
      pbxprojFile.writeAsStringSync(foreign);
      final mock = useMockLogger();

      await patch();

      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains('CODE_SIGN_STYLE'),
              contains('on the "Release" configuration'),
              contains('home_widget did not create this target'),
            ),
          ),
        ),
      ).called(1);
    });
  });

  group('export options', () {
    late Directory iosDir;
    late File projectFile;

    setUp(() {
      iosDir = Directory('${tempDir.path}/ios');
      projectFile = File('${iosDir.path}/Runner.xcodeproj/project.pbxproj')
        ..parent.createSync(recursive: true);
    });

    /// The patcher followed by the export options sync, as `generate` runs
    /// them; returns what the patcher asks the sync for.
    Future<Map<String, String?>> patch({Iterable<String>? flavors}) async {
      final profiles = await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: projectFile,
        widgetClassName: 'GreetingHomeWidget',
        flavors: flavors,
      );
      await syncExportOptionsProvisioningProfiles(
        iosDir: iosDir,
        widgetClassName: 'GreetingHomeWidget',
        profiles: profiles,
      );
      return profiles;
    }

    File exportOptions(String name, String content) =>
        File('${iosDir.path}/$name')..writeAsStringSync(content);

    test('leaves the plists to the caller', () async {
      projectFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          _flavorConfigId('AA', 2),
          profile: 'App Dev',
        ),
      );
      final content = _exportOptions(
        _profileEntry('com.example.app.dev', 'App Dev'),
      );
      final plist = exportOptions('ExportOptions.plist', content);

      final profiles = await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: projectFile,
        widgetClassName: 'GreetingHomeWidget',
      );

      expect(profiles, {'com.example.app.dev': 'App Dev GreetingHomeWidget'});
      expect(plist.readAsStringSync(), content);
    });

    test('keeps a hand-added entry of a bundle id no configuration has',
        () async {
      projectFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          _flavorConfigId('AA', 2),
          profile: 'App Dev',
        ),
      );
      final content = _exportOptions(
        _profileEntry('com.example.elsewhere', 'Elsewhere') +
            _profileEntry(
              'com.example.elsewhere.GreetingHomeWidget',
              'Elsewhere Widget',
            ),
      );
      final plist = exportOptions('ExportOptions.plist', content);

      final profiles = await patch();

      expect(profiles.containsKey('com.example.elsewhere'), isFalse);
      expect(plist.readAsStringSync(), content);
    });

    test('keeps a hand-added entry where the app signs automatically',
        () async {
      projectFile.writeAsStringSync(_buildFlavoredPbxproj());
      final content = _exportOptions(
        _profileEntry('com.example.app.dev', 'App Dev') +
            _profileEntry(
              'com.example.app.dev.GreetingHomeWidget',
              'Widget Dev',
            ),
      );
      final plist = exportOptions('ExportOptions.plist', content);

      final profiles = await patch();

      expect(profiles, isEmpty);
      expect(plist.readAsStringSync(), content);
    });

    test('keeps a hand-added entry where it has no profile to name', () async {
      projectFile.writeAsStringSync(
        _signManually(_buildFlavoredPbxproj(), _flavorConfigId('AA', 2)),
      );
      final content = _exportOptions(
        _profileEntry('com.example.app.dev', 'App Dev') +
            _profileEntry(
              'com.example.app.dev.GreetingHomeWidget',
              'Widget Dev',
            ),
      );
      final plist = exportOptions('ExportOptions.plist', content);

      final profiles = await patch();

      expect(profiles.containsKey('com.example.app.dev'), isFalse);
      expect(plist.readAsStringSync(), content);
    });

    test('keeps the first profile of configurations sharing a bundle id',
        () async {
      // The unflavored Release and Release-prod both build com.example.app.
      projectFile.writeAsStringSync(
        _signManually(
          _signManually(
            _buildFlavoredPbxproj(),
            _baseConfigId(1),
            profile: 'App Base',
          ),
          _flavorConfigId('BB', 2),
          profile: 'App Prod',
        ),
      );
      final plist = exportOptions(
        'ExportOptions.plist',
        _exportOptions(_profileEntry('com.example.app', 'App Prod')),
      );
      final mock = useMockLogger();

      final profiles = await patch();

      expect(profiles, {'com.example.app': 'App Base GreetingHomeWidget'});
      expect(
        plist.readAsStringSync(),
        _exportOptions(
          _profileEntry('com.example.app', 'App Prod') +
              _profileEntry(
                'com.example.app.GreetingHomeWidget',
                'App Base GreetingHomeWidget',
              ),
        ),
      );
      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains('Release, Release-prod share the bundle id '
                  'com.example.app '),
              contains('"App Base GreetingHomeWidget"'),
              contains('"App Prod GreetingHomeWidget"'),
            ),
          ),
        ),
      ).called(1);
    });

    test('does not warn when configurations sharing a bundle id agree',
        () async {
      projectFile.writeAsStringSync(
        _signManually(
          _signManually(
            _buildFlavoredPbxproj(),
            _baseConfigId(1),
            profile: 'App Prod',
          ),
          _flavorConfigId('BB', 2),
          profile: 'App Prod',
        ),
      );
      final mock = useMockLogger();

      final profiles = await patch();

      expect(profiles, {'com.example.app': 'App Prod GreetingHomeWidget'});
      verifyNever(() => mock.warn(any()));
    });

    test('keeps the value of an entry escaped without need', () async {
      projectFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          _flavorConfigId('AA', 2),
          profile: 'App Dev',
        ),
      );
      final plist = exportOptions(
        'ExportOptions.plist',
        _exportOptions(
          _profileEntry('com.example.app.dev', 'App Dev') +
              _profileEntry('com.example.other', 'Other -&gt; Dev'),
        ),
      );

      await patch();

      expect(
        plist.readAsStringSync(),
        _exportOptions(
          _profileEntry('com.example.app.dev', 'App Dev') +
              _profileEntry(
                'com.example.app.dev.GreetingHomeWidget',
                'App Dev GreetingHomeWidget',
              ) +
              _profileEntry('com.example.other', 'Other -> Dev'),
        ),
      );
    });

    test('reads the device profile from any variant of the device SDK',
        () async {
      final releaseDev = _flavorConfigId('AA', 2);
      String manual(Map<String, String> profiles) {
        final editor = PbxprojEditor(_buildFlavoredPbxproj())
          ..setBuildSetting(releaseDev, 'CODE_SIGN_STYLE', 'Manual');
        for (final MapEntry(:key, :value) in profiles.entries) {
          editor.setBuildSetting(
            releaseDev,
            'PROVISIONING_PROFILE_SPECIFIER$key',
            value,
          );
        }
        return editor.text;
      }

      for (final (profiles, expected) in [
        (
          {'': 'App Any', '[sdk=iphoneos*][arch=*]': 'App Device'},
          'App Device GreetingHomeWidget',
        ),
        (
          {'': 'App Any', '[sdk=iphoneos18.0]': 'App Device'},
          'App Device GreetingHomeWidget',
        ),
        (
          {
            '[sdk=iphoneos*][arch=*]': 'App Arch',
            '[sdk=iphoneos*]': 'App Device',
          },
          'App Device GreetingHomeWidget',
        ),
        (
          {'': 'App Any', '[sdk=iphonesimulator*]': 'App Simulator'},
          'App Any GreetingHomeWidget',
        ),
        (
          {'': 'App Any', '[sdk=iphoneos*]': ''},
          'App Any GreetingHomeWidget',
        ),
      ]) {
        projectFile.writeAsStringSync(manual(profiles));

        expect(
          await patch(),
          {'com.example.app.dev': expected},
          reason: '$profiles',
        );
      }
    });

    test('adds the extension profile to a manual plist by bundle id', () async {
      projectFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          _flavorConfigId('AA', 2),
          profile: 'App Dev',
        ),
      );
      final plist = exportOptions(
        'ExportOptionsDevelopment.plist',
        _exportOptions(_profileEntry('com.example.app.dev', 'App Dev')),
      );
      final mock = useMockLogger();

      await patch();

      expect(
        plist.readAsStringSync(),
        _exportOptions(
          _profileEntry('com.example.app.dev', 'App Dev') +
              _profileEntry(
                'com.example.app.dev.GreetingHomeWidget',
                'App Dev GreetingHomeWidget',
              ),
        ),
      );
      verify(
        () => mock.info(
          any(
            that: allOf(
              contains('ExportOptionsDevelopment.plist'),
              contains('com.example.app.dev.GreetingHomeWidget'),
            ),
          ),
        ),
      ).called(1);

      final patched = plist.readAsStringSync();
      await patch();
      expect(plist.readAsStringSync(), patched);
    });

    test('corrects the profile of an entry that names another', () async {
      projectFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          _flavorConfigId('AA', 2),
          profile: 'App Dev',
        ),
      );
      final plist = exportOptions(
        'ExportOptions.plist',
        _exportOptions(
          _profileEntry('com.example.app.dev', 'App Dev') +
              _profileEntry('com.example.app.dev.GreetingHomeWidget', 'Old'),
        ),
      );

      await patch();

      expect(
        plist.readAsStringSync(),
        _exportOptions(
          _profileEntry('com.example.app.dev', 'App Dev') +
              _profileEntry(
                'com.example.app.dev.GreetingHomeWidget',
                'App Dev GreetingHomeWidget',
              ),
        ),
      );
    });

    test('leaves a plist that signs automatically untouched', () async {
      projectFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          _flavorConfigId('AA', 2),
          profile: 'App Dev',
        ),
      );
      final content = _exportOptions(
        _profileEntry('com.example.app.dev', 'App Dev'),
        signingStyle: 'automatic',
      );
      final plist = exportOptions('ExportOptions.plist', content);

      await patch();

      expect(plist.readAsStringSync(), content);
    });

    test('removes the entry of a flavor the extension is not in', () async {
      projectFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          _flavorConfigId('BB', 2),
          profile: 'App Prod',
        ),
      );
      final plist = exportOptions(
        'ExportOptions-prod.plist',
        _exportOptions(
          _profileEntry('com.example.app', 'App Prod') +
              _profileEntry(
                'com.example.app.GreetingHomeWidget',
                'App Prod GreetingHomeWidget',
              ),
        ),
      );

      await patch(flavors: ['dev']);

      expect(
        plist.readAsStringSync(),
        _exportOptions(_profileEntry('com.example.app', 'App Prod')),
      );
    });

    test('keeps every entry it does not own as it is', () async {
      projectFile.writeAsStringSync(
        _signManually(
          _buildFlavoredPbxproj(),
          _flavorConfigId('AA', 2),
          profile: 'App Dev',
        ),
      );
      final others = _profileEntry(
            'com.example.app.dev.NotificationService',
            'App Dev Notifications',
          ) +
          _profileEntry('com.example.other', 'Other');
      final plist = exportOptions(
        'ExportOptions.plist',
        _exportOptions(
          _profileEntry('com.example.app.dev', 'App Dev') + others,
        ),
      );
      final unrelated = exportOptions(
        'Info.plist',
        _exportOptions(_profileEntry('com.example.app.dev', 'App Dev')),
      );

      await patch();

      expect(
        plist.readAsStringSync(),
        _exportOptions(
          _profileEntry('com.example.app.dev', 'App Dev') +
              _profileEntry(
                'com.example.app.dev.GreetingHomeWidget',
                'App Dev GreetingHomeWidget',
              ) +
              others,
        ),
      );
      expect(
        unrelated.readAsStringSync(),
        _exportOptions(_profileEntry('com.example.app.dev', 'App Dev')),
      );
    });
  });

  group('resolveProjectRelativePath', () {
    test('keeps a path relative to the project directory', () {
      expect(
        resolveProjectRelativePath(' Runner/Runner.entitlements '),
        'Runner/Runner.entitlements',
      );
    });

    test('strips the variables naming the project directory', () {
      for (final variable in const [
        r'$(SRCROOT)',
        r'${SRCROOT}',
        r'$(PROJECT_DIR)',
        r'${PROJECT_DIR}',
      ]) {
        expect(
          resolveProjectRelativePath('$variable/Runner/Runner.entitlements'),
          'Runner/Runner.entitlements',
          reason: variable,
        );
      }
    });

    test('has no path for any other variable or an empty value', () {
      expect(
        resolveProjectRelativePath(r'Runner/$(CONFIGURATION).entitlements'),
        isNull,
      );
      expect(
        resolveProjectRelativePath(r'${CUSTOM}/Runner.entitlements'),
        isNull,
      );
      expect(resolveProjectRelativePath(r'$(SRCROOT)/'), isNull);
      expect(resolveProjectRelativePath(''), isNull);
    });
  });

  group('xcconfig', () {
    late Directory iosDir;
    late File xcconfig;

    List<String> devEntitlements({bool withProjectDir = true}) =>
        runnerEntitlementsSettingsForFlavor(
          Pbxproj.parse(pbxprojFile.readAsStringSync()),
          'dev',
          projectDir: withProjectDir ? iosDir : null,
        );

    setUp(() {
      iosDir = Directory('${tempDir.path}/ios')..createSync();
      Directory('${iosDir.path}/Runner.xcodeproj').createSync();
      Directory('${iosDir.path}/Flutter').createSync();
      pbxprojFile = File('${iosDir.path}/Runner.xcodeproj/project.pbxproj')
        ..writeAsStringSync(_xcconfigFlavoredPbxproj());
      xcconfig = File('${iosDir.path}/Flutter/Debug-dev.xcconfig');
    });

    test('reads the bundle id a flavor keeps in its xcconfig', () async {
      // Generated.xcconfig only exists after the first build; Xcode reads the
      // project without it and so must this.
      xcconfig.writeAsStringSync(
        '#include "Generated.xcconfig"\n'
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev // the flavor\n',
      );

      expect(
        detectXcodeFlavors(Pbxproj.parse(pbxprojFile.readAsStringSync())),
        ['dev'],
      );

      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
      );
      final result = pbxprojFile.readAsStringSync();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev.GreetingHomeWidget;',
        ),
      );
      // Without the xcconfig the flavor would silently take the unflavored
      // bundle id, which iOS rejects for an extension of the flavored app.
      expect(
        _extensionConfig(result, 'Debug'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.GreetingHomeWidget;',
        ),
      );
    });

    test('reads the entitlements a flavor keeps in its xcconfig', () {
      xcconfig.writeAsStringSync(
        'CODE_SIGN_ENTITLEMENTS = Runner/RunnerDev.entitlements\n',
      );

      expect(devEntitlements(), ['Runner/RunnerDev.entitlements']);
    });

    test('resolves a bundle id assembled from other settings', () async {
      xcconfig.writeAsStringSync(
        'APP_ID = com.example.app\n'
        r'PRODUCT_BUNDLE_IDENTIFIER = $(APP_ID).dev'
        '\n',
      );

      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
      );

      expect(
        _extensionConfig(pbxprojFile.readAsStringSync(), 'Debug-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev.GreetingHomeWidget;',
        ),
      );
    });

    test('reads an xcconfig its file reference roots at the project directory',
        () {
      // The group carries a path of its own, which a `<group>` reference would
      // be resolved against; a SOURCE_ROOT one spells the path from `ios/`.
      pbxprojFile.writeAsStringSync(
        _xcconfigFlavoredPbxproj()
            .replaceFirst(
              '\t\t\tname = Flutter;',
              '\t\t\tname = Flutter;\n\t\t\tpath = Flutter;',
            )
            .replaceFirst(
              'path = "Flutter/Debug-dev.xcconfig"; sourceTree = "<group>";',
              'path = "Flutter/Debug-dev.xcconfig"; sourceTree = SOURCE_ROOT;',
            ),
      );
      xcconfig.writeAsStringSync(
        'CODE_SIGN_ENTITLEMENTS = Runner/RunnerDev.entitlements\n',
      );

      expect(devEntitlements(), ['Runner/RunnerDev.entitlements']);
    });

    test('unquotes an entitlements path a flavor keeps in its xcconfig', () {
      xcconfig.writeAsStringSync(
        r'CODE_SIGN_ENTITLEMENTS = "$(SRCROOT)/Runner/RunnerDev.entitlements"'
        '\n',
      );

      final settings = devEntitlements();

      expect(settings, [r'$(SRCROOT)/Runner/RunnerDev.entitlements']);
      expect(
        resolveProjectRelativePath(settings.single),
        'Runner/RunnerDev.entitlements',
      );
    });

    test('sees nothing without a project directory', () {
      xcconfig.writeAsStringSync(
        'CODE_SIGN_ENTITLEMENTS = Runner/RunnerDev.entitlements\n',
      );

      expect(devEntitlements(withProjectDir: false), isEmpty);
    });
  });

  group('compilation conditions', () {
    Future<String> patch() async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
      );
      return pbxprojFile.readAsStringSync();
    }

    setUp(() {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj());
    });

    test('keeps the flags a developer added to a flavored configuration',
        () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Debug-dev',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = '
              '"\$(inherited) MY_FLAG";',
        ),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Debug-dev'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) MY_FLAG HW_FLAVOR_DEV";',
        ),
      );
    });

    test('reads the list form Xcode writes without duplicating the key',
        () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Debug-dev',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = (\n'
              '\t\t\t\t\t"\$(inherited)",\n'
              '\t\t\t\t\tMY_FLAG,\n'
              '\t\t\t\t);',
        ),
      );

      final result = await patch();
      final config = _extensionConfig(result, 'Debug-dev');

      expect(
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS'.allMatches(config).length,
        1,
      );
      expect(
        config,
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = '
          '"\$(inherited) MY_FLAG HW_FLAVOR_DEV";',
        ),
      );
    });

    test('leaves a setting holding the flavor condition the way it is written',
        () async {
      final first = await patch();
      final edited = _withCompilationConditions(
        _withCompilationConditions(
          first,
          'Debug-dev',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = (\n'
              '\t\t\t\t\t"\$(inherited)",\n'
              '\t\t\t\t\tHW_FLAVOR_DEV,\n'
              '\t\t\t\t\tMY_FLAG,\n'
              '\t\t\t\t);',
        ),
        'Release-dev',
        '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = '
            '"HW_FLAVOR_DEV  \$(inherited)";',
      );
      pbxprojFile.writeAsStringSync(edited);

      expect(await patch(), edited);
    });

    test('drops a stale flavor condition and keeps the rest', () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Release',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = '
              '"\$(inherited) MY_FLAG HW_FLAVOR_OLD";',
        ),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Release'),
        contains(
          'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "\$(inherited) MY_FLAG";',
        ),
      );
    });

    test('removes a setting that held nothing but a flavor condition',
        () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Release',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = '
              '"\$(inherited) HW_FLAVOR_OLD";',
        ),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Release'),
        isNot(contains('SWIFT_ACTIVE_COMPILATION_CONDITIONS')),
      );
    });

    test('removes the list form a developer wrote', () async {
      final first = await patch();
      pbxprojFile.writeAsStringSync(
        _withCompilationConditions(
          first,
          'Release',
          '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = (\n'
              '\t\t\t\t\t"\$(inherited)",\n'
              '\t\t\t\t\tHW_FLAVOR_OLD,\n'
              '\t\t\t\t);',
        ),
      );

      final result = await patch();

      expect(
        _extensionConfig(result, 'Release'),
        isNot(contains('SWIFT_ACTIVE_COMPILATION_CONDITIONS')),
      );
      // The line closing the list has to go with it, or the object no longer
      // parses.
      expect(_extensionConfig(result, 'Release'), isNot(contains('HW_FLAVOR')));
    });

    test('changes nothing on a second run', () async {
      final first = await patch();
      final second = await patch();

      expect(second, first);
    });
  });

  group('synchronized groups', () {
    Future<String> patch() async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
      );
      return pbxprojFile.readAsStringSync();
    }

    setUp(() {
      pbxprojFile.writeAsStringSync(
        _buildFlavoredPbxproj(flavors: [_dev], synchronizedGroups: true),
      );
    });

    test('scaffolds the extension folder as a synchronized root group',
        () async {
      final result = await patch();

      final rootGroupId = xcodeObjectId('fsgroup:GreetingHomeWidget');
      final exceptionId = xcodeObjectId('fsex:GreetingHomeWidget');
      expect(
        result,
        contains('$rootGroupId /* GreetingHomeWidget */ = {'),
      );
      expect(result, contains('isa = PBXFileSystemSynchronizedRootGroup;'));
      // Info.plist is the one file the folder must not build.
      expect(
        result,
        contains('isa = PBXFileSystemSynchronizedBuildFileExceptionSet;'),
      );
      expect(result, contains('\t\t\t\tInfo.plist,\n'));
      expect(result, contains('$exceptionId /* Exceptions for '));

      // The target has to claim the folder, or nothing in it is compiled.
      final target = RegExp(
        r'isa = PBXNativeTarget;[\s\S]*?name = GreetingHomeWidget;',
      ).firstMatch(result)!.group(0)!;
      expect(target, contains('fileSystemSynchronizedGroups = ('));
      expect(target, contains(rootGroupId));

      // And the main group has to show it, or it is invisible in Xcode.
      final mainGroup = RegExp(
        r'97C146E51CF9000F007C117D = \{[\s\S]*?children = \(([\s\S]*?)\);',
      ).firstMatch(result)!.group(1)!;
      expect(mainGroup, contains(rootGroupId));
    });

    test('leaves out the explicit file references a classic group needs',
        () async {
      final result = await patch();

      // The synced folder already builds every file in it; listing them a
      // second time would have Xcode compile each one twice.
      expect(
        result,
        isNot(contains(xcodeObjectId('group:GreetingHomeWidget'))),
      );
      expect(result, isNot(contains('path = Widget.swift;')));
      expect(result, isNot(contains('path = WidgetBundle.swift;')));
      expect(result, isNot(contains('path = Info.plist;')));
    });

    test('is idempotent', () async {
      final first = await patch();
      final second = await patch();

      expect(second, first);
    });
  });

  group('Runner build phases', () {
    const runnerPhases = '\t\t\tbuildPhases = (\n'
        '\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,\n'
        '\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,\n'
        '\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n'
        '\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n'
        '\t\t\t);\n';
    final embedPhase =
        '${xcodeObjectId('phase:copy:GreetingHomeWidget')} /* Embed Foundation Extensions */';

    Future<String> patch() async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
      );
      return pbxprojFile.readAsStringSync();
    }

    String runnerBuildPhases(String pbxproj) => RegExp(
          r'97C146ED1CF9000F007C117D /\* Runner \*/ = \{[\s\S]*?'
          r'(\t\t\tbuildPhases = \([\s\S]*?\n\t\t\t\);\n)',
        ).firstMatch(pbxproj)!.group(1)!;

    test('moves an embed phase Runner still lists ahead of the script phases',
        () async {
      // A target removed by hand can leave its embed phase behind in Runner.
      pbxprojFile.writeAsStringSync(
        _buildFlavoredPbxproj(flavors: const [])
            .replaceFirst(
              runnerPhases,
              '\t\t\tbuildPhases = (\n'
              '\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,\n'
              '\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,\n'
              '\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n'
              '\t\t\t\tC0DE00000000000000000001 /* [CP] Embed Pods Frameworks */,\n'
              '\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n'
              '\t\t\t\t$embedPhase,\n'
              '\t\t\t);\n',
            )
            .replaceFirst(
              '/* Begin PBXSourcesBuildPhase section */',
              '/* Begin PBXShellScriptBuildPhase section */\n'
                  '\t\tC0DE00000000000000000001 /* [CP] Embed Pods Frameworks */ = {\n'
                  '\t\t\tisa = PBXShellScriptBuildPhase;\n'
                  '\t\t\tname = "[CP] Embed Pods Frameworks";\n'
                  '\t\t};\n'
                  '\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */ = {\n'
                  '\t\t\tisa = PBXShellScriptBuildPhase;\n'
                  '\t\t\tname = "Thin Binary";\n'
                  '\t\t};\n'
                  '/* End PBXShellScriptBuildPhase section */\n'
                  '\n'
                  '/* Begin PBXSourcesBuildPhase section */',
            ),
      );

      final result = await patch();

      expect(
        runnerBuildPhases(result),
        '\t\t\tbuildPhases = (\n'
        '\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,\n'
        '\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,\n'
        '\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n'
        '\t\t\t\t$embedPhase,\n'
        '\t\t\t\tC0DE00000000000000000001 /* [CP] Embed Pods Frameworks */,\n'
        '\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n'
        '\t\t\t);\n',
      );
    });

    test('creates the build phases of a Runner that has none', () async {
      pbxprojFile.writeAsStringSync(
        _buildFlavoredPbxproj(flavors: const []).replaceFirst(runnerPhases, ''),
      );

      final result = await patch();

      expect(
        result,
        contains(
          '\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */;\n'
          '\t\t\tbuildPhases = (\n'
          '\t\t\t\t$embedPhase,\n'
          '\t\t\t);\n'
          '\t\t\tbuildRules = (\n',
        ),
      );
    });
  });

  group('reporting', () {
    Future<String> patch({Map<String, String> flavorEntitlements = const {}}) =>
        ensureWidgetExtensionTargetInXcodeProject(
          pbxprojFile: pbxprojFile,
          widgetClassName: 'GreetingHomeWidget',
          flavorEntitlements: flavorEntitlements,
        ).then((_) => pbxprojFile.readAsStringSync());

    test('says which settings a sync reset on an existing configuration',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      await patch();
      final mock = useMockLogger();

      await patch(
        flavorEntitlements: {'dev': 'GreetingHomeWidget.dev.entitlements'},
      );

      verify(
        () => mock.info(
          any(
            that: allOf(
              contains('CODE_SIGN_ENTITLEMENTS'),
              contains('"Debug-dev"'),
            ),
          ),
        ),
      ).called(1);
    });

    test('warns when a sync resets a setting of a target it did not create',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      final created = await patch();
      final foreign = created
          .replaceAll(
            xcodeObjectId('target:GreetingHomeWidget'),
            'AB00000000000000000000FF',
          )
          .replaceFirst(
            'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;',
            'CODE_SIGN_ENTITLEMENTS = Chosen.entitlements;',
          );
      pbxprojFile.writeAsStringSync(foreign);
      final mock = useMockLogger();

      final result = await patch();

      verify(
        () => mock.warn(
          any(
            that: allOf(
              contains('Reset CODE_SIGN_ENTITLEMENTS on the "Debug"'),
              contains('home_widget did not create this target'),
            ),
          ),
        ),
      ).called(1);
      verifyNever(() => mock.info(any()));
      expect(
        result,
        foreign.replaceFirst(
          'CODE_SIGN_ENTITLEMENTS = Chosen.entitlements;',
          'CODE_SIGN_ENTITLEMENTS = GreetingHomeWidget.entitlements;',
        ),
      );
    });

    test('stays quiet when a re-run changes nothing', () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: [_dev]));
      await patch();
      final mock = useMockLogger();

      await patch();

      verifyNever(() => mock.info(any()));
    });

    test('fails and writes nothing when the project ids are not found',
        () async {
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
	};
}
''';
      pbxprojFile.writeAsStringSync(content);
      useMockLogger();

      await expectLater(
        patch(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(pbxprojFile.path),
              contains('root PBXProject'),
              contains('PBXNativeTarget named "Runner"'),
              endsWith('project structure that `flutter create` generates.'),
            ),
          ),
        ),
      );
      expect(pbxprojFile.readAsStringSync(), content);
    });

    test('fails and writes nothing when its edits leave the project unparsable',
        () async {
      // The extension's configuration is titled with the Runner one's name,
      // and a title holding `*/` ends its comment early.
      final content = _addRunnerConfigurations(
        _buildFlavoredPbxproj(flavors: const []),
        const ['Beta'],
      ).replaceFirst('name = Beta;', 'name = "Beta */ QA";');
      pbxprojFile.writeAsStringSync(content);
      useMockLogger();

      await expectLater(
        patch(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              startsWith(
                'home_widget produced an invalid Xcode project while updating '
                '${pbxprojFile.path} and left the file unchanged: ',
              ),
              contains('line'),
            ),
          ),
        ),
      );
      expect(pbxprojFile.readAsStringSync(), content);
    });

    test('fails and writes nothing when the project has no groups to attach to',
        () async {
      final content = _buildFlavoredPbxproj(flavors: const [])
          .replaceFirst('\t\t\tmainGroup = 97C146E51CF9000F007C117D;\n', '')
          .replaceFirst(
            '\t\t\tproductRefGroup = 97C146EF1CF9000F007C117D /* Products */;\n',
            '',
          );
      pbxprojFile.writeAsStringSync(content);
      useMockLogger();

      await expectLater(
        patch(),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('the mainGroup of its PBXProject'),
              contains('the productRefGroup of its PBXProject'),
              isNot(contains('root PBXProject')),
              isNot(contains('PBXNativeTarget named "Runner"')),
            ),
          ),
        ),
      );
      expect(pbxprojFile.readAsStringSync(), content);
    });

    test('warns when no Runner configuration can take the entitlements',
        () async {
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);
      final mock = useMockLogger();

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);

      verify(
        () => mock.warn(
          any(that: contains('Runner/Runner.entitlements')),
        ),
      ).called(1);
      expect(pbxprojFile.readAsStringSync(), content);
    });
  });

  group('ensureWidgetExtensionDevelopmentTeamInXcodeProject', () {
    test('copies DEVELOPMENT_TEAM from Runner to widget extensions', () async {
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				DEVELOPMENT_TEAM = TEAM123;
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Debug;
		};
		AABBCCDD11223344EEFF5566 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				APPLICATION_EXTENSION_API_ONLY = YES;
				CODE_SIGN_ENTITLEMENTS = MyWidgetHomeWidget.entitlements;
				CODE_SIGN_STYLE = Automatic;
				INFOPLIST_FILE = MyWidgetHomeWidget/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app.MyWidgetHomeWidget;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);

      await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      final result = pbxprojFile.readAsStringSync();
      expect(result, contains('DEVELOPMENT_TEAM = TEAM123;'));
      expect(
        'DEVELOPMENT_TEAM = TEAM123;'.allMatches(result).length,
        2,
      );
    });

    test('leaves the project alone when Runner names no team', () async {
      // Xcode writes the empty string when signing is set to none, which is
      // not a team to copy.
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				DEVELOPMENT_TEAM = "";
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Debug;
		};
		AABBCCDD11223344EEFF5566 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				APPLICATION_EXTENSION_API_ONLY = YES;
				INFOPLIST_FILE = MyWidgetHomeWidget/Info.plist;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);

      await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      // Writing an empty DEVELOPMENT_TEAM is worse than writing none: Xcode
      // reads it as "no team" and stops falling back to the account's own.
      expect(pbxprojFile.readAsStringSync(), content);
    });

    test('copies the conditional team settings and keeps the others', () async {
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				DEVELOPMENT_TEAM = "";
				"DEVELOPMENT_TEAM[sdk=iphoneos*]" = ABCDE12345;
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
			};
			name = Release;
		};
		AABBCCDD11223344EEFF5566 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				APPLICATION_EXTENSION_API_ONLY = YES;
				DEVELOPMENT_TEAM = ABCDE12345;
				"DEVELOPMENT_TEAM[sdk=macosx*]" = ABCDE12345;
				INFOPLIST_FILE = MyWidgetHomeWidget/Info.plist;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);

      await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      expect(
        pbxprojFile.readAsStringSync(),
        content.replaceFirst(
          '\t\t\t\tDEVELOPMENT_TEAM = ABCDE12345;\n'
              '\t\t\t\t"DEVELOPMENT_TEAM[sdk=macosx*]" = ABCDE12345;\n',
          '\t\t\t\tDEVELOPMENT_TEAM = "";\n'
              '\t\t\t\t"DEVELOPMENT_TEAM[sdk=iphoneos*]" = ABCDE12345;\n'
              '\t\t\t\t"DEVELOPMENT_TEAM[sdk=macosx*]" = ABCDE12345;\n',
        ),
      );
    });

    test('does not modify Runner configs', () async {
      const content = '''
// !\$*UTF8*\$!
{
	objects = {
/* Begin XCBuildConfiguration section */
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				DEVELOPMENT_TEAM = TEAM123;
				INFOPLIST_FILE = Runner/Info.plist;
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
	};
}
''';
      pbxprojFile.writeAsStringSync(content);

      await ensureWidgetExtensionDevelopmentTeamInXcodeProject(
        pbxprojFile: pbxprojFile,
      );

      expect(
        'DEVELOPMENT_TEAM = TEAM123;'
            .allMatches(
              pbxprojFile.readAsStringSync(),
            )
            .length,
        1,
      );
    });
  });

  group('app target', () {
    final dependency = xcodeObjectId('dep:GreetingHomeWidget');
    final embedPhase = xcodeObjectId('phase:copy:GreetingHomeWidget');

    String renamed(String pbxproj, String name) =>
        pbxproj.replaceFirst('\t\t\tname = Runner;\n', '\t\t\tname = $name;\n');

    /// [pbxproj] with a second application target, Other, next to its own.
    String withOtherApplication(String pbxproj) =>
        (PbxprojEditor(pbxproj)..insertObjects('PBXNativeTarget', '''
\t\tC0DE00000000000000000002 /* Other */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Other;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
''')).text;

    File inXcodeProject(String name, String content) =>
        File('${tempDir.path}/ios/$name.xcodeproj/project.pbxproj')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(content);

    Future<Pbxproj> patch(File file) async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: file,
        widgetClassName: 'GreetingHomeWidget',
      );
      return Pbxproj.parse(file.readAsStringSync());
    }

    test('is the only application target when none is named Runner', () async {
      pbxprojFile.writeAsStringSync(renamed(_buildFlavoredPbxproj(), 'App'));

      final project = await patch(pbxprojFile);

      final app = project.nativeTargetNamed('App')!;
      expect(app.strings('dependencies'), [dependency]);
      expect(app.strings('buildPhases'), contains(embedPhase));
      expect(detectXcodeFlavors(project), ['dev', 'prod']);
      expect(
        _extensionConfig(project.text, 'Debug-dev'),
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev.GreetingHomeWidget;',
        ),
      );
    });

    test('is the one named after the project among several', () async {
      final file = inXcodeProject(
        'App',
        withOtherApplication(
          renamed(_buildFlavoredPbxproj(), 'App')
              .replaceAll('Runner/Info.plist', 'App/Info.plist'),
        ),
      );

      final project = await patch(file);

      expect(
        project.nativeTargetNamed('App')!.strings('dependencies'),
        [dependency],
      );
      expect(
        project.nativeTargetNamed('Other')!.strings('dependencies'),
        isEmpty,
      );
      expect(detectXcodeFlavors(project, projectName: 'App'), ['dev', 'prod']);
      expect(detectXcodeFlavors(project), isEmpty);
    });

    test('is Runner whatever the project is called', () async {
      final file = inXcodeProject(
        'Other',
        withOtherApplication(_buildFlavoredPbxproj(flavors: const [])),
      );

      final project = await patch(file);

      expect(
        project.nativeTargetNamed('Runner')!.strings('dependencies'),
        [dependency],
      );
      expect(
        project.nativeTargetNamed('Other')!.strings('dependencies'),
        isEmpty,
      );
    });

    test('fails naming the targets it looked for when none can be the app',
        () async {
      final content = withOtherApplication(
        renamed(_buildFlavoredPbxproj(flavors: const []), 'App'),
      );
      final file = inXcodeProject('MyApp', content);

      await expectLater(
        checkWidgetExtensionTargetInXcodeProject(
          pbxprojFile: file,
          widgetClassName: 'GreetingHomeWidget',
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(
                'the project is missing an app target (a PBXNativeTarget '
                'named "Runner" or "MyApp", or the only one of productType '
                '"com.apple.product-type.application").',
              ),
              endsWith(
                'home_widget needs the app target and project structure that '
                '`flutter create` generates.',
              ),
            ),
          ),
        ),
      );
      expect(file.readAsStringSync(), content);
    });

    test('is what the patchers name in their reports', () async {
      pbxprojFile.writeAsStringSync(
        renamed(_buildFlavoredPbxproj(flavors: const []), 'App')
            .replaceAll('Runner/Info.plist', 'App/Info.plist'),
      );
      final mock = useMockLogger();

      await patch(pbxprojFile);
      await ensureMinimumDeploymentTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        minimumVersion: 15.0,
      );
      pbxprojFile.writeAsStringSync(
        pbxprojFile
            .readAsStringSync()
            .replaceAll('com.example.app;', 'com.example.renamed;'),
      );
      await patch(pbxprojFile);

      verify(() => mock.detail('Ensured App uses App/App.entitlements.'))
          .called(1);
      verify(
        () => mock.detail('Ensured App IPHONEOS_DEPLOYMENT_TARGET >= 15.0.'),
      ).called(1);
      verify(
        () => mock.detail(
          'Synced the Widget Extension target "GreetingHomeWidget" with App.',
        ),
      ).called(1);
      verify(
        () => mock.info(
          'Reset PRODUCT_BUNDLE_IDENTIFIER on the "Debug" configuration of '
          'GreetingHomeWidget to match App.',
        ),
      ).called(1);
    });
  });

  group('defaultRunnerEntitlementsPath', () {
    String withInfoPlist(String infoPlist) =>
        _buildFlavoredPbxproj(flavors: const []).replaceAll(
          'INFOPLIST_FILE = Runner/Info.plist;',
          'INFOPLIST_FILE = $infoPlist;',
        );

    for (final (infoPlist, path) in const [
      ('Runner/Info.plist', 'Runner/Runner.entitlements'),
      ('App/Info.plist', 'App/App.entitlements'),
      (r'"$(SRCROOT)/App/Info.plist"', 'App/App.entitlements'),
      ('./App/Info.plist', 'App/App.entitlements'),
      ('Sources/App/Info.plist', 'Sources/App/App.entitlements'),
      ('Info.plist', 'Runner/Runner.entitlements'),
      ('../Shared/Info.plist', 'Runner/Runner.entitlements'),
      ('/Shared/Info.plist', 'Runner/Runner.entitlements'),
      (r'"$(CUSTOM)/App/Info.plist"', 'Runner/Runner.entitlements'),
    ]) {
      test('is $path for an Info.plist at $infoPlist', () {
        expect(
          defaultRunnerEntitlementsPath(
            Pbxproj.parse(withInfoPlist(infoPlist)),
          ),
          path,
        );
      });
    }

    test('is Runner/Runner.entitlements without an app target', () {
      expect(
        defaultRunnerEntitlementsPath(
          Pbxproj.parse('{\n\tobjects = {\n\t};\n}\n'),
        ),
        'Runner/Runner.entitlements',
      );
    });

    test('is what a configuration naming no file is signed with', () async {
      pbxprojFile.writeAsStringSync(withInfoPlist('App/Info.plist'));

      await ensureRunnerEntitlementsInXcodeProject(pbxprojFile: pbxprojFile);

      expect(
        'CODE_SIGN_ENTITLEMENTS = App/App.entitlements;'
            .allMatches(pbxprojFile.readAsStringSync()),
        hasLength(3),
      );
    });
  });

  group('deployment target of a new extension configuration', () {
    const debugId = '97C147031CF9000F007C117D';

    String withRunnerDeploymentTarget(String pbxproj, String value) =>
        pbxproj.replaceAll(
          'IPHONEOS_DEPLOYMENT_TARGET = 14.0;',
          'IPHONEOS_DEPLOYMENT_TARGET = $value;',
        );

    Future<String> patch() async {
      await ensureWidgetExtensionTargetInXcodeProject(
        pbxprojFile: pbxprojFile,
        widgetClassName: 'GreetingHomeWidget',
      );
      return pbxprojFile.readAsStringSync();
    }

    String deploymentTarget(String pbxproj, String name) =>
        RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([^;]*);')
            .firstMatch(_extensionConfig(pbxproj, name))!
            .group(1)!;

    for (final (runner, extension) in const [
      ('16.0', '16.0'),
      ('15', '15'),
      ('14.0', '14.0'),
      ('12.0', '14.0'),
      (r'"$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)"', '14.0'),
      ('latest', '14.0'),
    ]) {
      test('is $extension where Runner resolves to $runner', () async {
        pbxprojFile.writeAsStringSync(
          withRunnerDeploymentTarget(
            _buildFlavoredPbxproj(flavors: const []),
            runner,
          ),
        );

        final result = await patch();

        for (final name in _baseConfigNames) {
          expect(deploymentTarget(result, name), extension, reason: name);
        }
      });
    }

    test('is what the project level sets, and 14.0 where nothing is set',
        () async {
      pbxprojFile.writeAsStringSync(
        (PbxprojEditor(
          _buildFlavoredPbxproj(flavors: const [])
              .replaceAll('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;\n', ''),
        )
              ..setBuildSetting(debugId, 'IPHONEOS_DEPLOYMENT_TARGET', '15.0')
              ..setBuildSetting(
                _baseConfigId(0),
                'IPHONEOS_DEPLOYMENT_TARGET',
                r'$(inherited)',
              ))
            .text,
      );

      final result = await patch();

      expect(deploymentTarget(result, 'Debug'), '15.0');
      expect(deploymentTarget(result, 'Release'), '14.0');
      expect(deploymentTarget(result, 'Profile'), '14.0');
    });

    test('follows the configuration of the same name', () async {
      final editor = PbxprojEditor(_buildFlavoredPbxproj(flavors: [_dev]));
      for (var rank = 1; rank <= 3; rank++) {
        editor.setBuildSetting(
          _flavorConfigId(_dev.idPrefix, rank),
          'IPHONEOS_DEPLOYMENT_TARGET',
          '16.0',
        );
      }
      pbxprojFile.writeAsStringSync(editor.text);

      final result = await patch();

      expect(deploymentTarget(result, 'Debug'), '14.0');
      expect(deploymentTarget(result, 'Release-dev'), '16.0');
    });

    test('is set for a flavor introduced later, and kept everywhere else',
        () async {
      pbxprojFile.writeAsStringSync(_buildFlavoredPbxproj(flavors: const []));
      final before = await patch();
      final raised = PbxprojEditor(_addRunnerFlavor(before, _stg))
        ..setBuildSetting(
          xcodeObjectId('cfg:Debug:GreetingHomeWidget'),
          'IPHONEOS_DEPLOYMENT_TARGET',
          '16.0',
        );
      for (var rank = 0; rank < 3; rank++) {
        raised.setBuildSetting(
          _baseConfigId(rank),
          'IPHONEOS_DEPLOYMENT_TARGET',
          '15.0',
        );
      }
      for (var rank = 1; rank <= 3; rank++) {
        raised.setBuildSetting(
          _flavorConfigId(_stg.idPrefix, rank),
          'IPHONEOS_DEPLOYMENT_TARGET',
          '17.0',
        );
      }
      pbxprojFile.writeAsStringSync(raised.text);

      final after = await patch();

      expect(deploymentTarget(after, 'Debug-stg'), '17.0');
      expect(deploymentTarget(after, 'Profile-stg'), '17.0');
      expect(deploymentTarget(after, 'Debug'), '16.0');
      expect(deploymentTarget(after, 'Release'), '14.0');
    });
  });
}
