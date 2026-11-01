import '../app_info.dart';
import 'log_sink.dart';

class AppLog {
  static final _sink = LogSink();
  static final List<String> _lines = [];
  static Future<void> _pending = Future.value();
  static String? failure;
  static String get location => failure == null ? _sink.location : '日志写入失败；请复制诊断：$failure';
  static String get text => _lines.join('\n');
  static Future<void> init() async {
    try { await _sink.init(); } catch (e) { failure = '$e'; }
    info('闲庭斗地主 $appVersion 启动');
  }
  static void info(String message) {
    final line = '${DateTime.now().toIso8601String()} $message';
    _lines.add(line);
    if (_lines.length > 300) _lines.removeAt(0);
    _pending = _pending.then((_) => _sink.write(line)).catchError((Object e) { failure = '$e'; });
  }
  static void error(Object error, StackTrace stack) => info('ERROR $error\n$stack');
  static Future<void> download() async {
    await _pending;
    try { _sink.download(text); } catch (e, s) { error(e, s); }
  }
  static Future<void> flush() => _pending;
}
