import 'dart:async';
import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_info.dart';
import 'game/cards.dart';
import 'game/match.dart';
import 'game/game_record.dart';
import 'game/practice.dart';
import 'game/table_game.dart';
import 'services/app_log.dart';
import 'services/player_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLog.init();
  FlutterError.onError = (details) {
    AppLog.error(details.exception, details.stack ?? StackTrace.current);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) { AppLog.error(error, stack); return true; };
  runApp(const LandlordApp());
}

const gold = Color(0xFFF3CE78);
const cream = Color(0xFFFFFDF5);
const pale = Color(0xFFDCEBE1);
const names = ['你', '阿竹', '老周'];

class LandlordApp extends StatelessWidget {
  const LandlordApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '闲庭斗地主', debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'), supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      fontFamily: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows ? 'Microsoft YaHei UI' : null,
      fontFamilyFallback: kIsWeb ? const ['OfflineChinese'] : null,
      colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark,
        primary: gold, surface: const Color(0xFF092B26)),
      scaffoldBackgroundColor: const Color(0xFF092B26),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: pale), bodyLarge: TextStyle(color: pale)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        foregroundColor: const Color(0xFF173B30), minimumSize: const Size(72, 46))),
    ),
    home: const TablePage(),
  );
}

class TablePage extends StatefulWidget {
  const TablePage({super.key});
  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> with WidgetsBindingObserver {
  Match match = Match();
  PracticePuzzle? activePuzzle;
  PlayerProfile profile = PlayerProfile.memory();
  Difficulty get nextDifficulty => profile.difficulty;
  List<GameRecord> get history => profile.history;
  final TableGame surface = TableGame();
  final Set<PlayingCard> selected = {};
  Timer? timer;
  bool paused = false, background = false, recorded = false, statsReady = false;
  int get totalScore => profile.totalScore;
  int get games => profile.games;
  int get wins => profile.wins;
  String message = '先看看手牌，再决定是否叫地主';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    AppLog.info('开始牌局');
  }
  Future<void> _load() async {
    final loaded = await PlayerProfile.load();
    if (!mounted) return;
    profile = loaded;
    match = Match(difficulty: nextDifficulty);
    if (!mounted) return;
    setState(() => statsReady = true);
    _schedule();
  }
  @override
  void dispose() { timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    background = state != AppLifecycleState.resumed;
    if (background) { timer?.cancel(); surface.pauseEngine(); } else {
      if (!paused) surface.resumeEngine();
      _schedule();
    }
  }
  bool get humanTurn => statsReady && !paused && !background && match.turn == 0 && match.phase != Phase.finished;
  void _schedule() {
    timer?.cancel();
    if (!mounted || !statsReady || paused || background || match.turn == 0 || match.phase == Phase.finished) return;
    timer = Timer(const Duration(milliseconds: 850), () {
      final who = match.turn;
      match.computerStep();
      AppLog.info('${names[who]} ${match.actions[who]}');
      _changed();
    });
  }
  void _changed() {
    if (match.phase == Phase.finished && !recorded) {
      recorded = true;
      if (activePuzzle == null) {
        profile.record(GameRecord(time: DateTime.now(), landlord: match.landlord == 0,
          won: match.humanWon, score: match.scores[0], difficulty: match.difficulty));
      } else if (match.humanWon) {
        profile.completePuzzle(activePuzzle!.id);
      }
      AppLog.info('mode=${activePuzzle?.id ?? 'normal'} won=${match.humanWon}');
      AppLog.info('结算 winner=${match.winner} landlord=${match.landlord} scores=${match.scores}');
    }
    setState(() {
      selected.removeWhere((c) => !match.hands[0].contains(c));
      message = match.phase == Phase.bidding ? '叫分越高，结算基础分越高；全不叫会重新发牌' :
          match.phase == Phase.finished ? '本局结束，积分仅记录在这台设备上' :
          match.turn == 0 ? (match.target == null ? '轮到你自由出牌，不能不出' : '轮到你出牌，也可以选择不出') : '${names[match.turn]}正在思考…';
    });
    _schedule();
  }
  void _bid(int score) { if (match.bid(0, score)) { AppLog.info('你叫分 $score'); _changed(); } }
  void _play() {
    final error = match.play(0, selected.toList());
    if (error != null) { setState(() => message = error); return; }
    AppLog.info('你出牌 ${match.target!.type.label} ${selected.length} 张');
    selected.clear(); _changed();
  }
  void _pass() { if (match.pass(0)) { selected.clear(); AppLog.info('你不出'); _changed(); } }
  void _hint() {
    final hint = match.suggest(0, cooperate: activePuzzle != null);
    setState(() {
      selected..clear()..addAll(hint);
      message = hint.isEmpty ? (activePuzzle == null ? '没有能压过的牌，可以选择不出' : '提示：选择不出，让队友继续出牌。') : '已选中建议牌，点击「出牌」确认';
    });
  }
  void _restart() {
    timer?.cancel();
    setState(() { match = activePuzzle?.create() ?? Match(difficulty: nextDifficulty); selected.clear(); recorded = false; message = activePuzzle?.goal ?? '新牌局开始，请叫分'; });
    AppLog.info('重新开始牌局'); _schedule();
  }
  void _normalGame() {
    setState(() => activePuzzle = null);
    _restart();
  }
  void _practice() => _dialog('残局练习', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('练习不计入普通战绩。选择题目会结束当前未完成牌局，可反复重试。'),
    const SizedBox(height: 12),
    ...practicePuzzles.map((puzzle) => ListTile(contentPadding: EdgeInsets.zero,
      title: Text(puzzle.title), subtitle: Text(puzzle.goal),
      trailing: Icon(profile.completedPuzzles.contains(puzzle.id) ? Icons.check_circle : Icons.play_circle_outline,
        semanticLabel: profile.completedPuzzles.contains(puzzle.id) ? '已通关' : '开始练习', color: gold),
      onTap: () {
        Navigator.pop(context);
        setState(() => activePuzzle = puzzle);
        _restart();
      },
    )),
  ]));
  Future<void> _dialog(String title, Widget content) async {
    timer?.cancel(); setState(() => paused = true); surface.pauseEngine();
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(title), content: SizedBox(width: 480, child: SingleChildScrollView(child: content)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('返回牌桌'))],
    ));
    if (!mounted) return;
    setState(() => paused = false);
    if (!background) surface.resumeEngine();
    _schedule();
  }
  Future<void> _newGame() async {
    if (match.phase == Phase.finished) { _restart(); return; }
    timer?.cancel(); setState(() => paused = true); surface.pauseEngine();
    final restart = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('重新发牌？'), content: const Text('当前牌局不会计入战绩。'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('继续本局')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('重新发牌'))],
    ));
    if (!mounted) return;
    setState(() => paused = false);
    if (!background) surface.resumeEngine();
    if (restart == true) { _restart(); } else { _schedule(); }
  }
  void _settings() => _dialog('难度设置', StatefulBuilder(builder: (context, refresh) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('当前牌局：${match.difficulty.label}'), const SizedBox(height: 12),
      DropdownButton<Difficulty>(value: nextDifficulty, isExpanded: true,
        items: Difficulty.values.map((d) => DropdownMenuItem(value: d, child: Text(d.label))).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() { profile.setDifficulty(value); }); refresh(() {});
          AppLog.info('下局难度 ${value.name}');
        }),
      const SizedBox(height: 12),
      const Text('下局生效。轻松电脑优先从小单张开始；标准电脑会组织长牌、配合队友，并关注对手剩余牌数。'),
    ])));
  void _history() => _dialog('最近战绩', history.isEmpty
    ? const Text('还没有已完成的牌局。完成一局后，这里会记录最近 20 局的结果。')
    : Column(children: history.map((record) => ListTile(contentPadding: EdgeInsets.zero,
      title: Text('${record.won ? '胜利' : '失利'} · ${record.landlord ? '地主' : '农民'} · ${record.difficulty.label}'),
      subtitle: Text(record.time.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')),
      trailing: Text('${record.score > 0 ? '+' : ''}${record.score} 分',
        style: const TextStyle(color: gold)),
    )).toList()));
  void _rules() => _dialog('经典三人斗地主', const Text(
    '一副 54 张牌，每人 17 张，地主额外获得 3 张底牌。轮流叫 1、2、3 分，只能加叫或不叫；3 分立即确定地主，全不叫则重发。\n\n'
    '地主先出。单张、对子、三张、三带一、三带一对、顺子（至少 5 张）、连对（至少 3 对）、飞机、飞机带单/对、四带二单/两对均可出。顺子、连对和飞机主体不能含 2 或王。\n\n'
    '飞机翅膀不能与主体同点数，单翼可含对子，对翼必须是不同点数的对子。四带二单可带一对。飞机及四带二不能同时带双王。\n\n'
    '同牌型、同张数才能比较大小，带牌不参与大小比较。炸弹大于普通牌型，王炸最大；四带二不算炸弹。连续两人不出后，最后出牌者自由领出。\n\n'
    '任一农民先出完即农民阵营获胜。基础分为叫分，炸弹、王炸、春天各翻倍。地主分数为基础分×倍数×2，农民各为基础分×倍数，输方扣分。地主获胜且农民均未出牌为春天；农民获胜且地主只出过一次为反春天。\n\n'
    '点击手牌选中，再点出牌；提示只选牌，不会自动打出。离开应用会暂停，返回后继续。电脑使用自己的手牌及公开信息进行决策。积分没有现金价值。',
    style: TextStyle(height: 1.65),
  ));
  void _logs() => _dialog('诊断日志 · $appVersion', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SelectableText(AppLog.location), const SizedBox(height: 12),
    Wrap(spacing: 8, children: [
      OutlinedButton(onPressed: () async {
        await Clipboard.setData(ClipboardData(text: '${AppLog.location}\n${AppLog.text}'));
      }, child: const Text('复制诊断')),
      if (kIsWeb) const OutlinedButton(onPressed: AppLog.download, child: Text('下载日志')),
    ]), const SizedBox(height: 12), SelectableText(AppLog.text, style: const TextStyle(fontSize: 12)),
  ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      return Stack(children: [
        Positioned.fill(child: ExcludeSemantics(child: IgnorePointer(child: GameWidget(game: surface)))),
        Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180),
          child: SingleChildScrollView(padding: EdgeInsets.all(wide ? 28 : 16), child: Column(children: [
            _header(wide), const SizedBox(height: 20),
            Row(children: [Expanded(child: _opponent(1)), const SizedBox(width: 12), Expanded(child: _opponent(2))]),
            const SizedBox(height: 14), _center(wide), const SizedBox(height: 16),
            _hand(wide), const SizedBox(height: 12), _controls(), const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: gold, height: 1.5))),
            const SizedBox(height: 16), Text('离线单机 · ${match.difficulty.label}  ·  本机战绩 $wins 胜 / $games 局  ·  积分 $totalScore',
              textAlign: TextAlign.center, style: const TextStyle(color: pale, fontSize: 12)),
          ])),
        )),
      ]);
    })),
  );
  Widget _header(bool wide) => Row(children: [
    const Icon(Icons.style_rounded, color: gold, size: 28), const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('闲庭斗地主', style: TextStyle(color: cream, fontSize: wide ? 28 : 22, fontWeight: FontWeight.w700)),
      const Text('一桌好牌，片刻闲趣', style: TextStyle(color: pale, fontSize: 12)),
    ])),
    PopupMenuButton<String>(tooltip: '牌桌菜单', icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'new': if (statsReady) _newGame();
          case 'settings': if (statsReady) _settings();
          case 'history': if (statsReady) _history();
          case 'practice': if (statsReady) _practice();
          case 'normal': if (statsReady) _normalGame();
          case 'rules': _rules();
          case 'logs': _logs();
        }
      }, itemBuilder: (context) => [
        const PopupMenuItem(value: 'new', child: Text('重新发牌')),
        const PopupMenuItem(value: 'settings', child: Text('难度设置')),
        const PopupMenuItem(value: 'history', child: Text('最近战绩')),
        const PopupMenuItem(value: 'practice', child: Text('残局练习')),
        if (activePuzzle != null) const PopupMenuItem(value: 'normal', child: Text('返回普通牌局')),
        const PopupMenuItem(value: 'rules', child: Text('玩法说明')),
        const PopupMenuItem(value: 'logs', child: Text('诊断日志')),
      ]),
  ]);
  Widget _opponent(int player) {
    final active = match.turn == player && match.phase != Phase.finished;
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      color: const Color(0xFF092B26), borderRadius: BorderRadius.circular(16),
      border: Border.all(color: active ? gold : const Color(0xFF28594B), width: active ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${names[player]}  ${match.landlord < 0 ? '待定' : match.landlord == player ? '地主' : '农民'}',
          style: TextStyle(color: active ? gold : cream, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('余 ${match.hands[player].length} 张${active ? ' · 思考中' : ''}', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6), Text(match.actions[player].isEmpty ? '等待出牌' : match.actions[player],
          style: const TextStyle(color: gold, fontSize: 12)),
      ]));
  }
  Widget _center(bool wide) => Container(
    width: double.infinity, constraints: BoxConstraints(minHeight: wide ? 205 : 156),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (activePuzzle != null) ...[
        Text('残局练习 · ${activePuzzle!.title}', style: const TextStyle(color: gold, fontSize: 18)),
        const SizedBox(height: 8), Text(activePuzzle!.goal, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        for (int i = 1; i < 3; i++) Text('${names[i]}（${match.landlord == i ? '地主' : '农民'}）：${match.hands[i].map((c) => c.label).join(' ')}'),
        TextButton(onPressed: _normalGame, child: const Text('返回普通牌局')),
      ],
      if (activePuzzle == null) Wrap(alignment: WrapAlignment.center, spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text('底牌', style: TextStyle(color: pale, fontSize: 12)),
        ...match.bottom.map((c) => match.landlord < 0
          ? const SizedBox(width: 28, height: 36, child: DecoratedBox(decoration: BoxDecoration(
              color: Color(0xFF28594B), borderRadius: BorderRadius.all(Radius.circular(4))),
              child: Center(child: Text('◆', style: TextStyle(color: gold)))))
          : _smallCard(c)),
        Text('  ${match.highestBid} 分 × ${match.multiplier}', style: const TextStyle(color: gold)),
      ]), const SizedBox(height: 18),
      if (match.phase == Phase.finished) ...[
        Text(activePuzzle != null ? (match.humanWon ? '挑战成功' : '再想一步') : (match.humanWon ? '这局，赢得漂亮' : '好牌，总在下一局'), textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, color: gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(activePuzzle != null ? '练习不计入战绩${match.humanWon ? ' · 已记录通关' : ''}' : '${match.winner == match.landlord ? '地主' : '农民'}获胜${match.spring ? ' · 春天翻倍' : ''}  /  本局 ${match.scores[0] > 0 ? '+' : ''}${match.scores[0]} 分'),
        const SizedBox(height: 12), FilledButton.icon(onPressed: _restart, icon: const Icon(Icons.refresh), label: Text(activePuzzle == null ? '再来一局' : '再练一次')),
      ] else if (match.table.isNotEmpty) ...[
        Text('${names[match.lastPlayer]} · ${match.target?.type.label ?? ''}', style: const TextStyle(fontSize: 12, color: pale)),
        const SizedBox(height: 8),
        Wrap(spacing: 3, runSpacing: 5, alignment: WrapAlignment.center, children: match.table.map(_smallCard).toList()),
      ] else ...[
        Text(match.phase == Phase.bidding ? '好戏，从叫地主开始' : '${names[match.turn]}自由出牌',
          style: const TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8), Text(match.phase == Phase.bidding ? '看好手牌，再出手' : '新一轮开始', style: const TextStyle(color: pale, fontSize: 13)),
      ],
    ]),
  );
  Widget _smallCard(PlayingCard card) => Container(width: 33, height: 46,
    decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(4)),
    child: Center(child: Text('${card.label}\n${card.suit}', textAlign: TextAlign.center,
      style: TextStyle(fontSize: card.rank > 15 ? 10 : 13, height: 1.2, fontWeight: FontWeight.bold,
        color: card.red ? const Color(0xFFB92F38) : const Color(0xFF17382E)))),
  );
  Widget _hand(bool wide) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text('你的手牌  ${match.landlord < 0 ? '' : match.landlord == 0 ? '· 地主' : '· 农民'}',
        style: const TextStyle(fontWeight: FontWeight.w600, color: cream)),
      const Spacer(), Text('${match.hands[0].length} 张', style: const TextStyle(color: pale)),
    ]), const SizedBox(height: 10),
    LayoutBuilder(builder: (context, constraints) {
      final count = wide ? 20 : constraints.maxWidth >= 480 ? 10 : 7;
      final width = ((constraints.maxWidth - (count - 1) * 4) / count).clamp(32.0, 64.0);
      return Wrap(spacing: 4, runSpacing: 8, children: match.hands[0].map((c) => Semantics(
        button: true, selected: selected.contains(c), label: '${c.suit}${c.label}',
        child: Tooltip(message: '${c.suit}${c.label}', child: Material(
          color: selected.contains(c) ? gold : cream, borderRadius: BorderRadius.circular(6),
          child: InkWell(borderRadius: BorderRadius.circular(6),
            onTap: humanTurn && match.phase == Phase.playing ? () => setState(() {
              if (!selected.add(c)) selected.remove(c);
            }) : null,
            child: Container(width: width, height: wide ? 88 : 70, padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selected.contains(c) ? const Color(0xFFC28B25) : cream, width: 2)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 24, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                  child: Text(c.label, maxLines: 1, style: TextStyle(fontSize: c.rank > 15 ? 13 : 20, height: 1.2,
                    color: c.red ? const Color(0xFFB92F38) : const Color(0xFF17382E), fontWeight: FontWeight.bold)))),
                Text(c.suit, style: TextStyle(fontSize: 18, height: 1.2, color: c.red ? const Color(0xFFB92F38) : const Color(0xFF17382E))),
                if (wide && selected.contains(c)) const Icon(Icons.check, size: 12, color: Color(0xFF17382E)),
              ])),
          ),
        )),
      )).toList());
    }),
  ]);
  Widget _controls() => Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: [
    if (match.phase == Phase.bidding) ...[
      OutlinedButton(onPressed: humanTurn ? () => _bid(0) : null, child: const Text('不叫')),
      for (int score = 1; score <= 3; score++) FilledButton(
        onPressed: humanTurn && score > match.highestBid ? () => _bid(score) : null, child: Text('$score 分')),
    ],
    if (match.phase == Phase.playing) ...[
      OutlinedButton(onPressed: humanTurn && match.target != null ? _pass : null, child: const Text('不出')),
      OutlinedButton(onPressed: humanTurn ? _hint : null, child: const Text('提示')),
      TextButton(onPressed: humanTurn && selected.isNotEmpty ? () => setState(selected.clear) : null, child: const Text('重选')),
      FilledButton(onPressed: humanTurn && selected.isNotEmpty ? _play : null, child: Text('出牌${selected.isEmpty ? '' : ' (${selected.length})'}')),
    ],
  ]);
}
