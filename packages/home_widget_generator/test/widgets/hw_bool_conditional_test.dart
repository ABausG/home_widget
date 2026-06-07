import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWBoolConditional', () {
    const boolConditional = HWBoolConditional(
      data: HWBool('myBool', defaultValue: true),
      whenTrue: HWText.fixed('True'),
      whenFalse: HWText.fixed('False'),
    );

    group('model', () {
      test('throws ArgumentError on missing defaultValue during generation',
          () {
        final invalidConditional = HWBoolConditional(
          data: const HWBool('x'),
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

      test('dataDependencies include HWBool', () {
        expect(
          boolConditional.dataDependencies,
          contains(const HWBool('myBool', defaultValue: true)),
        );
      });
    });

    group('iOS (SwiftUI)', () {
      test('toSwift emits if / else on bool field', () {
        final code = boolConditional.toSwift(0, dataExpr: 'entry.data');
        expect(
          code,
          equals('if entry.data.myBool == true {\n'
              '    Text("True")\n'
              '} else {\n'
              '    Text("False")\n'
              '}'),
        );
        expect(code, contains('if entry.data.myBool == true'));
        expect(code, contains('Text("True")'));
      });
    });

    group('Android (Glance)', () {
      test('toKotlin emits if / else on bool field', () {
        final code = boolConditional.toKotlin(0, dataExpr: 'widgetData');
        expect(
          code,
          equals('if (widgetData.myBool == true) {\n'
              '    Text(text = "True")\n'
              '} else {\n'
              '    Text(text = "False")\n'
              '}'),
        );
        expect(code, contains('if (widgetData.myBool == true)'));
        expect(code, contains('Text(text = "True")'));
      });

      test('supports JSON child bool conditions', () {
        const jsonConditional = HWBoolConditional(
          data: HWJson('profile', HWBool('isActive', defaultValue: false)),
          whenTrue: HWText.fixed('True'),
          whenFalse: HWText.fixed('False'),
        );

        expect(
          jsonConditional.toSwift(0, dataExpr: 'entry.data'),
          contains('if (((entry.data.profile?.isActive) ?? (false))) == true'),
        );
        expect(
          jsonConditional.toKotlin(0, dataExpr: 'widgetData'),
          contains('if ((widgetData.profile?.isActive ?: false) == true'),
        );
      });

      test('supports nested JSON child bool conditions', () {
        const jsonConditional = HWBoolConditional(
          data: HWJson(
            'profile',
            HWJson('user', HWBool('isActive', defaultValue: false)),
          ),
          whenTrue: HWText.fixed('True'),
          whenFalse: HWText.fixed('False'),
        );

        expect(
          jsonConditional.toSwift(0, dataExpr: 'entry.data'),
          contains(
            'if (((entry.data.profile?.user?.isActive) ?? (false))) == true',
          ),
        );
        expect(
          jsonConditional.toKotlin(0, dataExpr: 'widgetData'),
          contains('if ((widgetData.profile?.user?.isActive ?: false) == true'),
        );
      });
    });
  });
}
