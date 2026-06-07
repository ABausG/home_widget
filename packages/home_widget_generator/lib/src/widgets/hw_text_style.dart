import 'hw_color.dart';
import 'hw_generatable.dart';

enum HWTextAlign { start, end, center, justify }

enum HWFontWeight {
  w100,
  w200,
  w300,
  w400,
  w500,
  w600,
  w700,
  w800,
  w900,
  normal,
  bold
}

enum HWTextStyleRole { title, headline, body, callout, caption, captionSmall }

/// A class representing text styling options for `HWText`.
class HWTextStyle implements HWGeneratable {
  final double? fontSize;
  final HWFontWeight? fontWeight;
  final HWColor? color;
  final bool? italic;
  final bool? underline;
  final bool? lineThrough;
  final HWTextStyle? baseStyle;

  const HWTextStyle({
    this.fontSize,
    this.fontWeight,
    this.color,
    this.italic,
    this.underline,
    this.lineThrough,
    this.baseStyle,
  });

  /// Resolves the effective style properties by marching up the `baseStyle` chain.
  HWTextStyle _resolve() {
    return _resolveRecursive(this);
  }

  static HWTextStyle _resolveRecursive(HWTextStyle current) {
    if (current.baseStyle == null) {
      if (current is HWRoleTextStyle) {
        return HWTextStyle(
          fontSize: current.fontSize,
          fontWeight: current.fontWeight,
          color: current.color,
          italic: current.italic,
          underline: current.underline,
          lineThrough: current.lineThrough,
        );
      }
      return current;
    }

    final baseResolved = _resolveRecursive(current.baseStyle!);

    return HWTextStyle(
      fontSize: current.fontSize ?? baseResolved.fontSize,
      fontWeight: current.fontWeight ?? baseResolved.fontWeight,
      color: current.color ?? baseResolved.color,
      italic: current.italic ?? baseResolved.italic,
      underline: current.underline ?? baseResolved.underline,
      lineThrough: current.lineThrough ?? baseResolved.lineThrough,
    );
  }

  HWTextStyleRole? _getEffectiveRole() {
    HWTextStyle? current = this;
    while (current != null) {
      if (current is HWRoleTextStyle) {
        return current.role;
      }
      current = current.baseStyle;
    }
    return null;
  }

  @override
  Set<String> get kotlinImports {
    final resolved = _resolve();
    return {
      if (resolved.color != null) ...resolved.color!.kotlinImports,
      if (resolved.fontSize != null || _getEffectiveRole() != null)
        'import androidx.compose.ui.unit.sp',
      if (resolved.fontWeight != null || _getEffectiveRole() != null)
        'import androidx.glance.text.FontWeight',
      if (resolved.italic == true) 'import androidx.glance.text.FontStyle',
      if (resolved.underline == true || resolved.lineThrough == true)
        'import androidx.glance.text.TextDecoration',
    };
  }

  @override
  Set<String> get swiftViewModifiers {
    final resolved = _resolve();
    return {
      if (resolved.color != null) ...resolved.color!.swiftViewModifiers,
    };
  }

  @override
  String toSwift(int indent, {required String dataExpr}) {
    final resolved = _resolve();
    final effectiveRole = _getEffectiveRole();
    final parts = <String>[];

    // Apply role as semantic font or fallback if size/weight not explicitly provided
    if (resolved.fontSize != null) {
      if (resolved.fontWeight != null) {
        parts.add(
          '.font(.system(size: ${resolved.fontSize}, weight: ${_swiftFontWeight(resolved.fontWeight!)}))',
        );
      } else {
        parts.add('.font(.system(size: ${resolved.fontSize}))');
      }
    } else if (effectiveRole != null) {
      parts.add('.font(.${_swiftRole(effectiveRole)})');
      if (resolved.fontWeight != null) {
        parts.add('.fontWeight(${_swiftFontWeight(resolved.fontWeight!)})');
      }
    } else if (resolved.fontWeight != null) {
      parts.add('.fontWeight(${_swiftFontWeight(resolved.fontWeight!)})');
    }

    if (resolved.color != null) {
      parts.add(
        '.foregroundColor(${resolved.color!.toSwift(indent, dataExpr: dataExpr)})',
      );
    }

    if (resolved.italic == true) {
      parts.add('.italic()');
    }
    if (resolved.underline == true) {
      parts.add('.underline(true)');
    }
    if (resolved.lineThrough == true) {
      parts.add('.strikethrough(true)');
    }

    return parts.join('');
  }

  @override
  String toKotlin(int indent, {required String dataExpr}) {
    final resolved = _resolve();
    final effectiveRole = _getEffectiveRole();
    final args = <String>[];

    if (resolved.color != null) {
      args.add(
        'color = ${resolved.color!.toKotlin(indent, dataExpr: dataExpr)}',
      );
    }

    final size = resolved.fontSize ?? _androidRoleFontSize(effectiveRole);
    if (size != null) {
      // If ends with .0, strip it to match how generator outputs other numeric literals. (Optional but nice)
      final sizeStr =
          size == size.toInt() ? size.toInt().toString() : size.toString();
      args.add('fontSize = $sizeStr.sp');
    }

    final weight = resolved.fontWeight ?? _androidRoleFontWeight(effectiveRole);
    if (weight != null) {
      args.add('fontWeight = ${_kotlinFontWeight(weight)}');
    }

    if (resolved.italic == true) {
      args.add('fontStyle = FontStyle.Italic');
    }

    if (resolved.underline == true && resolved.lineThrough == true) {
      args.add(
        'textDecoration = TextDecoration.combine(listOf(TextDecoration.Underline, TextDecoration.LineThrough))',
      );
    } else if (resolved.underline == true) {
      args.add('textDecoration = TextDecoration.Underline');
    } else if (resolved.lineThrough == true) {
      args.add('textDecoration = TextDecoration.LineThrough');
    }

    if (args.isEmpty) return '';
    return 'TextStyle(${args.join(', ')})';
  }
}

class HWRoleTextStyle extends HWTextStyle {
  final HWTextStyleRole role;

  const HWRoleTextStyle({
    required this.role,
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.baseStyle,
  });

  const HWRoleTextStyle.title({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.baseStyle,
  }) : role = HWTextStyleRole.title;

  const HWRoleTextStyle.headline({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.baseStyle,
  }) : role = HWTextStyleRole.headline;

  const HWRoleTextStyle.body({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.baseStyle,
  }) : role = HWTextStyleRole.body;

  const HWRoleTextStyle.callout({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.baseStyle,
  }) : role = HWTextStyleRole.callout;

  const HWRoleTextStyle.caption({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.baseStyle,
  }) : role = HWTextStyleRole.caption;

  const HWRoleTextStyle.captionSmall({
    super.fontSize,
    super.fontWeight,
    super.color,
    super.italic,
    super.underline,
    super.lineThrough,
    super.baseStyle,
  }) : role = HWTextStyleRole.captionSmall;
}

String _swiftFontWeight(HWFontWeight weight) {
  switch (weight) {
    case HWFontWeight.w100:
      return '.ultraLight';
    case HWFontWeight.w200:
      return '.thin';
    case HWFontWeight.w300:
      return '.light';
    case HWFontWeight.w400:
      return '.regular';
    case HWFontWeight.w500:
      return '.medium';
    case HWFontWeight.w600:
      return '.semibold';
    case HWFontWeight.w700:
      return '.bold';
    case HWFontWeight.w800:
      return '.heavy';
    case HWFontWeight.w900:
      return '.black';
    case HWFontWeight.normal:
      return '.regular';
    case HWFontWeight.bold:
      return '.bold';
  }
}

String _kotlinFontWeight(HWFontWeight weight) {
  switch (weight) {
    case HWFontWeight.w100:
    case HWFontWeight.w200:
    case HWFontWeight.w300:
    case HWFontWeight.w400:
    case HWFontWeight.normal:
      return 'FontWeight.Normal';
    case HWFontWeight.w500:
    case HWFontWeight.w600:
      return 'FontWeight.Medium';
    case HWFontWeight.w700:
    case HWFontWeight.w800:
    case HWFontWeight.w900:
    case HWFontWeight.bold:
      return 'FontWeight.Bold';
  }
}

String _swiftRole(HWTextStyleRole role) {
  switch (role) {
    case HWTextStyleRole.title:
      return 'title';
    case HWTextStyleRole.headline:
      return 'headline';
    case HWTextStyleRole.body:
      return 'body';
    case HWTextStyleRole.callout:
      return 'callout';
    case HWTextStyleRole.caption:
      return 'caption';
    case HWTextStyleRole.captionSmall:
      return 'caption2';
  }
}

double? _androidRoleFontSize(HWTextStyleRole? role) {
  switch (role) {
    case HWTextStyleRole.title:
      return 22.0;
    case HWTextStyleRole.headline:
      return 18.0;
    case HWTextStyleRole.body:
      return 16.0;
    case HWTextStyleRole.callout:
      return 14.0;
    case HWTextStyleRole.caption:
      return 12.0;
    case HWTextStyleRole.captionSmall:
      return 11.0;
    case null:
      return null;
  }
}

HWFontWeight? _androidRoleFontWeight(HWTextStyleRole? role) {
  switch (role) {
    case HWTextStyleRole.title:
      return HWFontWeight.normal;
    case HWTextStyleRole.headline:
      return HWFontWeight.w600;
    case HWTextStyleRole.body:
      return HWFontWeight.normal;
    case HWTextStyleRole.callout:
      return HWFontWeight.normal;
    case HWTextStyleRole.caption:
      return HWFontWeight.normal;
    case HWTextStyleRole.captionSmall:
      return HWFontWeight.w500;
    case null:
      return null;
  }
}
