const String _defaultHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

/// Generates the Kotlin code for the GlanceAppWidget.
///
/// [packageName]: The Android package name.
/// [widgetClassName]: The class name of the widget (e.g., `ExampleWidgetHomeWidget`).
/// [contentBody]: Optional body content for the `WidgetContent` composable.
///                If null, a placeholder text is generated.
/// [previewPreferences]: The `SharedPreferences` expression `providePreview`
///                composes the gallery preview from. Defaults to the data the
///                app itself saved, which is what the widget body reads.
/// [previewParameter]: Whether `WidgetContent` takes the `preview` flag that
///                `providePreview` passes. Only a body that reads differently
///                in the gallery has anything to do with it.
/// [previewFingerprint]: Optional Kotlin body of `previewFingerprint`, which
///                describes what the preview currently renders. Omitting it
///                leaves the widget out of the automatic preview registration.
/// [measuresTextBounds]: Whether the body draws text into a bitmap, which needs
///                the room it may take measured first. The widget then composes
///                once with no bounds to measure them and once to render, and
///                against the size it was actually given rather than the
///                smallest one its provider declares, since the measurements
///                are keyed by it.
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String androidGlanceWidgetTemplate({
  required String packageName,
  required String widgetClassName,
  String? contentBody,
  String? extraContent,
  Set<String>? additionalImports,
  String previewPreferences = 'HomeWidgetPlugin.getData(context)',
  bool previewParameter = false,
  String? previewFingerprint,
  bool measuresTextBounds = false,
  String? header,
}) {
  final head = header ?? _defaultHeader;

  final extraImports = additionalImports?.difference({
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
        'import es.antonborri.home_widget.HomeWidgetPlugin',
      }) ??
      const <String>{};

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

  // The measuring pass composes the same body with no bounds, which every
  // bitmap text renders a tagged probe for; the gallery preview has no widget
  // to measure in and draws against no room at all.
  final provideGlance = measuresTextBounds
      ? '''
  override suspend fun provideGlance(context: Context, id: GlanceId) {
    val measuring: (HomeWidgetFonts.TextBounds) -> GlanceAppWidget = { bounds ->
      object : GlanceAppWidget() {
        override suspend fun provideGlance(context: Context, id: GlanceId) {
          provideContent { WidgetContent(context, HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)), textBounds = bounds) }
        }
      }
    }
    val measured = HomeWidgetFonts.measureTextBounds(context, id, measuring)
    provideContent {
      val size = LocalSize.current
      var textBounds by remember { mutableStateOf(measured) }
      LaunchedEffect(size) {
        if (!textBounds.covers(size)) {
          textBounds += HomeWidgetFonts.measureTextBounds(context, id, size, measuring)
        }
      }
      WidgetContent(context, currentState(), textBounds = textBounds)
    }
  }
'''
      : '''
  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { WidgetContent(context, currentState()) }
  }
''';
  final previewTextBounds = measuresTextBounds
      ? ', textBounds = HomeWidgetFonts.TextBounds.NONE'
      : '';
  final textBoundsParameter =
      measuresTextBounds ? ', textBounds: HomeWidgetFonts.TextBounds' : '';

  final buffer = StringBuffer();
  buffer.write('''
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
import es.antonborri.home_widget.HomeWidgetPlugin
''');

  for (final import in extraImports) {
    buffer.writeln(import);
  }

  buffer.write('''

class $widgetClassName : GlanceAppWidget() {
  override val stateDefinition = HomeWidgetGlanceStateDefinition()
${measuresTextBounds ? '''
  override val sizeMode: SizeMode = SizeMode.Exact
''' : ''}
$provideGlance
  override suspend fun providePreview(context: Context, widgetCategory: Int) {
    provideContent { WidgetContent(context, HomeWidgetGlanceState($previewPreferences)${previewParameter ? ', preview = true' : ''}$previewTextBounds) }
  }
''');

  if (previewFingerprint != null) {
    buffer
      ..writeln()
      ..writeln(previewFingerprint);
  }

  buffer.write('''

  @Composable
  private fun WidgetContent(context: Context, currentState: HomeWidgetGlanceState${previewParameter ? ', preview: Boolean = false' : ''}$textBoundsParameter) {
$body
  }
}

${extraContent ?? ''}
''');

  return buffer.toString();
}

/// Generates the Kotlin code for the HomeWidgetGlanceWidgetReceiver.
///
/// Do not add an `onReceive` override for `ACTION_LOCALE_CHANGED`: Glance's
/// `GlanceAppWidgetReceiver` already handles it and consumes the receiver's
/// single `goAsync()` result, so a second call returns null and crashes.
/// `ensureAndroidManifestReceiver` declares the intent-filter that gets the
/// broadcast here.
///
/// [packageName]: The Android package name.
/// [widgetClassName]: The class name of the widget.
/// [previewFingerprint]: Whether the widget declares a `previewFingerprint`,
///                which the receiver forwards so the plugin can re-register the
///                gallery preview once it changed.
/// [header]: Optional header comment. Defaults to "GENERATED CODE...".
String androidGlanceReceiverTemplate({
  required String packageName,
  required String widgetClassName,
  bool previewFingerprint = false,
  String? header,
}) {
  final head = header ?? _defaultHeader;

  final buffer = StringBuffer();
  buffer.write('''
$head
package $packageName

''');

  if (previewFingerprint) {
    buffer.writeln('import android.content.Context');
  }

  buffer.write('''
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class ${widgetClassName}Receiver : HomeWidgetGlanceWidgetReceiver<$widgetClassName>() {
  override val glanceAppWidget = $widgetClassName()
''');

  if (previewFingerprint) {
    buffer.write('''

  override fun previewFingerprint(context: Context): String =
      glanceAppWidget.previewFingerprint(context)
''');
  }

  buffer.write('''
}
''');

  return buffer.toString();
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

  final optionalAttributes = <String>[
    if (minResizeWidth != null)
      '    android:minResizeWidth="${minResizeWidth}dp"',
    if (minResizeHeight != null)
      '    android:minResizeHeight="${minResizeHeight}dp"',
    if (maxResizeWidth != null)
      '    android:maxResizeWidth="${maxResizeWidth}dp"',
    if (maxResizeHeight != null)
      '    android:maxResizeHeight="${maxResizeHeight}dp"',
    if (targetCellWidth != null)
      '    android:targetCellWidth="$targetCellWidth"',
    if (targetCellHeight != null)
      '    android:targetCellHeight="$targetCellHeight"',
    if (descriptionResource != null)
      '    android:description="$descriptionResource"',
  ];

  final buffer = StringBuffer();
  buffer.write('''
<?xml version="1.0" encoding="utf-8"?>
$head
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/$initialLayoutName"
    android:minWidth="${minWidth}dp"
    android:minHeight="${minHeight}dp"
    android:updatePeriodMillis="$updatePeriodMillis"
    android:resizeMode="$resizeMode"
    android:widgetCategory="$widgetCategory"
''');

  for (final attribute in optionalAttributes) {
    buffer.writeln(attribute);
  }

  buffer.writeln('/>');

  return buffer.toString();
}
