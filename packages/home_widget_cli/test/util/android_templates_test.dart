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

    test('routes a time change into onUpdate and leaves the rest to Glance',
        () {
      final source = androidGlanceReceiverTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
        handleTimeChange: true,
      );

      expect(
        source,
        contains('''
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == Intent.ACTION_TIME_CHANGED) {
      val manager = AppWidgetManager.getInstance(context)
      onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, javaClass)))
      return
    }
    super.onReceive(context, intent)
  }
'''),
      );
      // onUpdate makes the one goAsync() call a receiver gets; see
      // androidGlanceReceiverTemplate.
      expect(source, isNot(contains('goAsync')));
      expect(source, isNot(contains('ACTION_LOCALE_CHANGED')));
      expect(source, isNot(contains('updateAll')));
      expect(source, isNot(contains('kotlinx.coroutines')));
    });

    test('imports what the time change override names, in ktfmt order', () {
      List<String> importsOf(String source) => source
          .split('\n')
          .where((line) => line.startsWith('import '))
          .toList();

      const expected = [
        'import android.appwidget.AppWidgetManager',
        'import android.content.ComponentName',
        'import android.content.Context',
        'import android.content.Intent',
        'import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver',
      ];
      expect(
        importsOf(
          androidGlanceReceiverTemplate(
            packageName: 'com.example',
            widgetClassName: 'FooHomeWidget',
            handleTimeChange: true,
          ),
        ),
        expected,
      );

      final withFingerprint = androidGlanceReceiverTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
        previewFingerprint: true,
        handleTimeChange: true,
      );
      expect(importsOf(withFingerprint), expected);
      expect(
        withFingerprint.indexOf('override fun previewFingerprint('),
        lessThan(withFingerprint.indexOf('override fun onReceive(')),
      );
    });

    test('imports the context alone for a preview fingerprint', () {
      final source = androidGlanceReceiverTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
        previewFingerprint: true,
      );

      expect(
        source,
        contains('''
package com.example

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class FooHomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<FooHomeWidget>() {
'''),
      );
      expect(source, isNot(contains('onReceive')));
    });
  });
}
