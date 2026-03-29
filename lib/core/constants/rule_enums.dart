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
  static const rangeCode = 'RANGE';
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
  partial('PARTIAL');

  const UpdateStatus(this.code);

  final String code;
}
