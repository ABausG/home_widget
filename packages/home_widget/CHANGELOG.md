## 0.8.0

> Note: This release has breaking changes.

 - **FEAT**: Configurable WIdgets support for iOS ([#348](https://github.com/abausg/home_widget/issues/348)). ([e8809d89](https://github.com/abausg/home_widget/commit/e8809d89c15348cb3ded7769278add51ce4b2379))
 - **FEAT**: Add triggeredFromHomeWidget flag to updateWidget on Android ([#315](https://github.com/abausg/home_widget/issues/315)). ([dc2b9302](https://github.com/abausg/home_widget/commit/dc2b9302c30e6690f1f084e4fad2b1041a1d8c88))
 - **BREAKING** **FEAT**: Default to the device pixel ratio ([#304](https://github.com/abausg/home_widget/issues/304)). ([90522de3](https://github.com/abausg/home_widget/commit/90522de374d5411842e84031453756eeec25ac9e))
 - **BREAKING** **CHORE**: Enable strong language analyzer ([#305](https://github.com/abausg/home_widget/issues/305)). ([1b5df0b3](https://github.com/abausg/home_widget/commit/1b5df0b36e0ccf0c0ffef234faf0ed8731f9ade4))

## 0.7.0+1

 - **FIX**: Runtime error when starting App from Widget on Android 15 ([#330](https://github.com/abausg/home_widget/issues/330)). ([64a38eb3](https://github.com/abausg/home_widget/commit/64a38eb39fb6ef20342ac2a5eaf5c9bedf2e6c75))
 - **DOCS**: Move Documentation to docs.page ([#287](https://github.com/abausg/home_widget/issues/287)). ([52ee746a](https://github.com/abausg/home_widget/commit/52ee746ad1d1dd9ef2aa9f1c61e482825f73d9d9))
 - **DOCS**: Improve pubspec metadata ([#283](https://github.com/abausg/home_widget/issues/283)). ([f23c63e8](https://github.com/abausg/home_widget/commit/f23c63e8d393708aaf197ccb54b391d81a765a19))

## 0.7.0

 - **DOCS**: Move Documentation to docs.page ([#287](https://github.com/abausg/home_widget/issues/287)). ([52ee746a](https://github.com/abausg/home_widget/commit/52ee746ad1d1dd9ef2aa9f1c61e482825f73d9d9))
 - **DOCS**: Improve pubspec metadata ([#283](https://github.com/abausg/home_widget/issues/283)). ([f23c63e8](https://github.com/abausg/home_widget/commit/f23c63e8d393708aaf197ccb54b391d81a765a19))
 - **FIX**: Fix iOS Background Worker ([#244](https://github.com/abausg/home_widget/issues/244)). ([bb4895c](https://github.com/abausg/home_widget/commit/bb4895c5273fdb15858df544427ce03308ddd790))
 - **FIX**: Fix storing Long on Android ([#280](https://github.com/abausg/home_widget/issues/280)). ([284cd51](https://github.com/abausg/home_widget/commit/284cd5120a1bbc8cca837742882e8c10465ba567))

## 0.6.0
* Require Flutter 3.20+ due to changes in `ViewConfiguration`

## 0.5.0
**Breaking Changes**
* The package now uses a library pattern so you should only import `'package:home_widget/home_widget.dart'`

**New Features**
* Jetpack Glance Support
* Support `requestPinWidget` on Android
* Support getting Information about Widgets Users have currently added to their Home and Lock Screens
* Support saving `Uint8List` on iOS

**Fixes**
* iOS Background Work not working when App was fully closed
* Launching the App on Android 14+
* iOS not compiling when using interactive Widgets with Flutter 3.19+

## 0.4.1
* Fix First Background on iOS being ignored by [mchudy](https://github.com/mchudy) in [#188](https://github.com/ABausG/home_widget/pull/188)

## 0.4.0
* Add support for Interactive Widgets on iOS
* Rename `registerBackgroundCallback` to `registerInteractivityCallback`
* Restructure README

## 0.3.1
* fix: Fix Null Pointer when Saving `renderFlutterWidget` by [milindgoel15](https://github.com/milindgoel15) in [#182](https://github.com/ABausG/home_widget/pull/182)
* fix: Update Gradle to 8 by [milindgoel15](https://github.com/milindgoel15) in [#155](https://github.com/ABausG/home_widget/pull/155)
* docs: Fix syntax error in readme code example by [mattrltrent](https://github.com/mattrltrent) in [#154](https://github.com/ABausG/home_widget/pull/154)
* fix: Handle null check on Android when checking CallbackInformation by [eliasto](https://github.com/eliasto) in [#172](https://github.com/ABausG/home_widget/pull/172)

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
* Fix Issues relating to `initiallyLaunchedFromHomeWidget`
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
