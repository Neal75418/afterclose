import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 檔案分享服務 — 封裝 share_plus 與臨時檔案 I/O
class ShareService {
  const ShareService();

  /// 分享 CSV 字串
  Future<void> shareCsv(String csvContent, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(csvContent);

    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
  }

  /// 分享 PNG 圖片
  Future<void> shareImage(Uint8List imageBytes, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(imageBytes);

    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
  }
}
