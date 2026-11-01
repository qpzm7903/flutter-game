import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/difficulty.dart';
import '../game/game_record.dart';
import 'app_log.dart';

/// Owns legacy migration, data recovery, retention and ordered atomic snapshots.
class PlayerProfile {
  static const storageKey = 'profile.v1';
  final SharedPreferences? _preferences;
  int _totalScore = 0, _games = 0, _wins = 0;
  int get totalScore => _totalScore;
  int get games => _games;
  int get wins => _wins;
  Difficulty _difficulty = Difficulty.standard;
  Difficulty get difficulty => _difficulty;
  final List<GameRecord> _history = [];
  List<GameRecord> get history => List.unmodifiable(_history);
  Future<void> _pending = Future.value();
  Future<void> get flush => _pending;
  Object? saveError;
  PlayerProfile.memory() : _preferences = null;
  PlayerProfile._(this._preferences);

  static Future<PlayerProfile> load({SharedPreferences? preferences}) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final profile = PlayerProfile._(prefs);
      Map<String, dynamic>? snapshot;
      final raw = prefs.get(storageKey);
      if (raw is String) {
        try {
          final data = jsonDecode(raw);
          if (data is! Map<String, dynamic> || data['schema'] != 1) {
            throw const FormatException('Invalid profile schema');
          }
          snapshot = data;
        } catch (e, s) { AppLog.error(e, s); }
      }
      final legacy = prefs.get('stats');
      final stats = legacy is List<String> && legacy.length == 3 ? legacy : ['0', '0', '0'];
      int number(Object? value) => value is int ? value : value is String ? int.tryParse(value) ?? 0 : 0;
      profile._totalScore = number(snapshot == null ? stats[0] : snapshot['score']);
      profile._games = number(snapshot == null ? stats[1] : snapshot['games']);
      if (profile.games < 0) profile._games = 0;
      profile._wins = number(snapshot == null ? stats[2] : snapshot['wins']).clamp(0, profile.games);
      final choice = snapshot == null ? prefs.get('difficulty') : snapshot['difficulty'];
      profile._difficulty = Difficulty.values.firstWhere((d) => d.name == choice, orElse: () => Difficulty.standard);
      final records = snapshot == null ? prefs.get('history') : snapshot['history'];
      if (records is List) {
        for (final record in records) {
          if (profile._history.length == 20) break;
          try {
            profile._history.add(GameRecord.decode(record as String));
          } catch (e, s) { AppLog.error(e, s); }
        }
      }
      // Migration does not delete legacy data until a valid new snapshot exists.
      if (snapshot == null) await profile._save();
      return profile;
    } catch (e, s) {
      AppLog.error(e, s);
      return PlayerProfile.memory()..saveError = e;
    }
  }

  Future<void> setDifficulty(Difficulty value) {
    _difficulty = value;
    return _save();
  }
  Future<void> record(GameRecord result) {
    _totalScore += result.score;
    _games++;
    if (result.won) _wins++;
    _history.insert(0, result);
    if (_history.length > 20) _history.removeRange(20, _history.length);
    return _save();
  }
  Future<void> _save() {
    final snapshot = jsonEncode({'schema': 1, 'score': totalScore, 'games': games, 'wins': wins,
      'difficulty': difficulty.name, 'history': _history.map((r) => r.encode()).toList()});
    _pending = _pending.then((_) async {
      if (_preferences == null) throw StateError('Local storage unavailable');
      if (!await _preferences.setString(storageKey, snapshot)) throw StateError('Profile save failed');
      saveError = null;
    }).catchError((Object e, StackTrace s) { saveError = e; AppLog.error(e, s); });
    return _pending;
  }
}
