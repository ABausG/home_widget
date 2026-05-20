import 'dart:convert';

import 'package:home_widget_cli/src/util/gradle_utils.dart';
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
}
