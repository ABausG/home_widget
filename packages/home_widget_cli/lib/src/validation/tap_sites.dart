part of 'widget_data_validator.dart';

/// One place a tap target, an [HWLink] or an [HWButton], sits in a widget
/// tree.
class _TapSite<T extends HWSingleChildWidget> {
  final T target;

  /// Whether the target sits in the item of a list builder.
  final bool inItem;

  const _TapSite(this.target, {required this.inItem});
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
    HWWidget node, {
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
        links.add(_TapSite(target, inItem: inItem));
      } else if (target is HWButton) {
        buttons.add(_TapSite(target, inItem: inItem));
      }
      walk(target.child, inItem: inItem, enclosing: target);
      return;
    }

    final item = node is HWFlex ? node.item : null;
    final branches = switch (node) {
      HWConditional() => [node.firstBranch, node.secondBranch],
      HWAdaptive() => [node.ios, node.android],
      HWSizeAdaptive() || HWAppearanceAdaptive() => node.childWidgets,
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
          inItem: inItem || (item != null && index == 0),
          enclosing: enclosing,
        );
      }
      return;
    }

    for (final child in node.childWidgets) {
      walk(
        child,
        inItem: inItem || identical(child, item),
        enclosing: enclosing,
      );
    }
  }

  walk(spec.effectiveWidgetTree, inItem: false, enclosing: null);
  return (links: links, buttons: buttons);
}

/// Rejects [target] sending a value of [payload] under a name an earlier
/// target of its id sends as another type, adding the types it sends to
/// [sent], the types of the earlier ones by name.
///
/// Targets sharing an id reach the app as one class with one field per name.
void _validateSharedPayloadTypes(
  HWSingleChildWidget target,
  List<HWPayloadEntry> payload,
  Map<String, HWPayloadType> sent, {
  required String widget,
}) {
  final (kind, remedy) = switch (target) {
    HWLink() => ('Links', 'give the links different ids and urls'),
    _ => ('Buttons', 'give the buttons different ids'),
  };
  final spelled = _spellTapTarget(target);
  for (final entry in payload) {
    final type = entry.type!;
    final other = sent.putIfAbsent(entry.name, () => type);
    if (other == type) continue;
    throw GeneratorError(
      '$widget: $spelled sends "${entry.name}" as an ${_hwTypeName(type)}, '
      'where another $spelled sends it as an ${_hwTypeName(other)}. $kind '
      'sharing an id reach the app as one class with one field per name, so '
      'send "${entry.name}" as one type, send one of them under another name, '
      'or $remedy.',
    );
  }
}

/// The data type a schema writes a value of [type] as.
String _hwTypeName(HWPayloadType type) => switch (type) {
      HWPayloadType.string => 'HWString',
      HWPayloadType.int => 'HWInt',
      HWPayloadType.double => 'HWDouble',
      HWPayloadType.bool => 'HWBool',
      HWPayloadType.dateTime => 'HWDateTime',
    };
