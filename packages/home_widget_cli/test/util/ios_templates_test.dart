import 'package:home_widget_cli/src/util/ios_templates.dart';
import 'package:test/test.dart';

void main() {
  test('iosWidgetSwiftTemplate applies swiftViewModifiers lines', () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'ExampleHomeWidget',
      appGroupId: 'group.example',
      swiftViewModifiers: {r'@Environment(\.colorScheme) var scheme'},
      includeBackgroundExtension: true,
    );

    expect(out, contains(r'@Environment(\.colorScheme) var scheme'));
    expect(out, contains('applyContainerBackground'));
  });

  test('iosWidgetSwiftTemplate emits background extension when requested',
      () {
    final out = iosWidgetSwiftTemplate(
      widgetClassName: 'BareHomeWidget',
      appGroupId: 'group.bare',
      includeBackgroundExtension: true,
    );

    expect(out, contains('func applyContainerBackground'));
  });
}
