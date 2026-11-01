import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_game/main.dart';

Future<void> animate(WidgetTester tester) async {
  await tester.pump(); await tester.pump(const Duration(milliseconds: 400)); await tester.pump();
}
Future<void> playBomb(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const LandlordApp()); await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byTooltip('牌桌菜单')); await animate(tester);
  await tester.tap(find.text('残局练习')); await animate(tester);
  await tester.tap(find.text('炸弹夺权')); await animate(tester);
  await tester.ensureVisible(find.text('提示')); await tester.tap(find.text('提示')); await tester.pump();
  await tester.ensureVisible(find.text('出牌 (4)')); await tester.tap(find.text('出牌 (4)')); await tester.pump();
}
void main() {
  testWidgets('background pauses pending bot turns and resume continues once', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await playBomb(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('阿竹正在思考…'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pump(const Duration(milliseconds: 850));
    expect(find.text('轮到你自由出牌，不能不出'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('leaving practice cancels pending bot actions for the previous game', (tester) async {
    await playBomb(tester);
    await tester.ensureVisible(find.text('返回普通牌局')); await tester.tap(find.text('返回普通牌局')); await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('3 分'), findsOneWidget);
    expect(find.textContaining('本机战绩 0 胜 / 0 局'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
