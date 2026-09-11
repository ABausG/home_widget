import 'dart:io';

import 'package:home_widget_generator/home_widget_generator_cli.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../generator_error.dart';
import '../models/widget_spec.dart';
import '../models/extensions.dart';
import '../util/android_package.dart';
import '../util/android_templates.dart';
import '../util/android_wiring.dart';
import '../util/logger.dart';
import '../util/fs.dart';
import '../util/naming.dart';
import '../util/xml_utils.dart';
import 'kotlin_widget_emitter.dart';

/// Generates Android Glance widget files from a [WidgetSpec].
class AndroidGenerator {
  /// The widget specification to generate code for.
  final WidgetSpec spec;

  /// The root directory of the Flutter project.
  final Directory projectRoot;

  /// Creates a new [AndroidGenerator].
  AndroidGenerator({
    required this.spec,
    required this.projectRoot,
  });

  /// Generates the Android Glance widget files and wires them into Gradle
  /// and AndroidManifest.
  Future<void> generate() async {
    final primitiveFields = spec.primitiveDataFields;
    final jsonGroups = spec.jsonDataGroups;
    final timedPrimitiveFields = spec.timedPrimitiveDataFields;
    final timedJsonGroups = spec.timedJsonDataGroups;
    final hasTimedFields = spec.timedDataFields.isNotEmpty;
    final hasDataFields =
        primitiveFields.isNotEmpty || jsonGroups.isNotEmpty || hasTimedFields;

    // The Kotlin `locales` parameter and every argument passed to it have to be
    // gated on this one flag; two separately-spelled "equivalent" conditions
    // emit Kotlin that does not compile.
    final needsLocaleArg = spec.resolvesLocalizedOnRead;
    final needsResolver = spec.needsLocaleHelpers;
    // A preview resolves the JSON leaves that ship preview translations itself,
    // which the plain read leaves to the render site.
    final previewNeedsLocaleArg = needsLocaleArg ||
        (spec.hasPreviewValues &&
            [...jsonGroups, ...timedJsonGroups].any(_previewResolvesLocalized));

    final nativeHelpers = spec.nativeHelpers;

    // Gallery strings do not count — the launcher resolves those on its own.
    // A formatted number or date is locale-dependent too, so a widget that only
    // formats still goes stale on a language change; parsing a date it never
    // shows does not. The preview fingerprint's own locale read does not count
    // either: it only decides when the gallery preview is re-rendered, not
    // whether the running widget's content is stale.
    final handlesLocaleChange = spec.rendersLocalizedContent ||
        nativeHelpers.any((helper) => helper.localeDependent);

    // A preview fingerprint always folds in the current locale tags, so
    // whenever one is emitted the generated file needs hwCurrentLocales
    // whether or not anything else already pulled it in.
    final fileNativeHelpers = spec.androidAutoUpdatePreview
        ? resolveNativeHelpers(
            [...nativeHelpers, HWNativeHelper.hwCurrentLocales],
          )
        : nativeHelpers;

    final androidAppDir = Directory(p.join(projectRoot.path, 'android', 'app'));
    if (!androidAppDir.existsSync()) {
      logger.warn(
        'Warning: android/app/ not found. Skipping Android generation for ${spec.data.name}.',
      );
      return;
    }

    // Before anything is written: a receiver written into a source set of a
    // flavor Gradle does not know is merged into no build at all.
    if (spec.hasFlavors) _verifyDeclaredFlavorsExist();

    final detectedPackage = tryDetectAndroidPackage(projectRoot);
    final packageName =
        spec.data.android?.packageName ?? detectedPackage ?? 'com.example';
    final packagePath = packageName.split('.').join(p.separator);

    final widgetClassName = '${spec.className}HomeWidget';
    final providerInfoName = toSnakeCase(widgetClassName);

    final kotlinDir = Directory(
      p.join(
        projectRoot.path,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
        packagePath,
      ),
    );

    final resXmlDir = Directory(
      p.join(projectRoot.path, 'android', 'app', 'src', 'main', 'res', 'xml'),
    );

    await ensureDir(kotlinDir);
    await ensureDir(resXmlDir);

    final widgetFile = File(p.join(kotlinDir.path, '$widgetClassName.kt'));

    String? dataClassContent;
    String? contentBody;

    if (hasDataFields) {
      final className = '${spec.className}Data';
      final buffer = StringBuffer();
      buffer.writeln('data class $className(');
      for (final field in primitiveFields) {
        final type = field.kotlinType;
        buffer.writeln('    val ${field.key}: $type? = null,');
      }
      for (final group in jsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln('    val ${group.key}: $jsonClass? = null,');
      }
      for (final field in timedPrimitiveFields) {
        buffer.writeln('    val ${field.key}: ${field.kotlinType}? = null,');
      }
      for (final group in timedJsonGroups) {
        final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
        buffer.writeln('    val ${group.key}: $jsonClass? = null,');
      }
      buffer.write('''
) {
    companion object {
        private const val PREFERENCES_PREFIX = "home_widget.${spec.className}"
''');
      buffer.writeln();
      buffer.write(_androidDataFactory(className: className, preview: false));
      if (spec.hasPreviewValues) {
        buffer.writeln();
        buffer.write(_androidDataFactory(className: className, preview: true));
      }
      if (hasTimedFields) {
        buffer.writeln();
        buffer.write(_kotlinTimedDataResolver());
      }
      buffer.write('''
    }
}
''');
      // Keys are unique within each list, and the validator forbids sharing a
      // root key between a timed and an untimed field, so class names never
      // collide across the two.
      for (final group in [...jsonGroups, ...timedJsonGroups]) {
        buffer.writeln();
        buffer.write(
          _androidJsonNodeClass(
            className: '${spec.className}${toPascalCase(group.key)}JsonData',
            node: _buildJsonTree(group.children),
            isRoot: true,
            previewNeedsLocales:
                spec.hasPreviewValues && _previewResolvesLocalized(group),
          ),
        );
      }
      dataClassContent = buffer.toString();
    }

    // File-scope helpers: the spec resolves every helper the tree renders
    // through and every one the declared fields are read back with to its
    // transitive closure, already ordered so each one is declared after what
    // it calls.
    final fileHelpers = <String>[
      for (final helper in fileNativeHelpers)
        helper.toKotlin(0, dataExpr: '').trim(),
    ];
    if (fileHelpers.isNotEmpty) {
      dataClassContent = [
        if (dataClassContent != null) dataClassContent,
        ...fileHelpers,
      ].join('\n\n');
    }
    final bodyBuffer = StringBuffer();
    if (needsResolver) {
      bodyBuffer.writeln('    val hwLocales = hwCurrentLocales(context)');
    }
    if (hasDataFields) {
      final className = '${spec.className}Data';
      final localeArg = needsLocaleArg ? ', hwLocales' : '';
      final previewLocaleArg = previewNeedsLocaleArg ? ', hwLocales' : '';
      bodyBuffer.writeln('    val prefs = currentState.preferences');
      if (spec.hasPreviewValues) {
        bodyBuffer.write('''
    val widgetData =
        if (preview) $className.previewFromPreferences(prefs$previewLocaleArg)
        else $className.fromPreferences(prefs$localeArg)
''');
      } else {
        bodyBuffer.writeln(
          '    val widgetData = $className.fromPreferences(prefs$localeArg)',
        );
      }
    }

    final useTheme = spec.data.android?.useGlanceTheme ?? true;
    final bgColor = spec.data.android?.backgroundColor;
    final applyPadding = spec.data.android?.applyContentPadding ?? true;
    final fillContent = spec.data.android?.fillWidgetContent ?? true;

    var widgetTreeBody = emitKotlinWidgetBody(
      spec.effectiveWidgetTree,
      dataExpr: hasDataFields ? 'widgetData' : 'null',
      indent: useTheme ? 3 : 2, // inside WidgetContent, +1 if in GlanceTheme
    );

    final widgetUrl = spec.androidWidgetUrl;
    final launcherActivity = spec.androidOpensAppOnTap
        ? tryDetectAndroidLauncherActivity(projectRoot)
        : null;
    if (spec.androidOpensAppOnTap && launcherActivity == null) {
      logger.warn(
        'Warning: Could not detect the launcher activity in '
        'AndroidManifest.xml; ${spec.data.name} will not open the app when '
        'tapped. Declare an activity with the MAIN/LAUNCHER intent-filter, or '
        'set android.openAppOnTap to false to silence this warning.',
      );
    }
    final activityClassName = launcherActivity?.split('.').last;
    // A widget without a URL still opens the app, matching what iOS does for a
    // widget that declares no `widgetURL`. The plain Glance action carries no
    // home_widget launch intent, so no widget click is reported.
    final clickAction = activityClassName == null
        ? null
        : widgetUrl == null
            ? 'actionStartActivity<$activityClassName>()'
            : 'actionStartActivity<$activityClassName>(context, '
                'Uri.parse("${escapeKotlinStringLiteral(widgetUrl)}"))';

    final rootModifiers = <String>[];
    if (bgColor != null) {
      rootModifiers.add(
        'background(${bgColor.toKotlin(0, dataExpr: hasDataFields ? "widgetData" : "null")})',
      );
    }
    if (applyPadding) {
      rootModifiers.add('padding(16.dp)');
    }
    if (fillContent) {
      rootModifiers.add('fillMaxSize()');
    }
    if (clickAction != null) {
      rootModifiers.add('clickable(onClick = $clickAction)');
    }
    if (fillContent) {
      widgetTreeBody = wrapGlanceRootContent(
        widgetTreeBody,
        modifier: rootModifiers.join('.'),
      );
    } else {
      for (final modifier in rootModifiers) {
        widgetTreeBody = injectGlanceModifier(widgetTreeBody, modifier);
      }
    }

    if (useTheme) {
      bodyBuffer.writeln('    GlanceTheme {');
      bodyBuffer.writeln(widgetTreeBody);
      bodyBuffer.writeln('    }');
    } else {
      bodyBuffer.writeln(widgetTreeBody);
    }
    contentBody = bodyBuffer.toString();

    final layoutImports = (spec.effectiveWidgetTree.kotlinImports).toSet();
    // The helpers spell their types short; the aliased
    // `android.text.format.DateFormat` keeps the skeleton resolver apart from
    // the `java.text.DateFormat` the styled one uses.
    for (final helper in fileNativeHelpers) {
      layoutImports.addAll(helper.kotlinImports);
    }
    if (useTheme) {
      layoutImports.add('import androidx.glance.GlanceTheme');
    }
    if (bgColor != null) {
      layoutImports.addAll(bgColor.kotlinImports);
      layoutImports.add('import androidx.glance.layout.Box');
    }
    if (applyPadding) {
      layoutImports.add('import androidx.compose.ui.unit.dp');
      layoutImports.add('import androidx.glance.layout.padding');
      layoutImports.add('import androidx.glance.layout.Box');
    }

    if (fillContent) {
      layoutImports.add('import androidx.glance.layout.fillMaxSize');
      layoutImports.add('import androidx.glance.layout.Alignment');
      layoutImports.add('import androidx.glance.layout.Box');
    }

    if (clickAction != null) {
      layoutImports.add('import androidx.glance.action.clickable');
      if (widgetUrl == null) {
        // The reified Activity overload lives in glance core; the appwidget
        // package only carries the Intent-based ones.
        layoutImports.add('import androidx.glance.action.actionStartActivity');
      } else {
        layoutImports.add('import android.net.Uri');
        layoutImports
            .add('import es.antonborri.home_widget.actionStartActivity');
      }
      // Only a launcher activity outside the generated file's own package needs
      // naming; that package may be one the annotation overrode.
      if (launcherActivity != '$packageName.$activityClassName') {
        layoutImports.add('import $launcherActivity');
      }
    }
    // The gallery preview composes outside a running widget, so it has no state
    // to read and names the store itself: the app's own data when the preview
    // shows it, and a store holding nothing when it must not.
    final previewPreferences = spec.androidUsesLiveDataInPreview
        ? 'HomeWidgetPlugin.getData(context)'
        : 'HomeWidgetPreviews.emptyPreferences';
    if (!spec.androidUsesLiveDataInPreview) {
      layoutImports.add('import es.antonborri.home_widget.HomeWidgetPreviews');
    }
    // `R` lives in the Gradle namespace, not necessarily the package this file
    // is written into (an annotation may override `packageName`). Unqualified
    // `R` only resolves when the two coincide.
    if (spec.constantLocalizedStrings.isNotEmpty) {
      final rPackage =
          tryDetectAndroidNamespace(projectRoot) ?? detectedPackage;
      if (rPackage == null) {
        logger.warn(
          'Warning: could not detect the Android namespace. '
          '${widgetFile.path} references R.string, so the build will fail with '
          'an unresolved reference. Set android.packageName to the module '
          'namespace, or add the import manually.',
        );
      } else if (rPackage != packageName) {
        layoutImports.add('import $rPackage.R');
      }
    }

    final previewFingerprint = spec.androidAutoUpdatePreview
        ? _previewFingerprintFunction(
            hasDataFields: hasDataFields,
            needsLocaleArg: needsLocaleArg,
            previewNeedsLocaleArg: previewNeedsLocaleArg,
            previewPreferences: previewPreferences,
          )
        : null;

    await widgetFile.writeAsString(
      androidGlanceWidgetTemplate(
        packageName: packageName,
        widgetClassName: widgetClassName,
        contentBody: contentBody,
        extraContent: dataClassContent,
        additionalImports: layoutImports.isNotEmpty ? layoutImports : null,
        previewPreferences: previewPreferences,
        previewParameter: spec.hasPreviewValues,
        previewFingerprint: previewFingerprint,
      ),
    );
    logger.detail('Generated: ${widgetFile.path}');

    final receiverFile = File(
      p.join(kotlinDir.path, '${widgetClassName}Receiver.kt'),
    );
    await receiverFile.writeAsString(
      androidGlanceReceiverTemplate(
        packageName: packageName,
        widgetClassName: widgetClassName,
        previewFingerprint: previewFingerprint != null,
      ),
    );
    logger.detail('Generated: ${receiverFile.path}');

    final android = spec.data.android;
    final localization = spec.data.localization;

    final labelResourceName = spec.labelResourceName;
    final descriptionResourceName = spec.descriptionResourceName;

    final resources = <String, Map<String, String>>{};
    _collectLocalizedString(
      resources,
      name: labelResourceName,
      baseValue: spec.galleryName,
      translations: spec.galleryTranslations(localization?.name),
    );

    String? descriptionResource;
    final galleryDescription = spec.galleryDescription;
    if (galleryDescription != null) {
      _collectLocalizedString(
        resources,
        name: descriptionResourceName,
        baseValue: galleryDescription,
        translations: spec.galleryTranslations(localization?.description),
      );
      descriptionResource = '@string/$descriptionResourceName';
    }

    // Constant translations ship as resources so the platform resolves them
    // with the user's full language list and any per-app language override.
    for (final constant in spec.constantLocalizedStrings) {
      _collectLocalizedString(
        resources,
        name: constant.resourceName,
        baseValue: constant.baseValue,
        translations: {
          for (final entry in constant.defaultTranslations.entries)
            if (entry.key != constant.baseLocaleTag) entry.key: entry.value,
        },
      );
    }

    await _writeOwnedStringResources(projectRoot, resources);

    final providerInfoFile = File(
      p.join(resXmlDir.path, '$providerInfoName.xml'),
    );
    await providerInfoFile.writeAsString(
      androidAppWidgetProviderInfoTemplate(
        initialLayoutName: 'glance_default_loading_layout',
        minWidth: android?.minWidth ?? 80,
        minHeight: android?.minHeight ?? 80,
        minResizeWidth: android?.minResizeWidth,
        minResizeHeight: android?.minResizeHeight,
        maxResizeWidth: android?.maxResizeWidth,
        maxResizeHeight: android?.maxResizeHeight,
        targetCellWidth: android?.targetCellWidth,
        targetCellHeight: android?.targetCellHeight,
        resizeMode: android?.resizeMode?.toXmlValue() ?? 'horizontal|vertical',
        widgetCategory: android?.widgetCategory?.toXmlValue() ?? 'home_screen',
        updatePeriodMillis: android?.updatePeriodMillis ?? 0,
        descriptionResource: descriptionResource,
      ),
    );
    logger.detail('Generated: ${providerInfoFile.path}');

    await ensureAndroidGlanceGradleSetup(projectRoot);
    await ensureAndroidManifestReceiver(
      projectRoot,
      widgetClassName: widgetClassName,
      appPackageName: packageName,
      providerInfoName: providerInfoName,
      handleLocaleChange: handlesLocaleChange,
      label: '@string/$labelResourceName',
      flavors: spec.declaredFlavors,
    );
    if (spec.hasFlavors) _reportFlavorMismatches();
    if (widgetUrl != null) {
      await ensureAndroidManifestLaunchIntent(projectRoot);
    }
    if (spec.timedDataFields.isNotEmpty) {
      // Time-based content drives itself through HomeWidget.scheduleWidgetUpdates
      // on Android, which needs the plugin's scheduling receiver declared by the
      // consuming app. Specs without timed fields must not touch the manifest.
      await ensureAndroidManifestScheduledUpdates(projectRoot);
    }
  }

  /// Fails for a declared flavor that does not exist on Android.
  ///
  /// The receiver of a flavored widget only lives in
  /// `android/app/src/<flavor>/AndroidManifest.xml`, and Gradle merges that
  /// source set only for a flavor it knows — so generating for a flavor the
  /// Android project does not have would drop the widget from every build.
  ///
  /// Detection is text-based best effort, so an existing
  /// `android/app/src/<flavor>/` directory counts as the flavor existing too:
  /// it is the escape hatch for flavors declared in a way the scan cannot see.
  void _verifyDeclaredFlavorsExist() {
    final detected = tryDetectAndroidFlavors(projectRoot);

    for (final flavor in spec.declaredFlavors) {
      if (detected != null && detected.contains(flavor)) continue;
      if (_androidSourceSetDir(flavor).existsSync()) continue;

      final detectedList = detected == null
          ? 'No productFlavors block was found under android/app/'
          : detected.isEmpty
              ? 'The productFlavors block under android/app/ declares no '
                  'flavors'
              : 'Product flavors found under android/app/: '
                  '${detected.map((f) => '"$f"').join(', ')}';

      throw GeneratorError(
        '${spec.data.name} declares the flavor "$flavor", but no Android '
        'product flavor of that name exists. $detectedList. Gradle merges '
        'android/app/src/$flavor/ only for a flavor it knows, so the widget '
        'would be missing from every build. Declare "$flavor" in the '
        'android/app product flavors, or drop it from the widget. Creating '
        'the directory android/app/src/$flavor/ also marks the flavor as '
        'existing, for flavors declared in a way this check cannot read.',
      );
    }
  }

  Directory _androidSourceSetDir(String sourceSet) => Directory(
        p.join(projectRoot.path, 'android', 'app', 'src', sourceSet),
      );

  /// Reports the product flavors the Gradle files declare that this widget is
  /// not generated for. Detection is best effort, so this is never acted on.
  void _reportFlavorMismatches() {
    final detected = tryDetectAndroidFlavors(projectRoot);
    if (detected == null) {
      logger.detail(
        'Could not detect Android product flavors under android/app/; '
        'skipping the flavor report for ${spec.data.name}.',
      );
      return;
    }

    for (final flavor in detected) {
      if (spec.declaredFlavors.contains(flavor)) continue;
      logger.detail(
        '${spec.data.name} is not generated for the Android product flavor '
        '"$flavor".',
      );
    }
  }

  Directory _resDir(Directory projectRoot) => Directory(
        p.join(projectRoot.path, 'android', 'app', 'src', 'main', 'res'),
      );

  /// The resource file every `<string>` this widget owns is written to.
  ///
  /// One file per widget per locale, owned outright by the generator: it is
  /// rewritten whole on every run, so stale entries disappear on their own. The
  /// app's own `strings.xml` is never read or written.
  String get _stringsFileName => '${spec.resourcePrefix}.xml';

  File _ownedStringsFile(Directory projectRoot, String qualifier) => File(
        p.join(
          _resDir(projectRoot).path,
          qualifier.isEmpty ? 'values' : 'values-$qualifier',
          _stringsFileName,
        ),
      );

  /// Records [name] under the base locale plus one entry per translation.
  ///
  /// [resources] maps an Android locale qualifier (`''` for the base `values`
  /// directory) to that locale's resource name/value pairs.
  void _collectLocalizedString(
    Map<String, Map<String, String>> resources, {
    required String name,
    required String baseValue,
    Map<String, String>? translations,
  }) {
    (resources[''] ??= {})[name] = baseValue;

    for (final entry
        in translations?.entries ?? const <MapEntry<String, String>>[]) {
      final qualifier = androidLocaleQualifier(entry.key);
      if (qualifier.isEmpty) continue;
      (resources[qualifier] ??= {})[name] = entry.value;
    }
  }

  /// The document written to one locale's owned resource file.
  XmlDocument _stringResourcesDocument(Map<String, String> resources) =>
      XmlDocument([
        XmlDeclaration([
          XmlAttribute(XmlName('version'), '1.0'),
          XmlAttribute(XmlName('encoding'), 'utf-8'),
        ]),
        XmlElement(
          XmlName('resources'),
          const [],
          [
            for (final entry in resources.entries)
              XmlElement(
                XmlName('string'),
                [
                  XmlAttribute(XmlName('name'), entry.key),
                  if (androidStringNeedsFormattedFalse(entry.value))
                    XmlAttribute(XmlName('formatted'), 'false'),
                ],
                [XmlText(androidStringResourceText(entry.value))],
              ),
          ],
        ),
      ]);

  /// Writes one owned file per locale in [resources], then drops the files this
  /// widget left behind in locales it no longer ships.
  Future<void> _writeOwnedStringResources(
    Directory projectRoot,
    Map<String, Map<String, String>> resources,
  ) async {
    for (final entry in resources.entries) {
      final file = _ownedStringsFile(projectRoot, entry.key);
      await ensureDir(file.parent);
      if (writeXmlFile(file, _stringResourcesDocument(entry.value))) {
        logger.detail('Generated: ${file.path}');
      }
    }

    await _pruneStaleLocaleFiles(projectRoot, live: resources.keys.toSet());
  }

  /// Matches the locale-qualified directories this generator creates, so
  /// pruning never touches `values-night`, `values-v31` and friends.
  static final RegExp _localeValuesDirPattern = RegExp(
    r'^values-(b\+[A-Za-z0-9+]+|[a-z]{2,3}(-r[A-Z]{2})?)$',
  );

  /// Deletes this widget's owned file from every locale directory not in
  /// [live], and the directory too once nothing is left in it.
  ///
  /// Only files named [_stringsFileName] are ever deleted; other widgets' files
  /// and the app's own resources share these directories.
  Future<void> _pruneStaleLocaleFiles(
    Directory projectRoot, {
    required Set<String> live,
  }) async {
    final resDir = _resDir(projectRoot);
    if (!resDir.existsSync()) return;

    for (final entity in resDir.listSync().whereType<Directory>()) {
      final dirName = p.basename(entity.path);
      if (!_localeValuesDirPattern.hasMatch(dirName)) continue;
      if (live.contains(dirName.substring('values-'.length))) continue;

      final file = File(p.join(entity.path, _stringsFileName));
      if (!file.existsSync()) continue;

      await file.delete();
      logger.detail('Removed stale: ${file.path}');

      if (entity.listSync().isEmpty) await entity.delete();
    }
  }

  /// Emits one companion-object factory building the data class.
  ///
  /// [preview] emits the `previewFromPreferences` twin, whose reads fall back
  /// on the shipped preview values instead of the defaults. It is a separate
  /// function so the widget itself carries no branch the launcher takes and it
  /// does not.
  String _androidDataFactory({
    required String className,
    required bool preview,
  }) {
    final name = preview ? 'previewFromPreferences' : 'fromPreferences';
    final fromPath = preview ? 'previewFromPath' : 'fromPath';
    final fromJson = preview ? 'previewFromJson' : 'fromJson';
    String groupLocaleArg(JsonDataGroup group) =>
        preview && _previewResolvesLocalized(group) ? ', locales' : '';
    final needsLocales = spec.resolvesLocalizedOnRead ||
        (preview &&
            [...spec.jsonDataGroups, ...spec.timedJsonDataGroups]
                .any(_previewResolvesLocalized));
    final localeParam = needsLocales ? ', locales: List<String>' : '';
    final hasTimedFields = spec.timedDataFields.isNotEmpty;
    final nowParam =
        hasTimedFields ? ', now: Long = System.currentTimeMillis()' : '';

    final buffer = StringBuffer();
    buffer.writeln(
      '        fun $name(prefs: android.content.SharedPreferences'
      '$localeParam$nowParam): $className {',
    );
    if (hasTimedFields) {
      buffer.writeln(
        '            val timedValues = resolveTimedValues(prefs, now)',
      );
    }
    buffer.writeln('            return $className(');
    for (final field in spec.primitiveDataFields) {
      final readLogic = field.androidReadValue(
        store: 'prefs',
        key: '\${PREFERENCES_PREFIX}.${field.key}',
        preview: preview,
      );
      buffer.writeln('                ${field.key} = $readLogic,');
    }
    for (final group in spec.jsonDataGroups) {
      final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
      buffer.writeln(
        '                ${group.key} = $jsonClass.$fromPath('
        'prefs.getString("\${PREFERENCES_PREFIX}.${group.key}", null)'
        '${groupLocaleArg(group)}),',
      );
    }
    for (final field in spec.timedPrimitiveDataFields) {
      // Checked before the plain leaf read, of which HWString — and so
      // HWLocalizedString — is one: a timed translation is stored as a locale
      // map, not as the text of a single locale.
      // A date is stored as an ISO string too, so it is parsed rather than
      // read as the typed leaf it ends up as.
      final valueExpr = switch (field) {
        final HWLocalizedString string => string.androidTimedReadValue(
            valuesExpr: 'timedValues',
            preview: preview,
          ),
        final HWDateTime date => date.androidTimedReadValue(
            valuesExpr: 'timedValues',
            preview: preview,
          ),
        _ => _androidLeafReadExpression(
            objExpr: 'timedValues',
            key: field.key,
            type: field,
            preview: preview,
          ),
      };
      buffer.writeln('                ${field.key} = $valueExpr,');
    }
    for (final group in spec.timedJsonDataGroups) {
      final jsonClass = '${spec.className}${toPascalCase(group.key)}JsonData';
      buffer.writeln(
        '                ${group.key} = $jsonClass.$fromJson('
        'timedValues.optJSONObject("${group.key}")'
        '${groupLocaleArg(group)}),',
      );
    }
    buffer.write('''
            )
        }
''');
    return buffer.toString();
  }

  /// The `previewFingerprint` the generated receiver forwards to the plugin,
  /// which re-registers the gallery preview whenever it changes.
  ///
  /// Covers everything the preview renders from that is not fixed at generation
  /// time: [WidgetSpec.previewContentHash] for the annotation, the locale tags
  /// for a language change, the stored data where the preview reads it, and the
  /// modification time of every runtime image file that data points at, whose
  /// path stays the same when its bytes are replaced.
  String _previewFingerprintFunction({
    required bool hasDataFields,
    required bool needsLocaleArg,
    required bool previewNeedsLocaleArg,
    required String previewPreferences,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('  fun previewFingerprint(context: Context): String {');
    buffer.writeln('    val hwLocales = hwCurrentLocales(context)');
    final parts = <String>[
      '"${spec.previewContentHash}"',
      'hwLocales.joinToString(",")',
    ];

    if (spec.androidUsesLiveDataInPreview && hasDataFields) {
      final usesPreviewFactory = spec.hasPreviewValues;
      final factory =
          usesPreviewFactory ? 'previewFromPreferences' : 'fromPreferences';
      final localeArg =
          (usesPreviewFactory ? previewNeedsLocaleArg : needsLocaleArg)
              ? ', hwLocales'
              : '';
      buffer.write('''
    val hwPreviewData =
        ${spec.className}Data.$factory($previewPreferences$localeArg)
''');
      parts.add('hwPreviewData.toString()');

      final imagePaths = _previewImagePathAccessors('hwPreviewData');
      if (imagePaths.isNotEmpty) {
        parts.add(
          'listOf(${imagePaths.join(', ')}).joinToString(",") '
          '{ hwPath -> hwPath?.let { java.io.File(it).lastModified().toString() }'
          ' ?: "" }',
        );
      }
    }

    buffer.writeln('    return listOf(');
    for (final part in parts) {
      buffer.writeln('      $part,');
    }
    buffer.write('''
    ).joinToString("|")
  }''');
    return buffer.toString();
  }

  /// Kotlin accessors, from [dataExpr], for every runtime image path the
  /// preview can read. Asset images are left out; they have no runtime file.
  List<String> _previewImagePathAccessors(String dataExpr) => [
        for (final field in spec.runtimeImageFields) '$dataExpr.${field.key}',
        for (final field in [
          ...spec.jsonImageFields,
          ...spec.timedJsonImageFields,
        ])
          if (!field.image.isAsset)
            '$dataExpr.${field.rootKey}?.${field.path.join('?.')}',
      ];

  /// Emits the companion-object helper resolving the timed data entry that is
  /// active at `now` (greatest timestamp <= now), or an empty object.
  ///
  /// Reads the same timed-data file — decimal epoch-millis string keys, one
  /// flat JSON object per timestamp — that `generate()` in
  /// dart_helper_generator.dart writes and `loadTimedEntries` in
  /// ios_generator.dart parses on iOS; the three must stay in step. A root
  /// localized field's timed value comes back as a locale-tag-to-text
  /// object rather than a plain value, matching how it was written.
  String _kotlinTimedDataResolver() => '''
        private fun resolveTimedValues(prefs: android.content.SharedPreferences, now: Long): org.json.JSONObject {
            val path = prefs.getString("\${PREFERENCES_PREFIX}.timedData", null) ?: return org.json.JSONObject()
            return try {
                val file = java.io.File(path)
                if (!file.exists()) return org.json.JSONObject()
                val json = org.json.JSONObject(file.readText())
                var activeKey: String? = null
                var activeTimestamp = 0L
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val timestamp = key.toLongOrNull() ?: continue
                    if (timestamp <= now && (activeKey == null || timestamp > activeTimestamp)) {
                        activeKey = key
                        activeTimestamp = timestamp
                    }
                }
                val resolvedKey = activeKey ?: return org.json.JSONObject()
                json.optJSONObject(resolvedKey) ?: org.json.JSONObject()
            } catch (_: Exception) {
                org.json.JSONObject()
            }
        }
''';

  String _kotlinDefaultLiteral(HWDataType<dynamic> field) {
    final defaultValue = field.defaultValue;
    if (defaultValue == null) return 'null';
    if (defaultValue is String) {
      return '"${escapeKotlinStringLiteral(defaultValue)}"';
    }
    if (defaultValue is int) return '${defaultValue}L';
    return '$defaultValue';
  }

  _JsonPathNode _buildJsonTree(List<JsonDataField> fields) {
    final root = _JsonPathNode();
    for (final field in fields) {
      var node = root;
      for (final segment in field.path) {
        node = node.children.putIfAbsent(segment, _JsonPathNode.new);
      }
      node.leafType = field.type;
    }
    return root;
  }

  String _androidJsonNodeClass({
    required String className,
    required _JsonPathNode node,
    required bool isRoot,
    required bool previewNeedsLocales,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('data class $className(');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final leaf = child.leafType!;
        final kt = leaf.kotlinType;
        if (leaf.defaultValue == null) {
          buffer.writeln('    val $key: $kt? = null,');
        } else {
          buffer.writeln(
            '    val $key: $kt = ${_kotlinDefaultLiteral(leaf)},',
          );
        }
      } else {
        final childClass = '$className${toPascalCase(key)}';
        buffer.writeln('    val $key: $childClass? = null,');
      }
    }
    buffer.write('''
) {
    companion object {
''');
    buffer.write(
      _androidJsonFactories(
        className: className,
        node: node,
        isRoot: isRoot,
        preview: false,
        previewNeedsLocales: previewNeedsLocales,
      ),
    );
    if (spec.hasPreviewValues) {
      buffer.writeln();
      buffer.write(
        _androidJsonFactories(
          className: className,
          node: node,
          isRoot: isRoot,
          preview: true,
          previewNeedsLocales: previewNeedsLocales,
        ),
      );
    }
    buffer.write('''
    }
}
''');

    for (final entry in node.children.entries) {
      final child = entry.value;
      if (child.children.isNotEmpty) {
        buffer.writeln();
        buffer.write(
          _androidJsonNodeClass(
            className: '$className${toPascalCase(entry.key)}',
            node: child,
            isRoot: false,
            previewNeedsLocales: previewNeedsLocales,
          ),
        );
      }
    }
    return buffer.toString();
  }

  /// Emits the factories of one JSON node class into its companion object.
  ///
  /// The [preview] twins differ from the plain ones in two ways: their leaves
  /// fall back on the shipped preview values, and the root builds from an empty
  /// object rather than returning null when the group was never saved — which
  /// is what nested nodes already do, and what makes those leaf fallbacks reach
  /// a gallery preview at all.
  ///
  /// [previewNeedsLocales] threads the OS locale list through the preview twins,
  /// which a localized leaf shipping preview translations resolves against.
  String _androidJsonFactories({
    required String className,
    required _JsonPathNode node,
    required bool isRoot,
    required bool preview,
    required bool previewNeedsLocales,
  }) {
    final fromPath = preview ? 'previewFromPath' : 'fromPath';
    final fromJson = preview ? 'previewFromJson' : 'fromJson';
    final withLocales = preview && previewNeedsLocales;
    final localeParam = withLocales ? ', locales: List<String>' : '';
    final localeArg = withLocales ? ', locales' : '';
    final absent =
        preview ? '$fromJson(org.json.JSONObject()$localeArg)' : 'null';

    final buffer = StringBuffer();
    if (isRoot) {
      buffer.write('''
        fun $fromPath(path: String?$localeParam): $className? {
            if (path == null) return $absent
            return try {
                val file = java.io.File(path)
                if (!file.exists()) return $absent
                $fromJson(org.json.JSONObject(file.readText())$localeArg)
            } catch (_: Exception) {
                $absent
            }
        }

''');
    }

    buffer.writeln(
      '        fun $fromJson(obj: org.json.JSONObject?$localeParam): '
      '$className? {',
    );
    if (isRoot && !preview) {
      buffer.write('''
            if (obj == null) return null
            val json = obj
''');
    } else {
      buffer.writeln('            val json = obj ?: org.json.JSONObject()');
    }
    buffer.writeln('            return $className(');
    for (final entry in node.children.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child.leafType != null && child.children.isEmpty) {
        final valueExpr = _androidLeafReadExpression(
          objExpr: 'json',
          key: key,
          type: child.leafType!,
          preview: preview,
        );
        buffer.writeln('                $key = $valueExpr,');
      } else {
        buffer.writeln(
          '                $key = $className${toPascalCase(key)}.$fromJson('
          'json.optJSONObject("$key")$localeArg),',
        );
      }
    }
    buffer.write('''
            )
        }
''');
    return buffer.toString();
  }

  String _androidLeafReadExpression({
    required String objExpr,
    required String key,
    required HWDataType<dynamic> type,
    bool preview = false,
  }) {
    // A date travels as an ISO string with no default behind it, so it is
    // parsed rather than read as the typed leaf it becomes.
    if (type is HWDateTime) {
      return type.androidJsonReadValue(
        objExpr: objExpr,
        key: key,
        preview: preview,
      );
    }
    // Only the preview goes through the shared fallback resolution; the plain
    // read keeps the literal the data class field is declared with.
    final fallback = preview
        ? type is HWLocalizedString
            ? _kotlinPreviewLocalizedFallback(type)
            : type.codegenKotlinFallbackLiteral(preview: true) ?? 'null'
        : _kotlinDefaultLiteral(type);
    // An image's timed value is the absolute path of the PNG that was saved for
    // that timestamp, so it reads exactly like a string.
    if (type is HWString || type is HWImageData) {
      return 'if ($objExpr.has("$key") && !$objExpr.isNull("$key")) $objExpr.optString("$key") else $fallback';
    }
    if (type is HWInt) {
      return 'if ($objExpr.has("$key") && !$objExpr.isNull("$key")) $objExpr.optLong("$key") else $fallback';
    }
    if (type is HWDouble) {
      return 'if ($objExpr.has("$key") && !$objExpr.isNull("$key")) $objExpr.optDouble("$key") else $fallback';
    }
    if (type is HWBool) {
      return 'if ($objExpr.has("$key") && !$objExpr.isNull("$key")) $objExpr.optBoolean("$key") else $fallback';
    }
    return fallback;
  }

  /// The preview fallback of a localized JSON leaf: its preview translations
  /// resolved against the reader's locales, or `null` without them, which sends
  /// the render site to the shipped translations rather than to one locale's
  /// text.
  String _kotlinPreviewLocalizedFallback(HWLocalizedString leaf) {
    final values = leaf.kotlinPreviewMapLiteral;
    if (values == null) return 'null';
    final base = escapeKotlinStringLiteral(leaf.previewBaseLocaleTag!);
    return 'hwResolveLocalized(locales, $values, "$base")';
  }

  /// Whether [group] has a localized leaf whose preview translations the preview
  /// factories resolve, and so need the locale list for.
  static bool _previewResolvesLocalized(JsonDataGroup group) =>
      group.children.any((child) {
        final type = child.type;
        return type is HWLocalizedString && type.previewTranslations != null;
      });
}

class _JsonPathNode {
  final Map<String, _JsonPathNode> children = {};
  HWDataType<dynamic>? leafType;
}
