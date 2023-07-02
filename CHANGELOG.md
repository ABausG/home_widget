## 0.3.0
* Add `renderFlutterWidget` method to save a Flutter Widget as an Image [#126](https://github.com/ABausG/home_widget/pull/126) by [leighajarett](https://github.com/leighajarett)

## 0.2.1
* Update Gradle and Kotlin Versions
* Update to support Flutter 3.10

## 0.2.0+1
* Fix example annotation [#115](https://github.com/ABausG/home_widget/pull/115) by [ColinSchmale](https://github.com/ColinSchmale)

## 0.2.0
* Fix missing `@pragma("vm:entry-point")` for Background Callbacks [#99](https://github.com/ABausG/home_widget/pull/99) by [linziyou0601](https://github.com/linziyou0601)
* Update HomeWidgetBackgroundService.kt [#98](https://github.com/ABausG/home_widget/pull/98) by [roly151](https://github.com/roly151)
* README Improvements by [aaronkelton](https://github.com/aaronkelton) and [hadysata](https://github.com/hadysata)

## 0.1.6

* Allow the specification of fully qualified android name [#62](https://github.com/ABausG/home_widget/pull/62) by [NicolaVerbeeck](https://github.com/NicolaVerbeeck)

### Fixes
* Fix paths in README [#73](https://github.com/ABausG/home_widget/pull/73) by [AndyRusso](https://github.com/AndyRusso)
* Migrate example to Android embedding v2 [#80](https://github.com/ABausG/home_widget/pull/80) by [ronnieeeeee](https://github.com/ronnieeeeee)
* Fix onNewIntent in Flutter 3 [#84](https://github.com/ABausG/home_widget/pull/84) by [josepedromonteiro](https://github.com/josepedromonteiro) and [
stepushchik-denis-gismart](https://github.com/stepushchik-denis-gismart)

## 0.1.5

* Fix MissingPluginException for `registerBackgroundCallback` on iOS [#39](https://github.com/ABausG/home_widget/issues/39)

## 0.1.4

* Fix `HomeWidget.updateWidget` not completing on iOS [#26](https://github.com/ABausG/home_widget/issues/26)
* Fix casting Error on Registering Background Callback [#31](https://github.com/ABausG/home_widget/pull/31) by [aljkor](https://github.com/aljkor)
* Fix collision for Deeplinks [#42](https://github.com/ABausG/home_widget/pull/42) by [mgonzalezc](https://github.com/mgonzalezc)
* Make Android PendingIntents immutable for Android 12 [#49](https://github.com/ABausG/home_widget/pull/49) by [mgonzalezc](https://github.com/mgonzalezc)
* Update Gradle Versions and target Android SDK 31
* Fix Issues rrelating to `initiallyLaunchedFromHomeWidget`
  * [#48](https://github.com/ABausG/home_widget/issues/48) Call not completing on iOS
  * [#40](https://github.com/ABausG/home_widget/issues/40) Cast exception on Android for cases launched from Widget but without data Uri

## 0.1.3

* Add GitHub Actions, Tests and Integration Tests to ensure further quality
* Fix double and null handling on Android
* Fix HomeWidget.updateWidget not completing on Android [#26](https://github.com/ABausG/home_widget/issues/26)

## 0.1.2+1

* Fix [#19](https://github.com/ABausG/home_widget/issues/19) Receiver not registered bug

## 0.1.2

* Add Click Listeners
  * Detect if App has been launched via a view from the HomeScreen Widget
  * Execute Background Dart Code when clicking on a view in HomeScreen Widget [Android only]

## 0.1.1+2

* Set sdk bound correctly
* Workaround for analysis_options import error
* Cleanup Example

## 0.1.1+1

* Also allow older Flutter Versions

## 0.1.1

* Flutter 2

## 0.1.0+1

* More general Dart SDK Fixes Pub Score
* Add Pub Score and Like Badges

## 0.1.0

* Migrate HomeWidget to nullsafety.

## 0.0.2

* Background Updates
  * Add Paragraph on explaining background updates
  * Extend example to include background updates using [flutter_workmanager](https://pub.dev/packages/workmanager)

## 0.0.1+4

* Use absolute Image path to show images on pub.dev

## 0.0.1+3

* Compressed iOS and Android demo images in Readme (#16)
* Add README Entry to sync CFBundleVersion (#13)
* Format Examples into table (#10)
* Fix Build Error (#12)

## 0.0.1+2

* Add more documentation to README

## 0.0.1+1

* Add Images to README

## 0.0.1

* Initial Release of HomeWidget
