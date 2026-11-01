import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_game/main.dart';
import 'package:flutter_game/services/player_profile.dart';

Future<void> animate(WidgetTester tester) async {
  await tester.pump(); await tester.pump(const Duration(milliseconds: 400)); await tester.pump();
}
void main() {
  testWidgets('practice can be solved, retried and left without changing ordinary stats', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LandlordApp()); await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('牌桌菜单')); await animate(tester);
    await tester.tap(find.text('残局练习')); await animate(tester);
    await tester.tap(find.text('顺子收官')); await animate(tester);
    expect(find.text('残局练习 · 顺子收官'), findsOneWidget);
    await tester.ensureVisible(find.text('提示')); await tester.tap(find.text('提示')); await tester.pump();
    await tester.ensureVisible(find.text('出牌 (5)')); await tester.tap(find.text('出牌 (5)')); await tester.pump();
    expect(find.text('挑战成功'), findsOneWidget);
    expect(find.textContaining('本机战绩 0 胜 / 0 局'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString(PlayerProfile.storageKey), contains('straight'));
    await tester.ensureVisible(find.text('再练一次')); await tester.tap(find.text('再练一次')); await tester.pump();
    expect(find.text('5 张'), findsOneWidget);
    await tester.ensureVisible(find.text('返回普通牌局')); await tester.tap(find.text('返回普通牌局')); await tester.pump();
    expect(find.text('3 分'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
