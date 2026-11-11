import 'dart:io';

import 'package:home_widget_cli/src/util/ios_interactivity.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

const _widget = 'CounterHomeWidget';

const _runnerTarget = '''
platform :ios, '13.0'

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
''';

const _postInstall = '''
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
''';

const _podfile = '$_runnerTarget\n$_postInstall';

const _widgetTarget = '''
target 'CounterHomeWidget' do
  use_frameworks!
  use_modular_headers!

  pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'
end
''';

/// The app delegate `flutter create` wrote before the implicit engine.
const _appDelegate = '''
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
''';

const _patchedAppDelegate = '''
import Flutter
import UIKit
import home_widget

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 17, *) {
      HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
''';

/// The app delegate `flutter create` writes for the implicit engine, indented
/// by four spaces.
const _implicitEngineAppDelegate = '''
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}
''';

const _patchedImplicitEngineAppDelegate = '''
import Flutter
import UIKit
import home_widget

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if #available(iOS 17, *) {
          HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
          }
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}
''';

void main() {
  late Directory tempDir;
  late Directory iosDir;
  late MockLogger mockLogger;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ios_interactivity_test');
    iosDir = Directory(p.join(tempDir.path, 'ios'))..createSync();
    mockLogger = useMockLogger();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('podfileWidgetTarget names the widget and the home_widget pod', () {
    expect(podfileWidgetTarget(_widget), _widgetTarget);
  });

  group('ensurePodfileWidgetTarget', () {
    late File podfile;

    setUp(() {
      podfile = File(p.join(iosDir.path, 'Podfile'));
    });

    Future<String> ensure(String content) async {
      podfile.writeAsStringSync(content);
      await ensurePodfileWidgetTarget(podfile, _widget);
      return podfile.readAsStringSync();
    }

    test('inserts the target ahead of the post_install hook', () async {
      final result = await ensure(_podfile);

      expect(result, '$_runnerTarget\n$_widgetTarget\n$_postInstall');
      verify(() => mockLogger.detail('Updated: ${podfile.path}')).called(1);
    });

    test('appends the target to a Podfile ending with a newline', () async {
      final result = await ensure(_runnerTarget);

      expect(result, '$_runnerTarget\n$_widgetTarget');
    });

    test('appends the target to a Podfile ending without a newline', () async {
      final result = await ensure(_runnerTarget.trimRight());

      expect(result, '$_runnerTarget\n$_widgetTarget');
    });

    test('appends the target to a Podfile ending with a blank line', () async {
      final result = await ensure('$_runnerTarget\n');

      expect(result, '$_runnerTarget\n$_widgetTarget');
    });

    test('writes the target into an empty Podfile', () async {
      final result = await ensure('');

      expect(result, _widgetTarget);
    });

    test('is idempotent', () async {
      final first = await ensure(_podfile);
      await ensurePodfileWidgetTarget(podfile, _widget);

      expect(podfile.readAsStringSync(), first);
      verify(() => mockLogger.detail(any())).called(1);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('leaves a target naming the pod alone', () async {
      const content = '''
$_runnerTarget
target 'CounterHomeWidget' do
  use_frameworks!
  pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'
  pod 'Alamofire'
end

$_postInstall''';

      final result = await ensure(content);

      expect(result, content);
      verifyNever(() => mockLogger.warn(any()));
      verifyNever(() => mockLogger.detail(any()));
    });

    test('leaves a nested target in double quotes naming the pod alone',
        () async {
      const content = '''
target 'Runner' do
  use_frameworks!

  target "CounterHomeWidget" do
    inherit! :search_paths
    pod "home_widget", :path => '.symlinks/plugins/home_widget/ios'
  end
end

$_postInstall''';

      final result = await ensure(content);

      expect(result, content);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('warns about a target that does not name the pod', () async {
      const content = '''
$_runnerTarget
target "CounterHomeWidget" do
  use_frameworks!
end

target 'OtherHomeWidget' do
  pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'
end
''';

      final result = await ensure(content);

      expect(result, content);
      final warning = verify(() => mockLogger.warn(captureAny())).captured;
      expect(warning, hasLength(1));
      expect(
        warning.single,
        allOf(
          contains("The target '$_widget' in ${podfile.path}"),
          contains(
            "pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'",
          ),
        ),
      );
    });

    test('warns about a nested target that does not name the pod', () async {
      const content = '''
target 'Runner' do
  use_frameworks!

  target 'CounterHomeWidget' do
    inherit! :search_paths
  end
  pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'
end
''';

      final result = await ensure(content);

      expect(result, content);
      verify(
        () => mockLogger.warn(any(that: contains("The target '$_widget'"))),
      ).called(1);
    });

    test('reads a target that is never closed to the end of the file',
        () async {
      const withPod = '''
target 'CounterHomeWidget' do
  pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'
''';
      const withoutPod = '''
target 'CounterHomeWidget' do
  use_frameworks!
''';

      expect(await ensure(withPod), withPod);
      verifyNever(() => mockLogger.warn(any()));

      expect(await ensure(withoutPod), withoutPod);
      verify(() => mockLogger.warn(any())).called(1);
    });

    test('does not take a target of a longer name for the widget', () async {
      const content = '''
target 'CounterHomeWidgetTests' do
  pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'
end
''';

      final result = await ensure(content);

      expect(result, '$content\n$_widgetTarget');
    });
  });

  group('removePodfileWidgetTarget', () {
    late File podfile;

    setUp(() {
      podfile = File(p.join(iosDir.path, 'Podfile'));
    });

    test('restores the Podfile the target was inserted into', () async {
      podfile.writeAsStringSync(_podfile);
      await ensurePodfileWidgetTarget(podfile, _widget);
      expect(podfile.readAsStringSync(), isNot(_podfile));

      await removePodfileWidgetTarget(podfile, _widget);

      expect(podfile.readAsStringSync(), _podfile);
      verify(() => mockLogger.detail('Updated: ${podfile.path}')).called(2);
    });

    test('removes a target at the end of the Podfile', () async {
      podfile.writeAsStringSync('$_runnerTarget\n$_widgetTarget');

      await removePodfileWidgetTarget(podfile, _widget);

      expect(podfile.readAsStringSync(), _runnerTarget);
    });

    test('restores a Podfile without a post_install hook', () async {
      podfile.writeAsStringSync(_runnerTarget);

      await ensurePodfileWidgetTarget(podfile, _widget);
      await removePodfileWidgetTarget(podfile, _widget);

      expect(podfile.readAsStringSync(), _runnerTarget);
    });

    test('removes a target that is all the Podfile holds', () async {
      podfile.writeAsStringSync(_widgetTarget);

      await removePodfileWidgetTarget(podfile, _widget);

      expect(podfile.readAsStringSync(), isEmpty);
    });

    test('keeps the targets of other widgets', () async {
      final other = podfileWidgetTarget('OtherHomeWidget');
      podfile.writeAsStringSync(
        '$_runnerTarget\n$other\n$_widgetTarget\n$_postInstall',
      );

      await removePodfileWidgetTarget(podfile, _widget);

      expect(
        podfile.readAsStringSync(),
        '$_runnerTarget\n$other\n$_postInstall',
      );
    });

    test('leaves an edited target alone', () async {
      final content = '$_runnerTarget\n'
          '${_widgetTarget.replaceFirst('end\n', "  pod 'Alamofire'\nend\n")}\n'
          '$_postInstall';
      podfile.writeAsStringSync(content);

      await removePodfileWidgetTarget(podfile, _widget);

      expect(podfile.readAsStringSync(), content);
      verifyNever(() => mockLogger.detail(any()));
    });

    test('leaves a Podfile without the target alone', () async {
      podfile.writeAsStringSync(_podfile);
      final modified = podfile.lastModifiedSync();

      await removePodfileWidgetTarget(podfile, _widget);

      expect(podfile.readAsStringSync(), _podfile);
      expect(podfile.lastModifiedSync(), modified);
      verifyNever(() => mockLogger.detail(any()));
    });

    test('does nothing without a Podfile', () async {
      await removePodfileWidgetTarget(podfile, _widget);

      expect(podfile.existsSync(), isFalse);
      verifyNever(() => mockLogger.detail(any()));
    });
  });

  group('ensureAppDelegatePluginRegistrant', () {
    late File appDelegate;

    setUp(() {
      appDelegate = File(p.join(iosDir.path, 'Runner', 'AppDelegate.swift'))
        ..parent.createSync();
    });

    Future<String> ensure(String content) async {
      appDelegate.writeAsStringSync(content);
      await ensureAppDelegatePluginRegistrant(iosDir);
      return appDelegate.readAsStringSync();
    }

    test('registers the plugins ahead of the return of the launch method',
        () async {
      final result = await ensure(_appDelegate);

      expect(result, _patchedAppDelegate);
      verify(() => mockLogger.detail('Updated: ${appDelegate.path}')).called(1);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('indents the block the way an implicit engine delegate is indented',
        () async {
      final result = await ensure(_implicitEngineAppDelegate);

      expect(result, _patchedImplicitEngineAppDelegate);
    });

    test('is idempotent', () async {
      final first = await ensure(_appDelegate);
      await ensureAppDelegatePluginRegistrant(iosDir);

      expect(appDelegate.readAsStringSync(), first);
      verify(() => mockLogger.detail(any())).called(1);
      verifyNever(() => mockLogger.warn(any()));
    });

    test('leaves a delegate that already sets the callback alone', () async {
      const content = '''
import Flutter
import UIKit
import home_widget

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    HomeWidgetBackgroundWorker.setPluginRegistrantCallback(registerPlugins)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
''';

      final result = await ensure(content);

      expect(result, content);
      verifyNever(() => mockLogger.detail(any()));
      verifyNever(() => mockLogger.warn(any()));
    });

    test('adds the block next to the registrant callback of another plugin',
        () async {
      const content = '''
import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // HomeWidgetBackgroundWorker.setPluginRegistrantCallback is not set yet.
    /* HomeWidgetBackgroundWorker.setPluginRegistrantCallback { _ in } */
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
''';

      final result = await ensure(content);

      expect(
        result,
        contains(
          '    if #available(iOS 17, *) {\n'
          '      HomeWidgetBackgroundWorker.setPluginRegistrantCallback '
          '{ registry in\n',
        ),
      );
      expect(result, contains('import home_widget'));
      expect(
        result,
        contains('FlutterLocalNotificationsPlugin.setPluginRegistrantCallback'),
      );
      verifyNever(() => mockLogger.warn(any()));
    });

    test('does not import home_widget a second time', () async {
      final result = await ensure(
        _appDelegate.replaceFirst('import Flutter\n', 'import home_widget\n'),
      );

      expect('import home_widget'.allMatches(result), hasLength(1));
      expect(result, startsWith('import home_widget\nimport UIKit\n\n@main'));
      expect(result, contains('setPluginRegistrantCallback'));
    });

    test('puts the import at the top of a file without imports', () async {
      const content = '''
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
''';

      final result = await ensure(content);

      expect(result, startsWith('import home_widget\n@main\n'));
      expect(
        result,
        contains(
          '    }\n'
          '    return super.application(application, '
          'didFinishLaunchingWithOptions: launchOptions)\n',
        ),
      );
    });

    test('finds a return wrapped over several lines', () async {
      final result = await ensure(
        _appDelegate.replaceFirst(
          'return super.application(application, '
              'didFinishLaunchingWithOptions: launchOptions)',
          'return super.application(\n'
              '      application,\n'
              '      didFinishLaunchingWithOptions: launchOptions\n'
              '    )',
        ),
      );

      expect(
        result,
        contains(
          '    if #available(iOS 17, *) {\n'
          '      HomeWidgetBackgroundWorker.setPluginRegistrantCallback '
          '{ registry in\n'
          '        GeneratedPluginRegistrant.register(with: registry)\n'
          '      }\n'
          '    }\n'
          '    return super.application(\n',
        ),
      );
    });

    test('warns with the snippet when there is no app delegate', () async {
      await ensureAppDelegatePluginRegistrant(iosDir);

      expect(appDelegate.existsSync(), isFalse);
      final warning = verify(() => mockLogger.warn(captureAny())).captured;
      expect(warning, hasLength(1));
      expect(
        warning.single,
        allOf(
          contains(appDelegate.path),
          contains(appDelegatePluginRegistrant),
          contains('Import home_widget'),
        ),
      );
      verifyNever(() => mockLogger.detail(any()));
    });

    test('warns about a delegate without the return of the launch method',
        () async {
      const content = '''
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return true
  }
}
''';

      final result = await ensure(content);

      expect(result, content);
      verify(
        () => mockLogger.warn(
          any(
            that: allOf(
              contains(appDelegate.path),
              contains(appDelegatePluginRegistrant),
            ),
          ),
        ),
      ).called(1);
      verifyNever(() => mockLogger.detail(any()));
    });

    test('patches the first app directory that has a delegate', () async {
      final renamed = File(p.join(iosDir.path, 'MyApp', 'AppDelegate.swift'))
        ..parent.createSync()
        ..writeAsStringSync(_appDelegate);

      await ensureAppDelegatePluginRegistrant(
        iosDir,
        appDirectories: const ['Runner', 'MyApp'],
      );

      expect(renamed.readAsStringSync(), _patchedAppDelegate);
      expect(appDelegate.existsSync(), isFalse);
      verify(() => mockLogger.detail('Updated: ${renamed.path}')).called(1);
    });

    test('prefers the delegate of the directory listed first', () async {
      appDelegate.writeAsStringSync(_appDelegate);
      final renamed = File(p.join(iosDir.path, 'MyApp', 'AppDelegate.swift'))
        ..parent.createSync()
        ..writeAsStringSync(_appDelegate);

      await ensureAppDelegatePluginRegistrant(
        iosDir,
        appDirectories: const ['Runner', 'MyApp'],
      );

      expect(appDelegate.readAsStringSync(), _patchedAppDelegate);
      expect(renamed.readAsStringSync(), _appDelegate);
    });

    test('names the first directory when none has a delegate', () async {
      await ensureAppDelegatePluginRegistrant(
        iosDir,
        appDirectories: const ['Runner', 'MyApp'],
      );

      verify(
        () => mockLogger.warn(any(that: contains(appDelegate.path))),
      ).called(1);
    });
  });
}
