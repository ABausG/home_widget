import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWWidget.kotlinImports', () {
    test('Column in tree', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
        ],
      );
      final imports = node.kotlinImports;
      expect(imports, contains('import androidx.glance.layout.Column'));
    });

    test('Row in tree', () {
      final node = HWRow(
        children: [
          HWText.fixed('a'),
        ],
      );
      final imports = node.kotlinImports;
      expect(imports, contains('import androidx.glance.layout.Row'));
    });

    test('both Column + Row', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('a')]),
        ],
      );
      final imports = node.kotlinImports;
      expect(imports, contains('import androidx.glance.layout.Column'));
      expect(imports, contains('import androidx.glance.layout.Row'));
    });

    test('HWText only', () {
      final node = HWText.fixed('a');
      final imports = node.kotlinImports;
      // HWText might have text imports, check logic or ignore?
      // HWText imports: 'import androidx.glance.text.Text', 'import androidx.glance.text.TextStyle'
      expect(imports, contains('import androidx.glance.text.Text'));
    });

    test('alignment import when alignment is set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final imports = node.kotlinImports;
      expect(imports, contains('import androidx.glance.layout.Alignment'));
    });
    test('Spacer import collected when mainAxisAlignment set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final imports = node.kotlinImports;
      expect(imports, contains('import androidx.glance.layout.Spacer'));
    });

    test('no Spacer import when mainAxisAlignment not set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final imports = node.kotlinImports;
      expect(
        imports,
        isNot(contains('import androidx.glance.layout.Spacer')),
      );
    });
  });
}
