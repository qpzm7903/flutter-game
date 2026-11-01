import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/game/cards.dart';
import 'package:flutter_game/game/match.dart';

List<PlayingCard> cards(List<int> ranks) {
  final used = <int, int>{};
  return ranks.map((r) {
    final index = used.update(r, (v) => v + 1, ifAbsent: () => 0);
    return PlayingCard(r >= 16 ? r + 36 : (r - 3) * 4 + index);
  }).toList();
}
void main() {
  test('recognizes every classic combination', () {
    final cases = <HandType, List<int>>{
      HandType.single: [3], HandType.pair: [4,4], HandType.triple: [5,5,5],
      HandType.tripleSingle: [3,3,3,8], HandType.triplePair: [3,3,3,8,8],
      HandType.straight: [10,11,12,13,14], HandType.pairs: [3,3,4,4,5,5],
      HandType.plane: [3,3,3,4,4,4], HandType.planeSingles: [3,3,3,4,4,4,8,8],
      HandType.planePairs: [3,3,3,4,4,4,8,8,9,9],
      HandType.fourSingles: [3,3,3,3,8,8], HandType.fourPairs: [3,3,3,3,8,8,9,9],
      HandType.bomb: [3,3,3,3], HandType.rocket: [16,17],
    };
    for (final c in cases.entries) { expect(classify(cards(c.value))?.type, c.key); }
  });
  test('rejects illegal wings, duplicate cards and sequences containing 2', () {
    for (final ranks in [[11,12,13,14,15], [3,3,4,4], [3,3,3,3,16,17],
      [3,3,3,4,4,4,16,17], [3,3,3,3,4,4,4,8], [3,3,3,4,4,4,8,8,8,8]]) {
      expect(classify(cards(ranks)), isNull, reason: '$ranks');
    }
    expect(classify([const PlayingCard(0), const PlayingCard(0)]), isNull);
  });
  test('bomb ordering and equal-length sequence comparison', () {
    final bomb = classify(cards([3,3,3,3]))!;
    final rocket = classify(cards([16,17]))!;
    expect(bomb.beats(classify(cards([15]))), isTrue);
    expect(rocket.beats(bomb), isTrue);
    expect(bomb.beats(rocket), isFalse);
    expect(rocket.beats(rocket), isFalse);
    expect(classify(cards([4,5,6,7,8,9]))!.beats(classify(cards([3,4,5,6,7]))), isFalse);
  });
  test('ambiguous airplane can respond as airplane with single wings', () {
    final hand = cards([4,4,4,5,5,5,6,6,6,7,7,7]);
    final target = classify(cards([3,3,3,4,4,4,5,5,5,8,9,10]))!;
    expect(classify(hand)?.type, HandType.plane);
    expect(classify(hand, target: target)?.type, HandType.planeSingles);
    expect(classify(hand, target: target)!.beats(target), isTrue);
    expect(legalMoves(hand, target).any((m) => m.length == hand.length), isTrue);
  });
  test('move ranking prefers long normal leads and preserves bombs', () {
    final moves = legalMoves(cards([3,4,5,6,7,9,9,9,9,16,17]), null);
    expect(classify(moves.first)!.type, HandType.straight);
    final types = moves.map((m) => classify(m)!.type).toList();
    expect(types.last, HandType.rocket);
    expect(types[types.length - 2], HandType.bomb);
    expect(moves.map((m) => (m.map((c) => c.id).toList()..sort()).join(',')).toSet().length, moves.length);
  });
  test('responses prefer lowest matching card before special hands', () {
    final target = classify(cards([6]))!;
    final moves = legalMoves(cards([7,10,10,10,10,16,17]), target);
    expect(moves.first.single.rank, 7);
    expect(classify(moves.last)!.type, HandType.rocket);
    expect(moves.every((m) => classify(m, target: target)!.beats(target)), isTrue);
  });
  test('deals unique cards and grants landlord bottom cards', () {
    final m = Match(random: Random(7));
    expect({...m.hands.expand((h) => h), ...m.bottom}.length, 54);
    expect(m.bid(1, 3), isFalse);
    expect(m.bid(0, 3), isTrue);
    expect(m.hands[0].length, 20);
    expect(m.turn, 0);
    expect(m.phase, Phase.playing);
  });
  test('all pass redeals; bidding must increase', () {
    final m = Match(random: Random(1));
    m.bid(0, 0); m.bid(1, 0); m.bid(2, 0);
    expect(m.phase, Phase.bidding); expect(m.deals, 2); expect(m.turn, 1);
    m.bid(1, 2); expect(m.bid(2, 1), isFalse);
    m.bid(2, 0); m.bid(0, 0); expect(m.landlord, 1);
  });
  test('two passes restore free lead and cannot pass free lead', () {
    final m = Match(random: Random(2))..bid(0, 3);
    expect(m.pass(0), isFalse);
    expect(m.play(0, [m.hands[0].last]), isNull);
    expect(m.pass(1), isTrue); expect(m.pass(2), isTrue);
    expect(m.turn, 0); expect(m.target, isNull); expect(m.table, isEmpty);
    expect(m.pass(0), isFalse);
  });
  test('spring and reverse spring scores are zero sum', () {
    for (final landlordWins in [true, false]) {
      final m = Match(random: Random(2))..bid(0, 3);
      m.hands = [cards([3]), cards([4]), cards([5])];
      if (!landlordWins) { m.turn = 1; m.playedTurns[0] = 1; }
      final player = landlordWins ? 0 : 1;
      m.play(player, [...m.hands[player]]);
      expect(m.spring, isTrue); expect(m.multiplier, 2);
      expect(m.scores.reduce((a,b) => a+b), 0);
      expect(m.scores[0], landlordWins ? 12 : -12);
    }
  });
  test('suggestions only use owned cards and complete seeded matches', () {
    for (int seed = 0; seed < 50; seed++) {
      final m = Match(random: Random(seed));
      int steps = 0;
      while (m.phase != Phase.finished && steps++ < 500) {
        if (m.phase == Phase.playing) {
          final move = m.suggest(m.turn, cooperate: true);
          if (move.isNotEmpty) {
            expect(move.every(m.hands[m.turn].contains), isTrue);
            expect(classify(move, target: m.target)!.beats(m.target), isTrue);
          } else { expect(m.target, isNotNull); }
        }
        m.computerStep();
      }
      expect(m.phase, Phase.finished, reason: 'seed $seed after $steps steps');
      expect(m.scores.reduce((a,b) => a+b), 0);
    }
  });
}
