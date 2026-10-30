import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWButton', () {
    const plain = HWButton(
      'increment',
      child: HWText(HWString.fixed('Add')),
    );
    const withData = HWButton(
      'rate',
      data: [HWString('city'), HWPayload('stars', HWInt.fixed(3))],
      child: HWText(HWString('label')),
    );

    test('builds its URL from id and data', () {
      expect(HWButton.urlOf('increment'), 'homewidget://interaction/increment');
      expect(
        plain.payloadUrl.staticUrl,
        'homewidget://interaction/increment?homeWidget',
      );
      expect(
        withData.payloadUrl.payload.map((entry) => entry.name),
        ['city', 'stars'],
      );
    });

    test('depends on what the child and the payload read', () {
      expect(plain.dataDependencies, isEmpty);
      expect(
        withData.dataDependencies,
        {const HWString('label'), const HWString('city')},
      );
      expect(plain.childWidgets, [plain.child]);
    });

    test('names the helpers its code calls', () {
      expect(plain.renderHelpers, isEmpty);
      expect(
        withData.renderHelpers,
        {HWNativeHelper.hwPayloadUrl, HWNativeHelper.hwPayloadValue},
      );
      expect(withData.nativeHelpers, containsAll(withData.renderHelpers));
    });

    group('iOS (SwiftUI)', () {
      test('wraps the child in a button sending a static URL', () {
        expect(plain.toSwift(1, dataExpr: 'entry.data'), '''
    hwButton(URL(string: "homewidget://interaction/increment?homeWidget")) {
        Text(verbatim: "Add")
    }''');
      });

      test('builds the URL of a button with data at render time', () {
        expect(
          withData.toSwift(0, dataExpr: 'entry.data'),
          startsWith(
            'hwButton(hwPayloadUrl("homewidget://interaction/rate", '
            '[("city", hwPayloadValue(entry.data.city)), ("stars", "3")], '
            '"homeWidget", "")) {\n',
          ),
        );
      });

      test('reads an item field off the item inside a builder', () {
        const builder = HWColumn.builder(
          'todos',
          item: HWButton(
            'toggle',
            data: [HWItemData(HWString('id'))],
            child: HWText(HWItemData(HWString('title'))),
          ),
        );
        final code = builder.toSwift(0, dataExpr: 'entry.data');

        expect(code, contains('[("id", hwPayloadValue(hwItem.id))]'));
        expect(code, contains('ForEach('));
        expect(
          builder.itemReads.map((read) => read.key),
          containsAll(['id', 'title']),
        );
        expect(builder.dataDependencies, isEmpty);
      });

      test('a child rendering nothing leaves nothing to tap', () {
        const node = HWButton(
          'hidden',
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(node.swiftRendersNothing, isTrue);
        expect(node.toSwift(0, dataExpr: 'data'), isEmpty);
      });

      test('a size around the button frames the child inside it', () {
        const sized = HWSizedBox(width: 40, height: 20, child: plain);
        final code = sized.toSwift(0, dataExpr: 'data');

        expect(code, startsWith('hwButton('));
        expect(
          code.indexOf('.frame('),
          lessThan(code.lastIndexOf('}')),
          reason: 'the frame belongs to the label, not to the button',
        );
      });
    });

    group('Android (Glance)', () {
      const keyed = HWEmitContext(interactionKey: 'CounterHomeWidget');

      test('makes the child clickable with a static URL and the key', () {
        final code = plain.toKotlin(0, dataExpr: 'widgetData', context: keyed);

        expect(code, contains('Text('));
        expect(
          code,
          contains(
            'clickable(onClick = '
            'actionRunCallback<HomeWidgetInteractivityAction>('
            'HomeWidgetInteractivityAction.parameters('
            'Uri.parse("homewidget://interaction/increment?homeWidget"), '
            '"CounterHomeWidget")))',
          ),
        );
        expect(code, isNot(contains('Box')));
      });

      test('builds the URL of a button with data at composition time', () {
        final code =
            withData.toKotlin(0, dataExpr: 'widgetData', context: keyed);

        expect(
          code,
          contains(
            'HomeWidgetInteractivityAction.parameters('
            'hwPayloadUrl("homewidget://interaction/rate", '
            'listOf("city" to hwPayloadValue(widgetData.city), '
            '"stars" to "3"), "homeWidget", ""), "CounterHomeWidget")',
          ),
        );
      });

      test('reads an item field off the item inside a builder', () {
        const builder = HWRow.builder(
          'todos',
          item: HWButton(
            'toggle',
            data: [HWPayload('todo', HWItemData(HWInt('id')))],
            child: HWText(HWItemData(HWString('title'))),
          ),
        );
        final code = builder.toKotlin(
          0,
          dataExpr: 'widgetData',
          context: keyed,
        );

        expect(code, contains('listOf("todo" to hwPayloadValue(hwItem.id))'));
        expect(code, contains('"CounterHomeWidget")'));
        expect(code, contains('forEachIndexed { _, hwItem ->'));
      });

      test('reaches the callback without a key while the context names none',
          () {
        for (final context in [null, const HWEmitContext()]) {
          expect(
            plain.toKotlin(0, dataExpr: 'widgetData', context: context),
            contains(
              'HomeWidgetInteractivityAction.parameters('
              'Uri.parse("homewidget://interaction/increment?homeWidget"))))',
            ),
          );
        }
      });

      test('escapes the key', () {
        final code = plain.toKotlin(
          0,
          dataExpr: 'widgetData',
          context: const HWEmitContext(interactionKey: r'A$B"C'),
        );

        expect(code, contains(r'"A\$B\"C")))'));
      });

      test('a child rendering nothing leaves nothing to tap', () {
        const node = HWButton(
          'hidden',
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(node.kotlinRendersNothing, isTrue);
        expect(
          node.toKotlin(0, dataExpr: 'widgetData', context: keyed),
          isEmpty,
        );
        expect(node.kotlinImports, isEmpty);
      });

      test('imports the action next to what the child needs', () {
        expect(
          plain.kotlinImports,
          containsAll([
            'import androidx.glance.action.clickable',
            'import androidx.glance.appwidget.action.actionRunCallback',
            'import es.antonborri.home_widget.HomeWidgetInteractivityAction',
            'import android.net.Uri',
            'import androidx.glance.layout.Box',
            ...plain.child.kotlinImports,
          ]),
        );
      });

      test('keeps the gap of a stack outside the tap area', () {
        const column = HWColumn(
          spacing: 8,
          children: [HWText(HWString.fixed('a')), plain],
        );
        final code = column.toKotlin(0, dataExpr: 'widgetData', context: keyed);

        expect(plain.kotlinPaddingAddsRoom, isFalse);
        expect(code, contains('Box(modifier = GlanceModifier.padding(top ='));
      });

      test('a padding around the button goes on a Box of its own', () {
        const padded = HWPadding(padding: HWEdgeInsets.all(4), child: plain);
        final code = padded.toKotlin(0, dataExpr: 'widgetData', context: keyed);

        expect(code, startsWith('Box(modifier = GlanceModifier.padding('));
        expect(code, contains('clickable('));
      });

      test('reports the baseline of a text child', () {
        expect(plain.kotlinReportsBaseline, isTrue);
        expect(
          plain.kotlinBaselineText()?.ascent('d'),
          plain.child.kotlinBaselineText()?.ascent('d'),
        );
      });

      test('a picture in a sized button fills it as it does without one', () {
        const image = HWImage(HWImageData('photo'), fit: HWImageFit.cover);
        const sized = HWSizedBox(
          width: 80,
          height: 40,
          child: HWButton('photo', child: image),
        );
        final code = sized.toKotlin(0, dataExpr: 'widgetData', context: keyed);

        expect(code, contains('GlanceModifier.fillMaxSize()'));
        expect(code, contains('clickable('));
      });

      test('a size around the button sizes the clickable composable', () {
        const sized = HWSizedBox(width: 40, height: 20, child: plain);
        final code = sized.toKotlin(0, dataExpr: 'widgetData', context: keyed);

        expect(code, contains('clickable('));
        expect(code, contains('40'));
      });

      test('a conditional child takes the action on each branch', () {
        const node = HWButton(
          'toggle',
          child: HWBoolConditional(
            data: HWBool('done', defaultValue: false),
            whenTrue: HWText(HWString.fixed('Done')),
            whenFalse: HWText(HWString.fixed('Open')),
          ),
        );
        final code = node.toKotlin(0, dataExpr: 'widgetData', context: keyed);

        expect('clickable('.allMatches(code), hasLength(2));
      });
    });
  });

  group('HWEmitContext', () {
    test('names no interaction key by default', () {
      expect(const HWEmitContext().interactionKey, isNull);
    });

    test('carries the interaction key through every derived context', () {
      const context = HWEmitContext(interactionKey: 'CounterHomeWidget');

      for (final derived in [
        context.inLinear(HWAxis.horizontal),
        context.inItemOf('todos'),
        context.launching('MainActivity'),
      ]) {
        expect(derived.interactionKey, 'CounterHomeWidget');
      }
    });
  });

  group('HomeWidget.onInteraction', () {
    test('takes part in equality', () {
      const without = HomeWidget(name: 'Counter');
      const withHandler = HomeWidget(name: 'Counter', onInteraction: _handler);

      expect(withHandler.onInteraction, _handler);
      expect(
        withHandler,
        const HomeWidget(name: 'Counter', onInteraction: _handler),
      );
      expect(
        withHandler.hashCode,
        const HomeWidget(name: 'Counter', onInteraction: _handler).hashCode,
      );
      expect(withHandler, isNot(without));
      expect(
        withHandler,
        isNot(const HomeWidget(name: 'Counter', onInteraction: _other)),
      );
    });
  });
}

Future<void> _handler(Object interaction) async {}

Future<void> _other(Object interaction) async {}
