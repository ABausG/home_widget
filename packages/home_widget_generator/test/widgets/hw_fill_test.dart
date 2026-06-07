import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWFill', () {
    final fill = HWFill(child: HWText.fixed('a'));

    group('model', () {
      test('delegates dataDependencies to child', () {
        const f = HWFill(
          child: HWText(
            HWString('k'),
            style: HWTextStyle(
              color: HWThemedColor(
                light: HWFixedColor(0xFF000000),
                dark: HWFixedColor(0xFFFFFFFF),
              ),
            ),
          ),
        );
        expect(
          f.dataDependencies,
          containsAll(<Object>[const HWString('k')]),
        );
        expect(
          f.swiftViewModifiers.any(
            (e) => e.contains('colorScheme'),
          ),
          isTrue,
        );
        expect(
          f.kotlinImports.any(
            (s) => s.contains('ColorProvider') || s.contains('glance.color'),
          ),
          isTrue,
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('toSwift applies .frame max infinity on child', () {
        final result = fill.toSwift(0, dataExpr: 'data');
        expect(
          result,
          'Text("a")\n.frame(maxWidth: .infinity, maxHeight: .infinity)',
        );
        expect(result, contains('.frame(maxWidth:'));
      });

      test(
        'toSwift wraps conditional child in Group { ... } so the modifier '
        'chains on a View expression',
        () {
          const fillOverConditional = HWFill(
            child: HWDataExists(
              data: HWBool('flag'),
              whenPresent: HWText.fixed('on'),
              whenAbsent: HWText.fixed('off'),
            ),
          );

          final result = fillOverConditional.toSwift(0, dataExpr: 'data');

          expect(result, startsWith('Group {\n'));
          expect(result, contains('if data.flag != nil {'));
          expect(
            result,
            endsWith('\n}\n.frame(maxWidth: .infinity, maxHeight: .infinity)'),
          );
        },
      );
    });

    group('Android (Glance)', () {
      test('kotlinImports include fillMaxSize and Box', () {
        expect(
          fill.kotlinImports,
          contains('import androidx.glance.layout.fillMaxSize'),
        );
        expect(
          fill.kotlinImports,
          contains('import androidx.glance.layout.Box'),
        );
      });

      test('toKotlin injects fillMaxSize modifier on Text', () {
        final result = fill.toKotlin(0, dataExpr: 'data');
        expect(
          result,
          'Text(modifier = GlanceModifier.fillMaxSize(), text = "a")',
        );
        expect(result, contains('fillMaxSize()'));
      });
    });
  });
}
