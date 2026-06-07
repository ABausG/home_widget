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
void writeXmlFile(File file, XmlDocument document) {
  // "Nice default" formatting:
  // - pretty printed
  // - 4-space indentation (matches typical Android XML)
  // - preserve existing newline style if the file already exists
  // - space before self-close (`<tag />`) (common in Android XML)
  final newLine = file.existsSync() && file.readAsStringSync().contains('\r\n')
      ? '\r\n'
      : '\n';

  file.writeAsStringSync(
    document.toXmlString(
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
    ),
  );
}
