package es.antonborri.configurable_widget

import io.flutter.embedding.android.FlutterActivity

/** Hosts the widget configuration UI; uses Dart [configureMain] instead of [main]. */
class WidgetConfigurationActivity : FlutterActivity() {
  override fun getDartEntrypointFunctionName(): String = "configureMain"
}
