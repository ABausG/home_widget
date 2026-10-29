part of 'hw_widget.dart';

/// A region of the widget whose tap runs Dart code without opening the app.
///
/// A tap reaches the function `HomeWidget.onInteraction` names as the
/// generated interaction class named after [id]. [data] is sent along as its
/// fields, holding the values the widget was rendered with.
///
/// Maps to a SwiftUI `Button(intent:)`, which needs iOS 17, and a Glance
/// `clickable` running an action callback. A button has no styling of its own.
class HWButton extends HWSingleChildWidget {
  /// The name of this button, which the generated interaction class is named
  /// after.
  final String id;

  /// The values a tap sends along: stored values, sent under their key, and
  /// [HWPayload]s naming a value.
  final List<HWDataType<dynamic>> data;

  const HWButton(
    this.id, {
    this.data = const [],
    required super.child,
  });

  /// The Swift function the generated widget wraps the child of a button in,
  /// which `home_widget_cli` defines once per widget.
  static const String swiftFunction = 'hwButton';

  /// The URL a tap on the button with [id] reaches the Dart side as, without
  /// its payload. The format is internal to the generated code.
  static String urlOf(String id) => 'homewidget://interaction/$id';

  /// The URL a tap is sent as, with the payload of [data].
  HWPayloadUrl get payloadUrl => HWPayloadUrl.of(urlOf(id), data);

  /// The child's and every stored value of [data], which the widget has to
  /// read to send it.
  @override
  Set<HWDataType<dynamic>> get dataDependencies => {
        ...child.dataDependencies,
        ..._dataDependenciesOf(payloadUrl.payload.map((entry) => entry.value)),
      };

  @override
  Set<HWNativeHelper> get renderHelpers => payloadUrl.nativeHelpers;

  /// The tap action is injected into the child's own composable, so the child
  /// is still what the enclosing layout lays out.
  @override
  Set<String> _kotlinImportsAroundChild(HWAxis? enclosingLinearAxis) => {
        'import androidx.glance.layout.Box',
        'import androidx.glance.action.clickable',
        'import androidx.glance.appwidget.action.actionRunCallback',
        'import es.antonborri.home_widget.HomeWidgetInteractivityAction',
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
  HWButton _wrapping(HWWidget widget) =>
      HWButton(id, data: data, child: widget);

  /// Always, since the tap area covers the box, the way an [HWLink] does.
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

  static HWButton fromDartObject(DartObject obj, WidgetValueDecoder decoder) {
    final id = WidgetValueDecoder.getField(obj, 'id')?.toStringValue();
    final childField = WidgetValueDecoder.getField(obj, 'child');

    if (id == null) {
      // coverage:ignore-start
      throw GeneratorError('HWButton requires an id');
      // coverage:ignore-end
    }
    if (childField == null || childField.isNull) {
      // coverage:ignore-start
      throw GeneratorError('HWButton requires a non-null child property');
      // coverage:ignore-end
    }

    return HWButton(
      id,
      data: WidgetValueDecoder.decodePayload(
        WidgetValueDecoder.getField(obj, 'data'),
        owner: "HWButton('$id')",
        defaultLocale: decoder.defaultLocale,
        resourcePrefix: decoder.resourcePrefix,
      ),
      child: decoder.decodeRecursive(childField),
    );
  }

  /// The child inside [swiftFunction], or the bare child when it renders
  /// nothing to tap.
  @override
  String toSwift(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    if (child.swiftRendersNothing) {
      return child.toSwift(indent, dataExpr: dataExpr, context: context);
    }

    final pad = '    ' * indent;
    final childCode =
        child.toSwift(indent + 1, dataExpr: dataExpr, context: context);
    return '''
$pad$swiftFunction(${payloadUrl.toSwift(dataExpr)}) {
$childCode
$pad}''';
  }

  /// The child's code made clickable, running the callback registered under
  /// [HWEmitContext.interactionKey], or the default one without a key.
  @override
  String _kotlinAroundChild(
    int indent, {
    required String dataExpr,
    HWEmitContext? context,
  }) {
    final childCode =
        child.toKotlin(indent, dataExpr: dataExpr, context: context);
    final key = context?.interactionKey;
    final keyArgument =
        key == null ? '' : ', "${escapeKotlinStringLiteral(key)}"';
    return injectGlanceModifier(
      childCode,
      'clickable(onClick = actionRunCallback<HomeWidgetInteractivityAction>('
      'HomeWidgetInteractivityAction.parameters('
      '${payloadUrl.toKotlin(dataExpr)}$keyArgument)))',
    );
  }
}
