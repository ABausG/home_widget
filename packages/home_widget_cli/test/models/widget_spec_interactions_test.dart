import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _label = HWText(HWString.fixed('label'));

const _handler = InteractionHandler(
  libraryUri: 'package:app/handlers.dart',
  name: 'onCounterInteraction',
);

const _increment = HWButton(
  'increment',
  data: [HWInt('step')],
  child: HWText(HWString.fixed('+')),
);

const _reset = HWButton('reset', child: HWText(HWString.fixed('Reset')));

WidgetSpec _spec(
  HWWidget? tree, {
  InteractionHandler? handler = _handler,
  List<HWWidgetFamily>? families,
  bool configureIos = true,
  String className = 'Counter',
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Counter',
        android: const HomeWidgetAndroidConfiguration(),
        iOS: configureIos
            ? HomeWidgetIOSConfiguration(
                groupId: 'group.counter',
                supportedFamilies: families,
              )
            : null,
      ),
      className: className,
      widgetTree: tree,
      interactionHandler: handler,
    );

void main() {
  group('InteractionHandler', () {
    test('references a top-level function by its name', () {
      expect(_handler.reference, 'onCounterInteraction');
      expect(_handler.className, isNull);
      expect(_handler.returnsFuture, isTrue);
    });

    test('references a static function through its class', () {
      const handler = InteractionHandler(
        libraryUri: 'package:app/handlers.dart',
        name: 'onTap',
        className: 'Handlers',
        returnsFuture: false,
      );

      expect(handler.reference, 'Handlers.onTap');
      expect(handler.returnsFuture, isFalse);
    });

    test('equals a handler naming the same function', () {
      // ignore: prefer_const_constructors
      final same = InteractionHandler(
        libraryUri: 'package:app/handlers.dart',
        name: 'onCounterInteraction',
      );

      expect(_handler == _handler, isTrue);
      expect(same, _handler);
      expect(same.hashCode, _handler.hashCode);
    });

    test('differs in each of its fields', () {
      const others = [
        InteractionHandler(
          libraryUri: 'package:app/other.dart',
          name: 'onCounterInteraction',
        ),
        InteractionHandler(
          libraryUri: 'package:app/handlers.dart',
          name: 'onTap',
        ),
        InteractionHandler(
          libraryUri: 'package:app/handlers.dart',
          name: 'onCounterInteraction',
          className: 'Handlers',
        ),
        InteractionHandler(
          libraryUri: 'package:app/handlers.dart',
          name: 'onCounterInteraction',
          returnsFuture: false,
        ),
      ];

      for (final other in others) {
        expect(other, isNot(_handler), reason: other.reference);
        expect(other.hashCode, isNot(_handler.hashCode));
      }
      expect(_handler == (_label as Object), isFalse);
    });
  });

  group('WidgetSpec interactions', () {
    test('lists every button of the tree in document order', () {
      final spec = _spec(
        const HWColumn(
          children: [
            _increment,
            HWAdaptive(ios: _label, android: HWRow(children: [_reset])),
          ],
        ),
      );

      expect(spec.buttons, [_increment, _reset]);
    });

    test('lists no button without a widget tree', () {
      final spec = _spec(null);

      expect(spec.buttons, isEmpty);
      expect(spec.interactionTargets, isEmpty);
      expect(spec.iosInlineButtons, isEmpty);
    });

    test('has interactions with a button and a function', () {
      expect(_spec(_increment).hasInteractions, isTrue);
    });

    test('has no interactions without a function', () {
      final spec = _spec(_increment, handler: null);

      expect(spec.interactionHandler, isNull);
      expect(spec.hasInteractions, isFalse);
    });

    test('has no interactions without a button', () {
      final spec = _spec(const HWColumn(children: [_label]));

      expect(spec.interactionHandler, _handler);
      expect(spec.hasInteractions, isFalse);
    });

    test('names a class per button after the widget and the id', () {
      final spec = _spec(const HWColumn(children: [_increment, _reset]));

      expect(spec.interactionClassName, 'CounterInteraction');
      expect(spec.buttonClassName(_increment), 'CounterIncrementInteraction');
      expect(
        spec.buttonClassName(const HWButton('addOne', child: _label)),
        'CounterAddOneInteraction',
      );
      expect(
        spec.interactionTargets.map((target) => target.className),
        ['CounterIncrementInteraction', 'CounterResetInteraction'],
      );
      expect(
        spec.interactionTargets.first.description,
        'A tap on the `increment` button of the Counter widget.',
      );
    });

    test('a target carries the URL and the payload of its button', () {
      final target = _spec(_increment).interactionTargets.single;

      expect(target.url.url, HWButton.urlOf('increment'));
      expect(target.url.url, 'homewidget://interaction/increment');
      expect(target.url.payload.single.name, 'step');
    });

    test('folds buttons sharing an id into one target', () {
      final spec = _spec(
        const HWSizeAdaptive(
          small: HWColumn(children: [_increment]),
          medium: HWRow(children: [_increment, _reset]),
        ),
      );

      expect(spec.buttons, [_increment, _increment, _reset]);
      expect(
        spec.interactionTargets.map((target) => target.className),
        ['CounterIncrementInteraction', 'CounterResetInteraction'],
      );
    });

    test('names the key and the intent after the widget class', () {
      final spec = _spec(_increment, className: 'StepCounter');

      expect(spec.interactionClassName, 'StepCounterInteraction');
      expect(spec.interactionKey, 'StepCounterHomeWidget');
      expect(spec.iosIntentName, 'StepCounterHomeWidgetIntent');
    });

    test('hands Android the key only when a tap runs Dart code', () {
      expect(
        _spec(_increment).androidEmitContext.interactionKey,
        'CounterHomeWidget',
      );
      expect(
        _spec(_increment, handler: null).androidEmitContext.interactionKey,
        isNull,
      );
      expect(
        _spec(_label).androidEmitContext.interactionKey,
        isNull,
      );
    });
  });

  group('WidgetSpec iosInlineButtons', () {
    const inline = [
      HWWidgetFamily.systemMedium,
      HWWidgetFamily.accessoryInline,
    ];

    test('lists the buttons the inline accessory renders', () {
      final spec = _spec(
        const HWColumn(children: [_increment, _reset]),
        families: inline,
      );

      expect(spec.iosInlineButtons, [_increment, _reset]);
    });

    test('lists a button with another one below it', () {
      const outer = HWButton('outer', child: HWRow(children: [_reset]));
      final spec = _spec(outer, families: inline);

      expect(spec.iosInlineButtons, [outer, _reset]);
    });

    test('lists none for a widget never shown inline', () {
      const tree = HWColumn(children: [_increment]);

      expect(_spec(tree).iosInlineButtons, isEmpty);
      expect(
        _spec(tree, families: const [HWWidgetFamily.systemSmall])
            .iosInlineButtons,
        isEmpty,
      );
    });

    test('lists none without an iOS configuration', () {
      final spec = _spec(
        const HWColumn(children: [_increment]),
        configureIos: false,
      );

      expect(spec.iosInlineButtons, isEmpty);
    });

    test('only follows the iOS side of an HWAdaptive', () {
      final spec = _spec(
        const HWColumn(
          children: [
            HWAdaptive(ios: _increment, android: _reset),
            HWAdaptive(ios: _label, android: _reset),
          ],
        ),
        families: inline,
      );

      expect(spec.iosInlineButtons, [_increment]);
    });

    test('only follows the slot the inline accessory resolves to', () {
      final spec = _spec(
        const HWSizeAdaptive(
          medium: HWRow(children: [_increment, _reset]),
          accessoryInline: HWRow(children: [_reset]),
        ),
        families: inline,
      );

      expect(spec.iosInlineButtons, [_reset]);
    });

    test('lists none in a slot only another family renders', () {
      final spec = _spec(
        const HWSizeAdaptive(
          medium: HWRow(children: [_increment, _reset]),
          accessoryInline: _label,
        ),
        families: inline,
      );

      expect(spec.iosInlineButtons, isEmpty);
    });

    test('lists a slot written for two families once', () {
      const row = HWRow(children: [_increment]);
      final spec = _spec(
        const HWSizeAdaptive(medium: row, accessoryInline: row),
        families: inline,
      );

      expect(spec.iosInlineButtons, [_increment]);
    });
  });

  group('WidgetSpec equality', () {
    WidgetSpec spec({InteractionHandler? handler}) => WidgetSpec(
          data: const HomeWidget(name: 'Counter'),
          className: 'Counter',
          dataFields: const [],
          interactionHandler: handler,
        );

    test('holds for the same interaction function', () {
      final a = spec(handler: _handler);
      final b = spec(
        handler: const InteractionHandler(
          libraryUri: 'package:app/handlers.dart',
          name: 'onCounterInteraction',
        ),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs by the interaction function', () {
      final withHandler = spec(handler: _handler);
      final withOther = spec(
        handler: const InteractionHandler(
          libraryUri: 'package:app/handlers.dart',
          name: 'onTap',
        ),
      );
      final without = spec();

      expect(withHandler, isNot(withOther));
      expect(withHandler, isNot(without));
      expect(withHandler.hashCode, isNot(withOther.hashCode));
      expect(withHandler.hashCode, isNot(without.hashCode));
    });
  });
}
