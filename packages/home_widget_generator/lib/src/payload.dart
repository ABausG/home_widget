import 'native_helpers.dart';
import 'types.dart';
import 'utils/string_literals.dart';

/// The types a payload value can have.
enum HWPayloadType {
  string('String'),
  int('int'),
  double('double'),
  bool('bool'),
  dateTime('DateTime');

  const HWPayloadType(this.dartType);

  /// The Dart type a value of this type is handed to the app as.
  final String dartType;
}

/// One named value a tap target sends to the app.
///
/// Built from an entry of a `data` list: a stored value sent under its key, or
/// an [HWPayload] naming any value. The same entry describes the native code
/// writing the value into a URL and the Dart code reading it back.
class HWPayloadEntry {
  /// The name the value is sent under.
  final String name;

  /// The value itself, without the [HWPayload] naming it.
  final HWDataType<dynamic> value;

  /// Whether an [HWPayload] gave [name], rather than the key of [value].
  final bool isNamed;

  const HWPayloadEntry._(this.name, this.value, {required this.isNamed});

  /// The entry [data], one element of a `data` list, describes.
  factory HWPayloadEntry.of(HWDataType<dynamic> data) {
    if (data is HWPayload<dynamic>) {
      return HWPayloadEntry._(data.name, data.value, isNamed: true);
    }
    return HWPayloadEntry._(data.leaf.key, data, isNamed: false);
  }

  /// The entries of [data], in order.
  static List<HWPayloadEntry> listOf(Iterable<HWDataType<dynamic>> data) =>
      [for (final entry in data) HWPayloadEntry.of(entry)];

  /// The plain type [value] ends at, whatever it is wrapped in.
  HWDataType<dynamic> get leaf => value.leaf;

  /// Whether [value] is a constant rather than something the app stores.
  bool get isFixed => leaf.isFixed;

  /// Whether [value] is read off the item of a list builder.
  bool get readsItem => value.unwrapped is HWItemData;

  /// The type the value travels as, or null for one a payload cannot carry:
  /// an image, an icon, or a localized string.
  HWPayloadType? get type => switch (leaf) {
        HWLocalizedString() => null,
        HWString() => HWPayloadType.string,
        HWInt() => HWPayloadType.int,
        HWDouble() => HWPayloadType.double,
        HWBool() => HWPayloadType.bool,
        HWDateTime() => HWPayloadType.dateTime,
        _ => null,
      };

  /// Whether the app may receive no value: a stored one without a default.
  bool get isNullable => !isFixed && leaf.defaultValue == null;

  /// The text a fixed [value] travels as, or null for a stored one and for a
  /// constant that cannot be sent.
  String? get fixedWireValue {
    final leaf = this.leaf;
    return switch (leaf) {
      HWLocalizedString() => null,
      HWString(:final fixedValue) => fixedValue,
      HWInt(:final fixedValue) => fixedValue?.toString(),
      HWDouble(:final fixedValue) => fixedValue?.toString(),
      HWBool(:final fixedValue) => fixedValue?.toString(),
      HWDateTime(:final fixedDateTime) =>
        fixedDateTime?.toUtc().millisecondsSinceEpoch.toString(),
      _ => null,
    };
  }

  /// The Swift expression for the text the value travels as, a `String?` that
  /// is nil while there is no value.
  String swiftValue(String dataExpr) {
    final fixed = fixedWireValue;
    if (fixed != null) return '"${escapeSwiftStringLiteral(fixed)}"';
    return '${HWNativeHelper.hwPayloadValue.name}'
        '(${value.swiftReadExpr(dataExpr)})';
  }

  /// The Kotlin counterpart of [swiftValue].
  String kotlinValue(String dataExpr) {
    final fixed = fixedWireValue;
    if (fixed != null) return '"${escapeKotlinStringLiteral(fixed)}"';
    return '${HWNativeHelper.hwPayloadValue.name}'
        '(${value.kotlinReadExpr(dataExpr)})';
  }

  /// Whether [other] is sent and read back the same way: under the same name,
  /// as the same type, with the same nullability.
  bool hasSameShapeAs(HWPayloadEntry other) =>
      name == other.name &&
      type == other.type &&
      isNullable == other.isNullable &&
      (isFixed ? fixedWireValue : leaf.defaultValue) ==
          (other.isFixed ? other.fixedWireValue : other.leaf.defaultValue);
}

/// A URL a tap opens the app with, and the payload it carries.
///
/// The URL is written verbatim. The payload is appended as query parameters,
/// followed by the `homeWidget` parameter the plugin tells a widget tap by,
/// ahead of any fragment.
class HWPayloadUrl {
  /// The URL as the schema writes it.
  final String url;

  /// The values sent along, in order.
  final List<HWPayloadEntry> payload;

  const HWPayloadUrl(this.url, {this.payload = const []});

  /// A [url] carrying the entries of [data].
  HWPayloadUrl.of(this.url, Iterable<HWDataType<dynamic>> data)
      : payload = HWPayloadEntry.listOf(data);

  /// Query parameter marking a URL as coming from a widget tap.
  static const String marker = 'homeWidget';

  /// [url] up to its fragment, which the payload is appended to.
  String get head {
    final fragmentStart = url.indexOf('#');
    return fragmentStart == -1 ? url : url.substring(0, fragmentStart);
  }

  /// The fragment of [url] with its `#`, or empty without one.
  String get fragment {
    final fragmentStart = url.indexOf('#');
    return fragmentStart == -1 ? '' : url.substring(fragmentStart);
  }

  /// [marker] where it has to be appended, or empty for a [url] that already
  /// carries it.
  String get appendedMarker {
    final parsed = Uri.tryParse(url);
    final carries =
        parsed != null && parsed.queryParametersAll.containsKey(marker);
    return carries ? '' : marker;
  }

  /// [url] as it is opened while every payload value is missing: with
  /// [marker] appended, unless it is already there.
  ///
  /// The marker is spliced into the text rather than through [Uri.replace],
  /// which normalizes what it re-serializes.
  String get staticUrl {
    final marker = appendedMarker;
    if (marker.isEmpty) return url;
    final separator = head.contains('?') ? '&' : '?';
    return '$head$separator$marker$fragment';
  }

  /// [url] as the app receives it, without a payload, or null when it does
  /// not parse.
  Uri? get parsed => Uri.tryParse(staticUrl);

  /// The query parameters [url] itself carries, [marker] left out.
  Map<String, List<String>> get staticQuery => {
        for (final entry
            in (parsed?.queryParametersAll ?? const <String, List<String>>{})
                .entries)
          if (entry.key != marker) entry.key: entry.value,
      };

  /// The native functions [toSwift] and [toKotlin] call.
  Set<HWNativeHelper> get nativeHelpers => payload.isEmpty
      ? const {}
      : {
          HWNativeHelper.hwPayloadUrl,
          if (payload.any((entry) => !entry.isFixed))
            HWNativeHelper.hwPayloadValue,
        };

  /// The Swift expression for the URL, a `URL?`.
  String toSwift(String dataExpr) {
    if (payload.isEmpty) {
      return 'URL(string: "${escapeSwiftStringLiteral(staticUrl)}")';
    }
    final entries = [
      for (final entry in payload)
        '("${entry.name}", ${entry.swiftValue(dataExpr)})',
    ].join(', ');
    return '${HWNativeHelper.hwPayloadUrl.name}('
        '"${escapeSwiftStringLiteral(head)}", [$entries], '
        '"$appendedMarker", "${escapeSwiftStringLiteral(fragment)}")';
  }

  /// The Kotlin expression for the URL, an `android.net.Uri`.
  String toKotlin(String dataExpr) {
    if (payload.isEmpty) {
      return 'Uri.parse("${escapeKotlinStringLiteral(staticUrl)}")';
    }
    final entries = [
      for (final entry in payload)
        '"${entry.name}" to ${entry.kotlinValue(dataExpr)}',
    ].join(', ');
    return '${HWNativeHelper.hwPayloadUrl.name}('
        '"${escapeKotlinStringLiteral(head)}", listOf($entries), '
        '"$appendedMarker", "${escapeKotlinStringLiteral(fragment)}")';
  }

  /// The imports [toKotlin] needs beyond those of [nativeHelpers].
  static const Set<String> kotlinImports = {'import android.net.Uri'};

  /// Whether this URL and [other] share scheme, authority, path and fragment,
  /// which leaves the query to tell them apart.
  bool hasSameBaseAs(HWPayloadUrl other) {
    final a = parsed;
    final b = other.parsed;
    if (a == null || b == null) return false;
    return a.scheme == b.scheme &&
        a.authority == b.authority &&
        a.path == b.path &&
        a.fragment == b.fragment;
  }

  /// Whether this URL and [other] are the same once their payloads are left
  /// out: the same base, with the same static query parameters.
  bool hasSameStaticUrlAs(HWPayloadUrl other) {
    if (!hasSameBaseAs(other)) return false;
    final mine = staticQuery;
    final theirs = other.staticQuery;
    return mine.length == theirs.length &&
        mine.entries.every((entry) {
          final values = theirs[entry.key];
          return values != null && _sameValues(values, entry.value);
        });
  }

  /// The payload value of [other] that can make a URL [other] opens look like
  /// this one, by name, or null when none can.
  ///
  /// That takes the same base, and every static query parameter of this URL
  /// being one [other] writes too or one its payload can produce.
  String? payloadNameMatching(HWPayloadUrl other) {
    if (!hasSameBaseAs(other)) return null;
    final theirs = other.staticQuery;
    final names = {for (final entry in other.payload) entry.name};
    String? produced;
    for (final entry in staticQuery.entries) {
      final values = theirs[entry.key];
      if (values != null) {
        if (!_sameValues(values, entry.value)) return null;
      } else if (names.contains(entry.key)) {
        produced ??= entry.key;
      } else {
        return null;
      }
    }
    return produced;
  }

  /// Whether a URL one of the two opens can be read as the other, when each
  /// is matched on its own: the same base, and the static query parameters of
  /// one all written or producible by the other.
  ///
  /// Within one widget the more specific URL is matched first, which tells
  /// `myapp://home` and `myapp://home?tab=settings` apart; two widgets each
  /// match on their own, and both report such a tap.
  bool overlaps(HWPayloadUrl other) =>
      hasSameBaseAs(other) && (_coveredBy(other) || other._coveredBy(this));

  /// Whether every URL [other] opens can carry all of this one's static query
  /// parameters.
  bool _coveredBy(HWPayloadUrl other) {
    final theirs = other.staticQuery;
    final names = {for (final entry in other.payload) entry.name};
    return staticQuery.entries.every((entry) {
      final values = theirs[entry.key];
      if (values == null) return names.contains(entry.key);
      return _sameValues(values, entry.value);
    });
  }

  static bool _sameValues(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
