# Home Widget

[![Pub](https://img.shields.io/pub/v/home_widget.svg)](https://pub.dartlang.org/packages/home_widget)
[![likes](https://badges.bar/home_widget/likes)](https://pub.dev/packages/home_widget/score)
[![popularity](https://badges.bar/home_widget/popularity)](https://pub.dev/packages/home_widget/score)
[![pub points](https://badges.bar/home_widget/pub%20points)](https://pub.dev/packages/home_widget/score) 

HomeWidget is a Plugin to make it easier to create HomeScreen Widgets on Android and iOS.
HomeWidget does **not** allow writing Widgets with Flutter itself. It still requires writing the Widgets with native code. However it provides a unified Interface for sending data, retrieving data and updating the Widgets

| iOS | Android |
| ----- | ----- |
| <img src="https://github.com/ABausG/home_widget/blob/main/.github/assets/demo_ios.png?raw=true" width="500px"> | <img src="https://github.com/ABausG/home_widget/blob/main/.github/assets/demo_android.png?raw=true" width="608px">|

## Platform Setup
As stated there needs to be some platform specific setup. Check below on how to add support for Android and iOS

<details><summary>Android</summary>

### Create Widget Layout inside `android/app/res/layout`

### Create Widget Configuration into `android/app/res/xml`
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
For convenience you can extend from [HomeWidgetProvider](android/src/main/kotlin/es/antonborri/home_widget/HomeWidgetProvider.kt) which gives you access to a SharedPreferences Object with the Data in the `onUpdate` method.
If you don't want to use the convenience Method you can access the Data using
```kotlin
import es.antonborri.home_widget.HomeWidgetPlugin
...
HomeWidgetPlugin.getData(context)
```
which will give you access to the same SharedPreferences

### More Information
For more Information on how to create and configure Android Widgets checkout (https://developer.android.com/guide/topics/appwidgets)[this guide] on the Android Developers Page.

</details>

<details><summary>iOS</summary>

### Add a Widget to your App in Xcode
Add a widget extension by going `File > Target > Widget Extension`

![Widget Extension](https://github.com/ABausG/home_widget/blob/main/.github/assets/widget_extension.png?raw=true)


### Add GroupId
You need to add a groupId to the App and the Widget Extension

**Note: in order to add groupIds you need a paid Apple Developer Account**

Go to your [Apple Developer Account](https://developer.apple.com/account/resources/identifiers/list/applicationGroup) and add a new group
Add this group to you Runner and the Widget Extension inside XCode `Signing & Capabilities > App Groups > +`

![Build Targets](https://github.com/ABausG/home_widget/blob/main/.github/assets/target.png?raw=true)

(To swap between your App and the Extension change the Target)

### Sync CFBundleVersion (optional)
This step is optional, this will sync the widget extension build version with your app version so you don't get warnings of mismatch version from App Store Connect when uploading your app.

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
Check the [Example App](example/ios/HomeWidgetExample/HomeWidgetExample.swift) for an Implementation of a Widget
A more detailed overview on how to write Widgets for iOS 14 can fbe found on the [Apple Developer documentation](https://developer.apple.com/documentation/swiftui/widget)
In order to access the Data send with Flutter can be access with
```swift
let data = UserDefaults.init(suiteName:"YOUR_GROUP_ID")
```
</details>

## Usage

### Setup
For iOS you need to call `HomeWidget.setAppGroupId('YOUR_GROUP_ID');`
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
);
```

The name for Android will be chosen by checking `androidName` if that was not provided it will fallback to `name`.
This Name needs to be equal to the Classname of the [WidgetProvider](#-write-your-widgetprovider)

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
To detect if the App was initially started by clicking the Widget you can call `HomeWidget.initiallyLaunchedFromHomeWidget()` if the App was already running in the Background you can receive these Events by listening to `HomeWidget.widgetClicked`. Both methods will provide Uris so you can easily send back data from the Widget to the App to for example navigate to a content page.

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
    void backgroundCallback(Uri data) {
      // do something with data
      ...
    }
    ```
5. Register the callback function by calling
    ```dart
    HomeWidget.registerBackgroundCallback(backgroundCallback);
    ```