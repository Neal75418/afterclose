import 'package:shared_preferences/shared_preferences.dart';

import 'package:daredevil/data/remote/api_budget_tracker.dart';

/// [ApiBudgetStore] 的 SharedPreferences 實作。
///
/// 選 SharedPreferences 而非 Drift 的理由：狀態是單一小 JSON、寫入頻率低
/// （每 10 次呼叫或撞牆時），不值得為它加一張表與 migration；而且 tracker
/// 位於 data/remote 層，讓它依賴 AppDatabase 會把 remote 綁到 DB 上。
///
/// 失敗一律往上拋，由 [ApiBudgetTracker] fail-open 處理——儲存故障不該讓
/// 整個 app 打不了 API。
class SharedPrefsApiBudgetStore implements ApiBudgetStore {
  const SharedPrefsApiBudgetStore();

  static const String _key = 'api_budget_state_v1';

  @override
  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> save(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json);
  }
}
