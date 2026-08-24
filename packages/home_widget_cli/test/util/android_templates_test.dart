import 'package:home_widget_cli/src/util/android_templates.dart';
import 'package:test/test.dart';

void main() {
  group('androidGlanceReceiverTemplate', () {
    test('emits no onReceive override by default', () {
      final source = androidGlanceReceiverTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
      );

      expect(source, contains('class FooHomeWidgetReceiver'));
      expect(
          source, contains('override val glanceAppWidget = FooHomeWidget()'));
      expect(source, isNot(contains('onReceive')));
      expect(source, isNot(contains('ACTION_LOCALE_CHANGED')));
      expect(source, isNot(contains('kotlinx.coroutines')));
    });

    test('re-renders on a locale change when handleLocaleChange is set', () {
      final source = androidGlanceReceiverTemplate(
        packageName: 'com.example',
        widgetClassName: 'FooHomeWidget',
        handleLocaleChange: true,
      );

      expect(
        source,
        contains('override fun onReceive(context: Context, intent: Intent)'),
      );
      // super first, so the base receiver's own handling is not swallowed.
      expect(source, contains('super.onReceive(context, intent)'));
      expect(
        source,
        contains('if (intent.action == Intent.ACTION_LOCALE_CHANGED)'),
      );
      // goAsync()/finish() keeps the process alive across the async update.
      expect(source, contains('val pendingResult = goAsync()'));
      expect(source, contains('FooHomeWidget().updateAll(context)'));
      expect(source, contains('pendingResult.finish()'));

      expect(source, contains('import android.content.Context'));
      expect(source, contains('import android.content.Intent'));
      expect(source, contains('import androidx.glance.appwidget.updateAll'));
      expect(source, contains('import kotlinx.coroutines.CoroutineScope'));
      expect(source, contains('import kotlinx.coroutines.Dispatchers'));
      expect(source, contains('import kotlinx.coroutines.launch'));
    });
  });
}
