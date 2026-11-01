import 'dart:math';
import 'dart:ui';
import 'package:flame/game.dart';

/// Flame owns the responsive felt surface; Flutter owns accessible card controls.
class TableGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF123F36);
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(14, 14, max(0, size.x - 28), max(0, size.y - 28));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(38)),
        Paint()..color = const Color(0xFF28594B)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final paint = Paint()..color = const Color(0x082EDCA3);
    for (double x = 24; x < size.x; x += 32) {
      for (double y = 24; y < size.y; y += 32) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }
}
