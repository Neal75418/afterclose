import 'dart:convert';

// ==================================================
// Screening Field
// ==================================================

/// 條件分類
enum ScreeningCategory { price, volume, technical, fundamental, signal }

/// 可篩選欄位
enum ScreeningField {
  // 價格 (SQL)
  close(ScreeningCategory.price, ScreeningFieldType.numeric),
  priceChangePercent(ScreeningCategory.price, ScreeningFieldType.numeric),

  // 成交量
  volume(ScreeningCategory.volume, ScreeningFieldType.numeric),
  volumeRatioMa20(ScreeningCategory.volume, ScreeningFieldType.numeric),

  // 技術指標 (記憶體計算)
  aboveMa5(ScreeningCategory.technical, ScreeningFieldType.boolean),
  aboveMa10(ScreeningCategory.technical, ScreeningFieldType.boolean),
  aboveMa20(ScreeningCategory.technical, ScreeningFieldType.boolean),
  aboveMa60(ScreeningCategory.technical, ScreeningFieldType.boolean),
  rsi14(ScreeningCategory.technical, ScreeningFieldType.numeric),
  kValue(ScreeningCategory.technical, ScreeningFieldType.numeric),
  dValue(ScreeningCategory.technical, ScreeningFieldType.numeric),

  // 基本面 (SQL)
  pe(ScreeningCategory.fundamental, ScreeningFieldType.numeric),
  pbr(ScreeningCategory.fundamental, ScreeningFieldType.numeric),
  dividendYield(ScreeningCategory.fundamental, ScreeningFieldType.numeric),
  revenueYoyGrowth(ScreeningCategory.fundamental, ScreeningFieldType.numeric),
  revenueMomGrowth(ScreeningCategory.fundamental, ScreeningFieldType.numeric),

  // 訊號 (記憶體)
  hasSignal(ScreeningCategory.signal, ScreeningFieldType.signal),

  // 分析結果 (SQL)
  score(ScreeningCategory.fundamental, ScreeningFieldType.numeric);

  const ScreeningField(this.category, this.fieldType);

  final ScreeningCategory category;
  final ScreeningFieldType fieldType;

  /// 是否可以用 SQL 直接篩選
  bool get isSqlFilterable => switch (this) {
    close ||
    volume ||
    pe ||
    pbr ||
    dividendYield ||
    revenueYoyGrowth ||
    revenueMomGrowth ||
    score ||
    priceChangePercent => true,
    _ => false,
  };
}

/// 欄位資料型別
enum ScreeningFieldType { numeric, boolean, signal }

// ==================================================
// Screening Operator
// ==================================================

/// 篩選運算子
enum ScreeningOperator {
  greaterThan,
  greaterOrEqual,
  lessThan,
  lessOrEqual,
  between,
  equals,
  isTrue,
  isFalse;

  /// 此運算子是否適用於指定欄位型別
  bool isCompatibleWith(ScreeningFieldType type) => switch (type) {
    ScreeningFieldType.numeric =>
      this == greaterThan ||
          this == greaterOrEqual ||
          this == lessThan ||
          this == lessOrEqual ||
          this == between,
    ScreeningFieldType.boolean => this == isTrue || this == isFalse,
    ScreeningFieldType.signal => this == equals,
  };

  /// 取得指定欄位型別的預設運算子
  static ScreeningOperator defaultFor(ScreeningFieldType type) =>
      switch (type) {
        ScreeningFieldType.numeric => greaterOrEqual,
        ScreeningFieldType.boolean => isTrue,
        ScreeningFieldType.signal => equals,
      };

  /// 取得指定欄位型別可用的運算子列表
  static List<ScreeningOperator> availableFor(ScreeningFieldType type) =>
      values.where((op) => op.isCompatibleWith(type)).toList();
}

// ==================================================
// Screening Condition
// ==================================================

/// 單一篩選條件
class ScreeningCondition {
  const ScreeningCondition({
    required this.field,
    required this.operator,
    this.value,
    this.valueTo,
    this.stringValue,
  });

  final ScreeningField field;
  final ScreeningOperator operator;

  /// 數值（單值運算子用）
  final double? value;

  /// 數值上界（between 用）
  final double? valueTo;

  /// 字串值（hasSignal 的 reason code）
  final String? stringValue;

  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'field': field.name,
    'operator': operator.name,
    if (value != null) 'value': value,
    if (valueTo != null) 'valueTo': valueTo,
    if (stringValue != null) 'stringValue': stringValue,
  };

  /// JSON 反序列化
  factory ScreeningCondition.fromJson(Map<String, dynamic> json) {
    return ScreeningCondition(
      field: ScreeningField.values.byName(json['field'] as String),
      operator: ScreeningOperator.values.byName(json['operator'] as String),
      value: (json['value'] as num?)?.toDouble(),
      valueTo: (json['valueTo'] as num?)?.toDouble(),
      stringValue: json['stringValue'] as String?,
    );
  }

  ScreeningCondition copyWith({
    ScreeningField? field,
    ScreeningOperator? operator,
    double? value,
    double? valueTo,
    String? stringValue,
    bool clearValue = false,
    bool clearValueTo = false,
    bool clearStringValue = false,
  }) {
    return ScreeningCondition(
      field: field ?? this.field,
      operator: operator ?? this.operator,
      value: clearValue ? null : (value ?? this.value),
      valueTo: clearValueTo ? null : (valueTo ?? this.valueTo),
      stringValue: clearStringValue ? null : (stringValue ?? this.stringValue),
    );
  }
}

// ==================================================
// Screening Strategy
// ==================================================

/// 自訂選股策略（可儲存/載入）
class ScreeningStrategy {
  const ScreeningStrategy({
    this.id,
    required this.name,
    required this.conditions,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final List<ScreeningCondition> conditions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 從 DB entry 轉換
  static List<ScreeningCondition> conditionsFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => ScreeningCondition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 轉為 JSON 字串（存 DB 用）
  static String conditionsToJson(List<ScreeningCondition> conditions) {
    return jsonEncode(conditions.map((c) => c.toJson()).toList());
  }
}

// ==================================================
// Screening Result
// ==================================================

/// 篩選結果
class ScreeningResult {
  const ScreeningResult({
    required this.symbols,
    required this.matchCount,
    required this.totalScanned,
    required this.dataDate,
    this.executionTime,
  });

  /// 符合條件的股票代碼（已按 score 降序排列）
  final List<String> symbols;
  final int matchCount;
  final int totalScanned;
  final DateTime dataDate;
  final Duration? executionTime;
}
