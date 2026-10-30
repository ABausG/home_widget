import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

void main() {
  group('HWLink', () {
    const plain = HWLink(
      'history',
      url: 'myapp://history',
      child: HWText(HWString.fixed('History')),
    );
    const withData = HWLink(
      'forecast',
      url: 'myapp://forecast',
      data: [HWString('city'), HWPayload('days', HWInt.fixed(7))],
      child: HWText(HWString('label')),
    );

    test('builds its URL from url and data', () {
      expect(plain.payloadUrl.staticUrl, 'myapp://history?homeWidget');
      expect(
        withData.payloadUrl.payload.map((entry) => entry.name),
        ['city', 'days'],
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
      expect(plain.renderHelpers, {HWNativeHelper.hwLink});
      expect(
        withData.renderHelpers,
        {
          HWNativeHelper.hwLink,
          HWNativeHelper.hwPayloadUrl,
          HWNativeHelper.hwPayloadValue,
        },
      );
      expect(withData.nativeHelpers, containsAll(withData.renderHelpers));
    });

    group('iOS (SwiftUI)', () {
      test('wraps the child in a link to a static URL', () {
        expect(plain.toSwift(1, dataExpr: 'entry.data'), '''
    hwLink(URL(string: "myapp://history?homeWidget")) {
        Text(verbatim: "History")
    }''');
      });

      test('builds the URL of a link with data at render time', () {
        expect(
          withData.toSwift(0, dataExpr: 'entry.data'),
          startsWith(
            'hwLink(hwPayloadUrl("myapp://forecast", '
            '[("city", hwPayloadValue(entry.data.city)), ("days", "7")], '
            '"homeWidget", "")) {\n',
          ),
        );
      });

      test('reads an item field off the item inside a builder', () {
        const builder = HWColumn.builder(
          'todos',
          item: HWLink(
            'open',
            url: 'myapp://todo',
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

      test('opens through widgetURL where the context names the link', () {
        final code = plain.toSwift(
          1,
          dataExpr: 'entry.data',
          context: HWEmitContext(swiftWidgetUrlLinks: [plain]),
        );

        expect(code, '''
    Text(verbatim: "History")
    .widgetURL(URL(string: "myapp://history?homeWidget"))''');
      });

      test('another link in the context stays a link', () {
        final code = withData.toSwift(
          0,
          dataExpr: 'entry.data',
          context: HWEmitContext(swiftWidgetUrlLinks: [plain]),
        );

        expect(code, startsWith('hwLink('));
        expect(code, isNot(contains('.widgetURL(')));
      });

      test('a child rendering nothing leaves nothing to tap', () {
        const node = HWLink(
          'hidden',
          url: 'myapp://hidden',
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(node.swiftRendersNothing, isTrue);
        expect(node.toSwift(0, dataExpr: 'data'), isEmpty);
      });

      test('an Android-only child leaves no widgetURL behind on iOS', () {
        const node = HWLink(
          'promo',
          url: 'myapp://promo',
          child: HWAdaptive(
            ios: HWDataOnly([HWString('hidden')]),
            android: HWText(HWString.fixed('Promo')),
          ),
        );

        expect(node.swiftRendersNothing, isTrue);
        expect(node.toSwift(0, dataExpr: 'data'), isEmpty);
        expect(
          node.toSwift(
            0,
            dataExpr: 'data',
            context: const HWEmitContext(swiftWidgetUrlLinks: [node]),
          ),
          isEmpty,
        );
        expect(
          const HWColumn(children: [node]).toSwift(0, dataExpr: 'data'),
          allOf(isNot(contains('widgetURL')), isNot(contains('hwLink'))),
        );
        expect(
          node.toKotlin(
            0,
            dataExpr: 'data',
            context: const HWEmitContext(androidLaunchActivity: 'MainActivity'),
          ),
          contains('clickable('),
        );
      });

      test('a size around the link frames the child inside it', () {
        const sized = HWSizedBox(width: 40, height: 20, child: plain);
        final code = sized.toSwift(0, dataExpr: 'data');

        expect(code, startsWith('hwLink('));
        expect(
          code.indexOf('.frame('),
          lessThan(code.lastIndexOf('}')),
          reason: 'the frame belongs to the label, not to the link',
        );
      });
    });

    group('Android (Glance)', () {
      const launching = HWEmitContext(androidLaunchActivity: 'MainActivity');

      test('makes the child clickable with a static URL', () {
        final code =
            plain.toKotlin(0, dataExpr: 'widgetData', context: launching);

        expect(code, contains('Text('));
        expect(
          code,
          contains(
            'clickable(onClick = actionStartActivity<MainActivity>(context, '
            'Uri.parse("myapp://history?homeWidget")))',
          ),
        );
        expect(code, isNot(contains('Box')));
      });

      test('builds the URL of a link with data at composition time', () {
        final code =
            withData.toKotlin(0, dataExpr: 'widgetData', context: launching);

        expect(
          code,
          contains(
            'actionStartActivity<MainActivity>(context, '
            'hwPayloadUrl("myapp://forecast", '
            'listOf("city" to hwPayloadValue(widgetData.city), '
            '"days" to "7"), "homeWidget", ""))',
          ),
        );
      });

      test('reads an item field off the item inside a builder', () {
        const builder = HWRow.builder(
          'todos',
          item: HWLink(
            'open',
            url: 'myapp://todo',
            data: [HWPayload('todo', HWItemData(HWInt('id')))],
            child: HWText(HWItemData(HWString('title'))),
          ),
        );
        final code = builder.toKotlin(
          0,
          dataExpr: 'widgetData',
          context: launching,
        );

        expect(code, contains('listOf("todo" to hwPayloadValue(hwItem.id))'));
        expect(code, contains('forEachIndexed { _, hwItem ->'));
      });

      test('emits the bare child while nothing names an activity', () {
        const child = HWText(HWString.fixed('History'));

        expect(
          plain.toKotlin(0, dataExpr: 'widgetData'),
          child.toKotlin(0, dataExpr: 'widgetData'),
        );
        expect(
          plain.toKotlin(
            0,
            dataExpr: 'widgetData',
            context: const HWEmitContext(),
          ),
          isNot(contains('clickable')),
        );
      });

      test('a child rendering nothing leaves nothing to tap', () {
        const node = HWLink(
          'hidden',
          url: 'myapp://hidden',
          child: HWDataOnly([HWString('hidden')]),
        );

        expect(node.kotlinRendersNothing, isTrue);
        expect(
          node.toKotlin(0, dataExpr: 'widgetData', context: launching),
          isEmpty,
        );
        expect(node.kotlinImports, isEmpty);
      });

      test('imports the click action next to what the child needs', () {
        expect(
          plain.kotlinImports,
          containsAll([
            'import androidx.glance.action.clickable',
            'import es.antonborri.home_widget.actionStartActivity',
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
        final code =
            column.toKotlin(0, dataExpr: 'widgetData', context: launching);

        expect(plain.kotlinPaddingAddsRoom, isFalse);
        expect(code, contains('Box(modifier = GlanceModifier.padding(top ='));
      });

      test('a padding around the link goes on a Box of its own', () {
        const padded = HWPadding(padding: HWEdgeInsets.all(4), child: plain);
        final code =
            padded.toKotlin(0, dataExpr: 'widgetData', context: launching);

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

      test('a picture in a sized link fills it as it does without a link', () {
        const image = HWImage(HWImageData('photo'), fit: HWImageFit.cover);
        const sized = HWSizedBox(
          width: 80,
          height: 40,
          child: HWLink('photo', url: 'myapp://photo', child: image),
        );
        final code =
            sized.toKotlin(0, dataExpr: 'widgetData', context: launching);

        expect(
          const HWSizedBox(width: 80, height: 40, child: image)
              .toKotlin(0, dataExpr: 'widgetData'),
          contains('modifier = GlanceModifier.fillMaxSize(),'),
        );
        expect(code, contains('GlanceModifier.fillMaxSize()'));
        expect(code, contains('clickable('));
      });

      test('a size around the link sizes the clickable composable', () {
        const sized = HWSizedBox(width: 40, height: 20, child: plain);
        final code =
            sized.toKotlin(0, dataExpr: 'widgetData', context: launching);

        expect(code, contains('clickable('));
        expect(code, contains('40'));
      });
    });
  });

  group('HWEmitContext', () {
    const link = HWLink(
      'history',
      url: 'myapp://history',
      child: HWText(HWString.fixed('History')),
    );

    test('opens nothing and names no whole-widget link by default', () {
      const context = HWEmitContext();
      expect(context.androidLaunchActivity, isNull);
      expect(context.swiftWidgetUrlLinks, isEmpty);
    });

    test('carries the tap targets through every derived context', () {
      final context = HWEmitContext(
        reachableFamilies: const {HWWidgetFamily.systemSmall},
        swiftWidgetUrlLinks: const [link],
        itemList: 'todos',
        enclosingLinearAxis: HWAxis.vertical,
      ).launching('MainActivity');

      expect(context.androidLaunchActivity, 'MainActivity');
      expect(context.swiftWidgetUrlLinks, [link]);
      expect(context.reachableFamilies, {HWWidgetFamily.systemSmall});
      expect(context.itemList, 'todos');
      expect(context.enclosingLinearAxis, HWAxis.vertical);

      for (final derived in [
        context.inLinear(HWAxis.horizontal),
        context.inItemOf('other'),
      ]) {
        expect(derived.androidLaunchActivity, 'MainActivity');
        expect(derived.swiftWidgetUrlLinks, [link]);
      }
      expect(context.launching(null).androidLaunchActivity, isNull);
    });
  });
}
