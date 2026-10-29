import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'logger.dart';

/// Points every manual-signing export options plist in [iosDir] at the
/// provisioning profile the widget extension [widgetClassName] signs with.
///
/// A file takes part when it sits directly in [iosDir], its name contains
/// `ExportOptions`, and its root dict has `signingStyle` `manual` and a
/// `provisioningProfiles` dict. For every app bundle id that dict lists,
/// `<bundle id>.<widgetClassName>` is set to the profile [profiles] maps the
/// bundle id to, removed where it maps it to `null`, and left as it is where
/// [profiles] does not hold the bundle id.
///
/// Every other entry keeps its value and the file keeps its layout. A
/// rewritten file is not byte-identical beyond that: text escaped without
/// need (`&gt;`) comes back unescaped. A file that needs no change is not
/// rewritten.
Future<void> syncExportOptionsProvisioningProfiles({
  required Directory iosDir,
  required String widgetClassName,
  required Map<String, String?> profiles,
}) async {
  if (!iosDir.existsSync()) return;
  final files = [
    for (final entity in iosDir.listSync())
      if (entity is File &&
          p.extension(entity.path) == '.plist' &&
          p.basename(entity.path).contains('ExportOptions'))
        entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    await _syncExportOptions(file, widgetClassName, profiles);
  }
}

Future<void> _syncExportOptions(
  File file,
  String widgetClassName,
  Map<String, String?> profiles,
) async {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(await file.readAsString());
  } catch (_) {
    logger.warn(
      'Warning: Could not parse export options as XML: ${file.path}. Leaving '
      'it unchanged.',
    );
    return;
  }
  final root =
      doc.findElements('plist').firstOrNull?.findElements('dict').firstOrNull;
  if (root == null) return;
  final signingStyle = _valueOf(root, 'signingStyle');
  final dict = _valueOf(root, 'provisioningProfiles');
  if (signingStyle?.name.local != 'string' ||
      signingStyle!.innerText.trim() != 'manual' ||
      dict?.name.local != 'dict') {
    return;
  }

  final changes = <String>[];
  for (final (key: appKey, value: appValue) in _entriesOf(dict!).toList()) {
    final bundleId = appKey.innerText.trim();
    if (!profiles.containsKey(bundleId)) continue;
    final key = '$bundleId.$widgetClassName';
    final profile = profiles[bundleId];
    final existing = _entriesOf(dict)
        .where((entry) => entry.key.innerText.trim() == key)
        .firstOrNull;
    if (profile == null) {
      if (existing == null) continue;
      _removeEntry(existing);
      changes.add('removed $key');
    } else if (existing == null) {
      _insertEntryAfter(appKey, appValue, key, profile);
      changes.add('set $key to "$profile"');
    } else if (existing.value.name.local != 'string' ||
        existing.value.innerText != profile) {
      existing.value.replace(_stringElement(profile));
      changes.add('set $key to "$profile"');
    }
  }
  if (changes.isEmpty) return;

  await file.writeAsString(doc.toXmlString());
  logger.detail('Updated: ${file.path}');
  logger.info(
    'Updated the provisioning profiles of ${p.basename(file.path)}: '
    '${changes.join(', ')}.',
  );
}

/// The `<key>` / value element pairs of the plist [dict], in order.
Iterable<({XmlElement key, XmlElement value})> _entriesOf(
  XmlElement dict,
) sync* {
  final elements = dict.childElements.toList();
  for (var i = 0; i < elements.length - 1; i++) {
    if (elements[i].name.local != 'key') continue;
    yield (key: elements[i], value: elements[i + 1]);
    i++;
  }
}

/// The value the plist [dict] holds under [key], or `null`.
XmlElement? _valueOf(XmlElement dict, String key) => _entriesOf(dict)
    .where((entry) => entry.key.innerText.trim() == key)
    .firstOrNull
    ?.value;

XmlElement _stringElement(String value) =>
    XmlElement(XmlName('string'), const [], [XmlText(value)]);

/// Inserts [key] → [value] right after the entry [afterKey] → [afterValue],
/// indented the way that entry is.
void _insertEntryAfter(
  XmlElement afterKey,
  XmlElement afterValue,
  String key,
  String value,
) {
  final previous = afterKey.previousSibling;
  final indent = previous is XmlText && previous.value.trim().isEmpty
      ? previous.value
      : '';
  final siblings = afterValue.parent!.children;
  siblings.insertAll(siblings.indexOf(afterValue) + 1, [
    XmlText(indent),
    XmlElement(XmlName('key'), const [], [XmlText(key)]),
    XmlText(indent),
    _stringElement(value),
  ]);
}

/// Removes the entry [entry] along with the whitespace leading up to it.
void _removeEntry(({XmlElement key, XmlElement value}) entry) {
  final siblings = entry.key.parent!.children;
  var start = siblings.indexOf(entry.key);
  final previous = start > 0 ? siblings[start - 1] : null;
  if (previous is XmlText && previous.value.trim().isEmpty) start--;
  siblings.removeRange(start, siblings.indexOf(entry.value) + 1);
}
