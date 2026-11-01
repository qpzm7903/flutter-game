import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_game/main.dart';
import 'package:flutter_game/game/game_record.dart';
import 'package:flutter_game/game/match.dart';

Future<void> animate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}
Future<void> menu(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('牌桌菜单'));
  await animate(tester);
  await tester.tap(find.text(label));
  await animate(tester);
}
void main() {
  testWidgets('difficulty is saved and applies after recreating the table', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LandlordApp());
    await tester.pump(const Duration(milliseconds: 100));
    await menu(tester, '难度设置');
    expect(find.text('当前牌局：标准'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<Difficulty>));
    await animate(tester);
    await tester.tap(find.text('轻松').last);
    await animate(tester);
    expect(find.text('当前牌局：标准'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('difficulty'), 'easy');
    await tester.tap(find.text('返回牌桌'));
    await animate(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const LandlordApp());
    await tester.pump(const Duration(milliseconds: 100));
    await menu(tester, '难度设置');
    expect(find.text('当前牌局：轻松'), findsOneWidget);
    await tester.tap(find.text('返回牌桌'));
    await animate(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('history loads valid records and skips damaged entries', (tester) async {
    final record = GameRecord(time: DateTime(2026, 11), landlord: false,
      won: true, score: 6, difficulty: Difficulty.standard);
    SharedPreferences.setMockInitialValues({'history': ['bad', record.encode()]});
    await tester.pumpWidget(const LandlordApp());
    await tester.pump(const Duration(milliseconds: 100));
    await menu(tester, '最近战绩');
    expect(find.text('胜利 · 农民 · 标准'), findsOneWidget);
    expect(find.text('+6 分'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('返回牌桌'));
    await animate(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
