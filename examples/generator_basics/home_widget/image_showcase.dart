import 'package:home_widget_generator/home_widget_generator.dart';

/// Image demo combining every way of getting an image into a widget.
///
/// - `HWImage.asset` renders a bundled Flutter asset, read straight out of the
///   app bundle with nothing to save.
/// - `HWImage(HWImageData('picture'))` renders an image the app saves at
///   runtime via `saveData(picture: ...)`. Until that happens the
///   `HWDataExists` branch shows a placeholder text.
/// - `HWImage(HWTimedData(HWImageData('slide')))` renders one image per
///   timestamp: the app hands `saveData(timedData: {...})` an `ImageProvider`
///   for each slot and the widget swaps them on its own.
/// - `HWImage(HWJson('contact', HWImageData('avatar')))` reads the image out of
///   a JSON group, so a name and a picture travel together in one
///   `saveData(contact: ...)` call.
@HomeWidget(
  name: 'Image Showcase',
  description: 'A bundled asset logo plus images saved by the app.',
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWFill(
    child: HWPadding(
      padding: HWEdgeInsets.all(8),
      child: HWColumn(
        mainAxisAlignment: HWMainAxisAlignment.center,
        crossAxisAlignment: HWCrossAxisAlignment.center,
        children: [
          HWImage.asset(
            'assets/logo.png',
            width: 24,
            height: 24,
            semanticLabel: 'App logo',
          ),
          HWDataExists(
            data: HWImageData('picture'),
            whenPresent: HWImage(
              HWImageData('picture'),
              width: 64,
              height: 64,
              fit: HWImageFit.cover,
              semanticLabel: 'Picture saved by the app',
            ),
            whenAbsent: HWText.fixed(
              'Open the app to pick an image',
              style: HWRoleTextStyle(
                role: HWTextStyleRole.caption,
                color: HWDefaultColor(HWColorRole.contentSecondary),
              ),
            ),
          ),
          HWRow(
            mainAxisAlignment: HWMainAxisAlignment.center,
            crossAxisAlignment: HWCrossAxisAlignment.center,
            children: [
              HWImage(
                HWTimedData(HWImageData('slide')),
                width: 28,
                height: 28,
                fit: HWImageFit.contain,
                semanticLabel: 'Picture for the current time slot',
              ),
              HWImage(
                HWJson('contact', HWImageData('avatar')),
                width: 28,
                height: 28,
                fit: HWImageFit.cover,
                semanticLabel: 'Contact avatar',
              ),
              HWText(
                HWJson('contact', HWString('name', defaultValue: '')),
                style: HWRoleTextStyle(role: HWTextStyleRole.caption),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
)
class ImageShowcase {}
