import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWPayload', () {
    const payload = HWPayload('city', HWString('selectedCity'));

    test('is keyed by its name and typed like its value', () {
      expect(payload.key, 'city');
      expect(payload.dartType, 'String');
      expect(payload.kotlinType, 'String');
      expect(payload.swiftType, 'String');
      expect(payload.isFixed, isFalse);
      expect(payload.isDataDependency, isTrue);
      expect(payload.unwrapped, const HWString('selectedCity'));
      expect(payload.leaf, const HWString('selectedCity'));
      expect(payload.nativeHelpers, isEmpty);
    });

    test('hands on the defaults of its value', () {
      const defaulted = HWPayload(
        'count',
        HWInt('stored', defaultValue: 2, previewValue: 5),
      );
      expect(defaulted.defaultValue, 2);
      expect(defaulted.previewValue, 5);
    });

    test('reads and renders the way its value does', () {
      const value = HWString('selectedCity');
      expect(payload.swiftAccess('data'), value.swiftAccess('data'));
      expect(payload.kotlinAccess('data'), value.kotlinAccess('data'));
      expect(payload.swiftReadExpr('data'), value.swiftReadExpr('data'));
      expect(payload.kotlinReadExpr('data'), value.kotlinReadExpr('data'));
      expect(
        payload.androidReadValue(store: 'prefs', key: 'k'),
        value.androidReadValue(store: 'prefs', key: 'k'),
      );
      expect(
        payload.iosReadValue(store: 'defaults', key: 'k'),
        value.iosReadValue(store: 'defaults', key: 'k'),
      );
      expect(
        payload.androidToString(outerValue: 'a', innerValue: 'b'),
        value.androidToString(outerValue: 'a', innerValue: 'b'),
      );
      expect(
        payload.iosToString(outerValue: 'a', innerValue: 'b'),
        value.iosToString(outerValue: 'a', innerValue: 'b'),
      );
    });

    test('a fixed value stays fixed and is no data dependency', () {
      const fixed = HWPayload('days', HWInt.fixed(7));
      expect(fixed.isFixed, isTrue);
      expect(fixed.isDataDependency, isFalse);
    });

    test('equality goes by name and value, whatever the type argument', () {
      const HWDataType<dynamic> same = HWPayload<dynamic>(
        'city',
        HWString('selectedCity'),
      );
      expect(payload, same);
      expect(payload.hashCode, same.hashCode);
      expect(
        payload,
        isNot(equals(const HWPayload('town', HWString('selectedCity')))),
      );
      expect(payload, isNot(equals(const HWPayload('city', HWString('x')))));
      expect(payload, isNot(equals(const HWString('selectedCity'))));
    });

    test('merges with an entry of the same name naming a compatible value', () {
      const defaulted = HWPayload(
        'city',
        HWString('selectedCity', defaultValue: 'Berlin'),
      );
      expect(payload.isCompatibleWith(defaulted), isTrue);
      expect(payload.mergedWith(defaulted), defaulted);

      expect(
        payload.isCompatibleWith(
          const HWPayload('town', HWString('selectedCity')),
        ),
        isFalse,
      );
      expect(
        payload.isCompatibleWith(const HWString('selectedCity')),
        isFalse,
      );
      expect(
        () => payload.mergedWith(const HWString('selectedCity')),
        throwsA(isA<GeneratorError>()),
      );
    });
  });

  group('HWPayloadEntry', () {
    HWPayloadEntry entryOf(HWDataType<dynamic> data) => HWPayloadEntry.of(data);

    test('a stored value is sent under its key', () {
      final entry = entryOf(const HWString('city'));
      expect(entry.name, 'city');
      expect(entry.isNamed, isFalse);
      expect(entry.value, const HWString('city'));
      expect(entry.type, HWPayloadType.string);
      expect(entry.isFixed, isFalse);
      expect(entry.isNullable, isTrue);
      expect(entry.readsItem, isFalse);
      expect(entry.fixedWireValue, isNull);
    });

    test('an HWPayload names the value it wraps', () {
      final entry = entryOf(const HWPayload('town', HWString('city')));
      expect(entry.name, 'town');
      expect(entry.isNamed, isTrue);
      expect(entry.value, const HWString('city'));
    });

    test('a JSON leaf is named after the leaf key', () {
      final entry = entryOf(
        const HWJson('user', HWJson('profile', HWInt('age'))),
      );
      expect(entry.name, 'age');
      expect(entry.type, HWPayloadType.int);
    });

    test('an item field and a timed value keep the key of what they wrap', () {
      final item = entryOf(const HWItemData(HWString('id')));
      expect(item.name, 'id');
      expect(item.readsItem, isTrue);

      final timedItem = entryOf(const HWTimedData(HWItemData(HWBool('done'))));
      expect(timedItem.name, 'done');
      expect(timedItem.readsItem, isTrue);
      expect(timedItem.type, HWPayloadType.bool);

      final timed = entryOf(const HWTimedData(HWDouble('ratio')));
      expect(timed.name, 'ratio');
      expect(timed.readsItem, isFalse);
      expect(timed.type, HWPayloadType.double);
    });

    test('lists the entries of a data list in order', () {
      final entries = HWPayloadEntry.listOf(const [
        HWString('city'),
        HWPayload('days', HWInt.fixed(7)),
      ]);
      expect(entries.map((entry) => entry.name), ['city', 'days']);
    });

    test('carries scalars and dates, and nothing else', () {
      expect(entryOf(const HWDateTime('at')).type, HWPayloadType.dateTime);
      expect(entryOf(const HWImageData('avatar')).type, isNull);
      expect(
        entryOf(
          const HWIconData.resolved(
            'mood',
            entries: [],
            iconFont: HWIconFont(family: 'MaterialIcons'),
          ),
        ).type,
        isNull,
      );
      expect(
        entryOf(
          const HWLocalizedString('title', defaultTranslations: {'en': 'T'}),
        ).type,
        isNull,
      );
    });

    test('names the Dart type of every payload type', () {
      expect(
        HWPayloadType.values.map((type) => type.dartType),
        ['String', 'int', 'double', 'bool', 'DateTime'],
      );
    });

    test('is nullable unless fixed or defaulted', () {
      expect(entryOf(const HWInt('count')).isNullable, isTrue);
      expect(
        entryOf(const HWInt('count', defaultValue: 1)).isNullable,
        isFalse,
      );
      expect(
        entryOf(const HWPayload('n', HWInt.fixed(1))).isNullable,
        isFalse,
      );
      expect(
        entryOf(const HWJson('g', HWString('s', defaultValue: 'x'))).isNullable,
        isFalse,
      );
    });

    test('writes a fixed value as the text it travels as', () {
      String? wire(HWDataType<dynamic> value) =>
          entryOf(HWPayload<dynamic>('n', value)).fixedWireValue;

      expect(wire(const HWString.fixed('a b')), 'a b');
      expect(wire(const HWInt.fixed(7)), '7');
      expect(wire(const HWDouble.fixed(2.5)), '2.5');
      expect(wire(const HWBool.fixed(false)), 'false');
      expect(
        wire(const HWDateTime.fixed('2026-09-22T10:00:00+02:00')),
        '${DateTime.utc(2026, 9, 22, 8).millisecondsSinceEpoch}',
      );
      expect(wire(const HWDateTime.fixed('not a date')), isNull);
      expect(wire(const HWString.localizedFixed({'en': 'Hi'})), isNull);
      expect(wire(const HWImageData.asset('a.png')), isNull);
      expect(wire(const HWString('stored')), isNull);
    });

    test('encodes a stored value through the native helper', () {
      final entry = entryOf(const HWString('city'));
      expect(entry.swiftValue('entry.data'), 'hwPayloadValue(entry.data.city)');
      expect(
        entry.kotlinValue('widgetData'),
        'hwPayloadValue(widgetData.city)',
      );
    });

    test('encodes an item field off the loop item', () {
      final entry = entryOf(const HWItemData(HWString('id')));
      expect(entry.swiftValue('entry.data'), 'hwPayloadValue(hwItem.id)');
      expect(entry.kotlinValue('widgetData'), 'hwPayloadValue(hwItem.id)');
    });

    test('encodes a JSON leaf with its default applied', () {
      final entry = entryOf(
        const HWJson('user', HWString('name', defaultValue: 'Ada')),
      );
      expect(
        entry.swiftValue('data'),
        'hwPayloadValue((((data.user?.name) ?? ("Ada"))))',
      );
      expect(
        entry.kotlinValue('data'),
        'hwPayloadValue((data.user?.name ?: "Ada"))',
      );
    });

    test('encodes a fixed value as an escaped literal', () {
      final entry = entryOf(const HWPayload('q', HWString.fixed(r'a"$b')));
      expect(entry.swiftValue('data'), r'"a\"$b"');
      expect(entry.kotlinValue('data'), r'"a\"\$b"');
    });

    test('compares shapes by name, type, nullability and fallback', () {
      final base = entryOf(const HWInt('count', defaultValue: 1));
      expect(
        base.hasSameShapeAs(entryOf(const HWInt('count', defaultValue: 1))),
        isTrue,
      );
      expect(
        base.hasSameShapeAs(
          entryOf(const HWPayload('count', HWInt('other', defaultValue: 1))),
        ),
        isTrue,
      );
      expect(base.hasSameShapeAs(entryOf(const HWInt('count'))), isFalse);
      expect(
        base.hasSameShapeAs(entryOf(const HWInt('count', defaultValue: 2))),
        isFalse,
      );
      expect(
        base.hasSameShapeAs(entryOf(const HWInt('total', defaultValue: 1))),
        isFalse,
      );
      expect(
        base.hasSameShapeAs(
          entryOf(const HWDouble('count', defaultValue: 1)),
        ),
        isFalse,
      );

      final fixed = entryOf(const HWPayload('n', HWInt.fixed(1)));
      expect(
        fixed.hasSameShapeAs(entryOf(const HWPayload('n', HWInt.fixed(1)))),
        isTrue,
      );
      expect(
        fixed.hasSameShapeAs(entryOf(const HWPayload('n', HWInt.fixed(2)))),
        isFalse,
      );
    });
  });

  group('HWPayloadUrl', () {
    test('appends the marker, ahead of a fragment and after a query', () {
      expect(
        const HWPayloadUrl('myapp://weather').staticUrl,
        'myapp://weather?homeWidget',
      );
      expect(
        const HWPayloadUrl('myapp://weather?city=1').staticUrl,
        'myapp://weather?city=1&homeWidget',
      );
      expect(
        const HWPayloadUrl('myapp://weather#today').staticUrl,
        'myapp://weather?homeWidget#today',
      );
    });

    test('leaves a URL already carrying the marker as it is', () {
      const url = HWPayloadUrl('myapp://weather?homeWidget&a=1');
      expect(url.staticUrl, 'myapp://weather?homeWidget&a=1');
      expect(url.appendedMarker, isEmpty);
    });

    test('keeps the casing the schema wrote', () {
      expect(
        const HWPayloadUrl('myApp://Weather').staticUrl,
        'myApp://Weather?homeWidget',
      );
    });

    test('splits the URL at its fragment', () {
      const url = HWPayloadUrl('myapp://weather?a=1#today');
      expect(url.head, 'myapp://weather?a=1');
      expect(url.fragment, '#today');
      expect(url.appendedMarker, 'homeWidget');
      expect(const HWPayloadUrl('myapp://weather').fragment, isEmpty);
    });

    test('reads the static query, the marker left out', () {
      expect(
        const HWPayloadUrl('myapp://w?a=1&a=2&b=x').staticQuery,
        {
          'a': ['1', '2'],
          'b': ['x'],
        },
      );
      expect(const HWPayloadUrl('myapp://w').staticQuery, isEmpty);
    });

    test('parses to what the app receives', () {
      final parsed = const HWPayloadUrl('myApp://weather').parsed!;
      expect(parsed.scheme, 'myapp');
      expect(parsed.queryParametersAll.keys, ['homeWidget']);
      expect(const HWPayloadUrl('http://[::1').parsed, isNull);
      expect(const HWPayloadUrl('http://[::1').staticQuery, isEmpty);
      expect(const HWPayloadUrl('http://[::1').appendedMarker, 'homeWidget');
    });

    test('without a payload is a static URL on both platforms', () {
      const url = HWPayloadUrl(r'myapp://weather?q="$a"');
      expect(url.nativeHelpers, isEmpty);
      expect(
        url.toSwift('entry.data'),
        r'URL(string: "myapp://weather?q=\"$a\"&homeWidget")',
      );
      expect(
        url.toKotlin('widgetData'),
        r'Uri.parse("myapp://weather?q=\"\$a\"&homeWidget")',
      );
    });

    test('with a payload is built by the native helper', () {
      final url = HWPayloadUrl.of(
        'myapp://forecast?tab=1#top',
        const [HWString('city'), HWPayload('days', HWInt.fixed(7))],
      );
      expect(
        url.nativeHelpers,
        {HWNativeHelper.hwPayloadUrl, HWNativeHelper.hwPayloadValue},
      );
      expect(
        url.toSwift('entry.data'),
        'hwPayloadUrl("myapp://forecast?tab=1", '
        '[("city", hwPayloadValue(entry.data.city)), ("days", "7")], '
        '"homeWidget", "#top")',
      );
      expect(
        url.toKotlin('widgetData'),
        'hwPayloadUrl("myapp://forecast?tab=1", '
        'listOf("city" to hwPayloadValue(widgetData.city), "days" to "7"), '
        '"homeWidget", "#top")',
      );
    });

    test('a payload of constants needs no value helper', () {
      final url = HWPayloadUrl.of(
        'myapp://forecast',
        const [HWPayload('days', HWInt.fixed(7))],
      );
      expect(url.nativeHelpers, {HWNativeHelper.hwPayloadUrl});
    });

    test('names the import of the Kotlin Uri', () {
      expect(HWPayloadUrl.kotlinImports, {'import android.net.Uri'});
    });

    group('hasSameStaticUrlAs', () {
      test('ignores the payload and the casing parsing drops', () {
        expect(
          const HWPayloadUrl('myapp://a?tab=1').hasSameStaticUrlAs(
            HWPayloadUrl.of('myApp://a?tab=1', const [HWString('city')]),
          ),
          isTrue,
        );
        expect(
          const HWPayloadUrl('myapp://a')
              .hasSameStaticUrlAs(const HWPayloadUrl('myapp://a')),
          isTrue,
        );
      });

      test('tells URLs apart by base and by static query', () {
        const base = HWPayloadUrl('myapp://a?tab=1');
        for (final other in const [
          'myapp://b?tab=1',
          'myapp://a',
          'myapp://a?tab=2',
          'myapp://a?tab=1&tab=2',
          'myapp://a?tab=1&page=2',
          'myapp://a?page=1',
          'http://[::1',
        ]) {
          expect(
            base.hasSameStaticUrlAs(HWPayloadUrl(other)),
            isFalse,
            reason: other,
          );
          expect(
            HWPayloadUrl(other).hasSameStaticUrlAs(base),
            isFalse,
            reason: other,
          );
        }
      });
    });

    group('payloadNameMatching', () {
      const settings = HWPayloadUrl('myapp://home?tab=settings&page=1');

      test('names the value that can produce a static parameter', () {
        expect(
          settings.payloadNameMatching(
            HWPayloadUrl.of('myapp://home?page=1', const [HWString('tab')]),
          ),
          'tab',
        );
        expect(
          settings.payloadNameMatching(
            HWPayloadUrl.of(
              'myapp://home',
              const [HWInt('page'), HWString('tab')],
            ),
          ),
          'tab',
        );
      });

      test('is null when a static parameter cannot be produced', () {
        expect(
          settings.payloadNameMatching(const HWPayloadUrl('myapp://home')),
          isNull,
        );
        expect(
          settings.payloadNameMatching(
            HWPayloadUrl.of('myapp://home', const [HWString('tab')]),
          ),
          isNull,
        );
        expect(
          settings.payloadNameMatching(
            HWPayloadUrl.of('myapp://home?page=2', const [HWString('tab')]),
          ),
          isNull,
        );
        expect(
          settings.payloadNameMatching(
            HWPayloadUrl.of('myapp://other', const [HWString('tab')]),
          ),
          isNull,
        );
      });

      test('is null when nothing is left for a payload to produce', () {
        expect(
          settings.payloadNameMatching(
            HWPayloadUrl.of(
              'myapp://home?tab=settings&page=1&x=1',
              const [HWString('city')],
            ),
          ),
          isNull,
        );
        expect(
          const HWPayloadUrl('myapp://home').payloadNameMatching(
            HWPayloadUrl.of('myapp://home', const [HWString('tab')]),
          ),
          isNull,
        );
      });
    });

    group('overlaps', () {
      bool collide(HWPayloadUrl a, HWPayloadUrl b) {
        expect(a.overlaps(b), b.overlaps(a));
        return a.overlaps(b);
      }

      test('the same URL collides with itself', () {
        expect(
          collide(
            const HWPayloadUrl('myapp://a'),
            const HWPayloadUrl('myApp://a'),
          ),
          isTrue,
        );
      });

      test('another scheme, host, path or fragment tells two URLs apart', () {
        const base = HWPayloadUrl('myapp://a/b#c');
        expect(collide(base, const HWPayloadUrl('other://a/b#c')), isFalse);
        expect(collide(base, const HWPayloadUrl('myapp://x/b#c')), isFalse);
        expect(collide(base, const HWPayloadUrl('myapp://a/x#c')), isFalse);
        expect(collide(base, const HWPayloadUrl('myapp://a/b#x')), isFalse);
      });

      test('a URL with more static parameters still matches the bare one', () {
        expect(
          collide(
            const HWPayloadUrl('myapp://a'),
            const HWPayloadUrl('myapp://a?tab=1'),
          ),
          isTrue,
        );
      });

      test('differing values of a static parameter tell two URLs apart', () {
        expect(
          collide(
            const HWPayloadUrl('myapp://a?tab=1'),
            const HWPayloadUrl('myapp://a?tab=2'),
          ),
          isFalse,
        );
        expect(
          collide(
            const HWPayloadUrl('myapp://a?tab=1'),
            const HWPayloadUrl('myapp://a?tab=1&tab=2'),
          ),
          isFalse,
        );
        expect(
          collide(
            const HWPayloadUrl('myapp://a?tab=1'),
            const HWPayloadUrl('myapp://a?page=1'),
          ),
          isFalse,
        );
      });

      test('a payload value may happen to match a static parameter', () {
        expect(
          collide(
            const HWPayloadUrl('myapp://a?tab=1'),
            HWPayloadUrl.of('myapp://a', const [HWString('tab')]),
          ),
          isTrue,
        );
      });

      test('a URL that does not parse collides with nothing', () {
        expect(
          collide(
            const HWPayloadUrl('http://[::1'),
            const HWPayloadUrl('http://[::1'),
          ),
          isFalse,
        );
      });
    });
  });
}
