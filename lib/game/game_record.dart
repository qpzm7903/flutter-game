import 'dart:convert';
import 'match.dart';

class GameRecord {
  final DateTime time;
  final bool landlord;
  final bool won;
  final int score;
  final Difficulty difficulty;
  const GameRecord({required this.time, required this.landlord, required this.won,
    required this.score, required this.difficulty});
  String encode() => jsonEncode({'time': time.toIso8601String(), 'landlord': landlord,
    'won': won, 'score': score, 'difficulty': difficulty.name});
  factory GameRecord.decode(String text) {
    final data = jsonDecode(text) as Map<String, dynamic>;
    return GameRecord(time: DateTime.parse(data['time'] as String), landlord: data['landlord'] as bool,
      won: data['won'] as bool, score: data['score'] as int,
      difficulty: Difficulty.values.byName(data['difficulty'] as String));
  }
}
