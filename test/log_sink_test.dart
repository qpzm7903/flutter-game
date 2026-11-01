import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/services/log_sink_io.dart';

void main() {
  test('logs persist under user root and rotate with one backup', () async {
    final root = await Directory.systemTemp.createTemp('doudizhu-log-test');
    addTearDown(() => root.delete(recursive: true));
    final sink = LogSink();
    await sink.init(rootDirectory: root);
    expect(sink.location, startsWith(root.path));
    await sink.write('game started');
    final file = File(sink.location);
    expect(await file.readAsString(), contains('game started'));
    await file.writeAsString('x' * (1024 * 1024 + 1));
    await sink.write('after rotation');
    expect(await File('${file.path}.1').exists(), isTrue);
    expect(await file.readAsString(), 'after rotation\n');
  });
}
