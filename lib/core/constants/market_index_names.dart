/// TWSE API 回傳的指數全名（用於 DB 查詢與 UI 過濾）
class MarketIndexNames {
  MarketIndexNames._();

  static const taiex = '發行量加權股價指數';
  static const exFinance = '未含金融電子指數';
  static const electronics = '電子工業類指數';
  static const financeInsurance = '金融保險類指數';

  /// Dashboard 顯示的 4 個重點指數
  static const dashboardIndices = [
    taiex,
    exFinance,
    electronics,
    financeInsurance,
  ];
}
