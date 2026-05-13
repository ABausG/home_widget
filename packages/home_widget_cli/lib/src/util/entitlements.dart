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
  } else {
    final existing =
        arrayEl.findElements('string').map((e) => e.innerText.trim()).toSet();
    if (!existing.contains(id)) {
      // Keep indentation similar-ish.
      arrayEl.children.add(XmlText('\n\t\t'));
      arrayEl.children
          .add(XmlElement(XmlName('string'))..children.add(XmlText(id)));
      arrayEl.children.add(XmlText('\n\t'));
    }
  }

  final updated = doc.toXmlString(pretty: true, indent: '\t');
  if (updated != original) {
    await entitlementsFile.writeAsString(updated);
    logger.detail('Updated entitlements: ${entitlementsFile.path}');
  }
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
