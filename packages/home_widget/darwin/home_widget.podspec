#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint home_widget.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'home_widget'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'home_widget/Sources/home_widget/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '14.0'
  s.osx.deployment_target = '11.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.ios.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.osx.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  # Xcode 26 workaround: disable explicit modules for app targets that import home_widget
  # (e.g., widget extensions) to avoid "module 'Flutter' not found" errors
  s.ios.user_target_xcconfig = { 'SWIFT_ENABLE_EXPLICIT_MODULES' => 'NO' }
  s.swift_version = '5.0'
end
