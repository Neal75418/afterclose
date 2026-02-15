import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 網路連線狀態 Provider
///
/// 監聽 connectivity_plus 的連線變化，回傳是否在線。
/// 用於 UI 顯示離線提示橫幅。
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});
