import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';

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

      expect(info.iOSFamily, 'medium');
      expect(info.iOSKind, 'anotherKind');
      expect(info.androidClassName, 'com.example.AnotherWidget');
      expect(info.androidLabel, 'Another Widget');
    });

    test('HomeWidgetInfo toString', () {
      final homeWidgetInfo = HomeWidgetInfo(
        iOSFamily: 'systemSmall',
        iOSKind: 'ParkingWidget',
        androidWidgetId: 1,
        androidClassName: 'com.example.MyWidget',
        androidLabel: 'My Widget',
      );

      expect(
        homeWidgetInfo.toString(),
        'HomeWidgetInfo{iOSFamily: systemSmall, iOSKind: ParkingWidget, androidWidgetId: 1, androidClassName: com.example.MyWidget, androidLabel: My Widget}',
      );
    });

    test('HomeWidgetInfo equality', () {
      final info1 = HomeWidgetInfo(
        iOSFamily: 'medium',
        iOSKind: 'anotherKind',
        androidWidgetId: 1,
        androidClassName: 'com.example.AnotherWidget',
        androidLabel: 'Another Widget',
      );

      final info2 = HomeWidgetInfo(
        iOSFamily: 'medium',
        iOSKind: 'anotherKind',
        androidWidgetId: 1,
        androidClassName: 'com.example.AnotherWidget',
        androidLabel: 'Another Widget',
      );

      final info3 = HomeWidgetInfo(
        iOSFamily: 'systemSmall',
        iOSKind: 'ParkingWidget',
        androidWidgetId: 1,
        androidClassName: 'com.example.MyWidget',
        androidLabel: 'My Widget',
      );

      expect(info1 == info2, true);
      expect(info1.hashCode, equals(info2.hashCode));
      expect(info1 == info3, false);
      expect(info1.hashCode, isNot(equals(info3.hashCode)));
    });
  });
}
