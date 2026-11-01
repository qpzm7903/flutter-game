import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogSink {
  File? _file;
  String get location => _file?.path ?? '文件日志不可用，可复制诊断';
  Future<void> init({Directory? rootDirectory}) async {
    final root = rootDirectory ?? (Platform.isWindows && Platform.environment['USERPROFILE'] != null
        ? Directory('${Platform.environment['USERPROFILE']}/.xianting-doudizhu')
        : await getApplicationDocumentsDirectory());
    final dir = Directory('${root.path}/logs');
    await dir.create(recursive: true);
    _file = File('${dir.path}/doudizhu.log');
  }
  Future<void> write(String line) async {
    final file = _file;
    if (file == null) return;
    if (await file.exists() && await file.length() > 1024 * 1024) {
      final previous = File('${file.path}.1');
      if (await previous.exists()) await previous.delete();
      await file.rename(previous.path);
    }
    await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }
  void download(String text) {}
}
