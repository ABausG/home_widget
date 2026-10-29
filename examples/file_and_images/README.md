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

**Preview** — [`FileWidgetHomeWidget.kt`](android/app/src/main/kotlin/es/antonborri/file_and_images/FileWidgetHomeWidget.kt), [`FileWidgetHomeWidgetReceiver.kt`](android/app/src/main/kotlin/es/antonborri/file_and_images/FileWidgetHomeWidgetReceiver.kt), see [`docs/features/widget-previews.mdx`](../../docs/features/widget-previews.mdx):

```kotlin
override suspend fun providePreview(context: Context, widgetCategory: Int) {
  provideContent {
    WidgetContent(HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)), preview = true)
  }
}
```

The receiver's `previewFingerprint` includes the saved path and its `lastModified()`, so rewriting the file re-registers the preview.

On iOS the same fallback lives in `getSnapshot`, which WidgetKit calls with `context.isPreview`.
