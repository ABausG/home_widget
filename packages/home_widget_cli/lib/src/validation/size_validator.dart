import 'package:home_widget_generator/home_widget_generator.dart';

import '../models/widget_spec.dart';
import '../util/logger.dart';

/// Validates the [HWSizeAdaptive] instances of [spec] against the families the
/// widget can actually be shown in.
///
/// A reachable family without content is an error, because the widget would
/// render nothing there; content no family reaches is a warning, because it
/// only ever costs the developer their layout.
void validateSizeAdaptive(WidgetSpec spec) {
  final iosSites = spec.iosSizeAdaptiveSites;
  final androidSites = spec.androidSizeAdaptiveSites;
  if (iosSites.isEmpty && androidSites.isEmpty) return;

  final adaptives = <HWSizeAdaptive>[];
  for (final site in [...iosSites, ...androidSites]) {
    if (adaptives.any((other) => identical(other, site.adaptive))) continue;
    adaptives.add(site.adaptive);
  }

  _validateAndroidSizes(spec, adaptives);
  _validateMissingContent(spec, iosSites, androidSites);
  _warnUnreachableSlots(spec, adaptives, iosSites, androidSites);
  _warnSlotShapes(spec, adaptives, iosSites, androidSites);
}

/// Rejects `androidSizes` that no resolved size table could be built from, and
/// warns about a family that an override made smaller than its own fallback.
void _validateAndroidSizes(WidgetSpec spec, List<HWSizeAdaptive> adaptives) {
  final declared = <HWWidgetFamily, HWSize>{};
  final conflicts = <HWWidgetFamily, (HWSize, HWSize)>{};

  for (final adaptive in adaptives) {
    final sizes = adaptive.androidSizes;
    if (sizes == null) continue;

    for (final family in HWWidgetFamily.values) {
      final size = sizes[family];
      if (size == null) continue;

      if (family.isAccessory) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWSizeAdaptive.androidSizes has an '
          'entry for ${family.name}. Android has no accessory families, so '
          'only the system families can be given a size.',
        );
      }
      if (size.width <= 0 || size.height <= 0) {
        throw GeneratorError(
          'Widget "${spec.data.name}": HWSizeAdaptive.androidSizes gives '
          '${family.name} $size. A width and a height must be greater than 0.',
        );
      }

      final existing = declared[family];
      if (existing != null && existing != size) {
        conflicts[family] ??= (existing, size);
      }
      declared[family] = size;
    }
  }

  for (final entry in conflicts.entries) {
    final (first, second) = entry.value;
    throw GeneratorError(
      'Widget "${spec.data.name}": two HWSizeAdaptive instances give '
      '${entry.key.name} different androidSizes ($first and $second). sizeMode '
      'is declared once per widget, so an override applies to the whole tree '
      'and every instance has to agree.',
    );
  }

  // The resolved table only reaches a generated widget through the Android
  // sources, so it is only worth reasoning about when there are any.
  if (spec.data.android == null) return;

  final table = spec.androidSizeTable;

  final bySize = <HWSize, HWWidgetFamily>{};
  for (final family in HWWidgetFamily.values) {
    final size = table[family];
    if (size == null) continue;
    final clash = bySize[size];
    if (clash != null) {
      throw GeneratorError(
        'Widget "${spec.data.name}": ${clash.name} and ${family.name} both '
        'declare $size on Android. Glance cannot tell two identical sizes '
        'apart, so give them different androidSizes.',
      );
    }
    bySize[size] = family;
  }

  for (final family in HWWidgetFamily.values) {
    final size = table[family];
    if (size == null) continue;
    for (final fallback in family.fallbackChain) {
      final fallbackSize = table[fallback];
      if (fallbackSize == null) continue;
      if (size.width >= fallbackSize.width &&
          size.height >= fallbackSize.height) {
        continue;
      }
      logger.warn(
        'Warning: Widget "${spec.data.name}": androidSizes make '
        '${family.name} ($size) smaller than its fallback ${fallback.name} '
        '($fallbackSize). Content written for ${fallback.name} would be '
        'rendered in a smaller box.',
      );
    }
  }
}

/// Rejects an [HWSizeAdaptive] that renders nothing for a family the widget
/// can be shown in, naming every such family in one error.
void _validateMissingContent(
  WidgetSpec spec,
  List<HWSizeAdaptiveSite> iosSites,
  List<HWSizeAdaptiveSite> androidSites,
) {
  Set<HWWidgetFamily> missing(List<HWSizeAdaptiveSite> sites) => {
        for (final site in sites)
          for (final family in site.visible)
            if (site.adaptive.resolve(family) == null) family,
      };

  final onIos = missing(iosSites);
  final onAndroid = missing(androidSites);
  if (onIos.isEmpty && onAndroid.isEmpty) return;

  final message = StringBuffer();
  for (final family in HWWidgetFamily.values) {
    final where = <String>[
      if (onIos.contains(family)) 'iOS',
      if (onAndroid.contains(family)) 'Android',
    ];
    if (where.isEmpty) continue;
    message.writeln(
      'HWSizeAdaptive has no content for ${family.name}, which '
      '"${spec.data.name}" supports on ${_joinWithAnd(where)}. '
      '${_addSlotAdvice(family)}',
    );
  }
  throw GeneratorError(message.toString().trimRight());
}

/// Warns about a slot no reachable family ever renders.
void _warnUnreachableSlots(
  WidgetSpec spec,
  List<HWSizeAdaptive> adaptives,
  List<HWSizeAdaptiveSite> iosSites,
  List<HWSizeAdaptiveSite> androidSites,
) {
  final onIosPlatform = spec.data.iOS != null;
  final onAndroidPlatform = spec.data.android != null;
  final iosTopLevel = _iosCause(spec);
  final androidTopLevel = _androidCause(spec);

  for (final adaptive in adaptives) {
    final onIos = _siteFor(iosSites, adaptive);
    final onAndroid = _siteFor(androidSites, adaptive);

    for (final family in HWWidgetFamily.values) {
      final slot = adaptive.slotFor(family);
      if (slot == null) continue;

      final rendersFor = <HWWidgetFamily>{
        if (onIos != null) ...adaptive.familiesResolvingTo(slot, onIos.visible),
        if (onAndroid != null)
          ...adaptive.familiesResolvingTo(slot, onAndroid.visible),
      };
      if (rendersFor.isNotEmpty) continue;

      logger.warn(
        'Warning: HWSizeAdaptive slot `${family.slotName}` in '
        '"${spec.data.name}" is never rendered: '
        '${_siteCause(onIos, 'iOS', iosTopLevel, generated: onIosPlatform)} '
        'and ${_siteCause(
          onAndroid,
          'Android',
          androidTopLevel,
          generated: onAndroidPlatform,
        )}.',
      );
    }
  }
}

/// Warns about slot content a family cannot render the way it is written.
void _warnSlotShapes(
  WidgetSpec spec,
  List<HWSizeAdaptive> adaptives,
  List<HWSizeAdaptiveSite> iosSites,
  List<HWSizeAdaptiveSite> androidSites,
) {
  for (final adaptive in adaptives) {
    final inline = adaptive.accessoryInline;
    if (inline == null || _isInlineSlot(inline)) continue;
    logger.warn(
      'Warning: Widget "${spec.data.name}": the `accessoryInline` slot of '
      'HWSizeAdaptive is a ${inline.runtimeType}. The inline accessory '
      'renders a single line, so WidgetKit drops anything that is not an '
      'HWText, an HWImage, or an HWRow of those.',
    );
  }

  final allSites = [...iosSites, ...androidSites];
  final nested = <HWSizeAdaptive>[];
  for (final site in allSites) {
    final slot = site.enclosingSlot;
    if (slot == null) continue;
    if (nested.any((other) => identical(other, site.adaptive))) continue;
    nested.add(site.adaptive);

    final visible = <HWWidgetFamily>{
      for (final other in allSites)
        if (identical(other.adaptive, site.adaptive)) ...other.visible,
    };
    final families = visible.isEmpty
        ? 'no family the widget is generated for'
        : _ordered(visible).map((f) => f.name).join(', ');

    logger.warn(
      'Warning: Widget "${spec.data.name}": an HWSizeAdaptive sits inside the '
      '`${slot.slotName}` slot of another one, which only renders for '
      '$families. The inner one can never see another family.',
    );
  }
}

/// Where [adaptive] sits in [sites], or null when that platform never renders
/// it at all.
HWSizeAdaptiveSite? _siteFor(
  List<HWSizeAdaptiveSite> sites,
  HWSizeAdaptive adaptive,
) {
  for (final site in sites) {
    if (identical(site.adaptive, adaptive)) return site;
  }
  return null;
}

/// Why [site] renders what it renders on [platform], where [topLevel] is the
/// reason for an instance the widget root reaches directly.
///
/// A platform the widget is not [generated] for has one reason for everything,
/// which [topLevel] already carries.
String _siteCause(
  HWSizeAdaptiveSite? site,
  String platform,
  String topLevel, {
  required bool generated,
}) {
  if (!generated) return topLevel;
  if (site == null) return 'not rendered on $platform';

  final slot = site.enclosingSlot;
  if (slot == null) return topLevel;

  final families = _ordered(site.visible).map((f) => f.name).join(', ');
  return 'on $platform its enclosing `${slot.slotName}` slot only renders for '
      '[$families]';
}

/// How to give [family] content of its own, naming the fallbacks that would
/// cover it too.
String _addSlotAdvice(HWWidgetFamily family) {
  final slot = '`${family.slotName}`';
  final article = _article(family.slotName);
  final fallbacks = family.fallbackChain;
  if (fallbacks.isEmpty) return 'Add $article $slot slot.';

  final names = fallbacks.map((f) => '`${f.slotName}`').join(', ');
  return 'Add $article $slot slot or one of its fallbacks ($names).';
}

String _iosCause(WidgetSpec spec) {
  if (spec.data.iOS == null) return 'not generated for iOS';
  final families =
      _ordered(spec.iosReachableFamilies).map((f) => f.name).join(', ');
  return 'iOS supports [$families]';
}

String _androidCause(WidgetSpec spec) {
  if (spec.data.android == null) return 'not generated for Android';

  final max = spec.androidMaxSize;
  if (max.width != null && max.height != null) {
    return 'the Android configuration caps the widget at '
        '${HWSize.dimension(max.width!)} × ${HWSize.dimension(max.height!)} dp';
  }

  final min = spec.androidMinSize;
  return 'the Android configuration keeps the widget at '
      '${HWSize.dimension(min.width)} × ${HWSize.dimension(min.height)} dp or '
      'larger';
}

/// [families] in enum order, so a message reads the same on every run.
List<HWWidgetFamily> _ordered(Iterable<HWWidgetFamily> families) => [
      for (final family in HWWidgetFamily.values)
        if (families.contains(family)) family,
    ];

/// Whether [slot] is something the inline accessory can render.
bool _isInlineSlot(HWWidget slot) {
  if (_isInlineContent(slot)) return true;
  if (slot is HWRow) return slot.children.every(_isInlineContent);
  return false;
}

bool _isInlineContent(HWWidget widget) => widget is HWText || widget is HWImage;

const _vowels = {'a', 'e', 'i', 'o', 'u'};

String _article(String word) =>
    _vowels.contains(word[0].toLowerCase()) ? 'an' : 'a';

String _joinWithAnd(List<String> values) =>
    values.length == 1 ? values.single : values.join(' and ');
