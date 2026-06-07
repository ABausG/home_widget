import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

WidgetSpec _spec({
  String name = 'TestWidget',
  List<HWDataType<dynamic>> dataFields = const [],
  HWWidget? widgetTree,
}) {
  return WidgetSpec(
    data: HomeWidget(name: name),
    className: name,
    dataFields: dataFields,
    widgetTree: widgetTree,
  );
}

void main() {
  group('WidgetSpec.effectiveWidgetTree', () {
    test('returns provided widgetTree when set and not HWDataOnly', () {
      final tree = HWText.fixed('hello');
      final spec = _spec(widgetTree: tree);
      expect(identical(spec.effectiveWidgetTree, tree), isTrue);
    });

    test('builds default tree when widgetTree is null', () {
      final spec = _spec(
        name: 'MyWidget',
        dataFields: const [HWString('label'), HWInt('count')],
      );

      final tree = spec.effectiveWidgetTree;
      expect(tree, isA<HWColumn>());
      final children = (tree as HWColumn).children;
      expect(children.length, 3);
      expect(children.first, isA<HWText>());
      expect(children[1], isA<HWRow>());
      expect(children[2], isA<HWRow>());
    });

    test('builds default tree when widgetTree is HWDataOnly', () {
      final spec = _spec(
        widgetTree: const HWDataOnly([]),
        dataFields: const [HWString('label')],
      );
      expect(spec.effectiveWidgetTree, isA<HWColumn>());
    });
  });

  group('WidgetSpec.primitiveDataFields', () {
    test('filters out HWJson fields', () {
      const string = HWString('label');
      const int_ = HWInt('count');
      const json = HWJson('root', HWString('inner'));
      final spec = _spec(dataFields: const [string, int_, json]);

      expect(spec.primitiveDataFields, equals([string, int_]));
    });

    test('returns empty when only HWJson fields are present', () {
      const json = HWJson('root', HWString('inner'));
      final spec = _spec(dataFields: const [json]);
      expect(spec.primitiveDataFields, isEmpty);
    });
  });

  group('WidgetSpec.jsonDataGroups', () {
    test('returns empty when no HWJson fields', () {
      final spec = _spec(dataFields: const [HWString('label')]);
      expect(spec.jsonDataGroups, isEmpty);
    });

    test('groups multiple json fields under the same root key', () {
      const a = HWJson('user', HWString('name'));
      const b = HWJson('user', HWInt('age'));
      final spec = _spec(dataFields: const [a, b]);

      final groups = spec.jsonDataGroups;
      expect(groups.length, 1);
      expect(groups.single.key, 'user');
      expect(groups.single.children.length, 2);
      expect(groups.single.children[0].path, ['name']);
      expect(groups.single.children[1].path, ['age']);
    });

    test('preserves insertion order across distinct root keys', () {
      const a = HWJson('b_root', HWString('x'));
      const b = HWJson('a_root', HWString('y'));
      final spec = _spec(dataFields: const [a, b]);

      final groups = spec.jsonDataGroups;
      expect(groups.map((g) => g.key).toList(), ['b_root', 'a_root']);
    });

    test('deduplicates identical paths with identical leaf types', () {
      const a = HWJson('user', HWString('name'));
      const b = HWJson('user', HWString('name'));
      final spec = _spec(dataFields: const [a, b]);

      final groups = spec.jsonDataGroups;
      expect(groups.single.children.length, 1);
    });

    test('captures nested path segments', () {
      const nested = HWJson('user', HWJson('address', HWString('city')));
      final spec = _spec(dataFields: const [nested]);

      final group = spec.jsonDataGroups.single;
      expect(group.key, 'user');
      expect(group.children.single.path, ['address', 'city']);
    });
  });

  group('WidgetSpec equality', () {
    test('equal specs are equal and share hashCode', () {
      final a = _spec();
      final b = _spec();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different className breaks equality', () {
      final a = _spec(name: 'A');
      final b = _spec(name: 'B');
      expect(a, isNot(equals(b)));
    });
  });
}
