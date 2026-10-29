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

/// Rejects two buttons generating one interaction class unless they are the
/// same target: only one of them can ever render, and both send the same
/// payload.
void _validateButtonIds(
  WidgetSpec spec,
  List<_TapSite<HWButton>> sites,
  String widget,
) {
  final conflict = _conflictingTapSites(
    sites,
    className: spec.buttonClassName,
    payloadUrl: (button) => button.payloadUrl,
  );
  if (conflict == null) return;

  final button = conflict.second.target;
  final other = conflict.first.target;
  final ids = other.id == button.id
      ? "HWButton('${button.id}') is declared twice"
      : "HWButton('${other.id}') and HWButton('${button.id}') both generate "
          '${spec.buttonClassName(button)}';
  if (!conflict.exclusive) {
    throw GeneratorError(
      '$widget: $ids. A button id is unique within a widget; it may only '
      'repeat across the branches of a conditional or the slots of an '
      'HWSizeAdaptive, where one of them renders at a time.',
    );
  }
  throw GeneratorError(
    '$widget: $ids, but with different data. Both reach the app as the same '
    'interaction class, so give them the same data, or different ids.',
  );
}
