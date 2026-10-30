import 'dart:convert';
import 'dart:io';

import 'package:home_widget_cli/src/generators/payload_dart_emitter.dart';
import 'package:home_widget_generator/home_widget_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _declare(HWPayloadUrl url, String className) =>
    PayloadDartEmitter(url).classDeclaration(
      className: className,
      superClass: 'Launch',
      description: 'A tap.',
    );

void main() {
  final forecast = HWPayloadUrl.of(
    'myApp://forecast?tab=today#top',
    const [
      HWString('city'),
      HWPayload('town', HWString('home', defaultValue: "O'Hare \$1")),
      HWInt('count'),
      HWPayload('days', HWInt.fixed(7)),
      HWDouble('ratio', defaultValue: 0.5),
      HWBool('done'),
      HWPayload('flag', HWBool.fixed(true)),
      HWDateTime('at'),
      HWPayload('since', HWDateTime.fixed('2026-09-22T10:00:00Z')),
      HWPayload('other', HWJson('user', HWString('name'))),
    ],
  );
  const plain = HWPayloadUrl('myapp://plain');
  final borderline = HWPayloadUrl.of(
    'myapp://borderline',
    const [
      HWPayload('uri', HWString('a')),
      HWPayload('query', HWInt('b')),
      HWPayload('other', HWBool('c')),
      HWPayload('url', HWDouble('d')),
      HWPayload('Int', HWDateTime('e')),
      HWPayload('PlainTap', HWString('f')),
      HWPayload('value', HWString('g')),
      HWPayload('millis', HWString('h')),
      HWPayload('head', HWString('i')),
    ],
  );

  group('classDeclaration', () {
    test('documents and names the class', () {
      final code = _declare(plain, 'PlainTap');

      expect(
        code,
        startsWith('/// A tap.\nfinal class PlainTap extends Launch {\n'),
      );
    });

    test('a class without a payload is a const without fields', () {
      final code = _declare(plain, 'PlainTap');

      expect(code, contains('  const PlainTap();\n'));
      expect(code, isNot(contains('  final ')));
      expect(
        code,
        contains(
          "  static final Uri _\$url = Uri.parse('myapp://plain?homeWidget');",
        ),
      );
      expect(
        code,
        contains(
          '  static PlainTap? _\$fromUri(Uri uri) {\n'
          '    try {\n'
          '      if (!_\$matchesPayloadUrl(uri, _\$url)) return null;\n'
          '      return const PlainTap();\n'
          '    } on FormatException {\n'
          '      return null;\n'
          '    } on ArgumentError {\n'
          '      return null;\n'
          '    }\n'
          '  }',
        ),
      );
      expect(code, contains('  Uri toUri() => _\$url;'));
      expect(
        code,
        contains('bool operator ==(Object other) => other is PlainTap;'),
      );
      expect(code, contains('int get hashCode => (PlainTap).hashCode;'));
      expect(code, contains("String toString() => 'PlainTap()';"));
    });

    test('types a field per entry, nullable unless fixed or defaulted', () {
      final code = _declare(forecast, 'ForecastLink');

      expect(code, contains('  final String? city;\n'));
      expect(code, contains('  final String town;\n'));
      expect(code, contains('  final int? count;\n'));
      expect(code, contains('  final int days;\n'));
      expect(code, contains('  final double ratio;\n'));
      expect(code, contains('  final bool? done;\n'));
      expect(code, contains('  final bool flag;\n'));
      expect(code, contains('  final DateTime? at;\n'));
      expect(code, contains('  final DateTime since;\n'));
      expect(code, contains('  final String? other;\n'));
    });

    test('defaults what is never null, and requires a fixed date', () {
      final code = _declare(forecast, 'ForecastLink');

      expect(
        code,
        contains(
          '  const ForecastLink({this.city, '
          "this.town = 'O\\'Hare \\\$1', this.count, this.days = 7, "
          'this.ratio = 0.5, this.done, this.flag = true, this.at, '
          'required this.since, this.other});',
        ),
      );
    });

    test('reads every entry out of the query, with its fallback', () {
      final code = _declare(forecast, 'ForecastLink');
      final since = DateTime.utc(2026, 9, 22, 10).millisecondsSinceEpoch;

      expect(code, contains("city: query['city'], "));
      expect(code, contains("town: query['town'] ?? 'O\\'Hare \\\$1', "));
      expect(code, contains("count: _\$payloadInt(query['count']), "));
      expect(code, contains("days: _\$payloadInt(query['days']) ?? 7, "));
      expect(
        code,
        contains("ratio: _\$payloadDouble(query['ratio']) ?? 0.5, "),
      );
      expect(code, contains("done: _\$payloadBool(query['done']), "));
      expect(code, contains("flag: _\$payloadBool(query['flag']) ?? true, "));
      expect(code, contains("at: _\$payloadDateTime(query['at']), "));
      expect(
        code,
        contains(
          "since: _\$payloadDateTime(query['since']) ?? "
          'DateTime.fromMillisecondsSinceEpoch($since, isUtc: true), ',
        ),
      );
    });

    test('writes the payload back the way native code does', () {
      final code = _declare(forecast, 'ForecastLink');

      expect(
        code,
        contains(
          "Uri toUri() => _\$payloadUri('myApp://forecast?tab=today', "
          "{'city': city, 'town': town, 'count': count?.toString(), "
          "'days': days.toString(), 'ratio': ratio.toString(), "
          "'done': done?.toString(), 'flag': flag.toString(), "
          "'at': at?.toUtc().millisecondsSinceEpoch.toString(), "
          "'since': since.toUtc().millisecondsSinceEpoch.toString(), "
          "'other': other}, 'homeWidget', '#top');",
        ),
      );
    });

    test('compares against this, so a field may be named other', () {
      final code = _declare(forecast, 'ForecastLink');

      expect(code, contains('other.other == this.other'));
      expect(
        code,
        contains(
          'int get hashCode => Object.hashAll([ForecastLink, this.city, ',
        ),
      );
      expect(code, contains("'ForecastLink(city: \$city, town: \$town, "));
    });

    test('compares a date by the millisecond it travels as', () {
      final code = _declare(forecast, 'ForecastLink');

      expect(
        code,
        contains(
          'other.at?.millisecondsSinceEpoch == '
          'this.at?.millisecondsSinceEpoch',
        ),
      );
      expect(
        code,
        contains(
          'other.since.millisecondsSinceEpoch == '
          'this.since.millisecondsSinceEpoch',
        ),
      );
      expect(
        code,
        contains(
          'this.at?.millisecondsSinceEpoch, '
          'this.since.millisecondsSinceEpoch, this.other]);',
        ),
      );
    });

    test('names what a payload name cannot be', () {
      expect(
        PayloadDartEmitter.memberNames,
        containsAll(['toUri', 'fromUri', 'hashCode', 'toString']),
      );
      final code = _declare(forecast, 'ForecastLink');
      for (final name in PayloadDartEmitter.referencedNames) {
        expect(code, contains(RegExp('\\b$name\\b')), reason: name);
      }
    });

    test('appends no marker to a URL already carrying it', () {
      final code = _declare(
        HWPayloadUrl.of('myapp://a?homeWidget', const [HWString('city')]),
        'ALink',
      );

      expect(code, contains("_\$payloadUri('myapp://a?homeWidget', "));
      expect(code, contains("{'city': city}, '', '');"));
    });
  });

  group('helpers', () {
    test('carries the writer only for a payload to write', () {
      expect(
        PayloadDartEmitter.helpers([plain, forecast]),
        contains('Uri _\$payloadUri(String head, '),
      );
    });

    test('always carries the matcher', () {
      final code = PayloadDartEmitter.helpers([plain]);

      expect(code, contains('bool _\$matchesPayloadUrl(Uri uri, Uri url) {'));
      expect(code, isNot(contains('_\$payloadUri')));
      expect(code, isNot(contains('_\$payloadInt')));
      expect(code, isNot(contains('_\$payloadDouble')));
      expect(code, isNot(contains('_\$payloadBool')));
      expect(code, isNot(contains('_\$payloadDateTime')));
    });

    test('carries one reader per type a payload uses', () {
      final code = PayloadDartEmitter.helpers([plain, forecast]);

      expect(code, contains('int? _\$payloadInt(String? value)'));
      expect(code, contains('double? _\$payloadDouble(String? value)'));
      expect(code, contains('bool? _\$payloadBool(String? value)'));
      expect(code, contains('DateTime? _\$payloadDateTime(String? value)'));
    });

    test('skips an entry of a type no payload can carry', () {
      final code = PayloadDartEmitter.helpers([
        HWPayloadUrl.of('myapp://a', const [HWImageData('avatar')]),
      ]);

      expect(code, isNot(contains('_\$payloadInt')));
    });
  });

  group('the emitted code', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('payload_dart_emitter');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    /// Runs [statements], each an expression, against the classes of
    /// [forecast] and [plain] and answers what each evaluates to, as text.
    List<String> evaluate(List<String> statements) {
      final script = File(p.join(tempDir.path, 'launch.dart'));
      script.writeAsStringSync('''
import 'dart:convert';

sealed class Launch {
  const Launch();
  Uri toUri();
}

${_declare(forecast, 'ForecastLink')}
${_declare(plain, 'PlainTap')}
${_declare(borderline, 'BorderlineLink')}
${PayloadDartEmitter.helpers([forecast, plain, borderline])}

final since = DateTime.utc(2026, 9, 22, 10);

void main() {
  print(jsonEncode([
    ${statements.map((statement) => "'\${$statement}'").join(',\n    ')},
  ]));
}
''');
      final result = Process.runSync(
        Platform.resolvedExecutable,
        ['run', script.path],
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return (jsonDecode((result.stdout as String).trim().split('\n').last)
              as List<dynamic>)
          .cast<String>();
    }

    test('decodes what native code sends and round-trips through toUri', () {
      const everything = 'myapp://forecast?tab=today'
          '&city=New%20York%20%26%20Co%2B1%3D2%2F%C3%A9'
          '&town=Home&count=-3&days=3&ratio=1.0E20&done=false&flag=false'
          '&at=1790000000123&since=1000&other=Ada&homeWidget#top';
      final results = evaluate([
        "ForecastLink._\$fromUri(Uri.parse('$everything'))",
        "ForecastLink._\$fromUri(Uri.parse('$everything'))!.toUri()",
        "ForecastLink._\$fromUri(Uri.parse('myApp://forecast?tab=today&homeWidget#top'))",
        'ForecastLink(since: since).toUri()',
        'ForecastLink._\$fromUri(ForecastLink(since: since).toUri()) == '
            'ForecastLink(since: since)',
        "ForecastLink._\$fromUri(ForecastLink(city: 'a+b c&d=é/?#', "
            "at: DateTime.utc(2026), since: since).toUri()) == "
            "ForecastLink(city: 'a+b c&d=é/?#', at: DateTime.utc(2026), "
            'since: since)',
        "ForecastLink(city: 'a+b c', since: since).toUri().query",
        'ForecastLink(since: since).hashCode == '
            'ForecastLink(since: since).hashCode',
        "ForecastLink(city: 'x', since: since) == ForecastLink(since: since)",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?tab=today"
            "&count=many&ratio=&done=yes&at=soon&homeWidget#top'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?tab=today"
            "&ratio=NaN&unknown=1#top'))!.ratio.isNaN",
      ]);

      expect(
        results[0],
        'ForecastLink(city: New York & Co+1=2/é, town: Home, count: -3, '
        'days: 3, ratio: 100000000000000000000.0, done: false, flag: false, '
        'at: 2026-09-21 14:13:20.123Z, since: 1970-01-01 00:00:01.000Z, '
        'other: Ada)',
      );
      expect(
        results[1],
        'myapp://forecast?tab=today'
        '&city=New%20York%20%26%20Co%2B1%3D2%2F%C3%A9'
        '&town=Home&count=-3&days=3&ratio=100000000000000000000.0'
        '&done=false&flag=false&at=1790000000123&since=1000&other=Ada'
        '&homeWidget#top',
      );
      expect(
        results[2],
        "ForecastLink(city: null, town: O'Hare \$1, count: null, days: 7, "
        'ratio: 0.5, done: null, flag: true, at: null, '
        'since: 2026-09-22 10:00:00.000Z, other: null)',
      );
      expect(
        results[3],
        "myapp://forecast?tab=today&town=O'Hare%20%241&days=7&ratio=0.5"
        '&flag=true&since=${DateTime.utc(2026, 9, 22, 10).millisecondsSinceEpoch}'
        '&homeWidget#top',
      );
      expect(results[4], 'true');
      expect(results[5], 'true');
      expect(results[6], contains('city=a%2Bb%20c&'));
      expect(results[7], 'true');
      expect(results[8], 'false');
      expect(
        results[9],
        "ForecastLink(city: null, town: O'Hare \$1, count: null, days: 7, "
        'ratio: 0.5, done: null, flag: true, at: null, '
        'since: 2026-09-22 10:00:00.000Z, other: null)',
      );
      expect(results[10], 'true');
    });

    test('answers null for malformed percent-encoding', () {
      final results = evaluate([
        "PlainTap._\$fromUri(Uri.parse('myapp://plain?homeWidget=1&city=%FF'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?tab=today&city=%FF#top'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?tab=%FF#top'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?tab=today&city=ok#top'))?.city",
      ]);

      expect(results, ['null', 'null', 'null', 'ok']);
    });

    test('treats a date as an instant with millisecond precision', () {
      final results = evaluate([
        'ForecastLink(at: DateTime(2026, 9, 22, 10, 0, 0, 5, 7), since: since) == '
            'ForecastLink._\$fromUri(ForecastLink(at: DateTime(2026, 9, 22, '
            '10, 0, 0, 5, 7), since: since).toUri())',
        'ForecastLink(at: DateTime(2026, 9, 22, 10, 0, 0, 5, 7), since: since).hashCode == '
            'ForecastLink._\$fromUri(ForecastLink(at: DateTime(2026, 9, 22, '
            '10, 0, 0, 5, 7), since: since).toUri()).hashCode',
        'ForecastLink(since: since.toLocal()) == ForecastLink(since: since)',
        'ForecastLink(at: DateTime.utc(2026), since: since) == '
            'ForecastLink(at: DateTime.utc(2026, 1, 1, 0, 0, 0, 1), since: since)',
        'ForecastLink(at: DateTime.utc(2026), since: since) == '
            'ForecastLink(since: since)',
        "ForecastLink._\$fromUri(ForecastLink(at: DateTime(2026), "
            'since: since).toUri())!.at!.isUtc',
      ]);

      expect(results, ['true', 'true', 'true', 'false', 'false', 'true']);
    });

    test('compiles with names its own code uses for locals', () {
      final results = evaluate([
        "BorderlineLink._\$fromUri(BorderlineLink(uri: 'u', query: 2, "
            "other: true, url: 1.5, Int: DateTime.utc(2026), PlainTap: 'p', "
            "value: 'v', millis: 'm', head: 'h').toUri())",
        "BorderlineLink(uri: 'u') == BorderlineLink(uri: 'u')",
        "BorderlineLink(uri: 'u') == BorderlineLink(uri: 'x')",
      ]);

      expect(
        results[0],
        'BorderlineLink(uri: u, query: 2, other: true, url: 1.5, '
        'Int: 2026-01-01 00:00:00.000Z, PlainTap: p, value: v, millis: m, '
        'head: h)',
      );
      expect(results.sublist(1), ['true', 'false']);
    });

    test('only matches the URL the class stands for', () {
      final results = evaluate([
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?homeWidget#top'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?tab=week&homeWidget#top'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?tab=today&tab=week#top'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast?tab=today&homeWidget'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://forecast/x?tab=today#top'))",
        "ForecastLink._\$fromUri(Uri.parse('myapp://other?tab=today#top'))",
        "ForecastLink._\$fromUri(Uri.parse('other://forecast?tab=today#top'))",
        "ForecastLink._\$fromUri(Uri.parse('MYAPP://forecast?tab=today#top')) != null",
        "PlainTap._\$fromUri(Uri.parse('myapp://plain'))",
        "PlainTap._\$fromUri(Uri.parse('myapp://plain?extra=1&homeWidget'))",
        "PlainTap._\$fromUri(Uri.parse('myapp://plain/'))",
        'PlainTap._\$fromUri(Uri())',
        'const PlainTap().toUri()',
        'const PlainTap() == const PlainTap()',
        'const PlainTap().hashCode == const PlainTap().hashCode',
      ]);

      expect(results.sublist(0, 7), everyElement('null'));
      expect(results[7], 'true');
      expect(results[8], 'PlainTap()');
      expect(results[9], 'PlainTap()');
      expect(results[10], 'null');
      expect(results[11], 'null');
      expect(results[12], 'myapp://plain?homeWidget');
      expect(results[13], 'true');
      expect(results[14], 'true');
    });
  });
}
