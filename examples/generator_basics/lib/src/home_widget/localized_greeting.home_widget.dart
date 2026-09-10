// dart format off
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'dart:convert';
import 'package:home_widget/home_widget.dart';

class LocalizedGreetingHomeWidget {
  const LocalizedGreetingHomeWidget._();

  static const String _$appGroupId = 'group.es.antonborri.generatorBasics';

  static const String _$paramPrefix = 'home_widget.LocalizedGreeting';

  /// The translations compiled into the widget for `greeting`.
  ///
  /// `getData` merges anything stored by `saveData` over these, so a
  /// locale the app never pushed still resolves to shipped text.
  static const LocalizedGreetingHomeWidgetTranslations greetingDefaults =
      LocalizedGreetingHomeWidgetTranslations(
        en: 'Hello',
        de: 'Hallo',
        ptBR: 'Olá',
      );

  static Future<void> saveData({
    LocalizedGreetingHomeWidgetTranslations? greeting,
  }) {
    return Future.wait([
      if (greeting != null) HomeWidget.saveWidgetData<String>('${_$paramPrefix}.greeting', jsonEncode(greeting.toMap()), appGroupId: _$appGroupId),
    ]);
  }

  static Future<void> deleteData({
    bool greeting = false,
  }) {
    return Future.wait([
      if (greeting) HomeWidget.saveWidgetData('${_$paramPrefix}.greeting', null, appGroupId: _$appGroupId),
    ]);
  }

  /// Reads every stored value back.
  ///
  /// Localized fields come back fully populated: anything stored by [saveData]
  /// is merged over the compiled defaults, so every locale always has text.
  /// To read the raw stored blob instead — to tell an override apart from a
  /// shipped default — use `HomeWidget.getWidgetData` on the preferences key.
  static Future<({LocalizedGreetingHomeWidgetTranslations greeting})> getData() async {
    return (
      greeting: _$mergeTranslations(greetingDefaults, await _$readLocalized('${_$paramPrefix}.greeting')),
    );
  }


  static Future<bool?> updateWidget() {
    return HomeWidget.updateWidget(
      androidName: 'LocalizedGreetingHomeWidgetReceiver',
      iOSName: 'LocalizedGreetingHomeWidget',
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
      androidName: 'LocalizedGreetingHomeWidgetReceiver',
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
      androidName: 'LocalizedGreetingHomeWidgetReceiver',
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
      return androidClassName.endsWith('.LocalizedGreetingHomeWidgetReceiver');
    }
    return info.iOSKind == 'LocalizedGreetingHomeWidget';
  }

  static Future<Map<String, String>?> _$readLocalized(String key) async {
    final raw = await HomeWidget.getWidgetData<String>(key, appGroupId: _$appGroupId);
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final values = <String, String>{};
    decoded.forEach((locale, value) {
      if (locale is String && value is String) values[locale] = value;
    });
    return values.isEmpty ? null : values;
  }

  static LocalizedGreetingHomeWidgetTranslations _$mergeTranslations(
    LocalizedGreetingHomeWidgetTranslations defaults,
    Map<String, String>? stored,
  ) {
    if (stored == null) return defaults;
    return LocalizedGreetingHomeWidgetTranslations(
      en: stored['en'] ?? defaults.en,
      de: stored['de'] ?? defaults.de,
      ptBR: stored['pt-BR'] ?? defaults.ptBR,
    );
  }
}

class LocalizedGreetingHomeWidgetTranslations {
  const LocalizedGreetingHomeWidgetTranslations({
    required this.en,
    required this.de,
    required this.ptBR,
  });

  final String en;
  final String de;
  final String ptBR;

  Map<String, String> toMap() => {
        'en': en,
        'de': de,
        'pt-BR': ptBR,
      };

  /// The text this set resolves to for the BCP-47 locale [tag].
  ///
  /// Tries the exact tag (`pt-PT`), then the tag with its last subtag
  /// dropped, and so on down to the bare language (`zh-Hant-TW` →
  /// `zh-Hant` → `zh`), then any entry with the same language but a
  /// different region or script (`pt-BR`; the lexicographically
  /// smallest wins if several match), and finally the widget's default
  /// locale. Matching is case-insensitive, and `_` is treated as `-`.
  ///
  /// The widget natively runs these same steps against *every* entry
  /// of the OS preferred-language list in order; this answers for one
  /// explicit tag, which is what previews and tests need.
  String resolve(String tag) {
    final values = {
      for (final entry in toMap().entries)
        entry.key.toLowerCase(): entry.value,
    };
    final normalized = tag.replaceAll('_', '-').toLowerCase();
    var candidate = normalized;
    while (true) {
      final match = values[candidate];
      if (match != null) return match;
      final cut = candidate.lastIndexOf('-');
      if (cut <= 0) break;
      candidate = candidate.substring(0, cut);
    }
    final language = candidate;
    String? sibling;
    for (final key in values.keys) {
      if (key.split('-').first != language) continue;
      if (sibling == null || key.compareTo(sibling) < 0) sibling = key;
    }
    if (sibling != null) {
      final match = values[sibling];
      if (match != null) return match;
    }
    return en;
  }
}
