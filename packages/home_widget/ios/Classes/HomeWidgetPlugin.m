#import "HomeWidgetPlugin.h"
#if __has_include(<home_widget/home_widget-Swift.h>)
#import <home_widget/home_widget-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "home_widget-Swift.h"
#endif

@implementation HomeWidgetPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftHomeWidgetPlugin registerWithRegistrar:registrar];
}
@end
