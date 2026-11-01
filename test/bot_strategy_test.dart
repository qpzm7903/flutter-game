import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/game/match.dart';

void main() {
  test('unrevealed opponent cards cannot change a response', () {
    for (int seed = 0; seed < 20; seed++) {
      final match = Match(random: Random(seed))..bid(0, 3);
      match.play(0, [match.hands[0].last]);
      final own = [...match.hands[1]];
      final before = match.suggest(1).map((c) => c.id).toList();
      final pool = [...match.hands[0], ...match.hands[2]]..shuffle(Random(seed + 50));
      final length = match.hands[0].length;
      match.hands[0] = pool.sublist(0, length);
      match.hands[2] = pool.sublist(length);
      expect(match.suggest(1).map((c) => c.id).toList(), before);
      expect(match.hands[1], own);
    }
  });
  test('bidding depends only on own cards and current public bid', () {
    final match = Match(random: Random(5));
    final before = match.computerBid(0);
    final pool = [...match.hands[1], ...match.hands[2]]..shuffle(Random(10));
    match.hands[1] = pool.sublist(0, 17); match.hands[2] = pool.sublist(17);
    expect(match.computerBid(0), before);
  });
}
