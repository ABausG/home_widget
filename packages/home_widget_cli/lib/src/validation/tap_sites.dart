part of 'widget_data_validator.dart';

/// One place a tap target, an [HWLink] or an [HWButton], sits in a widget
/// tree.
class _TapSite<T extends HWSingleChildWidget> {
  final T target;

  /// Whether the target sits in the item of a list builder.
  final bool inItem;

  /// The choices made on the way down to the target: each widget rendering
  /// one of several subtrees, with the index of the one the target is in.
  final List<(HWWidget, int)> choices;

  const _TapSite(this.target, {required this.inItem, required this.choices});

  /// Whether this target and [other] can never render together, because some
  /// widget above both renders the subtree of one or of the other.
  bool excludes(_TapSite<T> other) => choices.any(
        (mine) => other.choices.any(
          (theirs) => identical(mine.$1, theirs.$1) && mine.$2 != theirs.$2,
        ),
      );
}

/// How an error spells [target].
String _spellTapTarget(HWSingleChildWidget target) => switch (target) {
      HWLink(:final id) => "HWLink('$id')",
      HWButton(:final id) => "HWButton('$id')",
      // coverage:ignore-start
      _ => '${target.runtimeType}',
      // coverage:ignore-end
    };

/// Every [HWLink] and [HWButton] of [spec], each in document order, rejecting
/// one inside another.
({List<_TapSite<HWLink>> links, List<_TapSite<HWButton>> buttons}) _tapSites(
  WidgetSpec spec,
  String widget,
) {
  final links = <_TapSite<HWLink>>[];
  final buttons = <_TapSite<HWButton>>[];

  void walk(
    HWWidget node,
    List<(HWWidget, int)> choices, {
    required bool inItem,
    required HWSingleChildWidget? enclosing,
  }) {
    if (node is HWLink || node is HWButton) {
      final target = node as HWSingleChildWidget;
      if (enclosing != null) {
        final nested = '$widget: ${_spellTapTarget(target)} sits inside '
            '${_spellTapTarget(enclosing)}.';
        throw GeneratorError(
          switch ((target, enclosing)) {
            (HWLink(), HWLink()) => '$nested A tap opens one URL, so a link '
                'cannot contain another one.',
            (HWButton(), HWButton()) => '$nested A tap runs one interaction, '
                'so a button cannot contain another one.',
            _ => '$nested A tap either opens the app or runs Dart code '
                'without opening it, so a link and a button cannot contain '
                'each other.',
          },
        );
      }
      if (target is HWLink) {
        links.add(_TapSite(target, inItem: inItem, choices: choices));
      } else if (target is HWButton) {
        buttons.add(_TapSite(target, inItem: inItem, choices: choices));
      }
      walk(target.child, choices, inItem: inItem, enclosing: target);
      return;
    }

    final item = node is HWFlex ? node.item : null;
    final branches = switch (node) {
      HWConditional() => [node.firstBranch, node.secondBranch],
      HWAdaptive() => [node.ios, node.android],
      HWSizeAdaptive() => node.childWidgets,
      HWFlex(:final whenEmpty?) when item != null => [item, whenEmpty],
      _ => null,
    };
    if (branches != null) {
      final walked = <HWWidget>[];
      for (final (index, branch) in branches.indexed) {
        // One widget written into two slots is one place in the tree.
        if (walked.any((other) => identical(other, branch))) continue;
        walked.add(branch);
        walk(
          branch,
          [...choices, (node, index)],
          inItem: inItem || (item != null && index == 0),
          enclosing: enclosing,
        );
      }
      return;
    }

    for (final child in node.childWidgets) {
      walk(
        child,
        choices,
        inItem: inItem || identical(child, item),
        enclosing: enclosing,
      );
    }
  }

  walk(spec.effectiveWidgetTree, const [], inItem: false, enclosing: null);
  return (links: links, buttons: buttons);
}

/// Whether [a] and [b] are the same URL with a payload of the same shape.
bool _samePayloadUrl(HWPayloadUrl a, HWPayloadUrl b) {
  if (a.url != b.url || a.payload.length != b.payload.length) return false;
  final theirs = {for (final entry in b.payload) entry.name: entry};
  return a.payload.every((entry) {
    final other = theirs[entry.name];
    return other != null && entry.hasSameShapeAs(other);
  });
}

/// The first two of [sites] generating one class without being the same
/// target, or null when every class is generated once.
///
/// [className] names the class a target generates. Two targets are the same
/// when only one of them can ever render and both carry the same payload;
/// `exclusive` is false when the two can render together, and true when only
/// their payloads differ. A target is checked against every earlier one of
/// its class.
({_TapSite<T> first, _TapSite<T> second, bool exclusive})?
    _conflictingTapSites<T extends HWSingleChildWidget>(
  List<_TapSite<T>> sites, {
  required String Function(T target) className,
  required HWPayloadUrl Function(T target) payloadUrl,
}) {
  final seen = <String, List<_TapSite<T>>>{};
  for (final site in sites) {
    final earlier = seen.putIfAbsent(className(site.target), () => []);
    for (final existing in earlier) {
      final exclusive = existing.excludes(site);
      if (exclusive &&
          _samePayloadUrl(
            payloadUrl(existing.target),
            payloadUrl(site.target),
          )) {
        continue;
      }
      return (first: existing, second: site, exclusive: exclusive);
    }
    earlier.add(site);
  }
  return null;
}
