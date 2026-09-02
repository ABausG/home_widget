import 'dart:io';

import 'package:xml/xml.dart';

/// Small XML helpers for `home_widget_cli`.
XmlDocument? tryParseXmlFile(File file) {
  if (!file.existsSync()) return null;
  try {
    return XmlDocument.parse(file.readAsStringSync());
  } catch (_) {
    return null;
  }
}

/// Writes an [XmlDocument] to [file] with pretty-printed, Android-style
/// formatting.
///
/// Returns whether anything was written: serializing a document that renders
/// byte-identical to what is already on disk is skipped, so a run that changes
/// nothing does not reformat the user's file (or log that it updated it).
bool writeXmlFile(File file, XmlDocument document) {
  final existing = file.existsSync() ? file.readAsStringSync() : null;

  // "Nice default" formatting:
  // - pretty printed
  // - 4-space indentation (matches typical Android XML)
  // - preserve existing newline style if the file already exists
  // - space before self-close (`<tag />`) (common in Android XML)
  final newLine = existing != null && existing.contains('\r\n') ? '\r\n' : '\n';

  final rendered = document.toXmlString(
    pretty: true,
    indent: '    ',
    newLine: newLine,
    // Match Android-style formatting: keep single-attribute elements inline,
    // but break onto multiple lines when there are multiple attributes.
    indentAttribute: (attr) {
      final parent = attr.parent;
      return parent is XmlElement && parent.attributes.length > 1;
    },
    spaceBeforeSelfClose: (_) => true,
  );

  if (existing == rendered) return false;

  file.writeAsStringSync(rendered);
  return true;
}

/// Whether [activity] is the activity the launcher starts, that is whether it
/// declares an `intent-filter` carrying both `android.intent.action.MAIN` and
/// `android.intent.category.LAUNCHER`.
bool isAndroidLauncherActivity(XmlElement activity) =>
    activity.childElements.where((e) => e.localName == 'intent-filter').any(
          (filter) =>
              filter.findElements('action').any(
                    (e) =>
                        e.getAttribute('android:name') ==
                        'android.intent.action.MAIN',
                  ) &&
              filter.findElements('category').any(
                    (e) =>
                        e.getAttribute('android:name') ==
                        'android.intent.category.LAUNCHER',
                  ),
        );
