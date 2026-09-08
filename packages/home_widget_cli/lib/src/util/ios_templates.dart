import 'naming.dart';

const String _defaultHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

/// The name of the enum holding the per-flavor values of [widgetClassName].
String iosFlavorEnumName(String widgetClassName) => '${widgetClassName}Flavor';

/// The Swift enum the generated widget reads its flavor-dependent values from.
///
/// The compilation conditions are set per build configuration by
/// `xcode_pbxproj_patcher.dart`, so exactly one branch is active in a flavored
/// build and the `#else` covers both an unflavored build and a flavor the
/// widget does not declare. Without [flavorAppGroupIds] there is nothing to
/// switch on and the enum holds the base value alone.
String iosFlavorEnumSwift({
  required String widgetClassName,
  required String appGroupId,
  Map<String, String> flavorAppGroupIds = const {},
}) {
  final buffer = StringBuffer();
  buffer.writeln('enum ${iosFlavorEnumName(widgetClassName)} {');
  if (flavorAppGroupIds.isEmpty) {
    buffer.writeln('  static let appGroupId = "$appGroupId"');
  } else {
    var first = true;
    for (final entry in flavorAppGroupIds.entries) {
      final condition = flavorCompilationCondition(entry.key);
      buffer.writeln('  #${first ? 'if' : 'elseif'} $condition');
      buffer.writeln('  static let appGroupId = "${entry.value}"');
      first = false;
    }
    buffer.writeln('  #else');
    buffer.writeln('  static let appGroupId = "$appGroupId"');
    buffer.writeln('  #endif');
  }
  buffer.write('}');
  return buffer.toString();
}

/// Generates the Swift code for the Widget.
///
/// [widgetClassName]: The class name of the widget (e.g., `ExampleWidgetHomeWidget`).
/// [appGroupId]: The App Group ID for data sharing, used by the build
///               configurations that are not one of [flavorAppGroupIds].
/// [flavorAppGroupIds]: App Group ID per declared flavor, in declaration order.
/// [widgetBody]: Optional body content for the `Widget` configuration.
///               If null, a placeholder configuration is generated.
/// [widgetUrl]: Optional URL opened when the widget is tapped, emitted as a
///              `.widgetURL(...)` modifier on the entry view's body.
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String iosWidgetSwiftTemplate({
  required String widgetClassName,
  required String appGroupId,
  Map<String, String> flavorAppGroupIds = const {},
  String? widgetUrl,
  String? placeholderBody,
  String? entryDefinition,
  String? getSnapshotBody,
  String? getTimelineBody,
  String? entryViewBody,
  String? extraContent,
  List<String>? extraImports,
  String? displayName,
  String? description,
  String? displayNameExpression,
  String? descriptionExpression,
  String? supportedFamilies,
  Set<String>? swiftViewModifiers,
  bool hasCustomContainerBackground = false,
  bool applyContentPadding = true,
  String? header,
}) {
  final head = header ?? _defaultHeader;
  final flavorEnumName = iosFlavorEnumName(widgetClassName);
  final entryDef = entryDefinition ??
      '''
struct ${widgetClassName}Entry: TimelineEntry {
  let date: Date
}
''';
  final snapshotBody = getSnapshotBody ??
      '''
    // Example of accessing data written by home_widget in Flutter:
    // let prefs = UserDefaults(suiteName: $flavorEnumName.appGroupId)
    // let counter = prefs?.integer(forKey: "counter") ?? 0
    completion(${widgetClassName}Entry(date: Date()))
''';
  final timelineBody = getTimelineBody ??
      '''
    completion(Timeline(entries: [${widgetClassName}Entry(date: Date())], policy: .atEnd))
''';
  final viewBody = entryViewBody ??
      '''
    Text("$widgetClassName (placeholder)")
''';

  final buffer = StringBuffer();
  buffer.writeln(head);
  buffer.writeln('//');
  buffer.writeln('// Placeholder SwiftUI widget.');
  buffer.writeln('//');
  buffer.writeln('// App Group ID used here: $flavorEnumName.appGroupId');
  buffer.writeln();
  for (final import in {
    'import SwiftUI',
    'import WidgetKit',
    ...?extraImports,
  }.toList()
    ..sort()) {
    buffer.writeln(import);
  }
  buffer.writeln();
  buffer.writeln(
    iosFlavorEnumSwift(
      widgetClassName: widgetClassName,
      appGroupId: appGroupId,
      flavorAppGroupIds: flavorAppGroupIds,
    ),
  );
  buffer.writeln();
  buffer.writeln('struct Provider: TimelineProvider {');
  buffer.writeln(
    '  func placeholder(in context: Context) -> ${widgetClassName}Entry {',
  );
  buffer.writeln(
    '    ${placeholderBody ?? '${widgetClassName}Entry(date: Date())'}',
  );
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln(
    '  func getSnapshot(in context: Context, completion: @escaping (${widgetClassName}Entry) -> Void) {',
  );
  buffer.writeln(snapshotBody);
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln(
    '  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {',
  );
  buffer.writeln(timelineBody);
  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();
  buffer.writeln(entryDef);
  buffer.writeln();
  buffer.writeln('struct ${widgetClassName}EntryView: View {');
  buffer.writeln('  var entry: Provider.Entry');

  if (swiftViewModifiers != null && swiftViewModifiers.isNotEmpty) {
    buffer.writeln();
    for (final modifier in swiftViewModifiers) {
      buffer.writeln('  $modifier');
    }
  }

  buffer.writeln();
  buffer.writeln('  var body: some View {');
  buffer.writeln(viewBody);
  if (widgetUrl != null) {
    buffer.writeln('    .widgetURL(URL(string: "$widgetUrl"))');
  }
  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();
  buffer.writeln('struct $widgetClassName: Widget {');
  buffer.writeln('  let kind: String = "$widgetClassName"');
  buffer.writeln();
  buffer.writeln('  var body: some WidgetConfiguration {');
  buffer.writeln(
    '    StaticConfiguration(kind: kind, provider: Provider()) { entry in',
  );
  buffer.writeln('      ${widgetClassName}EntryView(entry: entry)');
  buffer.writeln('    }');
  // A string literal keeps SwiftUI's LocalizedStringKey overload, which projects
  // shipping their own Localizable.strings in the extension rely on. Only switch
  // to a computed String when translations were actually configured.
  if (displayNameExpression != null) {
    buffer.writeln('    .configurationDisplayName($displayNameExpression)');
  } else {
    buffer.writeln(
      '    .configurationDisplayName("${displayName ?? widgetClassName}")',
    );
  }

  if (descriptionExpression != null) {
    buffer.writeln('    .description($descriptionExpression)');
  } else if (description != null) {
    buffer.writeln('    .description("$description")');
  }

  if (supportedFamilies != null) {
    buffer.writeln('    .supportedFamilies($supportedFamilies)');
  }

  if (!applyContentPadding) {
    buffer.writeln('    .disableContentMarginsIfNeeded()');
  }

  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();

  final includesContainerBackground =
      entryViewBody?.contains('.applyContainerBackground') ?? false;

  if (includesContainerBackground && !hasCustomContainerBackground) {
    buffer.writeln('''
extension View {
  @ViewBuilder
  func applyContainerBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(.fill.tertiary, for: .widget)
    } else if #available(iOSApplicationExtension 15.0, *) {
      self.background()
    } else {
      self
    }
  }
}
''');
  }

  if (includesContainerBackground && hasCustomContainerBackground) {
    buffer.writeln('''
extension View {
  @ViewBuilder
  func applyContainerBackground<T: View>(_ backgroundView: T) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(for: .widget) { backgroundView }
    } else {
      self.background(backgroundView)
    }
  }
}
''');
  }

  if (!applyContentPadding) {
    buffer.writeln('''
extension WidgetConfiguration {
  func disableContentMarginsIfNeeded() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 15.0, macOS 12.0, watchOS 9.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
}
''');
  }

  buffer.writeln(extraContent ?? '');

  return buffer.toString();
}

/// Generates the Swift code for the WidgetBundle.
///
/// [widgetClassName]: The class name of the main widget.
/// [flavors]: The flavors the widget is declared for. When non-empty the widget
///            is only registered in a build of one of them; the bundle itself
///            still builds in every configuration, holding no widget.
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String iosWidgetBundleSwiftTemplate({
  required String widgetClassName,
  List<String> flavors = const [],
  String? header,
}) {
  final head = header ?? _defaultHeader;
  final body = flavors.isEmpty
      ? '    $widgetClassName()'
      : '    #if ${flavors.map(flavorCompilationCondition).join(' || ')}\n'
          '    $widgetClassName()\n'
          '    #endif';
  return '''
$head

import WidgetKit
import SwiftUI

@main
struct ${widgetClassName}Bundle: WidgetBundle {
  var body: some Widget {
$body
  }
}
''';
}

/// Generates the Info.plist content for the Widget Extension.
String iosInfoPlistTemplate() {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
''';
}
