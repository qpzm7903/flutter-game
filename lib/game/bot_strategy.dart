import 'cards.dart';

/// Own cards and publicly visible information are the complete strategy input.
int chooseBid(List<PlayingCard> hand, int currentBid) {
    final groups = groupCards(hand);
    final strength = hand.where((c) => c.rank >= 15).length +
        groups.values.where((v) => v.length == 4).length * 2;
    final score = strength >= 5 ? 3 : strength >= 4 ? 2 : strength >= 2 ? 1 : 0;
    return score > currentBid ? score : 0;
}

List<PlayingCard> chooseMove({required List<PlayingCard> hand, required Combination? target,
  required int player, required int landlord, required int lastPlayer, required List<int> counts,
  bool cooperate = false, bool simple = false}) {
    final moves = legalMoves(hand, target);
    if (moves.isEmpty) return [];
    // Decide using own cards and public roles/counts only; never inspect an opponent's cards.
    final winning = moves.where((m) => m.length == hand.length);
    if (winning.isNotEmpty) return winning.first;
    if (simple && target == null) {
      final singles = moves.where((m) => m.length == 1).toList()
        ..sort((a, b) => a.single.rank.compareTo(b.single.rank));
      return singles.first;
    }
    if (cooperate && target != null && player != landlord && lastPlayer != landlord) return [];
    if (target?.type == HandType.single &&
        List.generate(3, (i) => i).any((i) => i != player && counts[i] == 1 &&
            (i == landlord || player == landlord))) {
      final singles = moves.where((m) => classify(m)!.type == HandType.single).toList();
      if (singles.isNotEmpty) return singles.last;
    }
    return moves.first;
}
