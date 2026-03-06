import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 檔案分享服務 — 封裝 share_plus 與臨時檔案 I/O
///
/// 在 macOS 上，NSSharingServicePicker 的 callback 在使用者選擇分享服務後
/// 就返回，但分享動作（如 AirDrop 傳輸）尚未完成。因此不能在 shareXFiles
/// 返回後立即刪除檔案，改為在下次分享時清理上次的匯出檔案。
class ShareService {
  const ShareService();

  /// 取得或建立匯出專用目錄，並清理先前的匯出檔案
  Future<Directory> _getExportDir() async {
    final appSupport = await getApplicationSupportDirectory();
    final exportDir = Directory('${appSupport.path}/exports');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    // 清理上次匯出的檔案（只保留最近 5 分鐘內的）
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    for (final entity in exportDir.listSync()) {
      if (entity is File) {
        final modified = entity.lastModifiedSync();
        if (modified.isBefore(cutoff)) {
          entity.deleteSync();
        }
      }
    }
    return exportDir;
  }

  /// 分享 CSV 字串
  Future<void> shareCsv(String csvContent, String filename) async {
    final exportDir = await _getExportDir();
    final file = File('${exportDir.path}/$filename');
    await file.writeAsString(csvContent);
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
  }

  /// 分享 PDF 文件
  Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
    final exportDir = await _getExportDir();
    final file = File('${exportDir.path}/$filename');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
  }

  /// 分享 PNG 圖片
  Future<void> shareImage(Uint8List imageBytes, String filename) async {
    final exportDir = await _getExportDir();
    final file = File('${exportDir.path}/$filename');
    await file.writeAsBytes(imageBytes);
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
  }
}
