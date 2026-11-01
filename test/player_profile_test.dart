import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_game/game/difficulty.dart';
import 'package:flutter_game/game/game_record.dart';
import 'package:flutter_game/services/player_profile.dart';

GameRecord result(int minute) => GameRecord(time: DateTime.utc(2026, 11, 1, 0, minute),
  landlord: false, won: true, score: 6, difficulty: Difficulty.easy);

class RecoveringPreferences implements SharedPreferences {
  final Map<String, Object> values = {};
  int attempts = 0;
  @override
  Object? get(String key) => values[key];
  @override
  Future<bool> setString(String key, String value) async {
    if (++attempts == 1) return false;
    values[key] = value;
    return true;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  test('migrates legacy keys into a single coherent snapshot', () async {
    SharedPreferences.setMockInitialValues({'stats': ['6', '2', '1'], 'difficulty': 'easy',
      'history': [result(1).encode()]});
    final prefs = await SharedPreferences.getInstance();
    final profile = await PlayerProfile.load(preferences: prefs);
    expect(profile.totalScore, 6); expect(profile.games, 2); expect(profile.wins, 1);
    expect(profile.difficulty, Difficulty.easy); expect(profile.history.length, 1);
    expect(prefs.getString(PlayerProfile.storageKey), contains('"schema":1'));
    expect(prefs.getStringList('stats'), ['6', '2', '1']);
    expect(() => profile.history.clear(), throwsUnsupportedError);
  });
  test('damaged snapshots recover legacy data and skip invalid records', () async {
    SharedPreferences.setMockInitialValues({PlayerProfile.storageKey: 'not json',
      'stats': ['bad', '-3', '200'], 'difficulty': 'unknown',
      'history': ['bad', ...List.generate(25, (i) => result(i).encode())]});
    final profile = await PlayerProfile.load();
    expect(profile.totalScore, 0); expect(profile.games, 0); expect(profile.wins, 0);
    expect(profile.difficulty, Difficulty.standard); expect(profile.history.length, 20);
    expect(() => GameRecord.decode(jsonEncode({'score': -6, 'won': true})), throwsFormatException);
  });
  test('queued changes retain latest complete state and cap recent history', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = await PlayerProfile.load();
    profile.setDifficulty(Difficulty.easy);
    for (int i = 0; i < 30; i++) { profile.record(result(i)); }
    await profile.flush;
    final restored = await PlayerProfile.load();
    expect(restored.totalScore, 180); expect(restored.games, 30); expect(restored.wins, 30);
    expect(restored.difficulty, Difficulty.easy); expect(restored.history.length, 20);
    expect(restored.history.first.time, result(29).time);
    expect(restored.history.last.time, result(10).time);
  });
  test('failed save preserves memory and the next write can recover', () async {
    final prefs = RecoveringPreferences();
    final profile = await PlayerProfile.load(preferences: prefs);
    expect(profile.saveError, isNotNull);
    await profile.record(result(1));
    expect(profile.saveError, isNull); expect(profile.games, 1);
    final restored = await PlayerProfile.load(preferences: prefs);
    expect(restored.games, 1); expect(restored.history.single.score, 6);
  });
}
