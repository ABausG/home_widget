# home_widget_generator

## Idea for home_widget_generator

home_widget_generator should be a package that works in combination with home_widget_cli to create easy to use HomeScreenWidgets for Flutter Apps

## Basic Usage

`example_widget.dart`

```dart

import 'package:home_widget_generator/home_widget_generator.dart'
part 'example_widget.home_widget.dart';

@homeWidget(
    /// Required Name of Widget
    name: 'Example Widget',
    /// Optional Map of Data Home Widget supports with the respective Data
    /// Will generate helper methods to update widget with new data for the given fields
    data: {
        HWData.string('countLabel'),
        HWData.int('count'),
    },
    /// Android Configuration. With options (optional) to configure the generated Widget Configuration  
    android: HomeWidgetAndroidConfiguration(
        packageName: 'es.antonborri.examleWidget',
        minWidth: '12dp'
        maxWidth: '40dp',
        ...
    ),
    /// Android Configuration. With options (optional) to configure the generated Widget Configuration  
    iOS: HomeWidgetIOSConfiguration(
        groupId: 'group.es.antonborri.example',
        supportedFamilies: [
            // Enum Map of Available iOS Families
        ],
    )
    /// Optional Static Tearoff for interactivity callback
    interactivityCallback: interactiveWidgetCallback,
)
class ExampleWidget with _$ExampleWidgetHomeWidget {

    /// If this is added by a user this will generate Swift/Kotlin Code of the Widget when the home_widget_cli is invoked
     static HomeWidgetWidgetBuilder<ExampleWidget> widgetBuilder(ExampleWidgetHomeWidgetData data) => HomeWidgetWidgetBuilder(
        /// Column, Text, Button etc should be dedicated HomeWidgetGeneratorWidgets coming from Home Widget
        child: Column(
            children: [
                Text(
                    data.countLabel,
                ),
                Text(
                    // Provide way to format data from HomeWidget Data
                    data.count.formatted
                ),
                Button.icon(
                    // Figure out a way to map Icons for both platforms matching best practices on how to get system icons
                    android: 'R.id.plus',
                    iOS: 'add',
                    /// Uri that will invoke the interactivityCallback provided through the annotation
                    callbackUri: Uri('addButton')
                )
            ]
        )
    )
}
```

## Generated Code

### Dart

Generate the according `file_name.home_widget.dart` file. In there write methods/extensions to:
- Init Widget (iOS Group, Interactivity callback etc) automatically
- Update Widget Data (based on Widget Data)
- Update Widget (should also be done automatic from Widget Data)
- Get Installed Widget Data

### iOS

- Use `home_widget_cli` to generate valid iOS Widget Configurations based on iOS Configuration from Annotation
- Entry should have proper data based on the data provided
- If widgetBuilder is provided translate the custom HomeWidgetWidgets into valid SwiftUI Code.

### Android
- Use `home_widget_cli` to generate valid Android Widget Code from Annotation
- Create a helper data class matching the defined data structure
- If widgetBuilder is provided translate the custom HomeWidgetWidgets into valid SwiftUI Code.

## HomeWidgetWidget

Part of the Magic of home_widget_generator should be that Developers should be able to write HomeScreenWidgetCode with a Flutter like syntax. For that the HomeWidgetWidgetBuilder should be used to translate these Widgets into valid SwiftUI/Jetpack Glance code.

HomeWidgetWidgetBuilder should thus probably have builder methods to `generateSwiftUI` and `generateJetpackGlance` based on their configurations.

In the very first version I think a quite rudimentary set of widgets as well as small sets of customization options is good. This should be easily extendable in the future.

Widgets I think should be in the first version:

- Column / Row
- Text (no styling yet. Maybe Text Align?)
- Button.icon, Button.label (Potentially later (adding interactivity later may be fine))
- Container
   - Allow for Size
   - Color