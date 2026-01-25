import 'package:afterclose/core/constants/rule_params.dart';

/// 特定規則觸發的原因
class TriggeredReason {
  const TriggeredReason({
    required this.type,
    required this.score,
    required this.description,
    this.evidence,
  });

  final ReasonType type;
  final int score;
  final String description;
  final Map<String, dynamic>? evidence;

  /// 取得證據的 JSON map
  Map<String, dynamic>? get evidenceJson => evidence;
}
