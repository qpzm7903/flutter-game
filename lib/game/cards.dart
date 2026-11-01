class PlayingCard {
  final int id;
  const PlayingCard(this.id) : assert(id >= 0 && id < 54);
  int get rank => id < 52 ? id ~/ 4 + 3 : id - 36;
  String get label => const {11: 'J', 12: 'Q', 13: 'K', 14: 'A', 15: '2', 16: '小王', 17: '大王'}[rank] ?? '$rank';
  String get suit => id < 52 ? const ['♠', '♥', '♣', '♦'][id % 4] : '王';
  bool get red => id == 53 || (id < 52 && id.isOdd);
  @override
  bool operator ==(Object other) => other is PlayingCard && id == other.id;
  @override
  int get hashCode => id;
}

void sortCards(List<PlayingCard> cards) => cards.sort((a, b) => b.id.compareTo(a.id));

enum HandType {
  single('单张'), pair('对子'), triple('三张'), tripleSingle('三带一'),
  triplePair('三带一对'), straight('顺子'), pairs('连对'), plane('飞机'),
  planeSingles('飞机带单'), planePairs('飞机带对'), fourSingles('四带二'),
  fourPairs('四带两对'), bomb('炸弹'), rocket('王炸');
  const HandType(this.label);
  final String label;
}

class Combination {
  final HandType type;
  final int rank;
  final int length;
  const Combination(this.type, this.rank, this.length);
  bool beats(Combination? other) {
    if (other == null) return true;
    if (other.type == HandType.rocket) return false;
    if (type == HandType.rocket) return true;
    if (type == HandType.bomb && other.type != HandType.bomb) return true;
    return type == other.type && length == other.length && rank > other.rank;
  }
}

Map<int, List<PlayingCard>> groupCards(Iterable<PlayingCard> cards) {
  final groups = <int, List<PlayingCard>>{};
  for (final c in cards) { (groups[c.rank] ??= []).add(c); }
  return groups;
}

Combination? classify(List<PlayingCard> cards, {Combination? target}) {
  final primary = _classifyDefault(cards);
  if (primary == null || target == null || primary.beats(target)) return primary;
  // Four consecutive triples can also be three triples with three single wings.
  // During a response, select a valid interpretation matching the table's shape.
  if (target.type == HandType.planeSingles && cards.length == target.length && cards.length % 4 == 0) {
    final groups = groupCards(cards);
    final count = cards.length ~/ 4;
    if (count >= 2 && !(groups.containsKey(16) && groups.containsKey(17))) {
      for (int end = 14; end >= count + 2; end--) {
        if (List.generate(count, (i) => end - i).every((rank) => groups[rank]?.length == 3)) {
          final candidate = Combination(HandType.planeSingles, end, cards.length);
          if (candidate.beats(target)) return candidate;
        }
      }
    }
  }
  return primary;
}

Combination? _classifyDefault(List<PlayingCard> cards) {
  final n = cards.length;
  if (n == 0 || cards.toSet().length != n) return null;
  final g = groupCards(cards);
  final ranks = g.keys.toList()..sort();
  Combination result(HandType t, int rank) => Combination(t, rank, n);
  if (n == 2 && g.containsKey(16) && g.containsKey(17)) return result(HandType.rocket, 17);
  if (g.length == 1) {
    final t = {1: HandType.single, 2: HandType.pair, 3: HandType.triple, 4: HandType.bomb}[n];
    return t == null ? null : result(t, ranks.single);
  }
  bool run(int count, int minRanks) => ranks.length >= minRanks && ranks.last <= 14 &&
      ranks.last - ranks.first + 1 == ranks.length && g.values.every((v) => v.length == count);
  if (run(1, 5)) return result(HandType.straight, ranks.last);
  if (run(2, 3)) return result(HandType.pairs, ranks.last);
  if (run(3, 2)) return result(HandType.plane, ranks.last);
  for (final r in ranks) {
    final size = g[r]!.length;
    if (size == 3) {
      if (n == 4) return result(HandType.tripleSingle, r);
      if (n == 5 && g.length == 2) return result(HandType.triplePair, r);
    }
    if (size == 4) {
      if (n == 6 && !(g.containsKey(16) && g.containsKey(17))) return result(HandType.fourSingles, r);
      if (n == 8 && g.length == 3 && g.entries.where((e) => e.key != r).every((e) => e.value.length == 2)) {
        return result(HandType.fourPairs, r);
      }
    }
  }
  for (final unit in [4, 5]) {
    if (n % unit != 0 || n ~/ unit < 2) continue;
    final k = n ~/ unit;
    for (int end = 14; end >= 3 + k - 1; end--) {
      final body = {for (int r = end - k + 1; r <= end; r++) r};
      if (!body.every((r) => g[r]?.length == 3)) continue;
      final wings = g.entries.where((e) => !body.contains(e.key)).toList();
      if (unit == 4 && !(g.containsKey(16) && g.containsKey(17))) return result(HandType.planeSingles, end);
      if (unit == 5 && wings.length == k && wings.every((e) => e.value.length == 2)) return result(HandType.planePairs, end);
    }
  }
  return null;
}

/// Enumerates rank-level patterns rather than the 2^20 subsets of a hand.
List<List<PlayingCard>> legalMoves(List<PlayingCard> hand, Combination? target) {
  final groups = groupCards(hand);
  final ranks = groups.keys.toList()..sort();
  final found = <String, List<PlayingCard>>{};
  void add(List<PlayingCard> cards) {
    final shape = classify(cards, target: target);
    if (shape == null || !shape.beats(target)) return;
    final ids = cards.map((c) => c.id).toList()..sort();
    found[ids.join(',')] = cards;
  }
  void attach(List<PlayingCard> body, int amount, bool pairs) {
    final bodyRanks = body.map((c) => c.rank).toSet();
    final options = ranks.where((r) => !bodyRanks.contains(r) && (!pairs || groups[r]!.length >= 2)).toList();
    void visit(int index, int left, List<PlayingCard> wings) {
      if (left == 0) { add([...body, ...wings]); return; }
      if (index >= options.length) return;
      final available = groups[options[index]]!;
      final maxTake = pairs ? 1 : (available.length < left ? available.length : left);
      for (int take = 0; take <= maxTake && take <= left; take++) {
        visit(index + 1, left - take, [...wings, ...available.take(pairs ? take * 2 : take)]);
      }
    }
    visit(0, amount, []);
  }
  for (final r in ranks) {
    final g = groups[r]!;
    for (int n = 1; n <= g.length; n++) { add(g.take(n).toList()); }
    if (g.length >= 3) {
      attach(g.take(3).toList(), 1, false);
      attach(g.take(3).toList(), 1, true);
    }
    if (g.length == 4) { attach(g, 2, false); attach(g, 2, true); }
  }
  if (groups.containsKey(16) && groups.containsKey(17)) add([groups[16]!.first, groups[17]!.first]);
  for (int unit = 1; unit <= 3; unit++) {
    final minimum = unit == 1 ? 5 : unit == 2 ? 3 : 2;
    for (int start = 3; start <= 14; start++) {
      final body = <PlayingCard>[];
      for (int end = start; end <= 14; end++) {
        if ((groups[end]?.length ?? 0) < unit) break;
        body.addAll(groups[end]!.take(unit));
        final count = end - start + 1;
        if (count < minimum) continue;
        add([...body]);
        if (unit == 3) { attach(body, count, false); attach(body, count, true); }
      }
    }
  }
  final moves = found.values.toList();
  moves.sort((a, b) {
    final x = classify(a, target: target)!, y = classify(b, target: target)!;
    int cost(Combination c) => c.type == HandType.rocket ? 2 : c.type == HandType.bomb ? 1 : 0;
    final special = cost(x).compareTo(cost(y));
    if (special != 0) return special;
    if (target == null && a.length != b.length) return b.length.compareTo(a.length);
    return x.rank.compareTo(y.rank);
  });
  return moves;
}
