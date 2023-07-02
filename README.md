# Home Widget

[![Pub](https://img.shields.io/pub/v/home_widget.svg)](https://pub.dartlang.org/packages/home_widget)
[![likes](https://img.shields.io/pub/likes/home_widget)](https://pub.dev/packages/home_widget/score)
[![popularity](https://img.shields.io/pub/popularity/home_widget)](https://pub.dev/packages/home_widget/score)
[![pub points](https://img.shields.io/pub/points/home_widget)](https://pub.dev/packages/home_widget/score)
[![Build](https://github.com/abausg/home_widget/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/ABausG/home_widget/actions/workflows/main.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/ABausG/home_widget/branch/main/graph/badge.svg?token=ZXTZOL6KFO)](https://codecov.io/gh/ABausG/home_widget)

HomeWidget is a Plugin to make it easier to create HomeScreen Widgets on Android and iOS.
HomeWidget does **not** allow writing Widgets with Flutter itself. It still requires writing the Widgets with native code. However, it provides a unified Interface for sending data, retrieving data and updating the Widgets

| iOS                                                                                                            |  Android                                                                                                           |
|----------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| <img src="https://github.com/ABausG/home_widget/blob/main/.github/assets/demo_ios.png?raw=true" width="500px"> | <img src="https://github.com/ABausG/home_widget/blob/main/.github/assets/demo_android.png?raw=true" width="608px"> |

## Platform Setup
In order to work correctly there needs to be some platform specific setup. Check below on how to add support for Android and iOS

<details><summary>Android</summary>

### Create Widget Layout inside `android/app/src/main/res/layout`

### Create Widget Configuration into `android/app/src/main/res/xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="40dp"
    android:minHeight="40dp"
    android:updatePeriodMillis="86400000"
    android:initialLayout="@layout/example_layout"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen">
</appwidget-provider>
```

### Add WidgetReceiver to AndroidManifest
```xml
<receiver android:name="HomeWidgetExampleProvider" >
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
        android:resource="@xml/home_widget_example" />
</receiver>
```

### Write your WidgetProvider
For convenience, you can extend from [HomeWidgetProvider](android/src/main/kotlin/es/antonborri/home_widget/HomeWidgetProvider.kt) which gives you access to a SharedPreferences Object with the Data in the `onUpdate` method.
In case you don't want to use the convenience Method you can access the Data using
```kotlin
import es.antonborri.home_widget.HomeWidgetPlugin
...
HomeWidgetPlugin.getData(context)
```
which will give you access to the same SharedPreferences

### More Information
For more Information on how to create and configure Android Widgets, check out [this guide](https://developer.android.com/develop/ui/views/appwidgets) on the Android Developers Page.

</details>

<details><summary>iOS</summary>

### Add a Widget to your App in Xcode
Add a widget extension by going `File > New > Target > Widget Extension`

![Widget Extension](https://github.com/ABausG/home_widget/blob/main/.github/assets/widget_extension.png?raw=true)


### Add GroupId
You need to add a groupId to the App and the Widget Extension

**Note: in order to add groupIds you need a paid Apple Developer Account**

Go to your [Apple Developer Account](https://developer.apple.com/account/resources/identifiers/list/applicationGroup) and add a new group
Add this group to you Runner and the Widget Extension inside XCode `Signing & Capabilities > App Groups > +`

![Build Targets](https://github.com/ABausG/home_widget/blob/main/.github/assets/target.png?raw=true)

(To swap between your App, and the Extension change the Target)

### Sync CFBundleVersion (optional)
This step is optional, this will sync the widget extension build version with your app version, so you don't get warnings of mismatch version from App Store Connect when uploading your app.

![Build Phases](https://github.com/ABausG/home_widget/blob/main/.github/assets/build_phases.png?raw=true)

In your Runner (app) target go to `Build Phases > + > New Run Script Phase` and add the following script:
```bash
generatedPath="$SRCROOT/Flutter/Generated.xcconfig"
versionNumber=$(grep FLUTTER_BUILD_NAME $generatedPath | cut -d '=' -f2)
buildNumber=$(grep FLUTTER_BUILD_NUMBER $generatedPath | cut -d '=' -f2)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "$SRCROOT/HomeExampleWidget/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $versionNumber" "$SRCROOT/HomeExampleWidget/Info.plist"
```

Replace `HomeExampleWidget` with the name of the widget extension folder that you have created.


### Write your Widget
Check the [Example App](example/ios/HomeWidgetExample/HomeWidgetExample.swift) for an Implementation of a Widget.
A more detailed overview on how to write Widgets for iOS 14 can be found on the [Apple Developer documentation](https://developer.apple.com/documentation/swiftui/widget).
In order to access the Data send with Flutter can be access with
```swift
let data = UserDefaults.init(suiteName:"YOUR_GROUP_ID")
```
</details>

## Usage

### Setup
For iOS, you need to call `HomeWidget.setAppGroupId('YOUR_GROUP_ID');`
Without this you won't be able to share data between your App and the Widget and calls to `saveWidgetData` and `getWidgetData` will return an error

### Save Data
In order to save Data call `HomeWidget.saveWidgetData<String>('id', data)`

### Update a Widget
In order to force a reload of the HomeScreenWidget you need to call
```dart
HomeWidget.updateWidget(
    name: 'HomeWidgetExampleProvider',
    androidName: 'HomeWidgetExampleProvider',
    iOSName: 'HomeWidgetExample',
    qualifiedAndroidName: 'com.example.app.HomeWidgetExampleProvider',
);
```

The name for Android will be chosen by checking `qualifiedAndroidName`, falling back to `<packageName>.androidName` and if that was not provided it 
will fallback to `<packageName>.name`.
This Name needs to be equal to the Classname of the [WidgetProvider](#Write-your-Widget)

The name for iOS will be chosen by checking `iOSName` if that was not provided it will fallback to `name`.
This name needs to be equal to the Kind specified in you Widget

### Retrieve Data
To retrieve the current Data saved in the Widget call `HomeWidget.getWidgetData<String>('id', defaultValue: data)`

### Background Update
As the methods of HomeWidget are static it is possible to use HomeWidget in the background to update the Widget even when the App is in the background.

The example App is using the [flutter_workmanager](https://pub.dev/packages/workmanager) plugin to achieve this.
Please follow the Setup Instructions for flutter_workmanager (or your preferred background code execution plugin). Most notably make sure that Plugins get registered in iOS in order to be able to communicate with the HomeWidget Plugin.
In case of flutter_workmanager this achieved by adding:
```swift
WorkmanagerPlugin.setPluginRegistrantCallback { registry in
    GeneratedPluginRegistrant.register(with: registry)
}
```
to [AppDelegate.swift](example/ios/Runner/AppDelegate.swift)

### Clicking
To detect if the App has been initially started by clicking the Widget you can call `HomeWidget.initiallyLaunchedFromHomeWidget()` if the App was already running in the Background you can receive these Events by listening to `HomeWidget.widgetClicked`. Both methods will provide Uris, so you can easily send back data from the Widget to the App to for example navigate to a content page.

In order for these methods to work you need to follow these steps:

#### iOS
Add `.widgetUrl` to your WidgetComponent
```swift
Text(entry.message)
    .font(.body)
    .widgetURL(URL(string: "homeWidgetExample://message?message=\(entry.message)&homeWidget"))
```
In order to only detect Widget Links you need to add the queryParameter`homeWidget` to the URL

#### Android
Add an `IntentFilter` to the `Activity` Section in your `AndroidManifest`
```
<intent-filter>
    <action android:name="es.antonborri.home_widget.action.LAUNCH" />
</intent-filter>
```

In your WidgetProvider add a PendingIntent to your View using `HomeWidgetLaunchIntent.getActivity`
```kotlin
val pendingIntentWithData = HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse("homeWidgetExample://message?message=$message"))
setOnClickPendingIntent(R.id.widget_message, pendingIntentWithData)
```

### Background Click

Android allows interactive elements in HomeScreenWidgets. This allows to for example add a refresh button on a widget.
With home_widget you can use this by following these steps:

#### Android/Native Part
1. Add the necessary Receiver and Service to you `AndroidManifest.xml` file
    ```
   <receiver android:name="es.antonborri.home_widget.HomeWidgetBackgroundReceiver">
        <intent-filter>
            <action android:name="es.antonborri.home_widget.action.BACKGROUND" />
        </intent-filter>
    </receiver>
    <service android:name="es.antonborri.home_widget.HomeWidgetBackgroundService"
        android:permission="android.permission.BIND_JOB_SERVICE" android:exported="true"/>
   ```
2. Add a `HomeWidgetBackgroundIntent.getBroadcast` PendingIntent to the View you want to add a click listener to
    ```kotlin
    val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
        context,
        Uri.parse("homeWidgetExample://titleClicked")
    )
    setOnClickPendingIntent(R.id.widget_title, backgroundIntent)
    ```

#### Dart
4. Write a **static** function that takes a Uri as an argument. This will get called when a user clicks on the View
    ```dart
    @pragma("vm:entry-point")
    void backgroundCallback(Uri data) {
      // do something with data
      ...
    }
    ```
   `@pragma('vm:entry-point')` must be placed above the `callback` function to avoid tree shaking in release mode for Android.

5. Register the callback function by calling
    ```dart
    HomeWidget.registerBackgroundCallback(backgroundCallback);
    ```
    
### Using images of Flutter widgets

In some cases, you may not want to rewrite UI code in the native frameworks for your widgets. 
For example, say you have a chart in your Flutter app configured with `CustomPaint`:

```dart
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LineChartPainter(),
      child: const SizedBox(
        height: 200,
        width: 200,
      ),
    );
  }
}
```

<img width="300" alt="Screenshot 2023-06-07 at 12 33 44 PM" src="https://github.com/ABausG/home_widget/assets/21065911/55619584-bc85-4e7e-9fad-17afde2f74df">

Rewriting the code to create this chart on both Android and iOS might be time consuming. 
Instead, you can generate a png file of the Flutter widget and save it to a shared container 
between your Flutter app and the home screen widget. 

```dart
var path = await HomeWidget.renderFlutterWidget(
  const LineChart(),
  key: 'lineChart',
  logicalSize: Size(width: 400, height: 400),
);
```
- `LineChart()` is the widget that will be rendered as an image.
- `key` is the key in the key/value storage on the device that stores the path of the file for easy retrieval on the native side

#### iOS 
To retrieve the image and display it in a widget, you can use the following SwiftUI code:

1. In your `TimelineEntry` struct add a property to retrieve the path:
    ```swift
    struct MyEntry: TimelineEntry {
        …
        let lineChartPath: String
    }
    ```

2. Get the path from the `UserDefaults` in `getSnapshot`:
    ```swift
   func getSnapshot(
        ...
        let lineChartPath = userDefaults?.string(forKey: "lineChart") ?? "No screenshot available"
    ```
3. Create a `View` to display the chart and resize the image based on the `displaySize` of the widget:
    ```swift
    struct WidgetEntryView : View {
      …
       var ChartImage: some View {
            if let uiImage = UIImage(contentsOfFile: entry.lineChartPath) {
                let image = Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: entry.displaySize.height*0.5, height: entry.displaySize.height*0.5, alignment: .center)
                return AnyView(image)
            }
            print("The image file could not be loaded")
            return AnyView(EmptyView())
        }
    …
    }
    ```
    
4. Display the chart in the body of the widget's `View`:
    ```swift
    VStack {
            Text(entry.title)
            Text(entry.description)
            ChartImage
        }
    ```

<img width="522" alt="Screenshot 2023-06-07 at 12 57 28 PM" src="https://github.com/ABausG/home_widget/assets/21065911/f7dcdea0-605a-4662-a03a-158831a4e946">

#### Android

1. Add an image UI element to your xml file:
    ```xml
    <ImageView
           android:id="@+id/widget_image"
           android:layout_width="200dp"
           android:layout_height="200dp"
           android:layout_below="@+id/headline_description"
           android:layout_alignBottom="@+id/headline_title"
           android:layout_alignParentStart="true"
           android:layout_alignParentLeft="true"
           android:layout_marginStart="8dp"
           android:layout_marginLeft="8dp"
           android:layout_marginTop="6dp"
           android:layout_marginBottom="-134dp"
           android:layout_weight="1"
           android:adjustViewBounds="true"
           android:background="@android:color/white"
           android:scaleType="fitCenter"
           android:src="@android:drawable/star_big_on"
           android:visibility="visible"
           tools:visibility="visible" />
    ```
2. Update your Kotlin code to get the chart image and put it into the widget, if it exists.
    ```kotlin
    class NewsWidget : AppWidgetProvider() {
       override fun onUpdate(
           context: Context,
           appWidgetManager: AppWidgetManager,
           appWidgetIds: IntArray,
       ) {
           for (appWidgetId in appWidgetIds) {
               // Get reference to SharedPreferences
               val widgetData = HomeWidgetPlugin.getData(context)
               val views = RemoteViews(context.packageName, R.layout.news_widget).apply {
                   // Get chart image and put it in the widget, if it exists
                   val imagePath = widgetData.getString("lineChart", null)
                   val imageFile = File(imagePath)
                   val imageExists = imageFile.exists()
                   if (imageExists) {
                      val myBitmap: Bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                      setImageViewBitmap(R.id.widget_image, myBitmap)
                   } else {
                      println("image not found!, looked @: $imagePath")
                   }
                   // End new code
               }
               appWidgetManager.updateAppWidget(appWidgetId, views)
           }
       }
    }
    ```
