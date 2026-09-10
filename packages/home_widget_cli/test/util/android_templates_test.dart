import 'package:home_widget_cli/src/util/android_templates.dart';
import 'package:test/test.dart';

void main() {
  group('androidGlanceWidgetTemplate', () {
    test('previews from the live data and imports the plugin by default', () {
      final source = androidGlanceWidgetTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
      );

      expect(
        source,
        contains(
          '    provideContent { WidgetContent(context, '
          'HomeWidgetGlanceState(HomeWidgetPlugin.getData(context))) }',
        ),
      );
      expect(
        source,
        contains('import es.antonborri.home_widget.HomeWidgetPlugin'),
      );
      expect(source, isNot(contains('HomeWidgetPreviews')));
    });

    test('does not repeat an additional import the template already has', () {
      final source = androidGlanceWidgetTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
        additionalImports: {
          'import es.antonborri.home_widget.HomeWidgetPlugin',
          'import es.antonborri.home_widget.HomeWidgetPreviews',
        },
      );

      const pluginImport = 'import es.antonborri.home_widget.HomeWidgetPlugin';
      final imports =
          source.split('\n').where((line) => line == pluginImport).toList();
      expect(imports, hasLength(1));
      expect(
        source,
        contains('import es.antonborri.home_widget.HomeWidgetPreviews'),
      );
    });
  });

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
