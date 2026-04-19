import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWDataExists', () {
    const dataExists = HWDataExists(
      data: HWString('myKey'),
      whenPresent: HWText.fixed('Present'),
      whenAbsent: HWText.fixed('Absent'),
    );

    test('toSwift generates correct if block', () {
      final code = dataExists.toSwift(0, dataExpr: 'entry.data');
      expect(
          code,
          equals('if entry.data.myKey != nil {\n'
              '    Text("Present")\n'
              '} else {\n'
              '    Text("Absent")\n'
              '}'));
    });

    test('toKotlin generates correct if block', () {
      final code = dataExists.toKotlin(0, dataExpr: 'widgetData');
      expect(
          code,
          equals('if (widgetData.myKey != null) {\n'
              '    Text(text = "Present")\n'
              '} else {\n'
              '    Text(text = "Absent")\n'
              '}'));
    });

    test('dataDependencies merges all dependencies', () {
      expect(dataExists.dataDependencies, contains(const HWString('myKey')));
    });

    test('kotlinImports merges both branches', () {
      expect(dataExists.kotlinImports,
          contains('import androidx.glance.text.Text'));
    });

    test('swiftViewModifiers merges both branches', () {
      expect(dataExists.swiftViewModifiers, isEmpty);
    });
  });
}
