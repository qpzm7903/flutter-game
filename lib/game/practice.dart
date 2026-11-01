import 'cards.dart';
import 'match.dart';

class PracticePuzzle {
  final String id, title, goal;
  final List<List<int>> ranks;
  final List<int> tableRanks;
  final int landlord, lastPlayer;
  const PracticePuzzle({required this.id, required this.title, required this.goal,
    required this.ranks, this.tableRanks = const [], this.landlord = 0, this.lastPlayer = -1});

  Match create() {
    final used = <int, int>{};
    PlayingCard card(int rank) {
      final count = used.update(rank, (n) => n + 1, ifAbsent: () => 0);
      if (rank < 3 || rank > 17 || count >= (rank > 15 ? 1 : 4)) {
        throw ArgumentError('Invalid practice cards');
      }
      return PlayingCard(rank > 15 ? rank + 36 : (rank - 3) * 4 + count);
    }
    final hands = ranks.map((hand) => hand.map(card).toList()).toList();
    final table = tableRanks.map(card).toList();
    return Match.position(hands: hands, landlord: landlord, table: table, lastPlayer: lastPlayer);
  }
}

const practicePuzzles = [
  PracticePuzzle(id: 'straight', title: '顺子收官', goal: '你是地主，先手把牌一次出完。',
    ranks: [[3,4,5,6,7], [8], [9]]),
  PracticePuzzle(id: 'bomb', title: '炸弹夺权', goal: '桌上是大于所有普通单张的 2。夺回出牌权，再处理小牌。',
    ranks: [[9,9,9,9,3], [14], [5]], tableRanks: [15], lastPlayer: 2),
  PracticePuzzle(id: 'team', title: '队友接力', goal: '你是农民，队友刚出了 A。让队友保住出牌权，赢下这一局。',
    ranks: [[3,5,16], [13], [4]], tableRanks: [14], landlord: 1, lastPlayer: 2),
];
