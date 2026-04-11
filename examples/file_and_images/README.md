# File and images

A simple demo app showing how to save images and files from Flutter and access the data from native widgets.

**Flutter (save)** — [`lib/main.dart`](lib/main.dart):

```dart
await HomeWidget.saveImage(_imageKey, imageProvider);
await HomeWidget.saveWidgetData(_imageTypeKey, imageType.name);
```

```dart
await HomeWidget.saveFile(
  _fileJsonKey,
  Uint8List.fromList(utf8.encode(json)),
  extension: 'json',
);
```

**Android (path → file)** — [`ImageWidgetHomeWidget.kt`](android/app/src/main/kotlin/es/antonborri/file_and_images/ImageWidgetHomeWidget.kt), [`FileWidgetHomeWidget.kt`](android/app/src/main/kotlin/es/antonborri/file_and_images/FileWidgetHomeWidget.kt):

```kotlin
val imagePath = prefs.getString(IMAGE_KEY, null)
BitmapFactory.decodeFile(imagePath)  // after `File(path).isFile` check
```

```kotlin
val jsonPath = prefs.getString(FILE_JSON_KEY, null)
File(jsonPath).readText(Charsets.UTF_8)  // when path exists and is a file
```

**iOS (path → file)** — [`ImageWidgetHomeWidget/Widget.swift`](ios/ImageWidgetHomeWidget/Widget.swift), [`FileWidgetHomeWidget/Widget.swift`](ios/FileWidgetHomeWidget/Widget.swift):

```swift
UserDefaults(suiteName: appGroupId)?.string(forKey: imageKey)  // then UIImage(contentsOfFile:)
```

```swift
UserDefaults(suiteName: appGroupId)?.string(forKey: fileJsonKey)  // then Data(contentsOf: URL(fileURLWithPath:))
```
