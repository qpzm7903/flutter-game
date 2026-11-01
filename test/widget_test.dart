import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_game/main.dart';

void main() {
  for (final size in [const Size(320, 720), const Size(360, 800), const Size(800, 600), const Size(1400, 900)]) {
    testWidgets('table fits $size and supports human bid', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const LandlordApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('闲庭斗地主'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('3 分'));
      await tester.tap(find.text('3 分'));
      await tester.pump();
      expect(find.textContaining('· 地主'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
