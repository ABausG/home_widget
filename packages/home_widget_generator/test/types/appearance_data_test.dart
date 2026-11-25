import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:home_widget_generator/home_widget_generator_cli.dart';
import 'package:test/test.dart';

const _font = HWIconFont(family: 'MaterialIcons');

void main() {
  group('HWAppearanceData', () {
    const logo = HWAppearanceData<String>(
      light: HWImageData('logoLight'),
      dark: HWImageData('logoDark'),
      iosAccented: HWImageData.asset('assets/mono.png'),
    );

    test('reads its sides, and is no field of its own', () {
      expect(logo.sides, [
        const HWImageData('logoLight'),
        const HWImageData('logoDark'),
        const HWImageData.asset('assets/mono.png'),
      ]);
      expect(logo.readValues, logo.sides);
      expect(logo.isDataDependency, isFalse);
      expect(logo.isFixed, isFalse);
      expect(logo.defaultValue, isNull);
      expect(logo.previewValue, isNull);
      expect(logo.unwrapped, same(logo));
      expect(logo.leaf, const HWImageData('logoLight'));
      expect(logo.nativeHelpers, isEmpty);
    });

    test('describes itself through its light side', () {
      expect(logo.dartType, 'String');
      expect(logo.swiftType, 'String');
      expect(logo.kotlinType, 'String');
      expect(
        logo.iosReadValue(store: 's', key: 'k'),
        const HWImageData('logoLight').iosReadValue(store: 's', key: 'k'),
      );
      expect(
        logo.androidReadValue(store: 's', key: 'k'),
        const HWImageData('logoLight').androidReadValue(store: 's', key: 'k'),
      );
    });

    test('picks a side, an asset side reading as its key', () {
      expect(
        logo.swiftAccess('entry.data'),
        'hwAppearance(hwEnvironment, light: entry.data.logoLight, '
        'dark: entry.data.logoDark, accented: "assets/mono.png")',
      );
      expect(logo.swiftReadExpr('entry.data'), logo.swiftAccess('entry.data'));
      expect(
        logo.kotlinAccess('widgetData'),
        'hwDayNight(context, { widgetData.logoLight }, '
        '{ widgetData.logoDark })',
      );
      expect(
        logo.kotlinReadExpr('widgetData'),
        logo.kotlinAccess('widgetData'),
      );
    });

    test('needs the environment and the pick helpers', () {
      expect(
        logo.swiftViewModifiers,
        {HWAppearanceChoice.swiftEnvironmentDeclaration},
      );
      expect(logo.renderHelpers, {HWNativeHelper.hwAppearance});
    });

    test('brings the Android helper its kind is rendered through', () {
      expect(
        const HWAppearanceData<String>(
          light: HWString.fixed('a'),
          dark: HWString('b'),
        ).renderHelpers,
        {HWNativeHelper.hwAppearance, HWNativeHelper.hwDayNight},
      );
      expect(
        const HWAppearanceData<int>(
          light: HWColor('a'),
          dark: HWDefaultColor(HWColorRole.contentPrimary),
        ).renderHelpers,
        {
          HWNativeHelper.hwAppearance,
          HWNativeHelper.hwAppearanceColor,
          HWNativeHelper.hwColor,
        },
      );
      expect(
        const HWAppearanceData<int>(
          light: HWColor.fixed(0xFF000000),
          dark: HWColor.fixed(0xFFFFFFFF),
        ).renderHelpers,
        {HWNativeHelper.hwAppearance},
      );
    });

    test('renders the picked value the way its kind renders a missing one', () {
      const text = HWAppearanceData<String>(
        light: HWString.fixed('a'),
        dark: HWString('b'),
      );
      expect(text.pickedLeaf, const HWString(''));
      expect(
        text.iosToString(outerValue: 'v', innerValue: 'v!'),
        'v ?? ""',
      );
      expect(
        text.androidToString(outerValue: 'v', innerValue: 'v'),
        'v ?: ""',
      );
      for (final (appearance, picked) in <(HWDataType<dynamic>, Object)>[
        (
          const HWAppearanceData<int>(light: HWInt('a'), dark: HWInt('b')),
          const HWInt(''),
        ),
        (
          const HWAppearanceData<double>(
            light: HWDouble('a'),
            dark: HWDouble('b'),
          ),
          const HWDouble(''),
        ),
        (
          const HWAppearanceData<bool>(light: HWBool('a'), dark: HWBool('b')),
          const HWBool(''),
        ),
        (
          const HWAppearanceData<DateTime>(
            light: HWDateTime('a'),
            dark: HWDateTime('b'),
          ),
          const HWDateTime(''),
        ),
        (
          const HWAppearanceData<int>(light: HWColor('a'), dark: HWColor('b')),
          const HWColor(''),
        ),
        (logo, const HWImageData('')),
      ]) {
        expect((appearance as HWAppearanceData).pickedLeaf, picked);
      }
      const icon = HWAppearanceData<int>(
        light: HWIconData.resolvedFixed(0xE430, iconFont: _font),
        dark: HWIconData.resolvedFixed(0xE431, iconFont: _font),
      );
      expect(icon.pickedLeaf, icon.light);
    });

    test('a localized item side falls back to its translations', () {
      const item = HWItemData(
        HWLocalizedString.resolved(
          'label',
          defaultTranslations: {'en': 'Hi'},
          isConstant: false,
          defaultLocale: 'en',
        ),
      );
      expect(item.swiftVariantValue('d'), contains('hwResolveLocalized('));
      expect(item.kotlinVariantValue('d'), contains('hwResolveLocalized('));
      const plain = HWItemData(HWString('label'));
      expect(plain.swiftVariantValue('d'), 'hwItem.label');
      expect(plain.kotlinVariantValue('d'), 'hwItem.label');
    });

    test('is never merged, and equal by its sides', () {
      expect(logo.isCompatibleWith(logo), isFalse);
      const same = HWAppearanceData<String>(
        light: HWImageData('logoLight'),
        dark: HWImageData('logoDark'),
        iosAccented: HWImageData.asset('assets/mono.png'),
      );
      expect(logo, same);
      expect(logo.hashCode, same.hashCode);
      expect(
        logo,
        isNot(
          const HWAppearanceData<String>(
            light: HWImageData('logoLight'),
            dark: HWImageData('logoDark'),
          ),
        ),
      );
      expect(spellFixedValue(logo), startsWith('HWAppearanceData'));
    });
  });

  group('HWAppearanceChoice', () {
    test('picks a value with the iOS slots it is given', () {
      expect(
        HWAppearanceChoice.swiftValue(light: 'a', dark: 'b', vibrant: 'v'),
        'hwAppearance(hwEnvironment, light: a, dark: b, vibrant: v)',
      );
      expect(
        HWAppearanceChoice.kotlinValue(light: 'a', dark: 'b'),
        'hwDayNight(context, { a }, { b })',
      );
    });

    test('picks a layout, rendering modes first', () {
      expect(
        HWAppearanceChoice.swiftLayout(
          1,
          light: '        L',
          dark: '        D',
          accented: '        A',
          vibrant: '        V',
        ),
        '    if hwIsAccented(hwEnvironment) {\n'
        '        A\n'
        '    } else if hwIsVibrant(hwEnvironment) {\n'
        '        V\n'
        '    } else if hwEnvironment.colorScheme == .dark {\n'
        '        D\n'
        '    } else {\n'
        '        L\n'
        '    }',
      );
      expect(
        HWAppearanceChoice.swiftLayout(0, light: '    L', dark: '    D'),
        'if hwEnvironment.colorScheme == .dark {\n'
        '    D\n'
        '} else {\n'
        '    L\n'
        '}',
      );
      expect(
        HWAppearanceChoice.kotlinLayout(0, light: '    L', dark: '    D'),
        'if (hwIsNight(context)) {\n'
        '    D\n'
        '} else {\n'
        '    L\n'
        '}',
      );
    });
  });

  group('rendering an HWAppearanceData', () {
    test('HWText picks text, numbers, dates and flags', () {
      const text = HWText(
        HWAppearanceData<String>(
          light: HWString.fixed('Light'),
          dark: HWString('dark'),
        ),
      );
      expect(
        text.toSwift(0, dataExpr: 'e'),
        'Text(hwAppearance(hwEnvironment, light: "Light", dark: e.dark) ?? "")',
      );
      expect(
        text.toKotlin(0, dataExpr: 'w'),
        contains('text = hwDayNight(context, { "Light" }, { w.dark }) ?: ""'),
      );
      expect(
        text.swiftViewModifiers,
        {HWAppearanceChoice.swiftEnvironmentDeclaration},
      );
      expect(text.dataDependencies, {const HWString('dark')});
      expect(text.nativeHelpers, contains(HWNativeHelper.hwAppearance));

      const number = HWText.number(
        HWAppearanceData<int>(light: HWInt.fixed(1), dark: HWInt('n')),
      );
      expect(
        number.toSwift(0, dataExpr: 'e'),
        contains(
          'hwAppearance(hwEnvironment, light: 1, dark: e.n).map { '
          'hwFormatDecimal(NSNumber(value: \$0)',
        ),
      );
      expect(
        number.toKotlin(0, dataExpr: 'w'),
        contains(
          'hwDayNight(context, { 1L }, { w.n })?.let { hwFormatDecimal(',
        ),
      );

      const date = HWText.dateTime(
        HWAppearanceData<DateTime>(
          light: HWDateTime('a'),
          dark: HWDateTime('b'),
        ),
      );
      expect(
        date.toSwift(0, dataExpr: 'e'),
        contains('hwAppearance(hwEnvironment, light: e.a, dark: e.b).map {'),
      );

      const flag = HWText(
        HWAppearanceData<bool>(
          light: HWBool('a'),
          dark: HWJson('g', HWBool('b')),
        ),
      );
      expect(
        flag.toSwift(0, dataExpr: 'e'),
        'Text(hwAppearance(hwEnvironment, light: e.a, dark: e.g?.b) != nil '
        '? "\\((hwAppearance(hwEnvironment, light: e.a, dark: e.g?.b))!)" '
        ': "false")',
      );
    });

    test('HWImage decodes each side only when it is reached', () {
      const image = HWImage(
        HWAppearanceData<String>(
          light: HWImageData('logoLight'),
          dark: HWImageData('logoDark'),
          iosAccented: HWImageData.asset('assets/mono.png'),
        ),
        height: 32,
      );
      final swift = image.toSwift(0, dataExpr: 'e');
      expect(
        swift,
        startsWith(
          'if let uiImage = hwAppearance(hwEnvironment, '
          'light: e.logoLight.flatMap { hwDecodeImage(\$0, nil, 32.0) }, '
          'dark: e.logoDark.flatMap { hwDecodeImage(\$0, nil, 32.0) }, '
          'accented: hwDecodeImage("assets/mono.png", nil, 32.0)) {',
        ),
      );
      final kotlin = image.toKotlin(0, dataExpr: 'w');
      expect(
        kotlin,
        startsWith(
          'HomeWidgetAppearance.pick(context, { w.logoLight?.let { path -> '
          'hwDecodeImage(context, path, null, 32.0) } }, '
          '{ w.logoDark?.let { path -> '
          'hwDecodeImage(context, path, null, 32.0) } })?.let { bitmaps ->',
        ),
      );
      expect(
        kotlin,
        contains(
          '    HwAppearanceImage(\n'
          '        modifier = GlanceModifier.height(32.0.dp),\n'
          '        size = GlanceModifier.height(32.0.dp),\n'
          '        context = context,\n'
          '        images = bitmaps,\n'
          '        contentDescription = null,\n'
          '        contentScale = ContentScale.Fit,\n'
          '    )',
        ),
      );
      expect(image.renderHelpers, contains(HWNativeHelper.hwAppearanceImage));
      expect(image.nativeHelpers, isNot(contains(HWNativeHelper.hwDayNight)));
      expect(
        image.kotlinImports,
        containsAll([
          'import es.antonborri.home_widget.HomeWidgetAppearance',
          'import androidx.glance.GlanceModifier',
        ]),
      );
      expect(
        image.kotlinImports,
        isNot(contains('import androidx.glance.Image')),
      );
      expect(
        image.dataDependencies,
        {
          const HWImageData('logoLight'),
          const HWImageData('logoDark'),
          const HWImageData.asset('assets/mono.png'),
        },
      );
      expect(
        image.swiftViewModifiers,
        {HWAppearanceChoice.swiftEnvironmentDeclaration},
      );

      const assetLight = HWImage(
        HWAppearanceData<String>(
          light: HWImageData.asset('assets/a.png'),
          dark: HWImageData('d'),
        ),
      );
      expect(
        assetLight.toKotlin(0, dataExpr: 'w'),
        startsWith(
          'HomeWidgetAppearance.pick(context, { hwDecodeImage(context, '
          '"assets/a.png", null, null) }, ',
        ),
      );
      expect(
        assetLight.toKotlin(0, dataExpr: 'w'),
        contains('modifier = GlanceModifier,\n        size = GlanceModifier,'),
      );
      const sized = HWSizedBox(
        width: 40,
        height: 40,
        child: HWImage(
          HWAppearanceData<String>(
            light: HWImageData('l'),
            dark: HWImageData('d'),
          ),
        ),
      );
      expect(
        sized.toKotlin(0, dataExpr: 'w'),
        contains('size = GlanceModifier.fillMaxSize(),'),
      );
    });

    test('HWImage asks iOS 18 for an accented rendering mode', () {
      const image = HWImage(
        HWImageData('photo'),
        iosAccentedRendering: HWAccentedRendering.fullColor,
      );
      final swift = image.toSwift(0, dataExpr: 'e');
      expect(
        swift,
        contains(
          'hwAccentedRendering(Image(uiImage: uiImage).resizable(), '
          '"fullColor")',
        ),
      );
      expect(swift, isNot(contains('.resizable()\n')));
      expect(image.renderHelpers, contains(HWNativeHelper.hwAccentedRendering));
      expect(
        image.toKotlin(0, dataExpr: 'w'),
        isNot(contains('Accented')),
      );
      expect(
        const HWImage(HWImageData('photo')).renderHelpers,
        {HWNativeHelper.hwDecodeImage},
      );
    });

    test('HWIcon picks a glyph and subsets every side', () {
      const icon = HWIcon(
        HWAppearanceData<int>(
          light: HWIconData.resolvedFixed(0xE430, iconFont: _font),
          dark: HWIconData.resolvedFixed(
            0xE5C4,
            iconFont: _font,
            matchTextDirection: true,
          ),
        ),
        color: HWColor('tint'),
      );
      expect(icon.ownIconCodePoints, {
        _font: {0xE430, 0xE5C4},
      });
      final swift = icon.toSwift(0, dataExpr: 'e');
      expect(
        swift,
        contains(
          'if let codePoint = hwAppearance(hwEnvironment, light: 0xE430, '
          'dark: 0xE5C4),',
        ),
      );
      expect(
        swift,
        contains(
          '.scaleEffect(x: layoutDirection == .rightToLeft && '
          '[0xE5C4].contains(codePoint) ? -1 : 1, y: 1)',
        ),
      );
      expect(swift, contains('.foregroundColor(hwColor(e.tint))'));
      final kotlin = icon.toKotlin(0, dataExpr: 'w');
      expect(
        kotlin,
        contains(
          'HomeWidgetAppearance.pick(context, { 0xE430 }, { 0xE5C4 })'
          '?.let { codePoints ->',
        ),
      );
      expect(
        kotlin,
        contains(
          'HwAppearanceImage(modifier = GlanceModifier.size(24.dp), '
          'size = GlanceModifier.size(24.dp), '
          'context = context, images = codePoints.map { codePoint -> '
          'HomeWidgetFonts.iconBitmap(',
        ),
      );
      expect(
        kotlin,
        contains('matchTextDirection = codePoint in setOf(0xE5C4)'),
      );
      expect(
        kotlin,
        contains('contentScale = ContentScale.Fit, '
            'tint = (hwColor(w.tint) ?: GlanceTheme.colors.onSurface))'),
      );
      expect(icon.dataDependencies, {const HWColor('tint')});
      expect(icon.renderHelpers, contains(HWNativeHelper.hwAppearanceImage));
      expect(
        icon.kotlinImports,
        containsAll([
          'import es.antonborri.home_widget.HomeWidgetAppearance',
          'import androidx.glance.layout.ContentScale',
        ]),
      );
      expect(
        icon.kotlinImports,
        isNot(contains('import androidx.glance.ColorFilter')),
      );

      const plain = HWIcon(
        HWAppearanceData<int>(
          light: HWIconData.resolvedFixed(0xE430, iconFont: _font),
          dark: HWIconData.resolvedFixed(0xE431, iconFont: _font),
        ),
      );
      expect(plain.toSwift(0, dataExpr: 'e'), isNot(contains('scaleEffect')));
      expect(
        plain.toKotlin(0, dataExpr: 'w'),
        isNot(contains('matchTextDirection')),
      );
    });

    test('HWDataExists tests the side the pick lands on', () {
      const exists = HWDataExists(
        data: HWAppearanceData<String>(
          light: HWImageData('a'),
          dark: HWImageData.asset('assets/b.png'),
        ),
        whenPresent: HWText(HWString.fixed('yes')),
        whenAbsent: HWText(HWString.fixed('no')),
      );
      expect(
        exists.conditionSwift(dataExpr: 'e'),
        'hwAppearance(hwEnvironment, '
        'light: (hwImageExists(e.a) ? e.a : nil), '
        'dark: (hwImageExists("assets/b.png") ? "assets/b.png" : nil)) != nil',
      );
      expect(
        exists.conditionKotlin(dataExpr: 'w'),
        'hwDayNight(context, { w.a.takeIf { hwImageExists(context, it) } }, '
        '{ "assets/b.png".takeIf { hwImageExists(context, it) } }) != null',
      );
      expect(
        exists.swiftViewModifiers,
        {HWAppearanceChoice.swiftEnvironmentDeclaration},
      );

      const text = HWDataExists(
        data: HWAppearanceData<String>(
          light: HWString('a'),
          dark: HWString('b'),
        ),
        whenPresent: HWText(HWString.fixed('yes')),
        whenAbsent: HWText(HWString.fixed('no')),
      );
      expect(
        text.conditionSwift(dataExpr: 'e'),
        'hwAppearance(hwEnvironment, light: e.a, dark: e.b) != nil',
      );
      expect(
        text.conditionKotlin(dataExpr: 'w'),
        'hwDayNight(context, { w.a }, { w.b }) != null',
      );
    });

    test('HWBoolConditional reads the picked flag, fixed sides included', () {
      const isDark = HWBoolConditional(
        data: HWAppearanceData<bool>(
          light: HWBool.fixed(false),
          dark: HWBool.fixed(true),
        ),
        whenTrue: HWText(HWString.fixed('dark')),
        whenFalse: HWText(HWString.fixed('light')),
      );
      expect(
        isDark.conditionSwift(dataExpr: 'e'),
        'hwAppearance(hwEnvironment, light: false, dark: true) == true',
      );
      expect(
        isDark.conditionKotlin(dataExpr: 'w'),
        'hwDayNight(context, { false }, { true }) == true',
      );
      expect(isDark.dataDependencies, isEmpty);
      expect(isDark.nativeHelpers, contains(HWNativeHelper.hwDayNight));
    });

    test('a baseline row reads an item side as reading the item', () {
      const row = HWRow.builder(
        'items',
        crossAxisAlignment: HWCrossAxisAlignment.baseline,
        item: HWBoolConditional(
          data: HWAppearanceData<bool>(
            light: HWItemData(HWBool('a')),
            dark: HWBool.fixed(true),
          ),
          whenTrue: HWText(HWString.fixed('a')),
          whenFalse: HWText(HWString.fixed('b')),
        ),
      );
      final conditional = row.item! as HWBoolConditional;
      expect(conditional.kotlinBaselineText()!.readsItem, isTrue);
    });
  });

  group('HWAppearanceAdaptive', () {
    const adaptive = HWAppearanceAdaptive(
      light: HWText(HWString('light')),
      dark: HWText(HWString('dark')),
      iosAccented: HWText(HWString('accented')),
      iosVibrant: HWText(HWString.fixed('vibrant')),
    );

    test('declares the fields of every slot, renders two on Android', () {
      expect(adaptive.dataDependencies, {
        const HWString('light'),
        const HWString('dark'),
        const HWString('accented'),
      });
      expect(adaptive.childWidgets, hasLength(4));
      expect(adaptive.androidChildWidgets, [adaptive.light, adaptive.dark]);
      expect(adaptive.renderHelpers, {
        HWNativeHelper.hwIsAccented,
        HWNativeHelper.hwIsVibrant,
        HWNativeHelper.hwIsNight,
      });
      expect(
        adaptive.swiftViewModifiers,
        contains(HWAppearanceChoice.swiftEnvironmentDeclaration),
      );
      expect(
        adaptive.kotlinImports,
        contains('import androidx.glance.text.Text'),
      );
      expect(adaptive.swiftFrameAlignment, '.topLeading');
      expect(adaptive.swiftClipsFrame, isFalse);
    });

    test('picks a slot on each platform', () {
      expect(
        adaptive.toSwift(0, dataExpr: 'e'),
        'if hwIsAccented(hwEnvironment) {\n'
        '    Text(e.accented ?? "")\n'
        '} else if hwIsVibrant(hwEnvironment) {\n'
        '    Text(verbatim: "vibrant")\n'
        '} else if hwEnvironment.colorScheme == .dark {\n'
        '    Text(e.dark ?? "")\n'
        '} else {\n'
        '    Text(e.light ?? "")\n'
        '}',
      );
      final kotlin = adaptive.toKotlin(0, dataExpr: 'w');
      expect(kotlin, startsWith('if (hwIsNight(context)) {\n'));
      expect(kotlin, contains('text = w.dark ?: ""'));
      expect(kotlin, contains('text = w.light ?: ""'));
      expect(kotlin, isNot(contains('accented')));
    });

    test('lays out each slot on its own inside a stack', () {
      const column = HWColumn(
        spacing: 4,
        children: [HWText(HWString.fixed('a')), adaptive],
      );
      final kotlin = column.toKotlin(0, dataExpr: 'w');
      expect(kotlin, contains('if (hwIsNight(context)) {'));
      expect(
        RegExp(r'padding\(top = 4\.0\.dp\)').allMatches(kotlin),
        hasLength(2),
      );
    });

    test('a size on a condition over a pick reaches the branches', () {
      const sized = HWSizedBox(
        width: double.infinity,
        height: 20,
        child: HWDataExists(
          data: HWAppearanceData<String>(
            light: HWString('a'),
            dark: HWString('b'),
          ),
          whenPresent: HWText(HWString.fixed('present')),
          whenAbsent: HWText(HWString.fixed('absent')),
        ),
      );
      final kotlin = sized.toKotlin(0, dataExpr: 'w');
      expect(
        kotlin,
        startsWith('if (hwDayNight(context, { w.a }, { w.b }) != null) {\n'),
      );
      expect(
        RegExp(r'GlanceModifier\.fillMaxWidth\(\)\.height\(20\.0\.dp\)')
            .allMatches(kotlin),
        hasLength(2),
      );
      expect(
        const HWDataExists(
          data: HWAppearanceData<String>(
            light: HWImageData('a'),
            dark: HWImageData('b'),
          ),
          whenPresent: HWText(HWString.fixed('present')),
          whenAbsent: HWText(HWString.fixed('absent')),
        ).nativeHelpers,
        containsAll([HWNativeHelper.hwDayNight, HWNativeHelper.hwImageExists]),
      );
    });

    test('sizes each SwiftUI slot inside a decoration', () {
      const box = HWSizedBox(
        width: 10,
        child: HWColoredBox(
          color: HWColor.fixed(0xFF000000),
          child: HWAppearanceAdaptive(
            light: HWColoredBox(
              color: HWColor.fixed(0xFFFFFFFF),
              child: HWText(HWString.fixed('l')),
            ),
            dark: HWText(HWString.fixed('d')),
            iosAccented: HWText(HWString.fixed('a')),
          ),
        ),
      );
      final swift = box.toSwift(0, dataExpr: 'e');
      expect(
        RegExp(r'\.frame\(width: 10\.0').allMatches(swift),
        hasLength(3),
      );
      expect(box.toKotlin(0, dataExpr: 'w'), contains('width(10.0.dp)'));
    });

    test('fills the picture of a slot on Glance', () {
      const box = HWSizedBox(
        width: 40,
        height: 40,
        child: HWAppearanceAdaptive(
          light: HWImage(HWImageData('a')),
          dark: HWText(HWString.fixed('d')),
        ),
      );
      expect(
        box.toKotlin(0, dataExpr: 'w'),
        contains('modifier = GlanceModifier.fillMaxSize(),'),
      );
      const darkOnly = HWSizedBox(
        width: 40,
        height: 40,
        child: HWAppearanceAdaptive(
          light: HWText(HWString.fixed('l')),
          dark: HWImage(HWImageData('d')),
        ),
      );
      expect(
        darkOnly.toKotlin(0, dataExpr: 'w'),
        contains('modifier = GlanceModifier.fillMaxSize(),'),
      );
      const neither = HWSizedBox.expand(
        child: HWAppearanceAdaptive(
          light: HWText(HWString.fixed('l')),
          dark: HWText(HWString.fixed('d')),
        ),
      );
      expect(neither.toKotlin(0, dataExpr: 'w'), contains('if (hwIsNight'));
    });

    test('lines a baseline row up by the slot that renders', () {
      const row = HWRow(
        crossAxisAlignment: HWCrossAxisAlignment.baseline,
        children: [
          HWText(HWString.fixed('a')),
          HWAppearanceAdaptive(
            light: HWText(HWString.fixed('l')),
            dark: HWText(HWString.fixed('d')),
          ),
        ],
      );
      final text =
          (row.children[1] as HWAppearanceAdaptive).kotlinBaselineText();
      expect(text, isNotNull);
      expect(text!.ascent('w'), startsWith('if (hwIsNight(context)) '));
      expect(
        const HWAppearanceAdaptive(
          light: HWText(HWString.fixed('l')),
          dark: HWImage(HWImageData('d')),
        ).kotlinBaselineText(),
        isNull,
      );
      expect(row.toKotlin(0, dataExpr: 'w'), contains('hwIsNight(context)'));
    });
  });
}
