import 'package:mason_logger/mason_logger.dart';

import 'logger.dart';

const _sponsorUri = 'https://github.com/sponsors/ABausG';

/// Visible GitHub Sponsors hyperlink ([label] is the anchor text).
String _githubSponsorsLink(String label) {
  final uri = Uri.parse(_sponsorUri);
  if (!ansiOutputEnabled) {
    return link(uri: uri, message: label);
  }
  // Easier to spot as interactive in terminals that support OSC 8 links.
  final styled = lightBlue.wrap(styleUnderlined.wrap(label)) ?? label;
  return link(uri: uri, message: styled);
}

/// Thank-you and sponsor line (dim). Reusable after any successful CLI flow.
void _logHomeWidgetThanksNote() {
  logger.info(
    'Thanks for using home_widget. 🩷 Please consider '
    '${_githubSponsorsLink('supporting the project on GitHub Sponsors')}.',
  );
}

/// Shown after a successful `generate` run (one or more widgets).
void logGenerateSuccessThanks() {
  logger.write('\n');
  logger.success('Widgets generated successfully.');
  _logHomeWidgetThanksNote();
}

/// Shown after a successful `create` run.
void logCreateSuccessThanks() {
  logger.write('\n');
  logger.success('Widget scaffolded successfully.');
  _logHomeWidgetThanksNote();
}
