part of 'widget_data_validator.dart';

/// Validates everything a tap on [spec] can open the app with: the widget's
/// own URL, its [HWLink]s, and the payloads of both.
///
/// Runs ahead of the list checks, so that an [HWItemData] in a payload is
/// reported for what it is.
void validateLaunches(WidgetSpec spec) {
  final widget = 'Widget "${spec.data.name}"';

  _validateLaunchUrl(spec.data.widgetUrl, where: '$widget: widgetUrl');
  final widgetUrl = spec.widgetUrl;
  if (widgetUrl == null) {
    if (spec.data.widgetUrlData.isNotEmpty) {
      throw GeneratorError(
        '$widget: widgetUrlData is set without a widgetUrl. The values are '
        'sent along with that URL, so set widgetUrl as well, or remove '
        'widgetUrlData.',
      );
    }
  } else {
    _validateUrlPayload(
      widgetUrl,
      owner: '$widget: widgetUrlData',
      className: spec.widgetTapClassName,
    );
  }

  final sites = _tapSites(spec, widget).links;
  for (final site in sites) {
    final link = site.target;
    final owner = "$widget: HWLink('${link.id}')";
    if (!asciiDataNamePattern.hasMatch(link.id)) {
      throw GeneratorError(
        '$widget: invalid HWLink id "${link.id}". The id names the generated '
        'launch class, so use ASCII letters and digits only, starting with a '
        'letter.',
      );
    }
    _validateLaunchUrl(link.url, where: '$owner url');
    _validateUrlPayload(
      link.payloadUrl,
      owner: owner,
      className: spec.linkClassName(link),
      inItem: site.inItem,
    );
  }

  _validateLinkIds(spec, sites, widget);
  _validateLaunchUrlCollisions(spec, widget);
  _validateTapAreas(spec, widget);
}

/// Rejects a URL that is not an absolute [Uri] with a scheme.
void _validateLaunchUrl(String? url, {required String where}) {
  if (url == null) return;

  if (url.trim().isEmpty) {
    throw GeneratorError(
      '$where is empty. A tap needs a URL to open the app with, e.g. '
      'myapp://details.',
    );
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    throw GeneratorError(
      '$where "$url" is not a valid URL. It must be an absolute URI including '
      'a scheme, e.g. myapp://details.',
    );
  }
  final illegal = _illegalUrlCharacter.firstMatch(url);
  if (illegal != null) {
    final character = illegal[0] == ' ' ? 'a space' : '"${illegal[0]}"';
    throw GeneratorError(
      '$where "$url" contains $character, which a URL cannot hold as it is: '
      'iOS opens nothing for such a URL. Percent-encode it, e.g. a space as '
      '%20.',
    );
  }
  final afterHost = url.substring(_ipLiteralHost.matchAsPrefix(url)?.end ?? 0);
  final misplaced = _bracket.firstMatch(afterHost)?[0] ??
      (afterHost.indexOf('#') != afterHost.lastIndexOf('#') ? '#' : null);
  if (misplaced != null) {
    final what = misplaced == '#'
        ? 'a second "#"'
        : '"$misplaced" outside an '
            'IP address host';
    throw GeneratorError(
      '$where "$url" contains $what, which a URL cannot hold as it is: iOS '
      'before 17 opens nothing for such a URL. Percent-encode it as '
      '${_percentEncoded[misplaced]}.',
    );
  }
  try {
    uri.queryParametersAll;
  } on FormatException {
    throw GeneratorError(
      '$where "$url" has a query that does not decode as UTF-8, so the app '
      'cannot read the tap back. Percent-encode the UTF-8 bytes of each '
      'character, e.g. "é" as %C3%A9.',
    );
  }
}

/// What RFC 3986 does not let a URL hold unescaped, and a `%` that starts no
/// escape.
final RegExp _illegalUrlCharacter = RegExp(
  r"[^A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]|%(?![0-9A-Fa-f]{2})",
);

/// The scheme and authority of a URL up to a host in brackets, an IP address
/// and the one place a URL can hold `[` and `]`.
final RegExp _ipLiteralHost =
    RegExp(r'[A-Za-z][A-Za-z0-9+.\-]*://(?:[^/?#\[\]@]*@)?\[[^/?#\[\]]*\]');

final RegExp _bracket = RegExp(r'[\[\]]');

const Map<String, String> _percentEncoded = {
  '[': '%5B',
  ']': '%5D',
  '#': '%23',
};

/// Validates the payload [url] carries, whose names share the query of the
/// URL with its own parameters, as the fields of [className].
void _validateUrlPayload(
  HWPayloadUrl url, {
  required String owner,
  required String className,
  bool inItem = false,
}) {
  validatePayload(
    url.payload,
    owner: owner,
    inItem: inItem,
    className: className,
    reserved: {
      HWPayloadUrl.marker: 'the query parameter marking a tap on a widget',
      for (final name in url.staticQuery.keys)
        name: 'already a query parameter of the URL "${url.url}"',
    },
  );
}

/// Rejects two links generating one launch class under different ids or with
/// different urls, and links of one id sending a value of one name as
/// different types.
///
/// Links sharing an id and url may render together and send different data:
/// they reach the app as one class with a field per name any of them sends.
void _validateLinkIds(
  WidgetSpec spec,
  List<_TapSite<HWLink>> sites,
  String widget,
) {
  final firstLinks = <String, HWLink>{};
  for (final site in sites) {
    final link = site.target;
    final className = spec.linkClassName(link);
    final other = firstLinks.putIfAbsent(className, () => link);
    if (other.id != link.id) {
      throw GeneratorError(
        "$widget: HWLink('${other.id}') and HWLink('${link.id}') both "
        'generate the launch class $className. Spell the id the same way in '
        'both, or give them ids that differ in more than case.',
      );
    }
    if (other.url != link.url) {
      throw GeneratorError(_differentLinkUrls(widget, link, other));
    }
  }

  final types = <String, Map<String, HWPayloadType>>{};
  for (final site in sites) {
    final link = site.target;
    _validateSharedPayloadTypes(
      link,
      link.payloadUrl.payload,
      types.putIfAbsent(spec.linkClassName(link), () => {}),
      widget: widget,
    );
  }
}

/// The error for [link] opening another url than [other] of its id.
String _differentLinkUrls(String widget, HWLink link, HWLink other) {
  final urls = "$widget: HWLink('${link.id}') opens \"${link.url}\", where "
      "another HWLink('${link.id}') opens \"${other.url}\". Links sharing an "
      'id reach the app as one launch class matched by one url';
  final mine = HWPayloadUrl(link.url);
  final theirs = HWPayloadUrl(other.url);
  if (mine.hasSameStaticUrlAs(theirs)) {
    return '$urls, and these two are the same URL written differently. Write '
        'the same url in both.';
  }
  if (mine.hasSameBaseAs(theirs)) {
    final (name, value) = _differingQueryParameter(mine, theirs);
    return "$urls, so move the query parameter \"$name\" into data, e.g. "
        "HWPayload('$name', HWString.fixed('${escapeDartStringLiteral(value)}'))"
        ', or give the links different ids.';
  }
  return '$urls, so give them the same url, or different ids.';
}

/// The first query parameter written into [a] or [b] that the other lacks or
/// writes with other values, with its first value in the URL writing it,
/// [a] where both do.
(String, String) _differingQueryParameter(HWPayloadUrl a, HWPayloadUrl b) {
  final mine = a.staticQuery;
  final theirs = b.staticQuery;
  for (final (query, other) in [(mine, theirs), (theirs, mine)]) {
    for (final MapEntry(key: name, value: values) in query.entries) {
      final otherValues = other[name];
      if (otherValues == null ||
          otherValues.length != values.length ||
          values.indexed.any((value) => otherValues[value.$1] != value.$2)) {
        return (name, values.first);
      }
    }
  }
  // coverage:ignore-start
  throw StateError('${a.url} and ${b.url} write the same query parameters.');
  // coverage:ignore-end
}

/// Rejects two launch targets whose URLs the app could not tell apart.
///
/// The target with more query parameters written into its URL is matched
/// first, so one URL extending another with a parameter is fine. What is left
/// are two URLs that only differ in their data, and a value one sends that
/// can turn its URL into the other.
void _validateLaunchUrlCollisions(WidgetSpec spec, String widget) {
  final targets = spec.launchTargets;
  for (var index = 0; index < targets.length; index++) {
    for (var other = 0; other < index; other++) {
      final a = targets[other];
      final b = targets[index];
      final pair = '$widget: ${a.className} ("${a.url.url}") and '
          '${b.className} ("${b.url.url}")';
      if (a.url.hasSameStaticUrlAs(b.url)) {
        throw GeneratorError(
          '$pair open the same URL, so the app cannot tell the two taps '
          'apart. The data a tap sends does not count: make the scheme, '
          'host, path, fragment or a query parameter written into the URL '
          'differ.',
        );
      }
      for (final (fixed, sender) in [(a, b), (b, a)]) {
        final name = fixed.url.payloadNameMatching(sender.url);
        if (name == null) continue;
        throw GeneratorError(
          '$pair cannot be told apart: ${sender.className} sends a value '
          'named "$name", which can equal the query parameter "$name" '
          'written into the URL of ${fixed.className}. Rename the value '
          'with HWPayload("other", ...), or change one of the URLs.',
        );
      }
    }
  }
}

/// Warns about launch targets of different widgets that can match the same
/// URL: each widget matches on its own, so both report such a tap.
void warnAboutSharedLaunchUrls(List<WidgetSpec> specs) {
  for (var index = 0; index < specs.length; index++) {
    for (var other = 0; other < index; other++) {
      for (final a in specs[other].launchTargets) {
        for (final b in specs[index].launchTargets) {
          if (!a.url.overlaps(b.url)) continue;
          logger.warn(
            'Warning: ${a.className} ("${a.url.url}") of widget '
            '"${specs[other].data.name}" and ${b.className} '
            '("${b.url.url}") of widget "${specs[index].data.name}" can '
            'match the same URL. Each widget reports the taps its own URLs '
            'match, so launches() of both report such a tap. Give the '
            'widgets URLs of their own to tell them apart.',
          );
        }
      }
    }
  }
}

/// Rejects a link claiming the whole-widget tap next to `widgetUrl`, and
/// warns about links a platform never opens.
void _validateTapAreas(WidgetSpec spec, String widget) {
  final links = spec.links;
  if (links.isEmpty) return;

  if (spec.data.android != null && !spec.androidOpensAppOnTap) {
    logger.warn(
      'Warning: $widget sets android.openAppOnTap to false, so its HWLinks '
      'open nothing on Android.',
    );
  }

  final wholeWidget = spec.iosWidgetUrlLinks;
  if (wholeWidget.isNotEmpty && spec.iosWidgetUrl != null) {
    throw GeneratorError(
      "$widget: HWLink('${wholeWidget.first.id}') is the whole layout of a "
      'widget iOS renders as one tap area, where it takes the place of '
      'widgetUrl. Both would claim the same tap, so remove widgetUrl, or move '
      'the link into a larger layout.',
    );
  }

  final ignored = spec.iosIgnoredLinks;
  if (ignored.isEmpty) return;
  final families = spec.iosReachableFamilies
      .intersection(WidgetSpec.iosSingleTapFamilies)
      .map((family) => family.name)
      .join(', ');
  final ids = {for (final link in ignored) "HWLink('${link.id}')"}.join(', ');
  logger.warn(
    'Warning: $widget can be shown as $families on iOS, which is one tap '
    'area: a tap on $ids there opens the app '
    '${spec.iosWidgetUrl != null ? 'through widgetUrl' : 'without a URL'} '
    'instead. Android is not affected. Put the link in an HWSizeAdaptive slot '
    'of a larger family to silence this warning.',
  );
}
