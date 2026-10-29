// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:generator_basics/interactive_counter.dart' as _$interaction;

class InteractiveCounterHomeWidget {
  const InteractiveCounterHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.InteractiveCounter';

  static Future<void> saveData({
    int? count,
  }) {
    _$ensureInteractivity();
    return Future.wait([
      if (count != null) HomeWidget.saveWidgetData<int>('${_$paramPrefix}.count', count, appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool count = false,
  }) {
    return Future.wait([
      if (count) HomeWidget.saveWidgetData('${_$paramPrefix}.count', null, appGroupId: _$appGroupId),
    ]);
  }

  static Future<({int? count})> getData() async {
    return (
      count: await HomeWidget.getWidgetData<int>('${_$paramPrefix}.count', defaultValue: 0, appGroupId: _$appGroupId),
    );
  }


  static Future<bool?> updateWidget() {
    _$ensureInteractivity();
    return HomeWidget.updateWidget(
      androidName: 'InteractiveCounterHomeWidgetReceiver',
      iOSName: 'InteractiveCounterHomeWidget',
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
      androidName: 'InteractiveCounterHomeWidgetReceiver',
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
      androidName: 'InteractiveCounterHomeWidgetReceiver',
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
      return androidClassName.endsWith('.InteractiveCounterHomeWidgetReceiver');
    }
    return info.iOSKind == 'InteractiveCounterHomeWidget';
  }

  static const String _$interactionKey = 'InteractiveCounterHomeWidget';

  static bool _$interactivityRegistered = false;

  static Future<void>? _$implicitRegistration;

  static bool _$registrationFailureLogged = false;

  /// Registers the function the buttons of this widget run with the plugin.
  ///
  /// `saveData` and `updateWidget` do this themselves, once per isolate.
  /// That neither waits for this nor fails with it. Call it when the app
  /// starts as well: a widget can be placed and tapped before the app updated
  /// it, and its buttons do nothing until this ran once.
  ///
  /// Returns false below iOS 17, where a widget cannot run code on a tap.
  /// Any other error of the plugin, such as a platform without interactive
  /// widgets, is thrown.
  static Future<bool?> registerInteractivity() async {
    try {
      final registered = await HomeWidget.registerInteractivityCallback(
        _$interactiveCounterInteractionEntryPoint,
        key: _$interactionKey,
        appGroupId: _$appGroupId,
      );
      _$interactivityRegistered = true;
      return registered;
    } on PlatformException catch (error) {
      if (error.code != '-5') rethrow;
      _$interactivityRegistered = true;
      debugPrint('The buttons of the Interactive Counter widget need iOS 17 or newer: a tap on them does nothing on this device.');
      return false;
    }
  }

  /// Registers in the background, unless that succeeded or is underway.
  ///
  /// A failure is logged once and tried again on the next call: it may not
  /// last, and the data is written either way.
  static void _$ensureInteractivity() {
    if (_$interactivityRegistered || _$implicitRegistration != null) return;
    _$implicitRegistration = registerInteractivity().then<void>(
      (_) {},
      onError: (Object error) {
        if (_$registrationFailureLogged) return;
        _$registrationFailureLogged = true;
        debugPrint('The buttons of the Interactive Counter widget will not work: registering them with home_widget failed: $error');
      },
    ).whenComplete(() => _$implicitRegistration = null);
  }
}

/// A tap on a button of the Interactive Counter widget.
///
/// The fields of an interaction hold the values the widget was rendered with
/// when it was tapped, which may be older than what the app has stored since.
sealed class InteractiveCounterInteraction {
  const InteractiveCounterInteraction();

  /// The interaction [uri] stands for, or null when it is not one a button of
  /// this widget sends.
  ///
  /// Query parameters the interaction does not know are ignored.
  static InteractiveCounterInteraction? fromUri(Uri uri) => InteractiveCounterDecrementInteraction._$fromUri(uri) ?? InteractiveCounterIncrementInteraction._$fromUri(uri);

  /// The URL the widget sends for this interaction.
  Uri toUri();
}

/// A tap on the `decrement` button of the Interactive Counter widget.
final class InteractiveCounterDecrementInteraction extends InteractiveCounterInteraction {
  const InteractiveCounterDecrementInteraction();

  static final Uri _$url = Uri.parse('homewidget://interaction/decrement?homeWidget');

  static InteractiveCounterDecrementInteraction? _$fromUri(Uri uri) {
    try {
      if (!_$matchesPayloadUrl(uri, _$url)) return null;
      return const InteractiveCounterDecrementInteraction();
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Uri toUri() => _$url;

  @override
  bool operator ==(Object other) => other is InteractiveCounterDecrementInteraction;

  @override
  int get hashCode => (InteractiveCounterDecrementInteraction).hashCode;

  @override
  String toString() => 'InteractiveCounterDecrementInteraction()';
}

/// A tap on the `increment` button of the Interactive Counter widget.
final class InteractiveCounterIncrementInteraction extends InteractiveCounterInteraction {
  const InteractiveCounterIncrementInteraction({this.step = 1});

  final int step;

  static final Uri _$url = Uri.parse('homewidget://interaction/increment?homeWidget');

  static InteractiveCounterIncrementInteraction? _$fromUri(Uri uri) {
    try {
      if (!_$matchesPayloadUrl(uri, _$url)) return null;
      final query = uri.queryParameters;
      return InteractiveCounterIncrementInteraction(step: _$payloadInt(query['step']) ?? 1);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Uri toUri() => _$payloadUri('homewidget://interaction/increment', {'step': step.toString()}, 'homeWidget', '');

  @override
  bool operator ==(Object other) => other is InteractiveCounterIncrementInteraction && other.step == this.step;

  @override
  int get hashCode => Object.hashAll([InteractiveCounterIncrementInteraction, this.step]);

  @override
  String toString() => 'InteractiveCounterIncrementInteraction(step: $step)';
}

@pragma('vm:entry-point')
Future<void> _$interactiveCounterInteractionEntryPoint(Uri? uri) async {
  InteractiveCounterHomeWidget._$interactivityRegistered = true;
  final interaction = uri == null ? null : InteractiveCounterInteraction.fromUri(uri);
  if (interaction != null) await _$interaction.onInteractiveCounterInteraction(interaction);
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
