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
  String? header,
}) {
  final head = header ?? _defaultHeader;
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
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

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
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String androidAppWidgetProviderInfoTemplate({
  required String initialLayoutName,
  String? header,
}) {
  final head = header ?? '<!-- $_defaultHeader -->';
  return '''
<?xml version="1.0" encoding="utf-8"?>
$head
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/$initialLayoutName"
    android:minWidth="180dp"
    android:minHeight="80dp"
    android:updatePeriodMillis="0"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
''';
}
