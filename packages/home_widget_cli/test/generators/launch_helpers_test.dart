import 'package:home_widget_cli/src/generators/dart_helper_generator.dart';
import 'package:home_widget_cli/src/models/widget_spec.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:test/test.dart';

const _history = HWLink(
  'history',
  url: 'myapp://history',
  child: HWText(HWString.fixed('History')),
);

const _forecast = HWLink(
  'forecast',
  url: 'myapp://forecast',
  data: [HWString('city'), HWPayload('days', HWInt.fixed(7))],
  child: HWText(HWString.fixed('Forecast')),
);

String _generate({
  String? widgetUrl,
  List<HWDataType<dynamic>> widgetUrlData = const [],
  HWWidget? tree,
  bool android = true,
  bool iOS = true,
  bool openAppOnTap = true,
}) =>
    DartHelperGenerator(
      WidgetSpec(
        data: HomeWidget(
          name: 'Weather',
          widgetUrl: widgetUrl,
          widgetUrlData: widgetUrlData,
          android: android
              ? HomeWidgetAndroidConfiguration(openAppOnTap: openAppOnTap)
              : null,
          iOS: iOS
              ? const HomeWidgetIOSConfiguration(groupId: 'group.weather')
              : null,
        ),
        className: 'Weather',
        widgetTree: tree,
      ),
    ).generate();

void main() {
  group('launch helpers', () {
    test('report launches through the plugin, decoded by the model', () {
      final output = _generate(widgetUrl: 'myapp://weather');

      expect(
        output,
        contains(
          '  static Future<WeatherLaunch?> initialLaunch() => '
          'HomeWidget.initialLaunch(WeatherLaunch.fromUri);',
        ),
      );
      expect(
        output,
        contains(
          '  static Stream<WeatherLaunch> launches() => '
          'HomeWidget.launches(WeatherLaunch.fromUri);',
        ),
      );
    });

    test('need neither dart:async nor dart:io', () {
      final output = _generate(widgetUrl: 'myapp://weather');

      expect(output, isNot(contains("import 'dart:async';")));
      expect(output, isNot(contains("import 'dart:io';")));
      expect(output, isNot(contains('Platform.')));
    });

    test('are emitted for a widget with links and no URL', () {
      final output = _generate(tree: _history);

      expect(output, contains('static Stream<WeatherLaunch> launches()'));
      expect(output, contains('final class WeatherHistoryLink'));
      expect(output, isNot(contains('WeatherWidgetTap')));
    });

    test('are left out where no platform opens the URL', () {
      final output = _generate(
        widgetUrl: 'myapp://weather',
        iOS: false,
        openAppOnTap: false,
      );

      expect(output, isNot(contains('WeatherLaunch')));
      expect(output, isNot(contains('launches()')));
    });
  });

  group('launch model', () {
    test('is a sealed class decoding every target in order', () {
      final output = _generate(
        widgetUrl: 'myapp://weather',
        tree: const HWColumn(children: [_history, _forecast]),
      );

      expect(
        output,
        contains(
          '/// A tap on the Weather widget that opened the app.\n'
          'sealed class WeatherLaunch {\n'
          '  const WeatherLaunch();\n',
        ),
      );
      expect(
        output,
        contains(
          '  static WeatherLaunch? fromUri(Uri uri) => '
          'WeatherWidgetTap._\$fromUri(uri) ?? '
          'WeatherHistoryLink._\$fromUri(uri) ?? '
          'WeatherForecastLink._\$fromUri(uri);',
        ),
      );
      expect(output, contains('  Uri toUri();'));
    });

    test('declares the tap on the widget only when a URL is set', () {
      final output = _generate(widgetUrl: 'myApp://weather');

      expect(
        output,
        contains(
          '/// A tap on the Weather widget itself.\n'
          'final class WeatherWidgetTap extends WeatherLaunch {\n'
          '  const WeatherWidgetTap();\n',
        ),
      );
      expect(
        output,
        contains(
          "static final Uri _\$url = Uri.parse('myApp://weather?homeWidget');",
        ),
      );
    });

    test('carries widgetUrlData on the tap on the widget', () {
      final output = _generate(
        widgetUrl: 'myapp://weather',
        widgetUrlData: const [HWString('city')],
      );

      expect(output, contains('  const WeatherWidgetTap({this.city});'));
      expect(output, contains('  final String? city;'));
      expect(
        output,
        contains("return WeatherWidgetTap(city: query['city']);"),
      );
    });

    test('declares one class per link id with its payload', () {
      final output = _generate(
        tree: const HWSizeAdaptive(
          small: HWColumn(children: [_forecast]),
          medium: HWRow(children: [_forecast, _history]),
        ),
      );

      expect(
        'final class WeatherForecastLink'.allMatches(output),
        hasLength(1),
      );
      expect(
        output,
        contains(
          '/// A tap on the `forecast` link of the Weather widget.\n'
          'final class WeatherForecastLink extends WeatherLaunch {\n'
          '  const WeatherForecastLink({this.city, this.days = 7});\n'
          '\n'
          '  final String? city;\n'
          '  final int days;\n',
        ),
      );
      expect(output, contains('final class WeatherHistoryLink'));
    });

    test('carries the readers its payloads need, once', () {
      final output = _generate(
        tree: const HWColumn(children: [_history, _forecast]),
      );

      expect('bool _\$matchesPayloadUrl('.allMatches(output), hasLength(1));
      expect('Uri _\$payloadUri('.allMatches(output), hasLength(1));
      expect('int? _\$payloadInt('.allMatches(output), hasLength(1));
      expect(output, isNot(contains('_\$payloadBool')));
    });

    test('stores what a link sends as a field of the widget', () {
      final output = DartHelperGenerator(
        WidgetSpec(
          data: HomeWidget(
            name: 'Weather',
            android: const HomeWidgetAndroidConfiguration(),
          ),
          className: 'Weather',
          dataFields: _forecast.dataDependencies.toList(),
          widgetTree: _forecast,
        ),
      ).generate();

      expect(output, contains('String? city,'));
      expect(output, isNot(contains('int? days')));
    });
  });

  group('Uri launch helpers', () {
    test('are deprecated wrappers around the tap on the widget', () {
      final output = _generate(
        widgetUrl: 'myApp://weather',
        tree: _history,
      );

      const deprecated =
          "  @Deprecated('Use launches() and initialLaunch() instead.')\n";
      expect(
        output,
        contains(
          '$deprecated'
          '  static final Uri widgetUrl = '
          "Uri.parse('myApp://weather?homeWidget');",
        ),
      );
      expect(
        output,
        contains(
          '$deprecated'
          '  static Future<Uri?> initiallyLaunchedFromWidget() => '
          'HomeWidget.initialLaunch(_\$widgetTapUri);',
        ),
      );
      expect(
        output,
        contains(
          '$deprecated'
          '  static Stream<Uri> get widgetClicked =>\n'
          '      HomeWidget.widgetClicked\n'
          '          .where((uri) => uri != null && '
          '_\$widgetTapUri(uri) != null)\n'
          '          .cast<Uri>();',
        ),
      );
      expect(
        output,
        contains(
          '$deprecated'
          '  static Stream<Uri> launchedFromWidget() => '
          'HomeWidget.launches(_\$widgetTapUri);',
        ),
      );
      expect(
        output,
        contains(
          '  static Uri? _\$widgetTapUri(Uri uri) => '
          'WeatherWidgetTap._\$fromUri(uri) == null ? null : uri;',
        ),
      );
    });

    test('are left out for a widget that only has links', () {
      final output = _generate(tree: _history);

      expect(output, isNot(contains('initiallyLaunchedFromWidget')));
      expect(output, isNot(contains('widgetClicked')));
      expect(output, isNot(contains('launchedFromWidget')));
      expect(output, isNot(contains('static final Uri widgetUrl')));
    });
  });
}
