import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWPadding', () {
    const padding = HWPadding(
      child: HWText.fixed('Hi'),
      padding: HWEdgeInsets.only(left: 1, top: 2, right: 3, bottom: 4),
    );

    group('iOS (SwiftUI)', () {
      test('chains .padding(EdgeInsets…) after child', () {
        final result = padding.toSwift(0, dataExpr: 'data');
        expect(result, contains('Text("Hi")'));
        expect(
          result,
          contains('.padding(EdgeInsets('),
        );
        expect(
          result,
          contains('trailing: 3.0'),
        );
      });

      test('respects indent on modifier chain', () {
        final result = padding.toSwift(1, dataExpr: 'data');
        expect(
          result,
          '    Text("Hi")\n    .padding(EdgeInsets(top: 2.0, leading: 1.0, bottom: 4.0, trailing: 3.0))',
        );
      });
    });

    group('Android (Glance)', () {
      test('kotlinImports include padding and Box', () {
        expect(
          padding.kotlinImports,
          contains('import androidx.glance.layout.padding'),
        );
        expect(
          padding.kotlinImports,
          contains('import androidx.glance.layout.Box'),
        );
        expect(
          padding.kotlinImports,
          contains('import androidx.compose.ui.unit.dp'),
        );
      });

      test('toKotlin injects GlanceModifier.padding(…dp)', () {
        final result = padding.toKotlin(0, dataExpr: 'data');
        expect(
          result,
          'Text(modifier = GlanceModifier.padding(start = 1.0.dp, top = 2.0.dp, end = 3.0.dp, bottom = 4.0.dp), text = "Hi")',
        );
        expect(result, contains('GlanceModifier.padding'));
      });
    });
  });
}
