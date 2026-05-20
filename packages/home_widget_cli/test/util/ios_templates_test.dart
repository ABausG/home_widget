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
}
