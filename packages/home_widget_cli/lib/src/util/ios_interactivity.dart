import 'dart:io';

import 'package:path/path.dart' as p;

import 'logger.dart';

/// The CocoaPods target giving the widget extension [widgetClassName] the
/// `home_widget` plugin, as it is written into a `Podfile`.
String podfileWidgetTarget(String widgetClassName) => '''
target '$widgetClassName' do
  use_frameworks!
  use_modular_headers!

  pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'
end
''';

RegExp _podfileTargetPattern(String widgetClassName) => RegExp(
      '^[ \\t]*target\\s+[\'"]${RegExp.escape(widgetClassName)}[\'"]\\s+do\\b',
      multiLine: true,
    );

/// Ensures [podfile] has a target for the widget extension [widgetClassName]
/// that links the `home_widget` plugin.
///
/// The target goes ahead of the `post_install` hook, or at the end without
/// one. A target of that name which is already there is left as it is, edited
/// or not, with a warning when it does not name the plugin.
Future<void> ensurePodfileWidgetTarget(
  File podfile,
  String widgetClassName,
) async {
  final content = await podfile.readAsString();
  final existing = _podfileTargetPattern(widgetClassName).firstMatch(content);
  if (existing != null) {
    final rest = content.substring(existing.start);
    final end = RegExp(r'^[ \t]*end\b', multiLine: true).firstMatch(rest);
    final block = end == null ? rest : rest.substring(0, end.end);
    if (!RegExp('''pod\\s+['"]home_widget['"]''').hasMatch(block)) {
      logger.warn(
        "Warning: The target '$widgetClassName' in ${podfile.path} does not "
        "name the home_widget pod, which its buttons need. Add `pod "
        "'home_widget', :path => '.symlinks/plugins/home_widget/ios'` to it.",
      );
    }
    return;
  }

  final block = podfileWidgetTarget(widgetClassName);
  final hook = RegExp(r'^post_install\s+do\b', multiLine: true)
      .firstMatch(content)
      ?.start;
  final String updated;
  if (hook != null) {
    updated = '${content.substring(0, hook)}$block\n${content.substring(hook)}';
  } else {
    final separator = content.isEmpty || content.endsWith('\n\n')
        ? ''
        : content.endsWith('\n')
            ? '\n'
            : '\n\n';
    updated = '$content$separator$block';
  }
  await podfile.writeAsString(updated);
  logger.detail('Updated: ${podfile.path}');
}

/// Removes the target [ensurePodfileWidgetTarget] wrote for
/// [widgetClassName] from [podfile]. One that was edited since stays.
Future<void> removePodfileWidgetTarget(
  File podfile,
  String widgetClassName,
) async {
  if (!podfile.existsSync()) return;
  final content = await podfile.readAsString();
  final block = podfileWidgetTarget(widgetClassName);
  var start = content.indexOf(block);
  if (start == -1) return;

  var end = start + block.length;
  if (content.startsWith('\n', end)) {
    end++;
  } else if (end == content.length &&
      start >= 2 &&
      content.startsWith('\n\n', start - 2)) {
    start--;
  }
  await podfile.writeAsString(content.replaceRange(start, end, ''));
  logger.detail('Updated: ${podfile.path}');
}

/// The lines an `AppDelegate.swift` runs so that the Dart function of a
/// widget interaction can use the app's plugins.
const String appDelegatePluginRegistrant = '''
if #available(iOS 17, *) {
  HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
    GeneratedPluginRegistrant.register(with: registry)
  }
}''';

/// A Swift line or block comment.
final RegExp _swiftComment = RegExp(r'//[^\n]*|/\*.*?\*/', dotAll: true);

final RegExp _superLaunchPattern = RegExp(
  r'^([ \t]*)return\s+super\.application\(\s*application\s*,\s*'
  r'didFinishLaunchingWithOptions\s*:\s*launchOptions\s*\)',
  multiLine: true,
);

/// Ensures the app delegate in [iosDir] registers the app's plugins with the
/// engine the plugin runs a widget interaction in.
///
/// The delegate is the `AppDelegate.swift` in the first of [appDirectories]
/// that has one. The block goes ahead of the `return super.application(...)`
/// of `application(_:didFinishLaunchingWithOptions:)`, the shape `flutter
/// create` writes, with an `import home_widget` next to the other imports. A
/// delegate that already sets the callback of `HomeWidgetBackgroundWorker`,
/// outside a comment, is left as it is; the registrant callback of another
/// plugin does not count. One of any other
/// shape is not guessed at: a warning prints what to add.
Future<void> ensureAppDelegatePluginRegistrant(
  Directory iosDir, {
  List<String> appDirectories = const ['Runner'],
}) async {
  final candidates = [
    for (final directory in appDirectories)
      File(p.join(iosDir.path, directory, 'AppDelegate.swift')),
  ];
  final file = candidates.firstWhere(
    (candidate) => candidate.existsSync(),
    orElse: () => candidates.first,
  );
  final content = file.existsSync() ? await file.readAsString() : null;
  if (content != null &&
      content
          .replaceAll(_swiftComment, '')
          .contains('HomeWidgetBackgroundWorker.setPluginRegistrantCallback')) {
    return;
  }

  final launch =
      content == null ? null : _superLaunchPattern.firstMatch(content);
  if (content == null || launch == null) {
    logger.warn(
      'Warning: Could not add the plugin registration for widget '
      'interactions to ${file.path}. Without it the Dart function a button '
      'runs can only use home_widget. Import home_widget there and add this '
      'to application(_:didFinishLaunchingWithOptions:):\n'
      '$appDelegatePluginRegistrant',
    );
    return;
  }

  final indent = launch.group(1)!;
  final block = [
    for (final line in appDelegatePluginRegistrant.split('\n')) '$indent$line',
  ].join('\n');
  var updated = content.replaceRange(launch.start, launch.start, '$block\n');

  if (!RegExp(r'^import\s+home_widget\b', multiLine: true).hasMatch(updated)) {
    final imports =
        RegExp(r'^import\s+\S+[ \t]*$', multiLine: true).allMatches(updated);
    final at = imports.isEmpty ? 0 : imports.last.end;
    updated = updated.replaceRange(
      at,
      at,
      imports.isEmpty ? 'import home_widget\n' : '\nimport home_widget',
    );
  }

  await file.writeAsString(updated);
  logger.detail('Updated: ${file.path}');
}
