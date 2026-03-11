/// 趨勢狀態
enum TrendState {
  up('UP'),
  down('DOWN'),
  range('RANGE');

  const TrendState(this.code);

  final String code;
}

/// 反轉狀態
enum ReversalState {
  none('NONE'),
  weakToStrong('W2S'),
  strongToWeak('S2W');

  const ReversalState(this.code);

  final String code;
}

/// 更新執行狀態
enum UpdateStatus {
  success('SUCCESS'),
  failed('FAILED'),
  partial('PARTIAL');

  const UpdateStatus(this.code);

  final String code;
}
