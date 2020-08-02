import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeroconf/zeroconf.dart';

void main() {
  const MethodChannel channel = MethodChannel('zeroconf');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await Zeroconf.platformVersion, '42');
  });
}
