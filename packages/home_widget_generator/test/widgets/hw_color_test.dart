import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWDefaultColor', () {
    test('contentPrimary maps correctly', () {
      const color = HWDefaultColor(HWColorRole.contentPrimary);
      expect(color.toSwift(0, dataExpr: ''), equals('Color.primary'));
      expect(color.toKotlin(0, dataExpr: ''),
          equals('GlanceTheme.colors.onSurface'));
    });

    test('contentSecondary maps correctly', () {
      const color = HWDefaultColor(HWColorRole.contentSecondary);
      expect(color.toSwift(0, dataExpr: ''), equals('Color.secondary'));
      expect(color.toKotlin(0, dataExpr: ''),
          equals('GlanceTheme.colors.onSurfaceVariant'));
    });

    test('backgroundPrimary maps correctly', () {
      const color = HWDefaultColor(HWColorRole.backgroundPrimary);
      expect(color.toSwift(0, dataExpr: ''), equals('Color.accentColor'));
      expect(color.toKotlin(0, dataExpr: ''),
          equals('GlanceTheme.colors.primaryContainer'));
    });

    test('contentTertiary maps correctly', () {
      const color = HWDefaultColor(HWColorRole.contentTertiary);
      expect(color.toSwift(0, dataExpr: ''), equals('Color(.tertiaryLabel)'));
      expect(color.toKotlin(0, dataExpr: ''),
          equals('GlanceTheme.colors.outline'));
    });
  });
}
