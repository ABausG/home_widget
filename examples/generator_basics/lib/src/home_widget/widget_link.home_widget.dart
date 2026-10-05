// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:home_widget/home_widget.dart';

class WidgetLinkHomeWidget {
  const WidgetLinkHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.WidgetLink';

  static Future<void> saveData({
    String? topic,
  }) {
    return Future.wait([
      if (topic != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.topic', topic, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool topic = false,
  }) {
    return Future.wait([
      if (topic) HomeWidget.saveWidgetData('${_$paramPrefix}.topic', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({String? topic})> getData() async {
    return (
      topic: await HomeWidget.getWidgetData<String>('${_$paramPrefix}.topic', defaultValue: 'Widgets', appGroupId: _$appGroupId),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'WidgetLinkHomeWidgetReceiver',
      iOSName: 'WidgetLinkHomeWidget',
    );
  }

  /// Asks the launcher to re-render this widget's gallery preview.
  ///
  /// Android 15 and newer only; returns false elsewhere and when the system
  /// rate limit (about two updates per hour and widget) was hit. The plugin
  /// registers the preview automatically when the app starts, so this is only
  /// needed after data changes that should show in the gallery right away.
  static Future<bool> updatePreview() async {
    return await HomeWidget.updateWidgetPreview(
      androidName: 'WidgetLinkHomeWidgetReceiver',
    ) ?? false;
  }

  /// Whether the launcher lets the app ask to add this widget to the home
  /// screen: Android 8 or newer with a launcher that supports pinning. Always
  /// false on iOS.
  static Future<bool> isRequestPinWidgetSupported() async {
    return await HomeWidget.isRequestPinWidgetSupported() ?? false;
  }

  /// Asks the launcher to add this widget to the home screen.
  ///
  /// Shows the system pin dialog where [isRequestPinWidgetSupported] is true
  /// and does nothing anywhere else.
  static Future<void> requestPinWidget() {
    return HomeWidget.requestPinWidget(
      androidName: 'WidgetLinkHomeWidgetReceiver',
    );
  }

  /// Every instance of this widget currently placed on a home screen.
  ///
  /// Android reports one entry per placed instance, iOS one entry per family
  /// the widget is placed in.
  static Future<List<HomeWidgetInfo>> getInstalledWidgets() async {
    final widgets = await HomeWidget.getInstalledWidgets();
    return widgets.where(_$isThisWidget).toList();
  }

  /// Whether at least one instance of this widget is on a home screen.
  static Future<bool> isInstalled() async {
    return (await getInstalledWidgets()).isNotEmpty;
  }

  /// Whether [info] describes this widget.
  ///
  /// Android reports the provider's short class name — `.Receiver` when it
  /// lives in the package of the application id, and the qualified name
  /// otherwise — which is why the suffix is matched.
  static bool _$isThisWidget(HomeWidgetInfo info) {
    final androidClassName = info.androidClassName;
    if (androidClassName != null) {
      return androidClassName.endsWith('.WidgetLinkHomeWidgetReceiver');
    }
    return info.iOSKind == 'WidgetLinkHomeWidget';
  }

  /// The tap on this widget the app was started by, or null when it was
  /// started any other way.
  static Future<WidgetLinkLaunch?> initialLaunch() => HomeWidget.initialLaunch(WidgetLinkLaunch.fromUri);

  /// Every tap on this widget that opens the app.
  ///
  /// Emits the tap that started the app first, if one did, then every tap
  /// while it runs. A tap on any other widget is not reported.
  static Stream<WidgetLinkLaunch> launches() => HomeWidget.launches(WidgetLinkLaunch.fromUri);

  /// The URL a tap on the widget opens the app with while it sends no data
  /// along, as the app will receive it.
  @Deprecated('Use launches() and initialLaunch() instead.')
  static final Uri widgetUrl = Uri.parse('generatorBasics://link?homeWidget');

  /// The URL the app was launched with by a tap on the widget, or null
  /// when it was started any other way.
  @Deprecated('Use launches() and initialLaunch() instead.')
  static Future<Uri?> initiallyLaunchedFromWidget() => HomeWidget.initialLaunch(_$widgetTapUri);

  /// The URL of every tap on the widget while the app is running.
  @Deprecated('Use launches() and initialLaunch() instead.')
  static Stream<Uri> get widgetClicked =>
      HomeWidget.widgetClicked
          .where((uri) => uri != null && _$widgetTapUri(uri) != null)
          .cast<Uri>();

  /// Every tap on the widget, launch included.
  @Deprecated('Use launches() and initialLaunch() instead.')
  static Stream<Uri> launchedFromWidget() => HomeWidget.launches(_$widgetTapUri);

  static Uri? _$widgetTapUri(Uri uri) => WidgetLinkWidgetTap._$fromUri(uri) == null ? null : uri;
}

/// A tap on the Widget Link widget that opened the app.
sealed class WidgetLinkLaunch {
  const WidgetLinkLaunch();

  /// The launch [uri] stands for, or null when it is not a URL this widget
  /// opens the app with.
  ///
  /// Query parameters the launch does not know are ignored.
  static WidgetLinkLaunch? fromUri(Uri uri) => WidgetLinkWidgetTap._$fromUri(uri) ?? WidgetLinkTopicLink._$fromUri(uri) ?? WidgetLinkSettingsLink._$fromUri(uri);

  /// The URL the widget opens the app with for this launch.
  Uri toUri();
}

/// A tap on the Widget Link widget itself.
final class WidgetLinkWidgetTap extends WidgetLinkLaunch {
  const WidgetLinkWidgetTap();

  static final Uri _$url = Uri.parse('generatorBasics://link?homeWidget');

  static WidgetLinkWidgetTap? _$fromUri(Uri uri) {
    if (!_$matchesPayloadUrl(uri, _$url)) return null;
    return const WidgetLinkWidgetTap();
  }

  @override
  Uri toUri() => _$url;

  @override
  bool operator ==(Object other) => other is WidgetLinkWidgetTap;

  @override
  int get hashCode => (WidgetLinkWidgetTap).hashCode;

  @override
  String toString() => 'WidgetLinkWidgetTap()';
}

/// A tap on the `topic` link of the Widget Link widget.
final class WidgetLinkTopicLink extends WidgetLinkLaunch {
  const WidgetLinkTopicLink({this.topic = 'Widgets', this.position = 1});

  final String topic;
  final int position;

  static final Uri _$url = Uri.parse('generatorBasics://topic?homeWidget');

  static WidgetLinkTopicLink? _$fromUri(Uri uri) {
    if (!_$matchesPayloadUrl(uri, _$url)) return null;
    final query = uri.queryParameters;
    return WidgetLinkTopicLink(topic: query['topic'] ?? 'Widgets', position: _$payloadInt(query['position']) ?? 1);
  }

  @override
  Uri toUri() => _$payloadUri('generatorBasics://topic', {'topic': topic, 'position': position.toString()}, 'homeWidget', '');

  @override
  bool operator ==(Object other) => other is WidgetLinkTopicLink && other.topic == this.topic && other.position == this.position;

  @override
  int get hashCode => Object.hashAll([WidgetLinkTopicLink, topic, position]);

  @override
  String toString() => 'WidgetLinkTopicLink(topic: $topic, position: $position)';
}

/// A tap on the `settings` link of the Widget Link widget.
final class WidgetLinkSettingsLink extends WidgetLinkLaunch {
  const WidgetLinkSettingsLink();

  static final Uri _$url = Uri.parse('generatorBasics://settings?homeWidget');

  static WidgetLinkSettingsLink? _$fromUri(Uri uri) {
    if (!_$matchesPayloadUrl(uri, _$url)) return null;
    return const WidgetLinkSettingsLink();
  }

  @override
  Uri toUri() => _$url;

  @override
  bool operator ==(Object other) => other is WidgetLinkSettingsLink;

  @override
  int get hashCode => (WidgetLinkSettingsLink).hashCode;

  @override
  String toString() => 'WidgetLinkSettingsLink()';
}

/// Whether [uri] is the URL [url] with any payload: scheme, authority, path
/// and fragment are the same, and every query parameter of [url] is there.
bool _$matchesPayloadUrl(Uri uri, Uri url) {
  if (uri.scheme != url.scheme ||
      uri.authority != url.authority ||
      uri.path != url.path ||
      uri.fragment != url.fragment) {
    return false;
  }
  final query = uri.queryParametersAll;
  for (final entry in url.queryParametersAll.entries) {
    if (entry.key == 'homeWidget') continue;
    final values = query[entry.key];
    if (values == null || values.length != entry.value.length) return false;
    for (var index = 0; index < values.length; index++) {
      if (values[index] != entry.value[index]) return false;
    }
  }
  return true;
}

/// [head] with every value of [payload] that is there appended as a query
/// parameter, then [marker] and [fragment].
Uri _$payloadUri(String head, Map<String, String?> payload, String marker, String fragment) {
  final url = StringBuffer(head);
  var separator = head.contains('?') ? '&' : '?';
  payload.forEach((name, value) {
    if (value == null) return;
    url.write('$separator$name=${Uri.encodeComponent(value)}');
    separator = '&';
  });
  if (marker.isNotEmpty) url.write('$separator$marker');
  url.write(fragment);
  return Uri.parse(url.toString());
}

int? _$payloadInt(String? value) => value == null ? null : int.tryParse(value);
