import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

String expectedSwiftTextStyleRoleName(HWTextStyleRole role) {
  return switch (role) {
    HWTextStyleRole.title => 'title',
    HWTextStyleRole.headline => 'headline',
    HWTextStyleRole.body => 'body',
    HWTextStyleRole.callout => 'callout',
    HWTextStyleRole.caption => 'caption',
    HWTextStyleRole.captionSmall => 'caption2',
  };
}

int expectedAndroidTextStyleFontSizeSp(HWTextStyleRole role) {
  return switch (role) {
    HWTextStyleRole.title => 22,
    HWTextStyleRole.headline => 18,
    HWTextStyleRole.body => 16,
    HWTextStyleRole.callout => 14,
    HWTextStyleRole.caption => 12,
    HWTextStyleRole.captionSmall => 11,
  };
}

HWRoleTextStyle _roleTextStyleFor(HWTextStyleRole role) {
  return switch (role) {
    HWTextStyleRole.title => HWRoleTextStyle.title(),
    HWTextStyleRole.headline => HWRoleTextStyle.headline(),
    HWTextStyleRole.body => HWRoleTextStyle.body(),
    HWTextStyleRole.callout => HWRoleTextStyle.callout(),
    HWTextStyleRole.caption => HWRoleTextStyle.caption(),
    HWTextStyleRole.captionSmall => HWRoleTextStyle.captionSmall(),
  };
}

void main() {
  group('HWRoleTextStyle (role table vs emitted code)', () {
    group('iOS (SwiftUI)', () {
      for (final role in HWTextStyleRole.values) {
        test(
          'for role "${role.name}" generates the correct '
          '"${expectedSwiftTextStyleRoleName(role)}"',
          () {
            final t = _roleTextStyleFor(role);
            final n = expectedSwiftTextStyleRoleName(role);
            final out =
                HWText.fixed('R', style: t).toSwift(0, dataExpr: 'data');
            expect(out, contains('.font(.$n)'), reason: 'role $role');
          },
        );
      }
    });

    group('Android (Glance)', () {
      for (final role in HWTextStyleRole.values) {
        test(
          'for role "${role.name}" generates the correct '
          '"fontSize = ${expectedAndroidTextStyleFontSizeSp(role)}.sp"',
          () {
            final t = _roleTextStyleFor(role);
            final out = HWText.fixed('R', style: t).toKotlin(0, dataExpr: 'd');
            final n = expectedAndroidTextStyleFontSizeSp(role);
            expect(out, contains('fontSize = $n.sp'), reason: 'role $role');
          },
        );
      }
    });
  });
}
