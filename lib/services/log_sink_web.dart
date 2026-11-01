import 'dart:js_interop';
import 'package:web/web.dart' as web;

class LogSink {
  String get location => '浏览器本地日志；点击下载可保存到下载目录';
  Future<void> init() async {}
  Future<void> write(String line) async {
    final old = web.window.localStorage.getItem('doudizhu.log') ?? '';
    final text = '$old$line\n';
    web.window.localStorage.setItem('doudizhu.log', text.length > 64000 ? text.substring(text.length - 64000) : text);
  }
  void download(String text) {
    final stored = web.window.localStorage.getItem('doudizhu.log') ?? text;
    final blob = web.Blob([stored.toJS].toJS, web.BlobPropertyBag(type: 'text/plain;charset=utf-8'));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()..href = url..download = 'doudizhu.log';
    anchor.click();
    Future<void>.delayed(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  }
}
