# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-05-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`home_widget` - `v0.9.2`](#home_widget---v092)

---

#### `home_widget` - `v0.9.2`

 - **FIX**: Add FlutterFramework to iOS SPM package ([#419](https://github.com/abausg/home_widget/issues/419)). ([85aa4bf2](https://github.com/abausg/home_widget/commit/85aa4bf2f56feddf1b8d4c6f6a3954363308317d))
 - **FIX**: Support Android Gradle Plugin 9.x ([#420](https://github.com/abausg/home_widget/issues/420)). ([cb2b4ad5](https://github.com/abausg/home_widget/commit/cb2b4ad530da0a599b283cd109fa01d928dae662))
 - **FIX**: Pin android dependency versions to prevent pre-release pickup ([#418](https://github.com/abausg/home_widget/issues/418)). ([e42f1f7c](https://github.com/abausg/home_widget/commit/e42f1f7cf53f23b0e2e2092463a2ef22f67b6d57))
 - **FEAT**: Support passing appGroupId directly with functions ([#416](https://github.com/abausg/home_widget/issues/416)). ([55e6f435](https://github.com/abausg/home_widget/commit/55e6f435cb573a570a524d662d2f2d0bd2c50f43))


## 2026-04-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`home_widget` - `v0.9.1`](#home_widget---v091)

---

#### `home_widget` - `v0.9.1`

 - **FEAT**: Configurable widgets for Android ([#396](https://github.com/abausg/home_widget/issues/396)). ([faf16897](https://github.com/abausg/home_widget/commit/faf16897d6667b54799c61fa714eec9247dda1c9))
 - **FEAT**: Add support for `HomeWidget.saveFile` and `HomeWidget.saveImage` ([#409](https://github.com/abausg/home_widget/issues/409)). ([bf965fbf](https://github.com/abausg/home_widget/commit/bf965fbf37e3d14aeb32077184897025014d994f))


## 2026-01-04

### Changes

---

Packages with breaking changes:

 - [`home_widget` - `v0.9.0`](#home_widget---v090)

Packages with other changes:

 - There are no other changes in this release.

---

#### `home_widget` - `v0.9.0`

 - **FIX**: Fix Xcode 26 support for interactive Widgets ([#391](https://github.com/abausg/home_widget/issues/391)). ([35047c6a](https://github.com/abausg/home_widget/commit/35047c6af5f2847652a51eb760c0d2ff70953259))
 - **FIX**: Fix iOS Widget Updating using only `name` parameter ([#381](https://github.com/abausg/home_widget/issues/381)). ([77919dbb](https://github.com/abausg/home_widget/commit/77919dbb464c238149cb7662c9c8bfd47b7f11f9))
 - **BREAKING** **FIX**: Add missing package name to HomeWidget Glance files ([#365](https://github.com/abausg/home_widget/issues/365)). ([caf6a1fe](https://github.com/abausg/home_widget/commit/caf6a1fe4d120b3b26b2b6d7aa1b008420790365))
 - **BREAKING** **FEAT**: Add support for Swift Package Manager ([#393](https://github.com/abausg/home_widget/issues/393)). ([8d3c1ddf](https://github.com/abausg/home_widget/commit/8d3c1ddf4c7b383d4b2028160771828eb9a0033e))
 - **BREAKING** **CHORE**: Upgrade to melos 7.0.0 ([#382](https://github.com/abausg/home_widget/issues/382)). ([66bffb17](https://github.com/abausg/home_widget/commit/66bffb17909890c3a70050488725d75c8aee46db))


## 2025-10-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`home_widget` - `v0.8.1`](#home_widget---v081)

---

#### `home_widget` - `v0.8.1`

 - **FIX**: Use WorkManager for Interactivity on Android. Improves reliability of clicks ([#361](https://github.com/abausg/home_widget/issues/361)). ([b25f8733](https://github.com/abausg/home_widget/commit/b25f87336913844d92ba6484c3516680beb6a3a2))


## 2025-05-25

### Changes

---

Packages with breaking changes:

 - [`home_widget` - `v0.8.0`](#home_widget---v080)

Packages with other changes:

 - There are no other changes in this release.

---

#### `home_widget` - `v0.8.0`

 - **FEAT**: Configurable Widgets support for iOS ([#348](https://github.com/abausg/home_widget/issues/348)). ([e8809d89](https://github.com/abausg/home_widget/commit/e8809d89c15348cb3ded7769278add51ce4b2379))
 - **FEAT**: Add triggeredFromHomeWidget flag to updateWidget on Android ([#315](https://github.com/abausg/home_widget/issues/315)). ([dc2b9302](https://github.com/abausg/home_widget/commit/dc2b9302c30e6690f1f084e4fad2b1041a1d8c88))
 - **BREAKING** **FEAT**: Default to the device pixel ratio ([#304](https://github.com/abausg/home_widget/issues/304)). ([90522de3](https://github.com/abausg/home_widget/commit/90522de374d5411842e84031453756eeec25ac9e))
 - **BREAKING** **CHORE**: Enable strong language analyzer ([#305](https://github.com/abausg/home_widget/issues/305)). ([1b5df0b3](https://github.com/abausg/home_widget/commit/1b5df0b36e0ccf0c0ffef234faf0ed8731f9ade4))


## 2025-02-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`home_widget` - `v0.7.0+1`](#home_widget---v0701)

---

#### `home_widget` - `v0.7.0+1`

 - **FIX**: Runtime error when starting App from Widget on Android 15 ([#330](https://github.com/abausg/home_widget/issues/330)). ([64a38eb3](https://github.com/abausg/home_widget/commit/64a38eb39fb6ef20342ac2a5eaf5c9bedf2e6c75))
 - **DOCS**: Move Documentation to docs.page ([#287](https://github.com/abausg/home_widget/issues/287)). ([52ee746a](https://github.com/abausg/home_widget/commit/52ee746ad1d1dd9ef2aa9f1c61e482825f73d9d9))
 - **DOCS**: Improve pubspec metadata ([#283](https://github.com/abausg/home_widget/issues/283)). ([f23c63e8](https://github.com/abausg/home_widget/commit/f23c63e8d393708aaf197ccb54b391d81a765a19))


## 2024-08-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`home_widget` - `v0.7.0`](#home_widget---v070)

---

#### `home_widget` - `v0.7.0`

 - **DOCS**: Move Documentation to docs.page ([#287](https://github.com/abausg/home_widget/issues/287)). ([52ee746a](https://github.com/abausg/home_widget/commit/52ee746ad1d1dd9ef2aa9f1c61e482825f73d9d9))
 - **DOCS**: Improve pubspec metadata ([#283](https://github.com/abausg/home_widget/issues/283)). ([f23c63e8](https://github.com/abausg/home_widget/commit/f23c63e8d393708aaf197ccb54b391d81a765a19))

