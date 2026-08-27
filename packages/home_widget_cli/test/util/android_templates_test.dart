import 'package:home_widget_cli/src/util/android_templates.dart';
import 'package:test/test.dart';

void main() {
  group('androidGlanceReceiverTemplate', () {
    test('emits a bare receiver with no onReceive override', () {
      final source = androidGlanceReceiverTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
      );

      expect(source, contains('class FooHomeWidgetReceiver'));
      expect(
        source,
        contains('override val glanceAppWidget = FooHomeWidget()'),
      );
      // Locale-change handling is inherited from Glance; see
      // androidGlanceReceiverTemplate.
      expect(source, isNot(contains('onReceive')));
      expect(source, isNot(contains('goAsync')));
      expect(source, isNot(contains('ACTION_LOCALE_CHANGED')));
      expect(source, isNot(contains('updateAll')));
      expect(source, isNot(contains('kotlinx.coroutines')));
    });

    test('imports only the base receiver', () {
      final source = androidGlanceReceiverTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
      );

      final imports = source
          .split('\n')
          .where((line) => line.startsWith('import '))
          .toList();
      expect(imports, [
        'import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver',
      ]);
    });
  });
}
