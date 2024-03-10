import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget_info.dart';

void main() {
  group('HomeWidgetInfo', () {
    test('fromMap constructs HomeWidgetInfo object from map', () {
      final data = {
        'family': 'medium',
        'kind': 'anotherKind',
        'widgetId': 1,
        'androidClassName': 'com.example.AnotherWidget',
        'label': 'Another Widget',
      };

      final info = HomeWidgetInfo.fromMap(data);

      expect(info.family, 'medium');
      expect(info.kind, 'anotherKind');
      expect(info.androidClassName, 'com.example.AnotherWidget');
      expect(info.label, 'Another Widget');
    });

    test('HomeWidgetInfo toString', () {
      final homeWidgetInfo = HomeWidgetInfo(
        family: 'systemSmall',
        kind: 'ParkingWidget',
        widgetId: 1,
        androidClassName: 'com.example.MyWidget',
        label: 'My Widget',
      );

      expect(
        homeWidgetInfo.toString(),
        'HomeWidgetInfo{family: systemSmall, kind: ParkingWidget, widgetId: 1, androidClassName: com.example.MyWidget, label: My Widget}',
      );
    });
  });
}
