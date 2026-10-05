part of 'hw_widget.dart';

/// A region of the widget whose tap opens the app with a URL of its own.
///
/// [url] follows the rules of `HomeWidget.widgetUrl`: it is written verbatim,
/// and the app reads the tap back through the generated launch helpers, as
/// the class named after [id]. [data] is sent along as query parameters.
///
/// Maps to a SwiftUI `Link` and a Glance `clickable` starting the app's
/// launcher activity. A link has no styling of its own. iOS ignores a `Link`
/// in a `systemSmall` widget, which is one tap area as a whole.
class HWLink extends HWSingleChildWidget {
  /// The name of this link, which the generated launch class is named after.
  final String id;

  /// The URL a tap opens the app with.
  final String url;

  /// The values a tap sends along with [url]: stored values, sent under their
  /// key, and [HWPayload]s naming a value.
  final List<HWDataType<dynamic>> data;

  const HWLink(
    this.id, {
    required this.url,
    this.data = const [],
    required super.child,
  });

  /// [url] with the payload of [data].
  HWPayloadUrl get payloadUrl => HWPayloadUrl.of(url, data);

  /// The child's and every stored value of [data], which the widget has to
  /// read to send it.
  @override
  Set<HWDataType<dynamic>> get dataDependencies => {
        ...child.dataDependencies,
        ..._dataDependenciesOf(payloadUrl.payload.map((entry) => entry.value)),
      };

  @override
  Set<HWNativeHelper> get renderHelpers => {
        HWNativeHelper.hwLink,
        ...payloadUrl.nativeHelpers,
      };

  /// The tap action is injected into the child's own composable, so the child
  /// is still what the enclosing layout lays out.
  @override
  Set<String> _kotlinImportsAroundChild(HWAxis? enclosingLinearAxis) => {
        'import androidx.glance.layout.Box',
        'import androidx.glance.action.clickable',
        'import es.antonborri.home_widget.actionStartActivity',
        ...HWPayloadUrl.kotlinImports,
        ...child.kotlinImportsIn(enclosingLinearAxis),
      };

  /// The child's: a text child stays a `Text` that can be tapped.
  @override
  HWKotlinBaselineText? kotlinBaselineText([HWEmitContext? context]) =>
      child.kotlinBaselineText(context);

  /// Never: a padding on the same composable would be part of the tap area.
  @override
  bool get kotlinPaddingAddsRoom => false;

  @override
  HWLink _wrapping(HWWidget widget) =>
      HWLink(id, url: url, data: data, child: widget);

  /// Always, since the tap area covers the box: SwiftUI frames the child
  /// inside the link, and Glance makes the composable the box sizes
  /// clickable, a picture among it filling the box as it does without a
  /// link.
  @override
  HWWidget? _sizedInside(
    double? width,
    double? height, {
    required bool glance,
  }) =>
      _wrapping(
        glance
            ? child._sizedInside(width, height, glance: true) ??
                child._kotlinFilling(
                  width: width != null,
                  height: height != null,
                ) ??
                child
            : HWSizedBox(width: width, height: height, child: child),
      );

  static HWLink fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final id = WidgetValueDecoder.getField(obj, 'id')?.toStringValue();
    final url = WidgetValueDecoder.getField(obj, 'url')?.toStringValue();
    final childField = WidgetValueDecoder.getField(obj, 'child');

    if (id == null || url == null) {
      // coverage:ignore-start
      throw GeneratorError('HWLink requires an id and a url');
      // coverage:ignore-end
    }
    if (childField == null || childField.isNull) {
      // coverage:ignore-start
      throw GeneratorError('HWLink requires a non-null child property');
      // coverage:ignore-end
    }

    return HWLink(
      id,
      url: url,
      data: WidgetValueDecoder.decodePayload(
        WidgetValueDecoder.getField(obj, 'data'),
        owner: "HWLink('$id')",
        defaultLocale: decoder.defaultLocale,
        resourcePrefix: decoder.resourcePrefix,
      ),
      child: decoder.decodeRecursive(childField),
    );
  }

  /// A `Link` around the child, or `.widgetURL` on it where
  /// [HWEmitContext.swiftWidgetUrlLinks] names this link.
  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final url = payloadUrl.toSwift(dataExpr);
    final asWidgetUrl =
        context?.swiftWidgetUrlLinks.any((link) => identical(link, this)) ??
            false;
    if (asWidgetUrl || child.swiftRendersNothing) {
      final childCode =
          child.toSwift(indent, dataExpr: dataExpr, context: context);
      return applySwiftModifier(childCode, '.widgetURL($url)', indent);
    }

    final pad = '    ' * indent;
    final childCode =
        child.toSwift(indent + 1, dataExpr: dataExpr, context: context);
    return '''
$pad${HWNativeHelper.hwLink.name}($url) {
$childCode
$pad}''';
  }

  /// The child's code made clickable, or as it is while
  /// [HWEmitContext.androidLaunchActivity] names nothing to open.
  @override
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final childCode =
        child.toKotlin(indent, dataExpr: dataExpr, context: context);
    final activity = context?.androidLaunchActivity;
    if (activity == null) return childCode;
    return injectGlanceModifier(
      childCode,
      'clickable(onClick = actionStartActivity<$activity>(context, '
      '${payloadUrl.toKotlin(dataExpr)}))',
    );
  }
}
