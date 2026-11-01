import 'dart:math';
import 'cards.dart';
import 'difficulty.dart';
import 'bot_strategy.dart';
export 'difficulty.dart';


enum Phase { bidding, playing, finished }

class Match {
  final Random random;
  final Difficulty difficulty;
  List<List<PlayingCard>> hands = [[], [], []];
  List<PlayingCard> bottom = [];
  final List<String> actions = ['', '', ''];
  final List<int> playedTurns = [0, 0, 0];
  Phase phase = Phase.bidding;
  int turn = 0, landlord = -1, highestBid = 0, bidsMade = 0, bidder = -1;
  int passes = 0, multiplier = 1, winner = -1, lastPlayer = -1;
  List<PlayingCard> table = [];
  Combination? target;
  bool spring = false;
  int deals = 0;
  Match({Random? random, this.difficulty = Difficulty.standard}) : random = random ?? Random() { deal(); }

  void deal() {
    final deck = List.generate(54, PlayingCard.new)..shuffle(random);
    hands = List.generate(3, (i) => deck.sublist(i * 17, i * 17 + 17));
    for (final h in hands) { sortCards(h); }
    bottom = deck.sublist(51);
    phase = Phase.bidding;
    turn = deals++ % 3;
    landlord = bidder = winner = lastPlayer = -1;
    highestBid = bidsMade = passes = 0;
    multiplier = 1;
    spring = false;
    table = [];
    target = null;
    for (int i = 0; i < 3; i++) { actions[i] = ''; playedTurns[i] = 0; }
  }

  bool bid(int player, int score) {
    if (phase != Phase.bidding || turn != player || score < 0 || score > 3 ||
        (score > 0 && score <= highestBid)) { return false; }
    actions[player] = score == 0 ? '不叫' : '叫 $score 分';
    if (score > highestBid) { highestBid = score; bidder = player; }
    bidsMade++;
    if (score == 3 || bidsMade == 3) {
      if (bidder == -1) { deal(); return true; }
      landlord = bidder;
      hands[landlord].addAll(bottom);
      sortCards(hands[landlord]);
      phase = Phase.playing;
      turn = landlord;
      for (int i = 0; i < 3; i++) { actions[i] = ''; }
    } else {
      turn = (turn + 1) % 3;
    }
    return true;
  }

  int computerBid(int player) {
    return chooseBid(hands[player], highestBid);
  }

  String? play(int player, List<PlayingCard> cards) {
    if (phase != Phase.playing || turn != player) return '请等待你的回合';
    if (cards.isEmpty) return '请先选择要出的牌';
    if (!cards.every(hands[player].contains) || cards.toSet().length != cards.length) return '所选手牌无效';
    final shape = classify(cards, target: target);
    if (shape == null) return '这些牌不能组成有效牌型';
    if (!shape.beats(target)) return '请出同牌型更大的牌，或使用炸弹';
    hands[player].removeWhere(cards.contains);
    playedTurns[player]++;
    table = [...cards]..sort((a, b) => a.id.compareTo(b.id));
    target = shape;
    lastPlayer = player;
    passes = 0;
    actions[player] = shape.type.label;
    if (shape.type == HandType.bomb || shape.type == HandType.rocket) multiplier *= 2;
    if (hands[player].isEmpty) {
      winner = player;
      phase = Phase.finished;
      spring = player == landlord
          ? List.generate(3, (i) => i).where((i) => i != landlord).every((i) => playedTurns[i] == 0)
          : playedTurns[landlord] == 1;
      if (spring) multiplier *= 2;
    } else {
      turn = (turn + 1) % 3;
    }
    return null;
  }

  bool pass(int player) {
    if (phase != Phase.playing || turn != player || target == null) return false;
    actions[player] = '不出';
    passes++;
    turn = (turn + 1) % 3;
    if (passes == 2) {
      target = null;
      table = [];
      passes = 0;
      for (int i = 0; i < 3; i++) { actions[i] = ''; }
    }
    return true;
  }

  List<PlayingCard> suggest(int player, {bool cooperate = false, bool simple = false}) {
    return chooseMove(hand: hands[player], target: target, player: player, landlord: landlord,
      lastPlayer: lastPlayer, counts: hands.map((h) => h.length).toList(),
      cooperate: cooperate, simple: simple);
  }

  void computerStep() {
    if (phase == Phase.bidding) { bid(turn, computerBid(turn)); return; }
    if (phase != Phase.playing) return;
    final move = suggest(turn, cooperate: difficulty == Difficulty.standard,
      simple: difficulty == Difficulty.easy);
    if (move.isEmpty) { pass(turn); } else { play(turn, move); }
  }

  bool get humanWon => phase == Phase.finished && ((winner == landlord) == (landlord == 0));
  List<int> get scores {
    if (phase != Phase.finished) return [0, 0, 0];
    final base = highestBid * multiplier;
    final sign = winner == landlord ? 1 : -1;
    return List.generate(3, (i) => i == landlord ? 2 * base * sign : -base * sign);
  }
}
