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

void writeXmlFile(File file, XmlDocument document) {
  // Pretty-print for readability; ensures deterministic output.
  file.writeAsStringSync(document.toXmlString(pretty: true));
}


