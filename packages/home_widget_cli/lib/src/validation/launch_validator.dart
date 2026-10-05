part of 'widget_data_validator.dart';

/// One place an [HWLink] sits in a widget tree.
class _LinkSite {
  final HWLink link;

  /// Whether the link sits in the item of a list builder.
  final bool inItem;

  /// The choices made on the way down to the link: each widget rendering one
  /// of several subtrees, with the index of the one the link is in.
  final List<(HWWidget, int)> choices;

  const _LinkSite(this.link, {required this.inItem, required this.choices});

  /// Whether this link and [other] can never render together, because some
  /// widget above both renders the subtree of one or of the other.
  bool excludes(_LinkSite other) => choices.any(
        (mine) => other.choices.any(
          (theirs) => identical(mine.$1, theirs.$1) && mine.$2 != theirs.$2,
        ),
      );
}

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

  final sites = _linkSites(spec, widget);
  for (final site in sites) {
    final link = site.link;
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
}

/// What RFC 3986 does not let a URL hold unescaped, and a `%` that starts no
/// escape.
final RegExp _illegalUrlCharacter = RegExp(
  r"[^A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]|%(?![0-9A-Fa-f]{2})",
);

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

/// Every [HWLink] of [spec], in document order, rejecting one inside another.
List<_LinkSite> _linkSites(WidgetSpec spec, String widget) {
  final sites = <_LinkSite>[];

  void walk(
    HWWidget node,
    List<(HWWidget, int)> choices, {
    required bool inItem,
    required HWLink? enclosing,
  }) {
    if (node is HWLink) {
      if (enclosing != null) {
        throw GeneratorError(
          "$widget: HWLink('${node.id}') sits inside "
          "HWLink('${enclosing.id}'). A tap opens one URL, so a link cannot "
          'contain another one.',
        );
      }
      sites.add(_LinkSite(node, inItem: inItem, choices: choices));
      walk(node.child, choices, inItem: inItem, enclosing: node);
      return;
    }

    final item = node is HWFlex ? node.item : null;
    final branches = switch (node) {
      HWConditional() => [node.firstBranch, node.secondBranch],
      HWAdaptive() => [node.ios, node.android],
      HWSizeAdaptive() => node.childWidgets,
      HWFlex(:final whenEmpty?) when item != null => [item, whenEmpty],
      _ => null,
    };
    if (branches != null) {
      final walked = <HWWidget>[];
      for (final (index, branch) in branches.indexed) {
        // One widget written into two slots is one place in the tree.
        if (walked.any((other) => identical(other, branch))) continue;
        walked.add(branch);
        walk(
          branch,
          [...choices, (node, index)],
          inItem: inItem || (item != null && index == 0),
          enclosing: enclosing,
        );
      }
      return;
    }

    for (final child in node.childWidgets) {
      walk(
        child,
        choices,
        inItem: inItem || identical(child, item),
        enclosing: enclosing,
      );
    }
  }

  walk(spec.effectiveWidgetTree, const [], inItem: false, enclosing: null);
  return sites;
}

/// Rejects two links generating one launch class unless they are the same
/// target: only one of them can ever render, and both open the same URL with
/// the same payload.
void _validateLinkIds(WidgetSpec spec, List<_LinkSite> sites, String widget) {
  final seen = <String, List<_LinkSite>>{};
  for (final site in sites) {
    final link = site.link;
    final earlier = seen.putIfAbsent(spec.linkClassName(link), () => []);
    for (final existing in earlier) {
      final other = existing.link;
      final ids = other.id == link.id
          ? "HWLink('${link.id}') is declared twice"
          : "HWLink('${other.id}') and HWLink('${link.id}') both generate "
              '${spec.linkClassName(link)}';
      if (!existing.excludes(site)) {
        throw GeneratorError(
          '$widget: $ids. A link id is unique within a widget; it may only '
          'repeat across the branches of a conditional or the slots of an '
          'HWSizeAdaptive, where one of them renders at a time.',
        );
      }
      if (!_sameLaunch(other.payloadUrl, link.payloadUrl)) {
        throw GeneratorError(
          '$widget: $ids, but with a different url or data. Both reach the '
          'app as the same launch class, so give them the same url and the '
          'same data, or different ids.',
        );
      }
    }
    earlier.add(site);
  }
}

/// Whether [a] and [b] open the same URL with a payload of the same shape.
bool _sameLaunch(HWPayloadUrl a, HWPayloadUrl b) {
  if (a.url != b.url || a.payload.length != b.payload.length) return false;
  final theirs = {for (final entry in b.payload) entry.name: entry};
  return a.payload.every((entry) {
    final other = theirs[entry.name];
    return other != null && entry.hasSameShapeAs(other);
  });
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
