import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWBoolConditional', () {
    test('throws ArgumentError on missing defaultValue during generation', () {
      final invalidConditional = HWBoolConditional(
        data: const HWBool('myBool'), // no default
        whenTrue: const HWText.fixed('True'),
        whenFalse: const HWText.fixed('False'),
      );
      expect(
        () => invalidConditional.toSwift(0, dataExpr: 'entry.data'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => invalidConditional.toKotlin(0, dataExpr: 'widgetData'),
        throwsA(isA<ArgumentError>()),
      );
    });

    final boolConditional = HWBoolConditional(
      data: const HWBool('myBool', defaultValue: true),
      whenTrue: const HWText.fixed('True'),
      whenFalse: const HWText.fixed('False'),
    );

    test('toSwift generates correct if block', () {
      final code = boolConditional.toSwift(0, dataExpr: 'entry.data');
      expect(
          code,
          equals('if entry.data.myBool == true {\n'
              '    Text("True")\n'
              '} else {\n'
              '    Text("False")\n'
              '}'));
    });

    test('toKotlin generates correct if block', () {
      final code = boolConditional.toKotlin(0, dataExpr: 'widgetData');
      expect(
          code,
          equals('if (widgetData.myBool == true) {\n'
              '    Text(text = "True")\n'
              '} else {\n'
              '    Text(text = "False")\n'
              '}'));
    });

    test('dataDependencies merges all dependencies', () {
      expect(boolConditional.dataDependencies,
          contains(const HWBool('myBool', defaultValue: true)));
    });
  });
}
