import 'dart:io';

import 'package:path/path.dart' as p;

/// A native flavor, i.e. the trio of Runner build configurations Flutter
/// creates for `--flavor <name>`.
final class RunnerFlavor {
  const RunnerFlavor({
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

/// Writes [flavoredPbxproj] to `ios/Runner.xcodeproj/project.pbxproj` under
/// [projectRoot], the Xcode project the iOS generator wires a widget into.
File writeRunnerXcodeProject(
  Directory projectRoot, {
  List<RunnerFlavor> flavors = const [],
  String? baseEntitlements,
}) =>
    File(
      p.join(projectRoot.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    )
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        flavoredPbxproj(flavors, baseEntitlements: baseEntitlements),
      );

const _baseConfigNames = ['Debug', 'Release', 'Profile'];

String _runnerConfigObject({
  required String id,
  required String name,
  required String bundleId,
  String? entitlements,
}) {
  final entitlementsLine = entitlements == null
      ? ''
      : '\t\t\t\tCODE_SIGN_ENTITLEMENTS = $entitlements;\n';
  return '''
\t\t$id /* $name */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
$entitlementsLine\t\t\t\tDEVELOPMENT_TEAM = TEAM123;
\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $bundleId;
\t\t\t};
\t\t\tname = ${_configName(name)};
\t\t};''';
}

/// A configuration name the way Xcode stores it: quoted unless it is a bare
/// identifier, so a flavored one reads `name = "Debug-dev";`.
String _configName(String name) =>
    RegExp(r'^[A-Za-z0-9_$./]+$').hasMatch(name) ? name : '"$name"';

/// A `flutter create` shaped project with Runner configurations for [flavors].
String flavoredPbxproj(
  List<RunnerFlavor> flavors, {
  String? baseEntitlements,
}) {
  final configObjects = <String>[];
  final configListEntries = <String>[];

  for (var rank = 0; rank < _baseConfigNames.length; rank++) {
    final name = _baseConfigNames[rank];
    final id = '97C1470${rank}1CF9000F007C117D';
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
      final id = '${flavor.idPrefix}${'0' * 21}${rank + 1}';
      configObjects.add(
        _runnerConfigObject(
          id: id,
          name: name,
          bundleId: flavor.bundleId,
          entitlements: flavor.entitlementsFor(_baseConfigNames[rank]),
        ),
      );
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
