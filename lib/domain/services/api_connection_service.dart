import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// API 連線測試服務
///
/// 從 UI 層分離 API 測試邏輯，提升可測試性和關注點分離。
class ApiConnectionService {
  const ApiConnectionService();

  /// 測試 FinMind API 連接
  ///
  /// [token] - FinMind API Token
  /// 回傳 [ApiTestResult] 包含測試結果
  Future<ApiTestResult> testFinMindConnection(String? token) async {
    // 檢查 Token 是否存在
    if (token == null || token.isEmpty) {
      return const ApiTestResult._(
        success: false,
        error: ApiTestError.noToken,
        errorMessage: 'Token 尚未設定',
      );
    }

    // 驗證 Token 格式
    if (!FinMindClient.isValidTokenFormat(token)) {
      return const ApiTestResult._(
        success: false,
        error: ApiTestError.invalidToken,
        errorMessage: 'Token 格式無效',
      );
    }

    try {
      // 建立臨時客戶端測試連線
      final client = FinMindClient(token: token);
      final stocks = await client.getStockList();

      return ApiTestResult._(success: true, stockCount: stocks.length);
    } on InvalidTokenException catch (e) {
      return ApiTestResult._(
        success: false,
        error: ApiTestError.invalidToken,
        errorMessage: e.message,
      );
    } on RateLimitException catch (e) {
      return ApiTestResult._(
        success: false,
        error: ApiTestError.quotaExceeded,
        errorMessage: e.message,
      );
    } on NetworkException catch (e) {
      return ApiTestResult._(
        success: false,
        error: ApiTestError.network,
        errorMessage: e.message,
      );
    } on ApiException catch (e) {
      return ApiTestResult._(
        success: false,
        error: ApiTestError.apiError,
        errorMessage: e.message,
      );
    } catch (e) {
      return ApiTestResult._(
        success: false,
        error: ApiTestError.unknown,
        errorMessage: e.toString(),
      );
    }
  }
}

/// API 測試結果
class ApiTestResult {
  const ApiTestResult._({
    required this.success,
    this.stockCount,
    this.error,
    this.errorMessage,
  });

  /// 測試是否成功
  final bool success;

  /// 成功時返回的股票數量
  final int? stockCount;

  /// 失敗時的錯誤類型
  final ApiTestError? error;

  /// 錯誤訊息
  final String? errorMessage;

  /// 建立成功結果
  factory ApiTestResult.success({required int stockCount}) =>
      ApiTestResult._(success: true, stockCount: stockCount);

  /// 建立失敗結果
  factory ApiTestResult.failure({
    required ApiTestError error,
    String? message,
  }) => ApiTestResult._(success: false, error: error, errorMessage: message);
}

/// API 測試錯誤類型
enum ApiTestError {
  /// Token 未設定
  noToken,

  /// Token 格式無效
  invalidToken,

  /// API 配額超限
  quotaExceeded,

  /// 網路錯誤
  network,

  /// API 回應錯誤
  apiError,

  /// 未知錯誤
  unknown,
}
