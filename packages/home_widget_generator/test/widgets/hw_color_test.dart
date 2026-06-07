import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

String expectedKotlinColor(HWColorRole role) {
  return switch (role) {
    HWColorRole.contentPrimary => 'GlanceTheme.colors.onSurface',
    HWColorRole.contentSecondary => 'GlanceTheme.colors.onSurfaceVariant',
    HWColorRole.contentTertiary => 'GlanceTheme.colors.outline',
    HWColorRole.contentAccent => 'GlanceTheme.colors.primaryContainer',
    HWColorRole.defaultBackground => 'GlanceTheme.colors.widgetBackground',
  };
}

String expectedSwiftColor(HWColorRole role) {
  return switch (role) {
    HWColorRole.contentPrimary => 'Color.primary',
    HWColorRole.contentSecondary => 'Color.secondary',
    HWColorRole.contentTertiary => 'Color(.tertiaryLabel)',
    HWColorRole.contentAccent => 'Color.accentColor',
    HWColorRole.defaultBackground => 'Color.clear',
  };
}

void main() {
  group('HWDefaultColor', () {
    group('Android (Glance)', () {
      for (final role in HWColorRole.values) {
        test(
          'for role "${role.name}" generates the correct '
          '"${expectedKotlinColor(role)}"',
          () {
            final color = HWDefaultColor(role);
            expect(
              color.toKotlin(0, dataExpr: ''),
              expectedKotlinColor(role),
            );
          },
        );
      }

      test('default colors pull GlanceTheme in kotlinImports', () {
        const c = HWDefaultColor(HWColorRole.contentPrimary);
        expect(
          c.kotlinImports,
          contains('import androidx.glance.GlanceTheme'),
        );
      });
    });

    group('iOS (SwiftUI)', () {
      for (final role in HWColorRole.values) {
        test(
          'for role "${role.name}" generates the correct '
          '"${expectedSwiftColor(role)}"',
          () {
            final color = HWDefaultColor(role);
            expect(
              color.toSwift(0, dataExpr: ''),
              expectedSwiftColor(role),
            );
          },
        );
      }
    });
  });

  group('HWColor factories and themed', () {
    test('HWColor.fixed matches HWFixedColor', () {
      const f = HWColor.fixed(0xFF00FF00);
      expect(f, isA<HWFixedColor>());
      expect((f as HWFixedColor).value, 0xFF00FF00);
    });

    test('HWColor.themed is HWThemedColor', () {
      const t = HWColor.themed(
        light: HWFixedColor(0xFF0000FF),
        dark: HWFixedColor(0xFF000000),
      );
      expect(t, isA<HWThemedColor>());
    });

    test('nested HWThemedColor toKotlin recurses in ColorProvider', () {
      const nested = HWThemedColor(
        light: HWThemedColor(
          light: HWFixedColor(0xFF00FF00),
          dark: HWFixedColor(0xFF0000FF),
        ),
        dark: HWFixedColor(0xFFFF0000),
      );
      final k = nested.toKotlin(0, dataExpr: 'data');
      expect(k, contains('Color(0xFF00FF00)'));
      expect(k, contains('Color(0xFFFF0000)'));
    });

    test('Themed with non-fixed light uses Color.White fallback in raw Kotlin',
        () {
      const t = HWThemedColor(
        light: HWDefaultColor(HWColorRole.contentPrimary),
        dark: HWFixedColor(0xFF000000),
      );
      final k = t.toKotlin(0, dataExpr: 'data');
      expect(k, contains('day = Color.White'));
      expect(k, contains('night = Color(0xFF000000)'));
    });

    test('HWThemedColor merges child kotlin import sets', () {
      const t = HWThemedColor(
        light: HWFixedColor(0xFF0000FF),
        dark: HWFixedColor(0xFF0000AA),
      );
      expect(
        t.kotlinImports,
        contains('import androidx.glance.color.ColorProvider'),
      );
    });
  });
}
