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
      widgetUrl: 'myapp://linked?homeWidget',
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
}
