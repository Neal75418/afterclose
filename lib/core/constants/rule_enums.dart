/// 趨勢狀態
enum TrendState {
  up('UP'),
  down('DOWN'),
  range('RANGE');

  const TrendState(this.code);

  final String code;

  /// 字串常數，供 DB 值比對使用（避免散落的 raw string）
  static const upCode = 'UP';
  static const downCode = 'DOWN';
}

/// 反轉狀態
enum ReversalState {
  none('NONE'),
  weakToStrong('W2S'),
  strongToWeak('S2W');

  const ReversalState(this.code);

  final String code;

  /// 字串常數，供 DB 值比對使用（避免散落的 raw string）
  static const w2sCode = 'W2S';
  static const s2wCode = 'S2W';
}

/// 更新執行狀態
enum UpdateStatus {
  success('SUCCESS'),
  failed('FAILED'),
  partial('PARTIAL'),

  /// 進行中(run 起手值)。app 中途被殺會遺留此狀態,由 DB beforeOpen 的
  /// `failOrphanRunningRuns` 收斂成 FAILED——見 UserDao 同名方法。
  running('RUNNING');

  const UpdateStatus(this.code);

  final String code;
}
