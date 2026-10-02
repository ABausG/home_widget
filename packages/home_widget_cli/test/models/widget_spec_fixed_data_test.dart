import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _font = HWIconFont(family: 'MaterialIcons');

const _constantLocalized =
    HWString.localizedFixed({'en': 'Hello', 'de': 'Hallo'});

/// A spec whose data fields are exactly what [tree] binds, the way the parser
/// builds one.
WidgetSpec _spec(HWWidget tree) => WidgetSpec(
      data: HomeWidget(name: 'TestWidget', widget: tree),
      className: 'TestWidget',
      dataFields: tree.dataDependencies.toList(),
      widgetTree: tree,
    );

void main() {
  group('WidgetSpec with fixed values', () {
    const fixedTexts = <String, HWText>{
      'HWString.fixed': HWText(HWString.fixed('Hi')),
      'HWString.localizedFixed': HWText(_constantLocalized),
      'HWInt.fixed': HWText.number(HWInt.fixed(3)),
      'HWDouble.fixed': HWText.number(HWDouble.fixed(2.5)),
      'HWBool.fixed': HWText(HWBool.fixed(true)),
      'HWDateTime.fixed':
          HWText.dateTime(HWDateTime.fixed('2026-09-22T10:00:00Z')),
    };

    for (final MapEntry(key: name, value: text) in fixedTexts.entries) {
      test('$name stores no field', () {
        final spec = _spec(text);

        expect(
          spec.declaredDataFields,
          text.dataType == _constantLocalized ? [_constantLocalized] : isEmpty,
        );
        expect(spec.primitiveDataFields, isEmpty);
        expect(spec.timedDataFields, isEmpty);
        expect(spec.jsonDataGroups, isEmpty);
        expect(spec.keyedLocalizedStrings, isEmpty);
        expect(spec.iconFields, isEmpty);
        expect(spec.imageDataFields, isEmpty);
        expect(spec.hasPreviewValues, isFalse);
        expect(spec.hasTimedData, isFalse);
      });
    }

    test('HWImageData.asset stores no field', () {
      final spec = _spec(const HWImage(HWImageData.asset('assets/logo.png')));

      expect(spec.primitiveDataFields, isEmpty);
      expect(spec.runtimeImageFields, isEmpty);
      expect(
        spec.assetImageFields,
        [const HWImageData.asset('assets/logo.png')],
      );
    });

    test('HWIconData.fixed stores no field and generates no enum', () {
      final spec = _spec(
        const HWIcon(HWIconData.resolvedFixed(0xe87d, iconFont: _font)),
      );

      expect(spec.dataFields, isEmpty);
      expect(spec.primitiveDataFields, isEmpty);
      expect(spec.iconFields, isEmpty);
      expect(spec.iconEnums, isEmpty);
    });

    test('dataFields keeps only the fixed values that own a resource', () {
      final spec = _spec(
        const HWColumn(
          children: [
            HWText(HWString.fixed('Hi')),
            HWText(_constantLocalized),
            HWText.number(HWInt.fixed(3)),
            HWText.number(HWDouble.fixed(2.5)),
            HWText(HWBool.fixed(true)),
            HWText.dateTime(HWDateTime.fixed('2026-09-22T10:00:00Z')),
            HWImage(HWImageData.asset('assets/logo.png')),
            HWText(HWString('label')),
          ],
        ),
      );

      expect(spec.dataFields, [
        _constantLocalized,
        const HWImageData.asset('assets/logo.png'),
        const HWString('label'),
      ]);
      expect(spec.primitiveDataFields, [const HWString('label')]);
      expect(spec.constantLocalizedStrings, [_constantLocalized]);
    });

    test('two different fixed values of one type never fold into one', () {
      final spec = _spec(
        const HWColumn(
          children: [
            HWText(HWString.fixed('a')),
            HWText(HWString.fixed('b')),
            HWText(HWString('label')),
          ],
        ),
      );

      expect(spec.declaredDataFields, [const HWString('label')]);
      expect(spec.dataFields, [const HWString('label')]);
      expect(
        spec.effectiveWidgetTree.toSwift(0, dataExpr: 'entry.data'),
        allOf(contains('Text("a")'), contains('Text("b")')),
      );
    });

    test('a fixed date still names the parser its render goes through', () {
      final spec = _spec(
        const HWText.dateTime(HWDateTime.fixed('2026-09-22T10:00:00Z')),
      );

      expect(spec.nativeHelpers, contains(HWNativeHelper.hwParseIsoDate));
    });

    group('previewContentHash', () {
      test('digests the fixed values with the body they are written into', () {
        const format = HWNumberFormat.percent();
        final spec = _spec(
          const HWColumn(
            children: [
              HWText(HWString.fixed('Hi')),
              HWText.number(HWInt.fixed(3), format: format),
              HWText.number(HWDouble.fixed(2.5), format: format),
              HWText(HWString('label')),
            ],
          ),
        );

        expect(spec.previewContentHash, '06ad621b');
        expect(spec.nativeHelpers, [
          HWNativeHelper.hwFormatLocale,
          HWNativeHelper.hwFormatPercent,
        ]);
      });

      test('changes with the fixed value', () {
        String hashOf(HWDataType<dynamic> data) =>
            _spec(HWText(data)).previewContentHash;

        expect(
          hashOf(const HWString.fixed('a')),
          isNot(hashOf(const HWString.fixed('b'))),
        );
        expect(
          hashOf(const HWDateTime.fixed('2026-09-22T10:00:00Z')),
          isNot(hashOf(const HWDateTime.fixed('2026-09-23T10:00:00Z'))),
        );
      });
    });
  });
}
