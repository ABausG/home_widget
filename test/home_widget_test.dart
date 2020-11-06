import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';

void main() {
  const channel = MethodChannel('home_widget');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return 'Test';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getTest', () async {
    expect(await HomeWidget.getWidgetData('GetTest'), 'Test');
  });
}
