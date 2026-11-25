import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';

/// One field of a generated payload class: the value the tap targets of the
/// class send under [name].
class PayloadField {
  /// The name the value is sent under, which names the field.
  final String name;

  /// The type the value travels as.
  final HWPayloadType type;

  /// The Dart literal a missing or unreadable value falls back on, or null
  /// where the targets share none: one of them sends a stored value without
  /// a default or nothing under [name], or they fall back on different
  /// values.
  final String? fallback;

  /// Creates a [PayloadField].
  const PayloadField({
    required this.name,
    required this.type,
    this.fallback,
  });

  /// Whether the app may receive no value, which is where there is no
  /// [fallback].
  bool get isNullable => fallback == null;

  /// The fields of a class one target sends [payload] for, in order.
  static List<PayloadField> listOf(List<HWPayloadEntry> payload) =>
      merge([payload]);

  /// The fields of a class every one of [payloads] is sent for, one per name
  /// in the order the names first appear.
  ///
  /// A field takes the type of the first entry of its name, and an entry no
  /// payload can carry is left out; the validator rejects both a name sent
  /// as two types and such an entry. A field falls back only where every one
  /// of [payloads] sends its name and all of them fall back on the same
  /// value.
  static List<PayloadField> merge(List<List<HWPayloadEntry>> payloads) {
    final sent = <String, List<HWPayloadEntry>>{};
    for (final payload in payloads) {
      for (final entry in payload) {
        if (entry.type == null) continue;
        sent.putIfAbsent(entry.name, () => []).add(entry);
      }
    }
    return [
      for (final MapEntry(key: name, value: entries) in sent.entries)
        _merged(
          name,
          entries,
          sentByAll: payloads.every(
            (payload) => payload.any((entry) => entry.name == name),
          ),
        ),
    ];
  }

  static PayloadField _merged(
    String name,
    List<HWPayloadEntry> entries, {
    required bool sentByAll,
  }) {
    final fallbacks = {for (final entry in entries) _fallbackOf(entry)};
    return PayloadField(
      name: name,
      type: entries.first.type!,
      fallback: sentByAll && fallbacks.length == 1 ? fallbacks.single : null,
    );
  }

  /// The Dart literal [entry] falls back on where it is never null: its
  /// constant or its default value. Null for a nullable one.
  static String? _fallbackOf(HWPayloadEntry entry) {
    if (entry.isNullable) return null;
    final leaf = entry.leaf;
    if (leaf is HWDateTime) {
      final millis = leaf.fixedDateTime!.toUtc().millisecondsSinceEpoch;
      return 'DateTime.fromMillisecondsSinceEpoch($millis, isUtc: true)';
    }
    final value = entry.isFixed ? entry.fixedWireValue! : leaf.defaultValue;
    return switch (entry.type!) {
      HWPayloadType.string => "'${escapeDartStringLiteral('$value')}'",
      HWPayloadType.int => dartIntLiteral(int.parse('$value')),
      _ => '$value',
    };
  }
}
