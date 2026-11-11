import 'package:home_widget_cli/src/util/ios_templates.dart';
import 'package:test/test.dart';

void main() {
  test('iosWidgetSwiftTemplate applies swiftViewModifiers lines', () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'ExampleHomeWidget',
      appGroupId: 'group.example',
      swiftViewModifiers: {r'@Environment(\.colorScheme) var scheme'},
    );

    expect(out, contains(r'@Environment(\.colorScheme) var scheme'));
    expect(out, isNot(contains('func applyContainerBackground')));
  });

  test('iosWidgetSwiftTemplate emits default containerBackground helper', () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'BareHomeWidget',
      appGroupId: 'group.bare',
      entryViewBody: '''
    Text("placeholder")
    .applyContainerBackground()
''',
    );

    expect(out, contains('func applyContainerBackground() -> some View'));
    expect(out, contains('containerBackground(.fill.tertiary, for: .widget)'));
    expect(out, isNot(contains('func applyContainerBackground<T: View>')));
  });

  test('iosWidgetSwiftTemplate emits custom containerBackground helper', () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'BareHomeWidget',
      appGroupId: 'group.bare',
      entryViewBody: '''
    Text("placeholder")
    .applyContainerBackground(Color.red)
''',
      hasCustomContainerBackground: true,
    );

    expect(out, contains('func applyContainerBackground<T: View>'));
    expect(
      out,
      isNot(contains('func applyContainerBackground() -> some View')),
    );
    expect(
      out,
      isNot(contains('containerBackground(.fill.tertiary, for: .widget)')),
    );
  });

  test('iosWidgetSwiftTemplate puts widgetURL on the entry view body', () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'LinkedHomeWidget',
      appGroupId: 'group.linked',
      widgetUrl: 'URL(string: "myapp://linked?homeWidget")',
      entryViewBody: '    Text("placeholder")',
    );

    expect(
      out,
      contains(
        '  var body: some View {\n'
        '    Text("placeholder")\n'
        '    .widgetURL(URL(string: "myapp://linked?homeWidget"))\n'
        '  }',
      ),
    );
  });

  test('iosWidgetSwiftTemplate omits widgetURL when none is given', () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'BareHomeWidget',
      appGroupId: 'group.bare',
    );

    expect(out, isNot(contains('.widgetURL(')));
  });

  test('iosWidgetSwiftTemplate emits a plain flavor enum without flavors', () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'BareHomeWidget',
      appGroupId: 'group.bare',
    );

    expect(
      out,
      contains(
        'enum BareHomeWidgetFlavor {\n'
        '  static let appGroupId = "group.bare"\n'
        '}',
      ),
    );
    expect(out, isNot(contains('#if HW_FLAVOR')));
    expect(
      out,
      contains('// App Group ID used here: BareHomeWidgetFlavor.appGroupId'),
    );
  });

  test('iosWidgetSwiftTemplate switches the flavor enum on the conditions', () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'WeatherHomeWidget',
      appGroupId: 'group.example',
      flavorAppGroupIds: const {
        'dev': 'group.example.dev',
        'prod': 'group.example',
      },
    );

    expect(
      out,
      contains(
        'enum WeatherHomeWidgetFlavor {\n'
        '  #if HW_FLAVOR_DEV\n'
        '  static let appGroupId = "group.example.dev"\n'
        '  #elseif HW_FLAVOR_PROD\n'
        '  static let appGroupId = "group.example"\n'
        '  #else\n'
        '  static let appGroupId = "group.example"\n'
        '  #endif\n'
        '}',
      ),
    );
  });

  test('iosFlavorEnumSwift maps a flavor name onto its condition', () {
    final out = iosFlavorEnumSwift(
      widgetClassName: 'MixedHomeWidget',
      appGroupId: 'group.base',
      flavorAppGroupIds: const {'in-house': 'group.inhouse'},
    );

    expect(out, contains('#if HW_FLAVOR_IN_HOUSE'));
    expect(out, contains('static let appGroupId = "group.inhouse"'));
  });

  test('iosWidgetBundleSwiftTemplate registers the widget unconditionally', () {
    final out = iosWidgetBundleSwiftTemplate(
      widgetClassName: 'BareHomeWidget',
    );

    expect(
      out,
      contains(
        '  var body: some Widget {\n'
        '    BareHomeWidget()\n'
        '  }',
      ),
    );
    expect(out, isNot(contains('#if')));
  });

  test('iosWidgetBundleSwiftTemplate guards the widget with its flavors', () {
    final out = iosWidgetBundleSwiftTemplate(
      widgetClassName: 'WeatherHomeWidget',
      flavors: const ['dev', 'prod'],
    );

    expect(
      out,
      contains(
        '  var body: some Widget {\n'
        '    #if HW_FLAVOR_DEV || HW_FLAVOR_PROD\n'
        '    WeatherHomeWidget()\n'
        '    #endif\n'
        '  }',
      ),
    );
  });

  group('iosIntentSwiftTemplate', () {
    test('declares an undiscoverable intent for iOS 17', () {
      final out = iosIntentSwiftTemplate(
        intentName: 'CounterHomeWidgetIntent',
        widgetName: 'Counter',
      );

      expect(out, startsWith('// GENERATED CODE'));
      expect(
        out,
        contains(
          'import AppIntents\n'
          'import Foundation\n'
          'import home_widget\n',
        ),
      );
      expect(
        out,
        contains(
          '@available(iOS 17, *)\n'
          'struct CounterHomeWidgetIntent: AppIntent {\n'
          '  static let title: LocalizedStringResource = '
          '"Counter interaction"\n'
          '  static let isDiscoverable: Bool = false\n',
        ),
      );
    });

    test('carries the URL, the App Group and the key as parameters', () {
      final out = iosIntentSwiftTemplate(
        intentName: 'CounterHomeWidgetIntent',
        widgetName: 'Counter',
      );

      expect(
        out,
        contains(
          '  @Parameter(title: "URL")\n'
          '  var url: URL?\n'
          '\n'
          '  @Parameter(title: "App Group")\n'
          '  var appGroup: String?\n'
          '\n'
          '  @Parameter(title: "Key")\n'
          '  var key: String?\n',
        ),
      );
      expect(
        out,
        contains(
          '  init() {}\n'
          '\n'
          '  init(url: URL?, appGroup: String?, key: String?) {\n'
          '    self.url = url\n'
          '    self.appGroup = appGroup\n'
          '    self.key = key\n'
          '  }\n',
        ),
      );
    });

    test('runs the background worker when it is performed', () {
      final out = iosIntentSwiftTemplate(
        intentName: 'CounterHomeWidgetIntent',
        widgetName: 'Counter',
      );

      expect(
        out,
        contains(
          '  func perform() async throws -> some IntentResult {\n'
          '    if let appGroup = appGroup {\n'
          '      await HomeWidgetBackgroundWorker.run('
          'url: url, appGroup: appGroup, key: key)\n'
          '    }\n'
          '    return .result()\n'
          '  }\n',
        ),
      );
    });

    test('continues in the app, which an app extension cannot', () {
      final out = iosIntentSwiftTemplate(
        intentName: 'CounterHomeWidgetIntent',
        widgetName: 'Counter',
      );

      expect(
        out,
        endsWith(
          '@available(iOS 17, *)\n'
          '@available(iOSApplicationExtension, unavailable)\n'
          'extension CounterHomeWidgetIntent: ForegroundContinuableIntent {}\n',
        ),
      );
    });

    test('escapes the widget name in the title', () {
      final out = iosIntentSwiftTemplate(
        intentName: 'QuotedHomeWidgetIntent',
        widgetName: r'My "best" \ widget',
      );

      expect(
        out,
        contains(
          r'static let title: LocalizedStringResource = '
          r'"My \"best\" \\ widget interaction"',
        ),
      );
    });

    test('starts with a custom header', () {
      final out = iosIntentSwiftTemplate(
        intentName: 'CounterHomeWidgetIntent',
        widgetName: 'Counter',
        header: '// Custom header',
      );

      expect(out, startsWith('// Custom header\n\nimport AppIntents\n'));
      expect(out, isNot(contains('GENERATED CODE')));
    });
  });

  group('iosButtonSwift', () {
    String button({String interactionKey = 'CounterHomeWidget'}) =>
        iosButtonSwift(
          function: 'hwButton',
          widgetClassName: 'CounterHomeWidget',
          intentName: 'CounterHomeWidgetIntent',
          interactionKey: interactionKey,
        );

    test('declares the function wrapping a child in the button view', () {
      expect(
        button(),
        endsWith(
          'func hwButton<Content: View>(_ url: URL?, '
          '@ViewBuilder content: () -> Content) -> some View {\n'
          '  return HWButtonView(url: url, content: content())\n'
          '}',
        ),
      );
      expect(
        button(),
        startsWith('struct HWButtonView<Content: View>: View {'),
      );
    });

    test('performs the intent with the App Group of the flavor and the key',
        () {
      expect(
        button(),
        contains(
          '      Button(\n'
          '        intent: CounterHomeWidgetIntent(\n'
          '          url: url, appGroup: CounterHomeWidgetFlavor.appGroupId,\n'
          '          key: "CounterHomeWidget")\n'
          '      ) {\n'
          '        content\n'
          '      }\n'
          '      .buttonStyle(.plain)\n',
        ),
      );
    });

    test('renders the bare child before iOS 17 and in the inline family', () {
      final out = button();

      expect(out, contains(r'@Environment(\.widgetFamily) private var family'));
      expect(
        out,
        contains(
          '    if #available(iOS 17.0, *), let url = url, '
          'family != .accessoryInline {\n',
        ),
      );
      expect(
        out,
        contains(
          '    } else {\n'
          '      content\n'
          '    }\n',
        ),
      );
    });

    test('escapes the interaction key', () {
      expect(
        button(interactionKey: r'Quoted"Home\Widget'),
        contains(r'key: "Quoted\"Home\\Widget")'),
      );
    });
  });
}
