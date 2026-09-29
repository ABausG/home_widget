import 'dart:io';

import 'package:xml/xml.dart';

import 'logger.dart';
import 'fs.dart';

/// Ensures [appGroupId] exists in the `com.apple.security.application-groups`
/// entitlement array inside [entitlementsFile].
///
/// If the file doesn't exist, it will be created.
Future<void> ensureAppGroupEntitlement({
  required File entitlementsFile,
  required String appGroupId,
}) async {
  final id = appGroupId.trim();
  if (id.isEmpty) return;

  if (!entitlementsFile.existsSync()) {
    await writeFileIfMissing(entitlementsFile, _newEntitlementsXml(id));
    return;
  }

  final original = await entitlementsFile.readAsString();
  XmlDocument doc;
  try {
    doc = XmlDocument.parse(original);
  } catch (_) {
    logger.warn(
      'Warning: Could not parse entitlements as XML: ${entitlementsFile.path}. '
      'Leaving it unchanged.',
    );
    return;
  }

  final plist = doc.findElements('plist').firstOrNull;
  final dict = plist?.findElements('dict').firstOrNull;
  if (dict == null) {
    logger.warn(
      'Warning: Entitlements plist missing <dict>: ${entitlementsFile.path}. '
      'Leaving it unchanged.',
    );
    return;
  }

  final pairs = dict.childElements.toList(growable: false);
  XmlElement? arrayEl;
  // Re-serializing reformats the whole plist, so a file already holding the
  // group is left exactly as it is.
  var added = false;

  for (var i = 0; i < pairs.length - 1; i++) {
    final a = pairs[i];
    final b = pairs[i + 1];
    if (a.name.local == 'key' &&
        a.innerText.trim() == 'com.apple.security.application-groups' &&
        b.name.local == 'array') {
      arrayEl = b;
      break;
    }
  }

  if (arrayEl == null) {
    // Append new entitlement at end.
    dict.children.add(XmlText('\n\t'));
    dict.children.add(
      XmlElement(XmlName('key'))
        ..children.add(XmlText('com.apple.security.application-groups')),
    );
    dict.children.add(XmlText('\n\t'));
    final newArray = XmlElement(XmlName('array'));
    newArray.children.add(XmlText('\n\t\t'));
    newArray.children
        .add(XmlElement(XmlName('string'))..children.add(XmlText(id)));
    newArray.children.add(XmlText('\n\t'));
    dict.children.add(newArray);
    dict.children.add(XmlText('\n'));
    added = true;
  } else {
    final existing =
        arrayEl.findElements('string').map((e) => e.innerText.trim()).toSet();
    if (!existing.contains(id)) {
      // Keep indentation similar-ish.
      arrayEl.children.add(XmlText('\n\t\t'));
      arrayEl.children
          .add(XmlElement(XmlName('string'))..children.add(XmlText(id)));
      arrayEl.children.add(XmlText('\n\t'));
      added = true;
    }
  }

  if (!added) return;

  await entitlementsFile.writeAsString(
    doc.toXmlString(pretty: true, indent: '\t'),
  );
  logger.detail('Updated entitlements: ${entitlementsFile.path}');
}

/// Creates [entitlementsFile] as an entitlements plist granting nothing when
/// it does not exist, so a configuration naming it still builds.
Future<void> ensureEntitlementsFile(File entitlementsFile) =>
    writeFileIfMissing(entitlementsFile, '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
''');

/// The App Groups the `com.apple.security.application-groups` entitlement in
/// [entitlementsFile] lists; none for a missing or unreadable file.
Future<Set<String>> appGroupEntitlements(File entitlementsFile) async {
  if (!entitlementsFile.existsSync()) return const {};
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(await entitlementsFile.readAsString());
  } catch (_) {
    return const {};
  }
  final pairs = doc
          .findElements('plist')
          .firstOrNull
          ?.findElements('dict')
          .firstOrNull
          ?.childElements
          .toList(growable: false) ??
      const <XmlElement>[];
  for (var i = 0; i < pairs.length - 1; i++) {
    if (pairs[i].name.local == 'key' &&
        pairs[i].innerText.trim() == 'com.apple.security.application-groups' &&
        pairs[i + 1].name.local == 'array') {
      return {
        for (final string in pairs[i + 1].findElements('string'))
          string.innerText.trim(),
      };
    }
  }
  return const {};
}

/// Removes [appGroupIds] from the `com.apple.security.application-groups`
/// entitlement array inside [entitlementsFile], and the entitlement itself once
/// its array is empty.
///
/// A missing file, or one that holds none of them, is left untouched.
Future<void> removeAppGroupEntitlements({
  required File entitlementsFile,
  required Set<String> appGroupIds,
}) async {
  if (appGroupIds.isEmpty || !entitlementsFile.existsSync()) return;

  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(await entitlementsFile.readAsString());
  } catch (_) {
    logger.warn(
      'Warning: Could not parse entitlements as XML: ${entitlementsFile.path}. '
      'Leaving it unchanged.',
    );
    return;
  }

  final dict = doc.findElements('plist').firstOrNull?.findElements('dict');
  final pairs = dict?.firstOrNull?.childElements.toList(growable: false) ??
      const <XmlElement>[];
  for (var i = 0; i < pairs.length - 1; i++) {
    final key = pairs[i];
    final array = pairs[i + 1];
    if (key.name.local != 'key' ||
        key.innerText.trim() != 'com.apple.security.application-groups' ||
        array.name.local != 'array') {
      continue;
    }

    final removed = [
      for (final string in array.findElements('string'))
        if (appGroupIds.contains(string.innerText.trim())) string,
    ];
    if (removed.isEmpty) return;
    for (final string in removed) {
      _removeWithLeadingWhitespace(string);
    }
    if (array.findElements('string').isEmpty) {
      _removeWithLeadingWhitespace(array);
      _removeWithLeadingWhitespace(key);
    }
    await entitlementsFile.writeAsString(
      doc.toXmlString(pretty: true, indent: '\t'),
    );
    logger.detail('Updated entitlements: ${entitlementsFile.path}');
    return;
  }
}

void _removeWithLeadingWhitespace(XmlElement element) {
  final siblings = element.parent!.children;
  final index = siblings.indexOf(element);
  if (index > 0 &&
      siblings[index - 1] is XmlText &&
      siblings[index - 1].value!.trim().isEmpty) {
    siblings.removeAt(index - 1);
  }
  siblings.remove(element);
}

String _newEntitlementsXml(String appGroupId) => '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>$appGroupId</string>
	</array>
</dict>
</plist>
''';

extension _FirstOrNullExt on Iterable<XmlElement> {
  XmlElement? get firstOrNull => isEmpty ? null : first;
}
