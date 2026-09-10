import 'dart:convert';

import 'package:home_widget_cli/src/util/gradle_utils.dart';
import 'package:home_widget_cli/src/util/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

void main() {
  test('ensureGlanceDependency preserves custom indentation in dependencies {}',
      () {
    final input = '''
android {
}

\tdependencies {\t\t
\t\t// existing
\t}
''';

    final out = ensureGlanceDependency(
      input,
      dialect: GradleDialect.groovy,
      glanceVersion: '9.9.9',
    );

    expect(out, contains("'androidx.glance:glance-appwidget:9.9.9'"));
    final depLine = LineSplitter.split(out)
        .firstWhere((l) => l.contains('glance-appwidget'));
    expect(depLine.startsWith('\t\t'), isTrue);
  });

  test(
      'ensureComposeEnabled adds composeOptions kotlinCompilerExtensionVersion',
      () {
    final input = '''
plugins {
}

android {
    buildFeatures {
    }
}

dependencies {
}
''';

    final out = ensureComposeEnabled(
      input,
      dialect: GradleDialect.groovy,
      kotlinCompilerExtensionVersion: '1.5.2',
    );

    expect(out, contains('composeOptions'));
    expect(
      out,
      contains('kotlinCompilerExtensionVersion = "1.5.2"'),
    );
  });

  test(
      'ensureGlanceDependency uses block indent when first dep line is not '
      'deeper than dependencies keyword', () {
    final input = '''
android {
}

    dependencies {
    implementation "x"
    }
''';

    final out = ensureGlanceDependency(
      input,
      dialect: GradleDialect.groovy,
      glanceVersion: '1.0.0',
    );

    final depLine = LineSplitter.split(out)
        .firstWhere((l) => l.contains('glance-appwidget'));
    expect(depLine, startsWith('        '));
  });

  test(
      'ensureGlanceDependency handles dependencies block with no closing brace',
      () {
    final input = '''
android {
}

dependencies {
    implementation "x"
''';

    final out = ensureGlanceDependency(
      input,
      dialect: GradleDialect.groovy,
      glanceVersion: '1.0.0',
    );

    expect(out, contains('glance-appwidget'));
  });

  test(
      'ensureComposeEnabled skips inserting kotlinCompilerExtensionVersion when '
      'already present in composeOptions', () {
    const input = '''
android {
    buildFeatures {
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "9.9.9"
    }
}
''';

    final out = ensureComposeEnabled(
      input,
      dialect: GradleDialect.groovy,
      kotlinCompilerExtensionVersion: '1.5.2',
    );

    expect(out, contains('kotlinCompilerExtensionVersion = "9.9.9"'));
    expect(out, isNot(contains('1.5.2')));
  });

  test(
      'ensureComposeEnabled inserts version into existing empty composeOptions',
      () {
    final input = '''
android {
    composeOptions {
    }
    buildFeatures {
    }
}
''';

    final out = ensureComposeEnabled(
      input,
      dialect: GradleDialect.groovy,
      kotlinCompilerExtensionVersion: '2.0.0',
    );

    expect(out, contains('kotlinCompilerExtensionVersion = "2.0.0"'));
  });

  group('ensureGlanceDependency version floor', () {
    late Logger previousLogger;
    late List<String> warnings;

    setUp(() {
      previousLogger = logger;
      warnings = [];
      logger = _WarningRecorder(warnings);
    });

    tearDown(() => logger = previousLogger);

    test('raises a pin below $minimumGlanceVersion to the resolved version',
        () {
      const input = '''
dependencies {
    implementation("androidx.glance:glance-appwidget:1.1.0")
}
''';

      final out = ensureGlanceDependency(
        input,
        dialect: GradleDialect.kts,
        glanceVersion: '1.2.1',
      );

      expect(
        out,
        contains('implementation("androidx.glance:glance-appwidget:1.2.1")'),
      );
      expect(out, isNot(contains('1.1.0')));
      expect(warnings.single, contains(minimumGlanceVersion));
      expect(warnings.single, contains('1.1.0'));
    });

    test('raises a Groovy pin too', () {
      const input = '''
dependencies {
    implementation 'androidx.glance:glance-appwidget:1.0.0'
}
''';

      final out = ensureGlanceDependency(
        input,
        dialect: GradleDialect.groovy,
        glanceVersion: '1.2.0',
      );

      expect(
        out,
        contains("implementation 'androidx.glance:glance-appwidget:1.2.0'"),
      );
    });

    test('leaves a pin at or above the floor alone and stays silent', () {
      for (final version in const ['1.2.0', '1.3.0', '2.0.0']) {
        final input = '''
dependencies {
    implementation("androidx.glance:glance-appwidget:$version")
}
''';

        expect(
          ensureGlanceDependency(
            input,
            dialect: GradleDialect.kts,
            glanceVersion: '9.9.9',
          ),
          input,
          reason: version,
        );
      }
      expect(warnings, isEmpty);
    });

    test('leaves a version it cannot compare alone', () {
      for (final version in const [
        r'$glanceVersion',
        '1.1.0-beta01',
        '1.1',
        'latest.release',
      ]) {
        final input = '''
dependencies {
    implementation("androidx.glance:glance-appwidget:$version")
}
''';

        expect(
          ensureGlanceDependency(
            input,
            dialect: GradleDialect.kts,
            glanceVersion: '1.2.0',
          ),
          input,
          reason: version,
        );
      }
      expect(warnings, isEmpty);
    });

    test('leaves a declaration without a version alone', () {
      const input = '''
dependencies {
    implementation("androidx.glance:glance-appwidget")
}
''';

      expect(
        ensureGlanceDependency(
          input,
          dialect: GradleDialect.kts,
          glanceVersion: '1.2.0',
        ),
        input,
      );
    });

    test('warns once when several pins are outdated', () {
      const input = '''
dependencies {
    implementation("androidx.glance:glance-appwidget:1.0.0")
    debugImplementation("androidx.glance:glance-appwidget:1.1.0")
}
''';

      final out = ensureGlanceDependency(
        input,
        dialect: GradleDialect.kts,
        glanceVersion: '1.2.0',
      );

      expect(
        'androidx.glance:glance-appwidget:1.2.0'.allMatches(out).length,
        2,
      );
      expect(warnings, hasLength(1));
    });
  });
}

/// [Logger] collecting the warnings the Gradle patchers emit.
class _WarningRecorder extends Logger {
  _WarningRecorder(this.warnings);

  final List<String> warnings;

  @override
  void warn(String? message, {String tag = 'WARN', LogStyle? style}) {
    warnings.add(message ?? '');
  }
}
