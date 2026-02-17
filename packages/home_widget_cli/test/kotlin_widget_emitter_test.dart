import 'package:home_widget_cli/src/generators/kotlin_widget_emitter.dart';

import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('collectKotlinLayoutImports', () {
    test('Column in tree', () {
      final node = HWColumn(
        children: [
          HWText.fixed('a'),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Column'));
    });

    test('Row in tree', () {
      final node = HWRow(
        children: [
          HWText.fixed('a'),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Row'));
    });

    test('both Column + Row', () {
      final node = HWColumn(
        children: [
          HWRow(children: [HWText.fixed('a')]),
        ],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Column'));
      expect(imports, contains('import androidx.glance.layout.Row'));
    });

    test('HWText only', () {
      final node = HWText.fixed('a');
      final imports = collectKotlinLayoutImports(node);
      expect(imports, isEmpty);
    });

    test('null tree', () {
      final imports = collectKotlinLayoutImports(null);
      expect(imports, isEmpty);
    });

    test('alignment import when alignment is set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        crossAxisAlignment: HWCrossAxisAlignment.center,
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.compose.ui.Alignment'));
    });
    test('Spacer import collected when mainAxisAlignment set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
        mainAxisAlignment: HWMainAxisAlignment.center,
      );
      final imports = collectKotlinLayoutImports(node);
      expect(imports, contains('import androidx.glance.layout.Spacer'));
    });

    test('no Spacer import when mainAxisAlignment not set', () {
      final node = HWColumn(
        children: [HWText.fixed('a')],
      );
      final imports = collectKotlinLayoutImports(node);
      expect(
        imports,
        isNot(contains('import androidx.glance.layout.Spacer')),
      );
    });
  });
}
