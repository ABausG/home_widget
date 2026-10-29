import 'dart:io';

import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_cli/src/validation/home_widget_version.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/font_fixture.dart';

WidgetSpec _spec({
  String? widgetUrl,
  HWWidget? widget,
  InteractionHandler? interactionHandler,
}) =>
    WidgetSpec(
      data: HomeWidget(
        name: 'Weather',
        widgetUrl: widgetUrl,
        android: const HomeWidgetAndroidConfiguration(),
      ),
      className: 'Weather',
      widgetTree: widget,
      interactionHandler: interactionHandler,
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('home_widget_version');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void lock(String version, {String source = 'hosted'}) => writeFontFixture(
        tempDir,
        lockedHomeWidgetVersion: version,
        homeWidgetSource: source,
      );

  group('validateLaunchSupport', () {
    test('rejects a hosted home_widget without the launch helpers', () {
      lock('0.10.0');

      expect(
        () => validateLaunchSupport(
          _spec(widgetUrl: 'myapp://weather'),
          tempDir,
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              startsWith(
                'Widget "Weather": this widget opens the app with a URL',
              ),
              contains('home_widget $minimumLaunchHomeWidgetVersion or newer'),
              contains('resolves home_widget 0.10.0'),
              contains('flutter pub get'),
            ),
          ),
        ),
      );
    });

    test('applies to a widget that only has links', () {
      lock('0.9.4');

      expect(
        () => validateLaunchSupport(
          _spec(
            widget: const HWLink(
              'open',
              url: 'myapp://open',
              child: HWText(HWString.fixed('Open')),
            ),
          ),
          tempDir,
        ),
        throwsA(isA<GeneratorError>()),
      );
    });

    test('accepts the release with the launch helpers and anything newer', () {
      for (final version in const [
        minimumLaunchHomeWidgetVersion,
        '$minimumLaunchHomeWidgetVersion-dev.1',
        '0.11.0',
        '1.0.0',
      ]) {
        lock(version);
        expect(
          () => validateLaunchSupport(
            _spec(widgetUrl: 'myapp://weather'),
            tempDir,
          ),
          returnsNormally,
          reason: version,
        );
      }
    });

    test('does not apply to a widget a tap opens nothing with', () {
      lock('0.9.0');

      expect(
        () => validateLaunchSupport(_spec(), tempDir),
        returnsNormally,
      );
    });
  });

  group('validateInteractionSupport', () {
    const handler = InteractionHandler(
      libraryUri: 'package:app/handlers.dart',
      name: 'onWeatherInteraction',
    );
    const button = HWButton(
      'refresh',
      child: HWText(HWString.fixed('Refresh')),
    );

    test('rejects a hosted home_widget without the keyed callbacks', () {
      lock('0.10.0');

      expect(
        () => validateInteractionSupport(
          _spec(widget: button, interactionHandler: handler),
          tempDir,
        ),
        throwsA(
          isA<GeneratorError>().having(
            (e) => e.message,
            'message',
            allOf(
              startsWith('Widget "Weather": this widget has an HWButton'),
              contains(
                'home_widget $minimumInteractionHomeWidgetVersion or newer',
              ),
              contains('resolves home_widget 0.10.0'),
              contains('flutter pub get'),
            ),
          ),
        ),
      );
    });

    test('accepts the release with the keyed callbacks and anything newer', () {
      for (final version in const [
        minimumInteractionHomeWidgetVersion,
        '$minimumInteractionHomeWidgetVersion-dev.1',
        '0.11.0',
        '1.0.0',
      ]) {
        lock(version);
        expect(
          () => validateInteractionSupport(
            _spec(widget: button, interactionHandler: handler),
            tempDir,
          ),
          returnsNormally,
          reason: version,
        );
      }
    });

    test('does not apply to a widget whose buttons call nothing', () {
      lock('0.9.0');

      expect(
        () => validateInteractionSupport(_spec(widget: button), tempDir),
        returnsNormally,
      );
    });

    test('does not apply to a widget without a button', () {
      lock('0.9.0');

      expect(
        () => validateInteractionSupport(
          _spec(interactionHandler: handler),
          tempDir,
        ),
        returnsNormally,
      );
      expect(
        () => validateInteractionSupport(_spec(), tempDir),
        returnsNormally,
      );
    });
  });

  group('requireHomeWidgetVersion', () {
    void require() => requireHomeWidgetVersion(
          tempDir,
          minimum: '1.2.3',
          feature: 'this needs it',
        );

    test('fails below the minimum, naming the feature', () {
      for (final version in const ['1.2.2', '1.1.9', '0.9.9']) {
        lock(version);
        expect(
          require,
          throwsA(
            isA<GeneratorError>().having(
              (e) => e.message,
              'message',
              startsWith(
                'this needs it, which needs home_widget 1.2.3 or newer; '
                'pubspec.lock resolves home_widget $version.',
              ),
            ),
          ),
          reason: version,
        );
      }
    });

    test('passes at and above the minimum', () {
      for (final version in const ['1.2.3', '1.2.4', '1.3.0', '2.0.0']) {
        lock(version);
        expect(require, returnsNormally, reason: version);
      }
    });

    test('only checks a hosted dependency', () {
      lock('0.1.0', source: 'path');

      expect(require, returnsNormally);
    });

    test('is silent on a version it cannot read', () {
      for (final version in const ['1.2', 'one.two.three']) {
        lock(version);
        expect(require, returnsNormally, reason: version);
      }
    });

    test('is silent without a lockfile, and on one it cannot read', () {
      expect(require, returnsNormally);

      final lockFile = File(p.join(tempDir.path, 'pubspec.lock'));
      for (final content in const [
        'packages: [\n  home_widget:\n',
        '- a list',
        'packages: none',
        'packages:\n  other: {}\n',
        'packages:\n  home_widget: hosted\n',
        'packages:\n  home_widget:\n    source: hosted\n    version: 3\n',
      ]) {
        lockFile.writeAsStringSync(content);
        expect(require, returnsNormally, reason: content);
      }
    });
  });
}
