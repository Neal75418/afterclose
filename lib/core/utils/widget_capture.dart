import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 從 GlobalKey 截圖 Widget 為 PNG bytes
class WidgetCapture {
  const WidgetCapture();

  /// 截取指定 GlobalKey 對應的 Widget 為 PNG
  Future<Uint8List?> captureFromKey(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
