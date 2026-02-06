/// TWSE API 回傳的指數全名（用於 DB 查詢與 UI 過濾）
class MarketIndexNames {
  MarketIndexNames._();

  // === 主要指數 ===
  static const taiex = '發行量加權股價指數';
  static const exFinance = '未含金融電子指數';

  // === 產業指數 ===
  static const electronics = '電子工業類指數';
  static const financeInsurance = '金融保險類指數';
  static const semiconductor = '半導體類指數';
  static const shipping = '航運類指數';
  static const biotech = '生技醫療類指數';
  static const steel = '鋼鐵類指數';
  static const greenEnergy = '綠能環保類指數';
  static const highDividend = '高股息指數';

  /// Dashboard 顯示的重點指數
  static const dashboardIndices = [
    taiex,
    exFinance,
    electronics,
    financeInsurance,
    semiconductor,
    shipping,
    biotech,
  ];
}
