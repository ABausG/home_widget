part of 'widget_data_validator.dart';

/// The members every class generated around a payload already has, which a
/// payload name would redeclare.
const Set<String> _reservedPayloadNames = {
  'fromUri',
  'hashCode',
  'noSuchMethod',
  'runtimeType',
  'toString',
  'toUri',
};

/// Validates [payload], the values a tap target sends to the app.
///
/// [owner] names what sends them, the way an error spells it, e.g.
/// `HWLink('forecast')`. [inItem] is whether it sits in the item of a list
/// builder, the only place an [HWItemData] has an item to read. [reserved]
/// maps every name the payload cannot use to the reason, which completes the
/// sentence "... is ".
void validatePayload(
  List<HWPayloadEntry> payload, {
  required String owner,
  required bool inItem,
  Map<String, String> reserved = const {},
}) {
  final seen = <String>{};
  for (final entry in payload) {
    final leaf = entry.leaf;
    if (entry.type == null) {
      throw GeneratorError(
        '$owner cannot send ${_describePayloadValue(entry)}. A payload carries '
        'HWString, HWInt, HWDouble, HWBool and HWDateTime values, also as an '
        'HWJson leaf, an HWItemData or an HWTimedData.',
      );
    }
    if (!entry.isNamed && leaf.isFixed) {
      throw GeneratorError(
        '$owner sends ${_spellFixed(leaf)}, which has no name. A fixed value '
        'has no key, so name it: HWPayload("name", ${_spellFixed(leaf)}).',
      );
    }
    if (entry.readsItem && !inItem) {
      throw GeneratorError(
        '$owner sends ${_spellItemRead(entry.value)}, which reads the item a '
        'builder is rendering. There is no item here: it only works inside the '
        'item of an HWColumn.builder or HWRow.builder.',
      );
    }
    _validateFixedPayloadValue(entry, owner);

    final name = entry.name;
    final descriptor = 'payload name of $owner';
    _validateAsciiIdentifier(name, descriptor: descriptor);
    if (_reservedPayloadNames.contains(name)) {
      throw GeneratorError(
        'Invalid data name "$name" ($descriptor): the generated class already '
        'has a member named "$name". Rename it with HWPayload("other", ...).',
      );
    }
    if (reserved[name] case final reason?) {
      throw GeneratorError(
        'Invalid data name "$name" ($descriptor): it is $reason. Rename it '
        'with HWPayload("other", ...).',
      );
    }
    if (!seen.add(name)) {
      throw GeneratorError(
        '$owner sends two values named "$name". The name is the field of the '
        'generated class, so rename one of them with HWPayload("other", ...).',
      );
    }
  }
}

/// Rejects a constant whose content cannot be written into a URL.
void _validateFixedPayloadValue(HWPayloadEntry entry, String owner) {
  final leaf = entry.leaf;
  if (leaf is HWDouble) {
    final value = leaf.fixedValue;
    if (value != null && !value.isFinite) {
      throw GeneratorError(
        '$owner: HWDouble.fixed($value) is not a finite number. Use a finite '
        'value.',
      );
    }
  }
  if (leaf is! HWDateTime) return;
  final iso = leaf.fixedIso;
  if (iso == null) return;
  final parsed = leaf.fixedDateTime;
  if (parsed == null) {
    throw GeneratorError(
      '$owner: HWDateTime.fixed("$iso") is not an ISO 8601 date. '
      '$_isoDateExample',
    );
  }
  if (!parsed.isUtc) {
    throw GeneratorError(
      '$owner: HWDateTime.fixed("$iso") names no time zone, so which instant '
      'it means would depend on where it is read. End it in Z or an offset '
      'such as +02:00. $_isoDateExample',
    );
  }
}

/// What [entry] holds, for the error rejecting its type.
String _describePayloadValue(HWPayloadEntry entry) => switch (entry.leaf) {
      final HWImageData image => 'an image (${_describeImage(image)})',
      HWIconData() => 'the icon "${entry.name}"',
      HWLocalizedString() => 'the localized string "${entry.name}"',
      // coverage:ignore-start
      final leaf => '${leaf.runtimeType}',
      // coverage:ignore-end
    };
