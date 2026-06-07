import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWDataExists', () {
    const dataExists = HWDataExists(
      data: HWString('myKey'),
      whenPresent: HWText.fixed('Present'),
      whenAbsent: HWText.fixed('Absent'),
    );

    group('model', () {
      test('dataDependencies include data key', () {
        expect(dataExists.dataDependencies, contains(const HWString('myKey')));
      });
    });

    group('iOS (SwiftUI)', () {
      test('toSwift emits if / else on data presence', () {
        final code = dataExists.toSwift(0, dataExpr: 'entry.data');
        expect(
          code,
          equals('if entry.data.myKey != nil {\n'
              '    Text("Present")\n'
              '} else {\n'
              '    Text("Absent")\n'
              '}'),
        );
        expect(code, contains('if '));
        expect(code, contains('Text("Present")'));
      });

      test('swiftViewModifiers merges both branches (empty for plain Text)',
          () {
        expect(dataExists.swiftViewModifiers, isEmpty);
      });
    });

    group('Android (Glance)', () {
      test('toKotlin emits if / else on null check', () {
        final code = dataExists.toKotlin(0, dataExpr: 'widgetData');
        expect(
          code,
          equals('if (widgetData.myKey != null) {\n'
              '    Text(text = "Present")\n'
              '} else {\n'
              '    Text(text = "Absent")\n'
              '}'),
        );
        expect(code, contains('if ('));
        expect(code, contains('Text(text = "Present")'));
      });

      test('kotlinImports merge both branches', () {
        expect(
          dataExists.kotlinImports,
          contains('import androidx.glance.text.Text'),
        );
      });

      test('supports JSON child existence checks', () {
        const jsonExists = HWDataExists(
          data: HWJson('profile', HWString('name')),
          whenPresent: HWText.fixed('Present'),
          whenAbsent: HWText.fixed('Absent'),
        );

        expect(
          jsonExists.toSwift(0, dataExpr: 'entry.data'),
          contains('if entry.data.profile?.name != nil'),
        );
        expect(
          jsonExists.toKotlin(0, dataExpr: 'widgetData'),
          contains('if (widgetData.profile?.name != null)'),
        );
      });
    });
  });
}
