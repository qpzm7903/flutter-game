import 'game/match.dart';
import 'game/practice.dart';
import 'game/game_record.dart';
import 'services/app_log.dart';
import 'services/player_profile.dart';

/// One lifecycle for normal games and practice, including exactly-once settlement.
class GameSession {
  final PlayerProfile profile;
  Match _match;
  Match get match => _match;
  PracticePuzzle? _puzzle;
  PracticePuzzle? get puzzle => _puzzle;
  String get mode => _puzzle?.id ?? 'normal';
  int _generation = 0;
  int get generation => _generation;
  bool _settled = false;
  String get initialMessage => _puzzle?.goal ?? '新牌局开始，请叫分';

  GameSession(this.profile) : _match = Match(difficulty: profile.difficulty);

  void restart() {
    _match = _puzzle?.create() ?? Match(difficulty: profile.difficulty);
    _settled = false;
    _generation++;
    AppLog.info('session start mode=$mode generation=$generation');
  }
  void startPractice(PracticePuzzle puzzle) {
    _puzzle = puzzle;
    restart();
  }
  void startNormal() {
    _puzzle = null;
    restart();
  }
  Future<void> settle() {
    if (_match.phase != Phase.finished || _settled) return Future.value();
    _settled = true;
    AppLog.info('session finish mode=$mode generation=$generation '
      'winner=${_match.winner} landlord=${_match.landlord} won=${_match.humanWon} scores=${_match.scores}');
    if (_puzzle == null) {
      return profile.record(GameRecord(time: DateTime.now(), landlord: _match.landlord == 0,
        won: _match.humanWon, score: _match.scores[0], difficulty: _match.difficulty));
    }
    if (_match.humanWon) return profile.completePuzzle(_puzzle!.id);
    return Future.value();
  }
}
