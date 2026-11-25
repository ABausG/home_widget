part of 'widget_data_validator.dart';

/// Validates everything a tap on an [HWButton] of [spec] sends to the app's
/// interaction function.
///
/// Runs after [validateLaunches], which rejects a button and a link inside
/// one another, and ahead of the list checks, so that an [HWItemData] in a
/// payload is reported for what it is.
void validateInteractions(WidgetSpec spec) {
  final widget = 'Widget "${spec.data.name}"';
  final sites = _tapSites(spec, widget).buttons;

  if (sites.isEmpty) {
    if (spec.interactionHandler != null) {
      logger.warn(
        'Warning: $widget sets onInteraction, but has no HWButton to call it. '
        'Wrap what should be tapped in an HWButton, or remove onInteraction.',
      );
    }
    return;
  }

  if (spec.interactionHandler == null) {
    throw GeneratorError(
      "$widget: HWButton('${sites.first.target.id}') has no function to "
      'call. Set onInteraction on the @HomeWidget annotation to a top-level '
      'or static function taking a ${spec.interactionClassName}.',
    );
  }

  for (final site in sites) {
    final button = site.target;
    if (!asciiDataNamePattern.hasMatch(button.id)) {
      throw GeneratorError(
        '$widget: invalid HWButton id "${button.id}". The id names the '
        'generated interaction class, so use ASCII letters and digits only, '
        'starting with a letter.',
      );
    }
    _validateUrlPayload(
      button.payloadUrl,
      owner: "$widget: HWButton('${button.id}')",
      className: spec.buttonClassName(button),
      inItem: site.inItem,
    );
  }

  _validateButtonIds(spec, sites, widget);

  final inline = spec.iosInlineButtons;
  if (inline.isEmpty) return;
  final ids = {for (final button in inline) "HWButton('${button.id}')"};
  logger.warn(
    'Warning: $widget can be shown as accessoryInline on iOS, which shows '
    'text only: ${ids.join(', ')} cannot be tapped there and its child '
    'renders without the button. Android is not affected. Put the button in '
    'an HWSizeAdaptive slot of another family to silence this warning.',
  );
}

/// Rejects two buttons generating one interaction class under different ids,
/// and buttons of one id sending a value of one name as different types.
///
/// Buttons sharing an id may render together and send different data: they
/// reach the app as one class with a field per name any of them sends.
void _validateButtonIds(
  WidgetSpec spec,
  List<_TapSite<HWButton>> sites,
  String widget,
) {
  final ids = <String, String>{};
  final types = <String, Map<String, HWPayloadType>>{};
  for (final site in sites) {
    final button = site.target;
    final className = spec.buttonClassName(button);
    final id = ids.putIfAbsent(className, () => button.id);
    if (id != button.id) {
      throw GeneratorError(
        "$widget: HWButton('$id') and HWButton('${button.id}') both generate "
        '$className, with ids that differ only in letter case. A tap sends '
        'the id as written and the app tells the interactions apart by it, so '
        'two spellings cannot be one button. Spell the id the same way in '
        'both, or give them ids that differ in more than case.',
      );
    }
    final sent = types.putIfAbsent(className, () => {});
    for (final entry in button.payloadUrl.payload) {
      final type = entry.type!;
      final other = sent.putIfAbsent(entry.name, () => type);
      if (other == type) continue;
      throw GeneratorError(
        "$widget: HWButton('${button.id}') sends \"${entry.name}\" as an "
        "${_hwTypeName(type)}, where another HWButton('${button.id}') sends "
        'it as an ${_hwTypeName(other)}. Buttons sharing an id reach the app '
        'as one class with one field per name, so send "${entry.name}" as '
        'one type, send one of them under another name, or give the buttons '
        'different ids.',
      );
    }
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
