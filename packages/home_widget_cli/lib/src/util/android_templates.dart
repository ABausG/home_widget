const String _defaultHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

/// Generates the Kotlin code for the GlanceAppWidget.
///
/// [packageName]: The Android package name.
/// [widgetClassName]: The class name of the widget (e.g., `ExampleWidgetHomeWidget`).
/// [contentBody]: Optional body content for the `WidgetContent` composable.
///                If null, a placeholder text is generated.
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String androidGlanceWidgetTemplate({
  required String packageName,
  required String widgetClassName,
  String? contentBody,
  String? extraContent,
  Set<String>? additionalImports,
  String? header,
}) {
  final head = header ?? _defaultHeader;

  if (additionalImports != null) {
    additionalImports = additionalImports.difference({
      'import androidx.compose.runtime.Composable',
      'import android.content.Context',
      'import androidx.compose.ui.graphics.Color',
      'import androidx.glance.GlanceId',
      'import androidx.glance.GlanceModifier',
      'import androidx.glance.appwidget.GlanceAppWidget',
      'import androidx.glance.appwidget.provideContent',
      'import androidx.glance.background',
      'import androidx.glance.currentState',
      'import androidx.glance.layout.Box',
      'import androidx.glance.layout.fillMaxSize',
      'import androidx.glance.text.Text',
      'import es.antonborri.home_widget.HomeWidgetGlanceState',
      'import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition',
    });
  }

  final body = contentBody ??
      '''
    // Example to access data from SharedPreferences:
    // Counter would be the "key" you stored via HomeWidget on Flutter
    // val prefs = currentState.preferences
    // val counter = prefs.getInt("counter", 0)
    Box(modifier = GlanceModifier.fillMaxSize().background(Color.White)) {
      Text(text = "$widgetClassName (placeholder)")
    }
''';

  return '''
$head
//
// This is a placeholder Glance (Jetpack Compose) widget.
package $packageName

import androidx.compose.runtime.Composable
import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Box
import androidx.glance.layout.fillMaxSize
import androidx.glance.text.Text
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition${additionalImports != null && additionalImports.isNotEmpty ? '\n${additionalImports.join('\n')}' : ''}

class $widgetClassName : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState) {
$body
  }
}

${extraContent ?? ''}
''';
}

/// Generates the Kotlin code for the HomeWidgetGlanceWidgetReceiver.
///
/// [packageName]: The Android package name.
/// [widgetClassName]: The class name of the widget.
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String androidGlanceReceiverTemplate({
  required String packageName,
  required String widgetClassName,
  String? header,
}) {
  final head = header ?? _defaultHeader;
  return '''
$head
package $packageName

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class ${widgetClassName}Receiver : HomeWidgetGlanceWidgetReceiver<$widgetClassName>() {
  override val glanceAppWidget = $widgetClassName()
}
''';
}

/// Generates the `appwidget-provider` XML content.
///
/// [initialLayoutName]: The name of the layout resource to use as initial layout.
/// [minWidth]: The minimum width of the widget (default 80dp).
/// [minHeight]: The minimum height of the widget (default 80dp).
/// [minResizeWidth]: The minimum resize width (optional).
/// [minResizeHeight]: The minimum resize height (optional).
/// [maxResizeWidth]: The maximum resize width (optional, API 31+).
/// [maxResizeHeight]: The maximum resize height (optional, API 31+).
/// [targetCellWidth]: The target cell width (optional, API 31+).
/// [targetCellHeight]: The target cell height (optional, API 31+).
/// [resizeMode]: The resize mode (default "horizontal|vertical").
/// [widgetCategory]: The widget category (default "home_screen").
/// [updatePeriodMillis]: The update period in milliseconds (default 0).
/// [descriptionResource]: The resource name for the description (optional, e.g. "@string/my_desc").
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String androidAppWidgetProviderInfoTemplate({
  required String initialLayoutName,
  int minWidth = 80,
  int minHeight = 80,
  int? minResizeWidth,
  int? minResizeHeight,
  int? maxResizeWidth,
  int? maxResizeHeight,
  int? targetCellWidth,
  int? targetCellHeight,
  String resizeMode = 'horizontal|vertical',
  String widgetCategory = 'home_screen',
  int updatePeriodMillis = 0,
  String? descriptionResource,
  String? header,
}) {
  final head = header ?? '<!-- $_defaultHeader -->';

  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
  buffer.writeln(head);
  buffer.writeln(
    '<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"',
  );
  buffer.writeln('    android:initialLayout="@layout/$initialLayoutName"');
  buffer.writeln('    android:minWidth="${minWidth}dp"');
  buffer.writeln('    android:minHeight="${minHeight}dp"');
  buffer.writeln('    android:updatePeriodMillis="$updatePeriodMillis"');
  buffer.writeln('    android:resizeMode="$resizeMode"');
  buffer.writeln('    android:widgetCategory="$widgetCategory"');

  if (minResizeWidth != null) {
    buffer.writeln('    android:minResizeWidth="${minResizeWidth}dp"');
  }
  if (minResizeHeight != null) {
    buffer.writeln('    android:minResizeHeight="${minResizeHeight}dp"');
  }
  if (maxResizeWidth != null) {
    buffer.writeln('    android:maxResizeWidth="${maxResizeWidth}dp"');
  }
  if (maxResizeHeight != null) {
    buffer.writeln('    android:maxResizeHeight="${maxResizeHeight}dp"');
  }
  if (targetCellWidth != null) {
    buffer.writeln('    android:targetCellWidth="$targetCellWidth"');
  }
  if (targetCellHeight != null) {
    buffer.writeln('    android:targetCellHeight="$targetCellHeight"');
  }
  if (descriptionResource != null) {
    buffer.writeln('    android:description="$descriptionResource"');
  }

  buffer.writeln('/>');

  return buffer.toString();
}
