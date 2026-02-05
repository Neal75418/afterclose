// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StockMasterTable extends StockMaster
    with TableInfo<$StockMasterTable, StockMasterEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMasterTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marketMeta = const VerificationMeta('market');
  @override
  late final GeneratedColumn<String> market = GeneratedColumn<String>(
    'market',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _industryMeta = const VerificationMeta(
    'industry',
  );
  @override
  late final GeneratedColumn<String> industry = GeneratedColumn<String>(
    'industry',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    name,
    market,
    industry,
    isActive,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_master';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockMasterEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('market')) {
      context.handle(
        _marketMeta,
        market.isAcceptableOrUnknown(data['market']!, _marketMeta),
      );
    } else if (isInserting) {
      context.missing(_marketMeta);
    }
    if (data.containsKey('industry')) {
      context.handle(
        _industryMeta,
        industry.isAcceptableOrUnknown(data['industry']!, _industryMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol};
  @override
  StockMasterEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMasterEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      market: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}market'],
      )!,
      industry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}industry'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StockMasterTable createAlias(String alias) {
    return $StockMasterTable(attachedDatabase, alias);
  }
}

class StockMasterEntry extends DataClass
    implements Insertable<StockMasterEntry> {
  /// 股票代碼（如 "2330"）
  final String symbol;

  /// 股票名稱（如「台積電」）
  final String name;

  /// 市場：TWSE（上市）或 TPEx（上櫃）
  final String market;

  /// 產業類別（可為空）
  final String? industry;

  /// 是否仍在交易
  final bool isActive;

  /// 最後更新時間
  final DateTime updatedAt;
  const StockMasterEntry({
    required this.symbol,
    required this.name,
    required this.market,
    this.industry,
    required this.isActive,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['name'] = Variable<String>(name);
    map['market'] = Variable<String>(market);
    if (!nullToAbsent || industry != null) {
      map['industry'] = Variable<String>(industry);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StockMasterCompanion toCompanion(bool nullToAbsent) {
    return StockMasterCompanion(
      symbol: Value(symbol),
      name: Value(name),
      market: Value(market),
      industry: industry == null && nullToAbsent
          ? const Value.absent()
          : Value(industry),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory StockMasterEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMasterEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      name: serializer.fromJson<String>(json['name']),
      market: serializer.fromJson<String>(json['market']),
      industry: serializer.fromJson<String?>(json['industry']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'market': serializer.toJson<String>(market),
      'industry': serializer.toJson<String?>(industry),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StockMasterEntry copyWith({
    String? symbol,
    String? name,
    String? market,
    Value<String?> industry = const Value.absent(),
    bool? isActive,
    DateTime? updatedAt,
  }) => StockMasterEntry(
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    market: market ?? this.market,
    industry: industry.present ? industry.value : this.industry,
    isActive: isActive ?? this.isActive,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StockMasterEntry copyWithCompanion(StockMasterCompanion data) {
    return StockMasterEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      name: data.name.present ? data.name.value : this.name,
      market: data.market.present ? data.market.value : this.market,
      industry: data.industry.present ? data.industry.value : this.industry,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMasterEntry(')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('market: $market, ')
          ..write('industry: $industry, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(symbol, name, market, industry, isActive, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMasterEntry &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.market == this.market &&
          other.industry == this.industry &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class StockMasterCompanion extends UpdateCompanion<StockMasterEntry> {
  final Value<String> symbol;
  final Value<String> name;
  final Value<String> market;
  final Value<String?> industry;
  final Value<bool> isActive;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StockMasterCompanion({
    this.symbol = const Value.absent(),
    this.name = const Value.absent(),
    this.market = const Value.absent(),
    this.industry = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockMasterCompanion.insert({
    required String symbol,
    required String name,
    required String market,
    this.industry = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       name = Value(name),
       market = Value(market);
  static Insertable<StockMasterEntry> custom({
    Expression<String>? symbol,
    Expression<String>? name,
    Expression<String>? market,
    Expression<String>? industry,
    Expression<bool>? isActive,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (market != null) 'market': market,
      if (industry != null) 'industry': industry,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockMasterCompanion copyWith({
    Value<String>? symbol,
    Value<String>? name,
    Value<String>? market,
    Value<String?>? industry,
    Value<bool>? isActive,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StockMasterCompanion(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      market: market ?? this.market,
      industry: industry ?? this.industry,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (market.present) {
      map['market'] = Variable<String>(market.value);
    }
    if (industry.present) {
      map['industry'] = Variable<String>(industry.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMasterCompanion(')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('market: $market, ')
          ..write('industry: $industry, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyPriceTable extends DailyPrice
    with TableInfo<$DailyPriceTable, DailyPriceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyPriceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openMeta = const VerificationMeta('open');
  @override
  late final GeneratedColumn<double> open = GeneratedColumn<double>(
    'open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highMeta = const VerificationMeta('high');
  @override
  late final GeneratedColumn<double> high = GeneratedColumn<double>(
    'high',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lowMeta = const VerificationMeta('low');
  @override
  late final GeneratedColumn<double> low = GeneratedColumn<double>(
    'low',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closeMeta = const VerificationMeta('close');
  @override
  late final GeneratedColumn<double> close = GeneratedColumn<double>(
    'close',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceChangeMeta = const VerificationMeta(
    'priceChange',
  );
  @override
  late final GeneratedColumn<double> priceChange = GeneratedColumn<double>(
    'price_change',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    open,
    high,
    low,
    close,
    volume,
    priceChange,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_price';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyPriceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('open')) {
      context.handle(
        _openMeta,
        open.isAcceptableOrUnknown(data['open']!, _openMeta),
      );
    }
    if (data.containsKey('high')) {
      context.handle(
        _highMeta,
        high.isAcceptableOrUnknown(data['high']!, _highMeta),
      );
    }
    if (data.containsKey('low')) {
      context.handle(
        _lowMeta,
        low.isAcceptableOrUnknown(data['low']!, _lowMeta),
      );
    }
    if (data.containsKey('close')) {
      context.handle(
        _closeMeta,
        close.isAcceptableOrUnknown(data['close']!, _closeMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('price_change')) {
      context.handle(
        _priceChangeMeta,
        priceChange.isAcceptableOrUnknown(
          data['price_change']!,
          _priceChangeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  DailyPriceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyPriceEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      open: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}open'],
      ),
      high: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}high'],
      ),
      low: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}low'],
      ),
      close: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}close'],
      ),
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      ),
      priceChange: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_change'],
      ),
    );
  }

  @override
  $DailyPriceTable createAlias(String alias) {
    return $DailyPriceTable(attachedDatabase, alias);
  }
}

class DailyPriceEntry extends DataClass implements Insertable<DailyPriceEntry> {
  /// 股票代碼
  final String symbol;

  /// 交易日期（以 UTC 儲存）
  final DateTime date;

  /// 開盤價
  final double? open;

  /// 最高價
  final double? high;

  /// 最低價
  final double? low;

  /// 收盤價
  final double? close;

  /// 成交量（張）
  final double? volume;

  /// 漲跌價差（來自 TWSE/TPEX API，用於計算漲跌幅）
  final double? priceChange;
  const DailyPriceEntry({
    required this.symbol,
    required this.date,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.priceChange,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || open != null) {
      map['open'] = Variable<double>(open);
    }
    if (!nullToAbsent || high != null) {
      map['high'] = Variable<double>(high);
    }
    if (!nullToAbsent || low != null) {
      map['low'] = Variable<double>(low);
    }
    if (!nullToAbsent || close != null) {
      map['close'] = Variable<double>(close);
    }
    if (!nullToAbsent || volume != null) {
      map['volume'] = Variable<double>(volume);
    }
    if (!nullToAbsent || priceChange != null) {
      map['price_change'] = Variable<double>(priceChange);
    }
    return map;
  }

  DailyPriceCompanion toCompanion(bool nullToAbsent) {
    return DailyPriceCompanion(
      symbol: Value(symbol),
      date: Value(date),
      open: open == null && nullToAbsent ? const Value.absent() : Value(open),
      high: high == null && nullToAbsent ? const Value.absent() : Value(high),
      low: low == null && nullToAbsent ? const Value.absent() : Value(low),
      close: close == null && nullToAbsent
          ? const Value.absent()
          : Value(close),
      volume: volume == null && nullToAbsent
          ? const Value.absent()
          : Value(volume),
      priceChange: priceChange == null && nullToAbsent
          ? const Value.absent()
          : Value(priceChange),
    );
  }

  factory DailyPriceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyPriceEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      open: serializer.fromJson<double?>(json['open']),
      high: serializer.fromJson<double?>(json['high']),
      low: serializer.fromJson<double?>(json['low']),
      close: serializer.fromJson<double?>(json['close']),
      volume: serializer.fromJson<double?>(json['volume']),
      priceChange: serializer.fromJson<double?>(json['priceChange']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'open': serializer.toJson<double?>(open),
      'high': serializer.toJson<double?>(high),
      'low': serializer.toJson<double?>(low),
      'close': serializer.toJson<double?>(close),
      'volume': serializer.toJson<double?>(volume),
      'priceChange': serializer.toJson<double?>(priceChange),
    };
  }

  DailyPriceEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> open = const Value.absent(),
    Value<double?> high = const Value.absent(),
    Value<double?> low = const Value.absent(),
    Value<double?> close = const Value.absent(),
    Value<double?> volume = const Value.absent(),
    Value<double?> priceChange = const Value.absent(),
  }) => DailyPriceEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    open: open.present ? open.value : this.open,
    high: high.present ? high.value : this.high,
    low: low.present ? low.value : this.low,
    close: close.present ? close.value : this.close,
    volume: volume.present ? volume.value : this.volume,
    priceChange: priceChange.present ? priceChange.value : this.priceChange,
  );
  DailyPriceEntry copyWithCompanion(DailyPriceCompanion data) {
    return DailyPriceEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      open: data.open.present ? data.open.value : this.open,
      high: data.high.present ? data.high.value : this.high,
      low: data.low.present ? data.low.value : this.low,
      close: data.close.present ? data.close.value : this.close,
      volume: data.volume.present ? data.volume.value : this.volume,
      priceChange: data.priceChange.present
          ? data.priceChange.value
          : this.priceChange,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyPriceEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('open: $open, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('close: $close, ')
          ..write('volume: $volume, ')
          ..write('priceChange: $priceChange')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(symbol, date, open, high, low, close, volume, priceChange);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyPriceEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.open == this.open &&
          other.high == this.high &&
          other.low == this.low &&
          other.close == this.close &&
          other.volume == this.volume &&
          other.priceChange == this.priceChange);
}

class DailyPriceCompanion extends UpdateCompanion<DailyPriceEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> open;
  final Value<double?> high;
  final Value<double?> low;
  final Value<double?> close;
  final Value<double?> volume;
  final Value<double?> priceChange;
  final Value<int> rowid;
  const DailyPriceCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.open = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.close = const Value.absent(),
    this.volume = const Value.absent(),
    this.priceChange = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyPriceCompanion.insert({
    required String symbol,
    required DateTime date,
    this.open = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.close = const Value.absent(),
    this.volume = const Value.absent(),
    this.priceChange = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<DailyPriceEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? open,
    Expression<double>? high,
    Expression<double>? low,
    Expression<double>? close,
    Expression<double>? volume,
    Expression<double>? priceChange,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (open != null) 'open': open,
      if (high != null) 'high': high,
      if (low != null) 'low': low,
      if (close != null) 'close': close,
      if (volume != null) 'volume': volume,
      if (priceChange != null) 'price_change': priceChange,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyPriceCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? open,
    Value<double?>? high,
    Value<double?>? low,
    Value<double?>? close,
    Value<double?>? volume,
    Value<double?>? priceChange,
    Value<int>? rowid,
  }) {
    return DailyPriceCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      priceChange: priceChange ?? this.priceChange,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (open.present) {
      map['open'] = Variable<double>(open.value);
    }
    if (high.present) {
      map['high'] = Variable<double>(high.value);
    }
    if (low.present) {
      map['low'] = Variable<double>(low.value);
    }
    if (close.present) {
      map['close'] = Variable<double>(close.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (priceChange.present) {
      map['price_change'] = Variable<double>(priceChange.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyPriceCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('open: $open, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('close: $close, ')
          ..write('volume: $volume, ')
          ..write('priceChange: $priceChange, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyInstitutionalTable extends DailyInstitutional
    with TableInfo<$DailyInstitutionalTable, DailyInstitutionalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyInstitutionalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foreignNetMeta = const VerificationMeta(
    'foreignNet',
  );
  @override
  late final GeneratedColumn<double> foreignNet = GeneratedColumn<double>(
    'foreign_net',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _investmentTrustNetMeta =
      const VerificationMeta('investmentTrustNet');
  @override
  late final GeneratedColumn<double> investmentTrustNet =
      GeneratedColumn<double>(
        'investment_trust_net',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dealerNetMeta = const VerificationMeta(
    'dealerNet',
  );
  @override
  late final GeneratedColumn<double> dealerNet = GeneratedColumn<double>(
    'dealer_net',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    foreignNet,
    investmentTrustNet,
    dealerNet,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_institutional';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyInstitutionalEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('foreign_net')) {
      context.handle(
        _foreignNetMeta,
        foreignNet.isAcceptableOrUnknown(data['foreign_net']!, _foreignNetMeta),
      );
    }
    if (data.containsKey('investment_trust_net')) {
      context.handle(
        _investmentTrustNetMeta,
        investmentTrustNet.isAcceptableOrUnknown(
          data['investment_trust_net']!,
          _investmentTrustNetMeta,
        ),
      );
    }
    if (data.containsKey('dealer_net')) {
      context.handle(
        _dealerNetMeta,
        dealerNet.isAcceptableOrUnknown(data['dealer_net']!, _dealerNetMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  DailyInstitutionalEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyInstitutionalEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      foreignNet: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}foreign_net'],
      ),
      investmentTrustNet: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}investment_trust_net'],
      ),
      dealerNet: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dealer_net'],
      ),
    );
  }

  @override
  $DailyInstitutionalTable createAlias(String alias) {
    return $DailyInstitutionalTable(attachedDatabase, alias);
  }
}

class DailyInstitutionalEntry extends DataClass
    implements Insertable<DailyInstitutionalEntry> {
  /// 股票代碼
  final String symbol;

  /// 交易日期
  final DateTime date;

  /// 外資買賣超（張）
  final double? foreignNet;

  /// 投信買賣超（張）
  final double? investmentTrustNet;

  /// 自營商買賣超（張）
  final double? dealerNet;
  const DailyInstitutionalEntry({
    required this.symbol,
    required this.date,
    this.foreignNet,
    this.investmentTrustNet,
    this.dealerNet,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || foreignNet != null) {
      map['foreign_net'] = Variable<double>(foreignNet);
    }
    if (!nullToAbsent || investmentTrustNet != null) {
      map['investment_trust_net'] = Variable<double>(investmentTrustNet);
    }
    if (!nullToAbsent || dealerNet != null) {
      map['dealer_net'] = Variable<double>(dealerNet);
    }
    return map;
  }

  DailyInstitutionalCompanion toCompanion(bool nullToAbsent) {
    return DailyInstitutionalCompanion(
      symbol: Value(symbol),
      date: Value(date),
      foreignNet: foreignNet == null && nullToAbsent
          ? const Value.absent()
          : Value(foreignNet),
      investmentTrustNet: investmentTrustNet == null && nullToAbsent
          ? const Value.absent()
          : Value(investmentTrustNet),
      dealerNet: dealerNet == null && nullToAbsent
          ? const Value.absent()
          : Value(dealerNet),
    );
  }

  factory DailyInstitutionalEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyInstitutionalEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      foreignNet: serializer.fromJson<double?>(json['foreignNet']),
      investmentTrustNet: serializer.fromJson<double?>(
        json['investmentTrustNet'],
      ),
      dealerNet: serializer.fromJson<double?>(json['dealerNet']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'foreignNet': serializer.toJson<double?>(foreignNet),
      'investmentTrustNet': serializer.toJson<double?>(investmentTrustNet),
      'dealerNet': serializer.toJson<double?>(dealerNet),
    };
  }

  DailyInstitutionalEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> foreignNet = const Value.absent(),
    Value<double?> investmentTrustNet = const Value.absent(),
    Value<double?> dealerNet = const Value.absent(),
  }) => DailyInstitutionalEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    foreignNet: foreignNet.present ? foreignNet.value : this.foreignNet,
    investmentTrustNet: investmentTrustNet.present
        ? investmentTrustNet.value
        : this.investmentTrustNet,
    dealerNet: dealerNet.present ? dealerNet.value : this.dealerNet,
  );
  DailyInstitutionalEntry copyWithCompanion(DailyInstitutionalCompanion data) {
    return DailyInstitutionalEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      foreignNet: data.foreignNet.present
          ? data.foreignNet.value
          : this.foreignNet,
      investmentTrustNet: data.investmentTrustNet.present
          ? data.investmentTrustNet.value
          : this.investmentTrustNet,
      dealerNet: data.dealerNet.present ? data.dealerNet.value : this.dealerNet,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyInstitutionalEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('foreignNet: $foreignNet, ')
          ..write('investmentTrustNet: $investmentTrustNet, ')
          ..write('dealerNet: $dealerNet')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(symbol, date, foreignNet, investmentTrustNet, dealerNet);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyInstitutionalEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.foreignNet == this.foreignNet &&
          other.investmentTrustNet == this.investmentTrustNet &&
          other.dealerNet == this.dealerNet);
}

class DailyInstitutionalCompanion
    extends UpdateCompanion<DailyInstitutionalEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> foreignNet;
  final Value<double?> investmentTrustNet;
  final Value<double?> dealerNet;
  final Value<int> rowid;
  const DailyInstitutionalCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.foreignNet = const Value.absent(),
    this.investmentTrustNet = const Value.absent(),
    this.dealerNet = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyInstitutionalCompanion.insert({
    required String symbol,
    required DateTime date,
    this.foreignNet = const Value.absent(),
    this.investmentTrustNet = const Value.absent(),
    this.dealerNet = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<DailyInstitutionalEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? foreignNet,
    Expression<double>? investmentTrustNet,
    Expression<double>? dealerNet,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (foreignNet != null) 'foreign_net': foreignNet,
      if (investmentTrustNet != null)
        'investment_trust_net': investmentTrustNet,
      if (dealerNet != null) 'dealer_net': dealerNet,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyInstitutionalCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? foreignNet,
    Value<double?>? investmentTrustNet,
    Value<double?>? dealerNet,
    Value<int>? rowid,
  }) {
    return DailyInstitutionalCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      foreignNet: foreignNet ?? this.foreignNet,
      investmentTrustNet: investmentTrustNet ?? this.investmentTrustNet,
      dealerNet: dealerNet ?? this.dealerNet,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (foreignNet.present) {
      map['foreign_net'] = Variable<double>(foreignNet.value);
    }
    if (investmentTrustNet.present) {
      map['investment_trust_net'] = Variable<double>(investmentTrustNet.value);
    }
    if (dealerNet.present) {
      map['dealer_net'] = Variable<double>(dealerNet.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyInstitutionalCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('foreignNet: $foreignNet, ')
          ..write('investmentTrustNet: $investmentTrustNet, ')
          ..write('dealerNet: $dealerNet, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NewsItemTable extends NewsItem
    with TableInfo<$NewsItemTable, NewsItemEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NewsItemTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    title,
    content,
    url,
    category,
    publishedAt,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_item';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewsItemEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NewsItemEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewsItemEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $NewsItemTable createAlias(String alias) {
    return $NewsItemTable(attachedDatabase, alias);
  }
}

class NewsItemEntry extends DataClass implements Insertable<NewsItemEntry> {
  /// 新聞唯一 ID（URL 或 RSS guid 的 hash）
  final String id;

  /// 新聞來源（如 MoneyDJ、Yahoo）
  final String source;

  /// 新聞標題
  final String title;

  /// 新聞內文摘要（從 RSS description 抓取，可能為空）
  final String? content;

  /// 新聞連結
  final String url;

  /// 分類：EARNINGS、POLICY、INDUSTRY、COMPANY_EVENT、OTHER
  final String category;

  /// 發布時間
  final DateTime publishedAt;

  /// 抓取時間
  final DateTime fetchedAt;
  const NewsItemEntry({
    required this.id,
    required this.source,
    required this.title,
    this.content,
    required this.url,
    required this.category,
    required this.publishedAt,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source'] = Variable<String>(source);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['url'] = Variable<String>(url);
    map['category'] = Variable<String>(category);
    map['published_at'] = Variable<DateTime>(publishedAt);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  NewsItemCompanion toCompanion(bool nullToAbsent) {
    return NewsItemCompanion(
      id: Value(id),
      source: Value(source),
      title: Value(title),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      url: Value(url),
      category: Value(category),
      publishedAt: Value(publishedAt),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory NewsItemEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewsItemEntry(
      id: serializer.fromJson<String>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String?>(json['content']),
      url: serializer.fromJson<String>(json['url']),
      category: serializer.fromJson<String>(json['category']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'source': serializer.toJson<String>(source),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String?>(content),
      'url': serializer.toJson<String>(url),
      'category': serializer.toJson<String>(category),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  NewsItemEntry copyWith({
    String? id,
    String? source,
    String? title,
    Value<String?> content = const Value.absent(),
    String? url,
    String? category,
    DateTime? publishedAt,
    DateTime? fetchedAt,
  }) => NewsItemEntry(
    id: id ?? this.id,
    source: source ?? this.source,
    title: title ?? this.title,
    content: content.present ? content.value : this.content,
    url: url ?? this.url,
    category: category ?? this.category,
    publishedAt: publishedAt ?? this.publishedAt,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  NewsItemEntry copyWithCompanion(NewsItemCompanion data) {
    return NewsItemEntry(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      url: data.url.present ? data.url.value : this.url,
      category: data.category.present ? data.category.value : this.category,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewsItemEntry(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('url: $url, ')
          ..write('category: $category, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    title,
    content,
    url,
    category,
    publishedAt,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsItemEntry &&
          other.id == this.id &&
          other.source == this.source &&
          other.title == this.title &&
          other.content == this.content &&
          other.url == this.url &&
          other.category == this.category &&
          other.publishedAt == this.publishedAt &&
          other.fetchedAt == this.fetchedAt);
}

class NewsItemCompanion extends UpdateCompanion<NewsItemEntry> {
  final Value<String> id;
  final Value<String> source;
  final Value<String> title;
  final Value<String?> content;
  final Value<String> url;
  final Value<String> category;
  final Value<DateTime> publishedAt;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const NewsItemCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.url = const Value.absent(),
    this.category = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NewsItemCompanion.insert({
    required String id,
    required String source,
    required String title,
    this.content = const Value.absent(),
    required String url,
    required String category,
    required DateTime publishedAt,
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       source = Value(source),
       title = Value(title),
       url = Value(url),
       category = Value(category),
       publishedAt = Value(publishedAt);
  static Insertable<NewsItemEntry> custom({
    Expression<String>? id,
    Expression<String>? source,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? url,
    Expression<String>? category,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (url != null) 'url': url,
      if (category != null) 'category': category,
      if (publishedAt != null) 'published_at': publishedAt,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NewsItemCompanion copyWith({
    Value<String>? id,
    Value<String>? source,
    Value<String>? title,
    Value<String?>? content,
    Value<String>? url,
    Value<String>? category,
    Value<DateTime>? publishedAt,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return NewsItemCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      title: title ?? this.title,
      content: content ?? this.content,
      url: url ?? this.url,
      category: category ?? this.category,
      publishedAt: publishedAt ?? this.publishedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewsItemCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('url: $url, ')
          ..write('category: $category, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NewsStockMapTable extends NewsStockMap
    with TableInfo<$NewsStockMapTable, NewsStockMapEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NewsStockMapTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _newsIdMeta = const VerificationMeta('newsId');
  @override
  late final GeneratedColumn<String> newsId = GeneratedColumn<String>(
    'news_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES news_item (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [newsId, symbol];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_stock_map';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewsStockMapEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('news_id')) {
      context.handle(
        _newsIdMeta,
        newsId.isAcceptableOrUnknown(data['news_id']!, _newsIdMeta),
      );
    } else if (isInserting) {
      context.missing(_newsIdMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {newsId, symbol};
  @override
  NewsStockMapEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewsStockMapEntry(
      newsId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}news_id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
    );
  }

  @override
  $NewsStockMapTable createAlias(String alias) {
    return $NewsStockMapTable(attachedDatabase, alias);
  }
}

class NewsStockMapEntry extends DataClass
    implements Insertable<NewsStockMapEntry> {
  /// 新聞 ID
  final String newsId;

  /// 關聯股票代碼
  final String symbol;
  const NewsStockMapEntry({required this.newsId, required this.symbol});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['news_id'] = Variable<String>(newsId);
    map['symbol'] = Variable<String>(symbol);
    return map;
  }

  NewsStockMapCompanion toCompanion(bool nullToAbsent) {
    return NewsStockMapCompanion(newsId: Value(newsId), symbol: Value(symbol));
  }

  factory NewsStockMapEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewsStockMapEntry(
      newsId: serializer.fromJson<String>(json['newsId']),
      symbol: serializer.fromJson<String>(json['symbol']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'newsId': serializer.toJson<String>(newsId),
      'symbol': serializer.toJson<String>(symbol),
    };
  }

  NewsStockMapEntry copyWith({String? newsId, String? symbol}) =>
      NewsStockMapEntry(
        newsId: newsId ?? this.newsId,
        symbol: symbol ?? this.symbol,
      );
  NewsStockMapEntry copyWithCompanion(NewsStockMapCompanion data) {
    return NewsStockMapEntry(
      newsId: data.newsId.present ? data.newsId.value : this.newsId,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewsStockMapEntry(')
          ..write('newsId: $newsId, ')
          ..write('symbol: $symbol')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(newsId, symbol);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewsStockMapEntry &&
          other.newsId == this.newsId &&
          other.symbol == this.symbol);
}

class NewsStockMapCompanion extends UpdateCompanion<NewsStockMapEntry> {
  final Value<String> newsId;
  final Value<String> symbol;
  final Value<int> rowid;
  const NewsStockMapCompanion({
    this.newsId = const Value.absent(),
    this.symbol = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NewsStockMapCompanion.insert({
    required String newsId,
    required String symbol,
    this.rowid = const Value.absent(),
  }) : newsId = Value(newsId),
       symbol = Value(symbol);
  static Insertable<NewsStockMapEntry> custom({
    Expression<String>? newsId,
    Expression<String>? symbol,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (newsId != null) 'news_id': newsId,
      if (symbol != null) 'symbol': symbol,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NewsStockMapCompanion copyWith({
    Value<String>? newsId,
    Value<String>? symbol,
    Value<int>? rowid,
  }) {
    return NewsStockMapCompanion(
      newsId: newsId ?? this.newsId,
      symbol: symbol ?? this.symbol,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (newsId.present) {
      map['news_id'] = Variable<String>(newsId.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewsStockMapCompanion(')
          ..write('newsId: $newsId, ')
          ..write('symbol: $symbol, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyAnalysisTable extends DailyAnalysis
    with TableInfo<$DailyAnalysisTable, DailyAnalysisEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyAnalysisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trendStateMeta = const VerificationMeta(
    'trendState',
  );
  @override
  late final GeneratedColumn<String> trendState = GeneratedColumn<String>(
    'trend_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reversalStateMeta = const VerificationMeta(
    'reversalState',
  );
  @override
  late final GeneratedColumn<String> reversalState = GeneratedColumn<String>(
    'reversal_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NONE'),
  );
  static const VerificationMeta _supportLevelMeta = const VerificationMeta(
    'supportLevel',
  );
  @override
  late final GeneratedColumn<double> supportLevel = GeneratedColumn<double>(
    'support_level',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resistanceLevelMeta = const VerificationMeta(
    'resistanceLevel',
  );
  @override
  late final GeneratedColumn<double> resistanceLevel = GeneratedColumn<double>(
    'resistance_level',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _computedAtMeta = const VerificationMeta(
    'computedAt',
  );
  @override
  late final GeneratedColumn<DateTime> computedAt = GeneratedColumn<DateTime>(
    'computed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    trendState,
    reversalState,
    supportLevel,
    resistanceLevel,
    score,
    computedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_analysis';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyAnalysisEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('trend_state')) {
      context.handle(
        _trendStateMeta,
        trendState.isAcceptableOrUnknown(data['trend_state']!, _trendStateMeta),
      );
    } else if (isInserting) {
      context.missing(_trendStateMeta);
    }
    if (data.containsKey('reversal_state')) {
      context.handle(
        _reversalStateMeta,
        reversalState.isAcceptableOrUnknown(
          data['reversal_state']!,
          _reversalStateMeta,
        ),
      );
    }
    if (data.containsKey('support_level')) {
      context.handle(
        _supportLevelMeta,
        supportLevel.isAcceptableOrUnknown(
          data['support_level']!,
          _supportLevelMeta,
        ),
      );
    }
    if (data.containsKey('resistance_level')) {
      context.handle(
        _resistanceLevelMeta,
        resistanceLevel.isAcceptableOrUnknown(
          data['resistance_level']!,
          _resistanceLevelMeta,
        ),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('computed_at')) {
      context.handle(
        _computedAtMeta,
        computedAt.isAcceptableOrUnknown(data['computed_at']!, _computedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  DailyAnalysisEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyAnalysisEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      trendState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trend_state'],
      )!,
      reversalState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reversal_state'],
      )!,
      supportLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}support_level'],
      ),
      resistanceLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}resistance_level'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      computedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}computed_at'],
      )!,
    );
  }

  @override
  $DailyAnalysisTable createAlias(String alias) {
    return $DailyAnalysisTable(attachedDatabase, alias);
  }
}

class DailyAnalysisEntry extends DataClass
    implements Insertable<DailyAnalysisEntry> {
  /// 股票代碼
  final String symbol;

  /// 分析日期
  final DateTime date;

  /// 趨勢狀態：UP（上漲）、DOWN（下跌）、RANGE（盤整）
  final String trendState;

  /// 反轉狀態：NONE（無）、W2S（弱轉強）、S2W（強轉弱）
  final String reversalState;

  /// 支撐價位
  final double? supportLevel;

  /// 壓力價位
  final double? resistanceLevel;

  /// 所有觸發規則的總分數
  final double score;

  /// 分析運算時間
  final DateTime computedAt;
  const DailyAnalysisEntry({
    required this.symbol,
    required this.date,
    required this.trendState,
    required this.reversalState,
    this.supportLevel,
    this.resistanceLevel,
    required this.score,
    required this.computedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    map['trend_state'] = Variable<String>(trendState);
    map['reversal_state'] = Variable<String>(reversalState);
    if (!nullToAbsent || supportLevel != null) {
      map['support_level'] = Variable<double>(supportLevel);
    }
    if (!nullToAbsent || resistanceLevel != null) {
      map['resistance_level'] = Variable<double>(resistanceLevel);
    }
    map['score'] = Variable<double>(score);
    map['computed_at'] = Variable<DateTime>(computedAt);
    return map;
  }

  DailyAnalysisCompanion toCompanion(bool nullToAbsent) {
    return DailyAnalysisCompanion(
      symbol: Value(symbol),
      date: Value(date),
      trendState: Value(trendState),
      reversalState: Value(reversalState),
      supportLevel: supportLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(supportLevel),
      resistanceLevel: resistanceLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(resistanceLevel),
      score: Value(score),
      computedAt: Value(computedAt),
    );
  }

  factory DailyAnalysisEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyAnalysisEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      trendState: serializer.fromJson<String>(json['trendState']),
      reversalState: serializer.fromJson<String>(json['reversalState']),
      supportLevel: serializer.fromJson<double?>(json['supportLevel']),
      resistanceLevel: serializer.fromJson<double?>(json['resistanceLevel']),
      score: serializer.fromJson<double>(json['score']),
      computedAt: serializer.fromJson<DateTime>(json['computedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'trendState': serializer.toJson<String>(trendState),
      'reversalState': serializer.toJson<String>(reversalState),
      'supportLevel': serializer.toJson<double?>(supportLevel),
      'resistanceLevel': serializer.toJson<double?>(resistanceLevel),
      'score': serializer.toJson<double>(score),
      'computedAt': serializer.toJson<DateTime>(computedAt),
    };
  }

  DailyAnalysisEntry copyWith({
    String? symbol,
    DateTime? date,
    String? trendState,
    String? reversalState,
    Value<double?> supportLevel = const Value.absent(),
    Value<double?> resistanceLevel = const Value.absent(),
    double? score,
    DateTime? computedAt,
  }) => DailyAnalysisEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    trendState: trendState ?? this.trendState,
    reversalState: reversalState ?? this.reversalState,
    supportLevel: supportLevel.present ? supportLevel.value : this.supportLevel,
    resistanceLevel: resistanceLevel.present
        ? resistanceLevel.value
        : this.resistanceLevel,
    score: score ?? this.score,
    computedAt: computedAt ?? this.computedAt,
  );
  DailyAnalysisEntry copyWithCompanion(DailyAnalysisCompanion data) {
    return DailyAnalysisEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      trendState: data.trendState.present
          ? data.trendState.value
          : this.trendState,
      reversalState: data.reversalState.present
          ? data.reversalState.value
          : this.reversalState,
      supportLevel: data.supportLevel.present
          ? data.supportLevel.value
          : this.supportLevel,
      resistanceLevel: data.resistanceLevel.present
          ? data.resistanceLevel.value
          : this.resistanceLevel,
      score: data.score.present ? data.score.value : this.score,
      computedAt: data.computedAt.present
          ? data.computedAt.value
          : this.computedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyAnalysisEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('trendState: $trendState, ')
          ..write('reversalState: $reversalState, ')
          ..write('supportLevel: $supportLevel, ')
          ..write('resistanceLevel: $resistanceLevel, ')
          ..write('score: $score, ')
          ..write('computedAt: $computedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    date,
    trendState,
    reversalState,
    supportLevel,
    resistanceLevel,
    score,
    computedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyAnalysisEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.trendState == this.trendState &&
          other.reversalState == this.reversalState &&
          other.supportLevel == this.supportLevel &&
          other.resistanceLevel == this.resistanceLevel &&
          other.score == this.score &&
          other.computedAt == this.computedAt);
}

class DailyAnalysisCompanion extends UpdateCompanion<DailyAnalysisEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<String> trendState;
  final Value<String> reversalState;
  final Value<double?> supportLevel;
  final Value<double?> resistanceLevel;
  final Value<double> score;
  final Value<DateTime> computedAt;
  final Value<int> rowid;
  const DailyAnalysisCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.trendState = const Value.absent(),
    this.reversalState = const Value.absent(),
    this.supportLevel = const Value.absent(),
    this.resistanceLevel = const Value.absent(),
    this.score = const Value.absent(),
    this.computedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyAnalysisCompanion.insert({
    required String symbol,
    required DateTime date,
    required String trendState,
    this.reversalState = const Value.absent(),
    this.supportLevel = const Value.absent(),
    this.resistanceLevel = const Value.absent(),
    this.score = const Value.absent(),
    this.computedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date),
       trendState = Value(trendState);
  static Insertable<DailyAnalysisEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<String>? trendState,
    Expression<String>? reversalState,
    Expression<double>? supportLevel,
    Expression<double>? resistanceLevel,
    Expression<double>? score,
    Expression<DateTime>? computedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (trendState != null) 'trend_state': trendState,
      if (reversalState != null) 'reversal_state': reversalState,
      if (supportLevel != null) 'support_level': supportLevel,
      if (resistanceLevel != null) 'resistance_level': resistanceLevel,
      if (score != null) 'score': score,
      if (computedAt != null) 'computed_at': computedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyAnalysisCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<String>? trendState,
    Value<String>? reversalState,
    Value<double?>? supportLevel,
    Value<double?>? resistanceLevel,
    Value<double>? score,
    Value<DateTime>? computedAt,
    Value<int>? rowid,
  }) {
    return DailyAnalysisCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      trendState: trendState ?? this.trendState,
      reversalState: reversalState ?? this.reversalState,
      supportLevel: supportLevel ?? this.supportLevel,
      resistanceLevel: resistanceLevel ?? this.resistanceLevel,
      score: score ?? this.score,
      computedAt: computedAt ?? this.computedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (trendState.present) {
      map['trend_state'] = Variable<String>(trendState.value);
    }
    if (reversalState.present) {
      map['reversal_state'] = Variable<String>(reversalState.value);
    }
    if (supportLevel.present) {
      map['support_level'] = Variable<double>(supportLevel.value);
    }
    if (resistanceLevel.present) {
      map['resistance_level'] = Variable<double>(resistanceLevel.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (computedAt.present) {
      map['computed_at'] = Variable<DateTime>(computedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyAnalysisCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('trendState: $trendState, ')
          ..write('reversalState: $reversalState, ')
          ..write('supportLevel: $supportLevel, ')
          ..write('resistanceLevel: $resistanceLevel, ')
          ..write('score: $score, ')
          ..write('computedAt: $computedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyReasonTable extends DailyReason
    with TableInfo<$DailyReasonTable, DailyReasonEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyReasonTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonTypeMeta = const VerificationMeta(
    'reasonType',
  );
  @override
  late final GeneratedColumn<String> reasonType = GeneratedColumn<String>(
    'reason_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceJsonMeta = const VerificationMeta(
    'evidenceJson',
  );
  @override
  late final GeneratedColumn<String> evidenceJson = GeneratedColumn<String>(
    'evidence_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleScoreMeta = const VerificationMeta(
    'ruleScore',
  );
  @override
  late final GeneratedColumn<double> ruleScore = GeneratedColumn<double>(
    'rule_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    rank,
    reasonType,
    evidenceJson,
    ruleScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_reason';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyReasonEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    } else if (isInserting) {
      context.missing(_rankMeta);
    }
    if (data.containsKey('reason_type')) {
      context.handle(
        _reasonTypeMeta,
        reasonType.isAcceptableOrUnknown(data['reason_type']!, _reasonTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonTypeMeta);
    }
    if (data.containsKey('evidence_json')) {
      context.handle(
        _evidenceJsonMeta,
        evidenceJson.isAcceptableOrUnknown(
          data['evidence_json']!,
          _evidenceJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceJsonMeta);
    }
    if (data.containsKey('rule_score')) {
      context.handle(
        _ruleScoreMeta,
        ruleScore.isAcceptableOrUnknown(data['rule_score']!, _ruleScoreMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date, rank};
  @override
  DailyReasonEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyReasonEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      )!,
      reasonType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_type'],
      )!,
      evidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_json'],
      )!,
      ruleScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rule_score'],
      )!,
    );
  }

  @override
  $DailyReasonTable createAlias(String alias) {
    return $DailyReasonTable(attachedDatabase, alias);
  }
}

class DailyReasonEntry extends DataClass
    implements Insertable<DailyReasonEntry> {
  /// 股票代碼
  final String symbol;

  /// 分析日期
  final DateTime date;

  /// 原因排序（1 = 主要、2 = 次要）
  final int rank;

  /// 原因類型代碼
  final String reasonType;

  /// 證據資料（JSON 格式）
  final String evidenceJson;

  /// 此規則的分數
  final double ruleScore;
  const DailyReasonEntry({
    required this.symbol,
    required this.date,
    required this.rank,
    required this.reasonType,
    required this.evidenceJson,
    required this.ruleScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    map['rank'] = Variable<int>(rank);
    map['reason_type'] = Variable<String>(reasonType);
    map['evidence_json'] = Variable<String>(evidenceJson);
    map['rule_score'] = Variable<double>(ruleScore);
    return map;
  }

  DailyReasonCompanion toCompanion(bool nullToAbsent) {
    return DailyReasonCompanion(
      symbol: Value(symbol),
      date: Value(date),
      rank: Value(rank),
      reasonType: Value(reasonType),
      evidenceJson: Value(evidenceJson),
      ruleScore: Value(ruleScore),
    );
  }

  factory DailyReasonEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyReasonEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      rank: serializer.fromJson<int>(json['rank']),
      reasonType: serializer.fromJson<String>(json['reasonType']),
      evidenceJson: serializer.fromJson<String>(json['evidenceJson']),
      ruleScore: serializer.fromJson<double>(json['ruleScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'rank': serializer.toJson<int>(rank),
      'reasonType': serializer.toJson<String>(reasonType),
      'evidenceJson': serializer.toJson<String>(evidenceJson),
      'ruleScore': serializer.toJson<double>(ruleScore),
    };
  }

  DailyReasonEntry copyWith({
    String? symbol,
    DateTime? date,
    int? rank,
    String? reasonType,
    String? evidenceJson,
    double? ruleScore,
  }) => DailyReasonEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    rank: rank ?? this.rank,
    reasonType: reasonType ?? this.reasonType,
    evidenceJson: evidenceJson ?? this.evidenceJson,
    ruleScore: ruleScore ?? this.ruleScore,
  );
  DailyReasonEntry copyWithCompanion(DailyReasonCompanion data) {
    return DailyReasonEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      rank: data.rank.present ? data.rank.value : this.rank,
      reasonType: data.reasonType.present
          ? data.reasonType.value
          : this.reasonType,
      evidenceJson: data.evidenceJson.present
          ? data.evidenceJson.value
          : this.evidenceJson,
      ruleScore: data.ruleScore.present ? data.ruleScore.value : this.ruleScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyReasonEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('rank: $rank, ')
          ..write('reasonType: $reasonType, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('ruleScore: $ruleScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(symbol, date, rank, reasonType, evidenceJson, ruleScore);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyReasonEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.rank == this.rank &&
          other.reasonType == this.reasonType &&
          other.evidenceJson == this.evidenceJson &&
          other.ruleScore == this.ruleScore);
}

class DailyReasonCompanion extends UpdateCompanion<DailyReasonEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<int> rank;
  final Value<String> reasonType;
  final Value<String> evidenceJson;
  final Value<double> ruleScore;
  final Value<int> rowid;
  const DailyReasonCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.rank = const Value.absent(),
    this.reasonType = const Value.absent(),
    this.evidenceJson = const Value.absent(),
    this.ruleScore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyReasonCompanion.insert({
    required String symbol,
    required DateTime date,
    required int rank,
    required String reasonType,
    required String evidenceJson,
    this.ruleScore = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date),
       rank = Value(rank),
       reasonType = Value(reasonType),
       evidenceJson = Value(evidenceJson);
  static Insertable<DailyReasonEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<int>? rank,
    Expression<String>? reasonType,
    Expression<String>? evidenceJson,
    Expression<double>? ruleScore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (rank != null) 'rank': rank,
      if (reasonType != null) 'reason_type': reasonType,
      if (evidenceJson != null) 'evidence_json': evidenceJson,
      if (ruleScore != null) 'rule_score': ruleScore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyReasonCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<int>? rank,
    Value<String>? reasonType,
    Value<String>? evidenceJson,
    Value<double>? ruleScore,
    Value<int>? rowid,
  }) {
    return DailyReasonCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      rank: rank ?? this.rank,
      reasonType: reasonType ?? this.reasonType,
      evidenceJson: evidenceJson ?? this.evidenceJson,
      ruleScore: ruleScore ?? this.ruleScore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (reasonType.present) {
      map['reason_type'] = Variable<String>(reasonType.value);
    }
    if (evidenceJson.present) {
      map['evidence_json'] = Variable<String>(evidenceJson.value);
    }
    if (ruleScore.present) {
      map['rule_score'] = Variable<double>(ruleScore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyReasonCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('rank: $rank, ')
          ..write('reasonType: $reasonType, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('ruleScore: $ruleScore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyRecommendationTable extends DailyRecommendation
    with TableInfo<$DailyRecommendationTable, DailyRecommendationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyRecommendationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date, rank, symbol, score];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_recommendation';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyRecommendationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    } else if (isInserting) {
      context.missing(_rankMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, rank};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date, symbol},
  ];
  @override
  DailyRecommendationEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyRecommendationEntry(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
    );
  }

  @override
  $DailyRecommendationTable createAlias(String alias) {
    return $DailyRecommendationTable(attachedDatabase, alias);
  }
}

class DailyRecommendationEntry extends DataClass
    implements Insertable<DailyRecommendationEntry> {
  /// 推薦日期
  final DateTime date;

  /// 排名（1-10）
  final int rank;

  /// 股票代碼
  final String symbol;

  /// 總分數
  final double score;
  const DailyRecommendationEntry({
    required this.date,
    required this.rank,
    required this.symbol,
    required this.score,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['rank'] = Variable<int>(rank);
    map['symbol'] = Variable<String>(symbol);
    map['score'] = Variable<double>(score);
    return map;
  }

  DailyRecommendationCompanion toCompanion(bool nullToAbsent) {
    return DailyRecommendationCompanion(
      date: Value(date),
      rank: Value(rank),
      symbol: Value(symbol),
      score: Value(score),
    );
  }

  factory DailyRecommendationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyRecommendationEntry(
      date: serializer.fromJson<DateTime>(json['date']),
      rank: serializer.fromJson<int>(json['rank']),
      symbol: serializer.fromJson<String>(json['symbol']),
      score: serializer.fromJson<double>(json['score']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'rank': serializer.toJson<int>(rank),
      'symbol': serializer.toJson<String>(symbol),
      'score': serializer.toJson<double>(score),
    };
  }

  DailyRecommendationEntry copyWith({
    DateTime? date,
    int? rank,
    String? symbol,
    double? score,
  }) => DailyRecommendationEntry(
    date: date ?? this.date,
    rank: rank ?? this.rank,
    symbol: symbol ?? this.symbol,
    score: score ?? this.score,
  );
  DailyRecommendationEntry copyWithCompanion(
    DailyRecommendationCompanion data,
  ) {
    return DailyRecommendationEntry(
      date: data.date.present ? data.date.value : this.date,
      rank: data.rank.present ? data.rank.value : this.rank,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      score: data.score.present ? data.score.value : this.score,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyRecommendationEntry(')
          ..write('date: $date, ')
          ..write('rank: $rank, ')
          ..write('symbol: $symbol, ')
          ..write('score: $score')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, rank, symbol, score);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyRecommendationEntry &&
          other.date == this.date &&
          other.rank == this.rank &&
          other.symbol == this.symbol &&
          other.score == this.score);
}

class DailyRecommendationCompanion
    extends UpdateCompanion<DailyRecommendationEntry> {
  final Value<DateTime> date;
  final Value<int> rank;
  final Value<String> symbol;
  final Value<double> score;
  final Value<int> rowid;
  const DailyRecommendationCompanion({
    this.date = const Value.absent(),
    this.rank = const Value.absent(),
    this.symbol = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyRecommendationCompanion.insert({
    required DateTime date,
    required int rank,
    required String symbol,
    required double score,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       rank = Value(rank),
       symbol = Value(symbol),
       score = Value(score);
  static Insertable<DailyRecommendationEntry> custom({
    Expression<DateTime>? date,
    Expression<int>? rank,
    Expression<String>? symbol,
    Expression<double>? score,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (rank != null) 'rank': rank,
      if (symbol != null) 'symbol': symbol,
      if (score != null) 'score': score,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyRecommendationCompanion copyWith({
    Value<DateTime>? date,
    Value<int>? rank,
    Value<String>? symbol,
    Value<double>? score,
    Value<int>? rowid,
  }) {
    return DailyRecommendationCompanion(
      date: date ?? this.date,
      rank: rank ?? this.rank,
      symbol: symbol ?? this.symbol,
      score: score ?? this.score,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyRecommendationCompanion(')
          ..write('date: $date, ')
          ..write('rank: $rank, ')
          ..write('symbol: $symbol, ')
          ..write('score: $score, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuleAccuracyTable extends RuleAccuracy
    with TableInfo<$RuleAccuracyTable, RuleAccuracyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleAccuracyTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<String> ruleId = GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
    'period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triggerCountMeta = const VerificationMeta(
    'triggerCount',
  );
  @override
  late final GeneratedColumn<int> triggerCount = GeneratedColumn<int>(
    'trigger_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _successCountMeta = const VerificationMeta(
    'successCount',
  );
  @override
  late final GeneratedColumn<int> successCount = GeneratedColumn<int>(
    'success_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgReturnMeta = const VerificationMeta(
    'avgReturn',
  );
  @override
  late final GeneratedColumn<double> avgReturn = GeneratedColumn<double>(
    'avg_return',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ruleId,
    period,
    triggerCount,
    successCount,
    avgReturn,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rule_accuracy';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleAccuracyEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('period')) {
      context.handle(
        _periodMeta,
        period.isAcceptableOrUnknown(data['period']!, _periodMeta),
      );
    } else if (isInserting) {
      context.missing(_periodMeta);
    }
    if (data.containsKey('trigger_count')) {
      context.handle(
        _triggerCountMeta,
        triggerCount.isAcceptableOrUnknown(
          data['trigger_count']!,
          _triggerCountMeta,
        ),
      );
    }
    if (data.containsKey('success_count')) {
      context.handle(
        _successCountMeta,
        successCount.isAcceptableOrUnknown(
          data['success_count']!,
          _successCountMeta,
        ),
      );
    }
    if (data.containsKey('avg_return')) {
      context.handle(
        _avgReturnMeta,
        avgReturn.isAcceptableOrUnknown(data['avg_return']!, _avgReturnMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ruleId, period};
  @override
  RuleAccuracyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleAccuracyEntry(
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      )!,
      period: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period'],
      )!,
      triggerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trigger_count'],
      )!,
      successCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}success_count'],
      )!,
      avgReturn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_return'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RuleAccuracyTable createAlias(String alias) {
    return $RuleAccuracyTable(attachedDatabase, alias);
  }
}

class RuleAccuracyEntry extends DataClass
    implements Insertable<RuleAccuracyEntry> {
  /// 規則 ID（如 reversal_w2s）
  final String ruleId;

  /// 統計週期：DAILY、WEEKLY、MONTHLY
  final String period;

  /// 觸發次數
  final int triggerCount;

  /// 成功次數（N 日後上漲）
  final int successCount;

  /// 平均報酬率（%）
  final double avgReturn;

  /// 最後更新時間
  final DateTime updatedAt;
  const RuleAccuracyEntry({
    required this.ruleId,
    required this.period,
    required this.triggerCount,
    required this.successCount,
    required this.avgReturn,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['rule_id'] = Variable<String>(ruleId);
    map['period'] = Variable<String>(period);
    map['trigger_count'] = Variable<int>(triggerCount);
    map['success_count'] = Variable<int>(successCount);
    map['avg_return'] = Variable<double>(avgReturn);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RuleAccuracyCompanion toCompanion(bool nullToAbsent) {
    return RuleAccuracyCompanion(
      ruleId: Value(ruleId),
      period: Value(period),
      triggerCount: Value(triggerCount),
      successCount: Value(successCount),
      avgReturn: Value(avgReturn),
      updatedAt: Value(updatedAt),
    );
  }

  factory RuleAccuracyEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleAccuracyEntry(
      ruleId: serializer.fromJson<String>(json['ruleId']),
      period: serializer.fromJson<String>(json['period']),
      triggerCount: serializer.fromJson<int>(json['triggerCount']),
      successCount: serializer.fromJson<int>(json['successCount']),
      avgReturn: serializer.fromJson<double>(json['avgReturn']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ruleId': serializer.toJson<String>(ruleId),
      'period': serializer.toJson<String>(period),
      'triggerCount': serializer.toJson<int>(triggerCount),
      'successCount': serializer.toJson<int>(successCount),
      'avgReturn': serializer.toJson<double>(avgReturn),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RuleAccuracyEntry copyWith({
    String? ruleId,
    String? period,
    int? triggerCount,
    int? successCount,
    double? avgReturn,
    DateTime? updatedAt,
  }) => RuleAccuracyEntry(
    ruleId: ruleId ?? this.ruleId,
    period: period ?? this.period,
    triggerCount: triggerCount ?? this.triggerCount,
    successCount: successCount ?? this.successCount,
    avgReturn: avgReturn ?? this.avgReturn,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RuleAccuracyEntry copyWithCompanion(RuleAccuracyCompanion data) {
    return RuleAccuracyEntry(
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      period: data.period.present ? data.period.value : this.period,
      triggerCount: data.triggerCount.present
          ? data.triggerCount.value
          : this.triggerCount,
      successCount: data.successCount.present
          ? data.successCount.value
          : this.successCount,
      avgReturn: data.avgReturn.present ? data.avgReturn.value : this.avgReturn,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleAccuracyEntry(')
          ..write('ruleId: $ruleId, ')
          ..write('period: $period, ')
          ..write('triggerCount: $triggerCount, ')
          ..write('successCount: $successCount, ')
          ..write('avgReturn: $avgReturn, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ruleId,
    period,
    triggerCount,
    successCount,
    avgReturn,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleAccuracyEntry &&
          other.ruleId == this.ruleId &&
          other.period == this.period &&
          other.triggerCount == this.triggerCount &&
          other.successCount == this.successCount &&
          other.avgReturn == this.avgReturn &&
          other.updatedAt == this.updatedAt);
}

class RuleAccuracyCompanion extends UpdateCompanion<RuleAccuracyEntry> {
  final Value<String> ruleId;
  final Value<String> period;
  final Value<int> triggerCount;
  final Value<int> successCount;
  final Value<double> avgReturn;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RuleAccuracyCompanion({
    this.ruleId = const Value.absent(),
    this.period = const Value.absent(),
    this.triggerCount = const Value.absent(),
    this.successCount = const Value.absent(),
    this.avgReturn = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuleAccuracyCompanion.insert({
    required String ruleId,
    required String period,
    this.triggerCount = const Value.absent(),
    this.successCount = const Value.absent(),
    this.avgReturn = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ruleId = Value(ruleId),
       period = Value(period);
  static Insertable<RuleAccuracyEntry> custom({
    Expression<String>? ruleId,
    Expression<String>? period,
    Expression<int>? triggerCount,
    Expression<int>? successCount,
    Expression<double>? avgReturn,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ruleId != null) 'rule_id': ruleId,
      if (period != null) 'period': period,
      if (triggerCount != null) 'trigger_count': triggerCount,
      if (successCount != null) 'success_count': successCount,
      if (avgReturn != null) 'avg_return': avgReturn,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuleAccuracyCompanion copyWith({
    Value<String>? ruleId,
    Value<String>? period,
    Value<int>? triggerCount,
    Value<int>? successCount,
    Value<double>? avgReturn,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RuleAccuracyCompanion(
      ruleId: ruleId ?? this.ruleId,
      period: period ?? this.period,
      triggerCount: triggerCount ?? this.triggerCount,
      successCount: successCount ?? this.successCount,
      avgReturn: avgReturn ?? this.avgReturn,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ruleId.present) {
      map['rule_id'] = Variable<String>(ruleId.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (triggerCount.present) {
      map['trigger_count'] = Variable<int>(triggerCount.value);
    }
    if (successCount.present) {
      map['success_count'] = Variable<int>(successCount.value);
    }
    if (avgReturn.present) {
      map['avg_return'] = Variable<double>(avgReturn.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuleAccuracyCompanion(')
          ..write('ruleId: $ruleId, ')
          ..write('period: $period, ')
          ..write('triggerCount: $triggerCount, ')
          ..write('successCount: $successCount, ')
          ..write('avgReturn: $avgReturn, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecommendationValidationTable extends RecommendationValidation
    with
        TableInfo<
          $RecommendationValidationTable,
          RecommendationValidationEntry
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecommendationValidationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recommendationDateMeta =
      const VerificationMeta('recommendationDate');
  @override
  late final GeneratedColumn<DateTime> recommendationDate =
      GeneratedColumn<DateTime>(
        'recommendation_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _primaryRuleIdMeta = const VerificationMeta(
    'primaryRuleId',
  );
  @override
  late final GeneratedColumn<String> primaryRuleId = GeneratedColumn<String>(
    'primary_rule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryPriceMeta = const VerificationMeta(
    'entryPrice',
  );
  @override
  late final GeneratedColumn<double> entryPrice = GeneratedColumn<double>(
    'entry_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exitPriceMeta = const VerificationMeta(
    'exitPrice',
  );
  @override
  late final GeneratedColumn<double> exitPrice = GeneratedColumn<double>(
    'exit_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _returnRateMeta = const VerificationMeta(
    'returnRate',
  );
  @override
  late final GeneratedColumn<double> returnRate = GeneratedColumn<double>(
    'return_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSuccessMeta = const VerificationMeta(
    'isSuccess',
  );
  @override
  late final GeneratedColumn<bool> isSuccess = GeneratedColumn<bool>(
    'is_success',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_success" IN (0, 1))',
    ),
  );
  static const VerificationMeta _validationDateMeta = const VerificationMeta(
    'validationDate',
  );
  @override
  late final GeneratedColumn<DateTime> validationDate =
      GeneratedColumn<DateTime>(
        'validation_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _holdingDaysMeta = const VerificationMeta(
    'holdingDays',
  );
  @override
  late final GeneratedColumn<int> holdingDays = GeneratedColumn<int>(
    'holding_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recommendationDate,
    symbol,
    primaryRuleId,
    entryPrice,
    exitPrice,
    returnRate,
    isSuccess,
    validationDate,
    holdingDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recommendation_validation';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecommendationValidationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recommendation_date')) {
      context.handle(
        _recommendationDateMeta,
        recommendationDate.isAcceptableOrUnknown(
          data['recommendation_date']!,
          _recommendationDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recommendationDateMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('primary_rule_id')) {
      context.handle(
        _primaryRuleIdMeta,
        primaryRuleId.isAcceptableOrUnknown(
          data['primary_rule_id']!,
          _primaryRuleIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_primaryRuleIdMeta);
    }
    if (data.containsKey('entry_price')) {
      context.handle(
        _entryPriceMeta,
        entryPrice.isAcceptableOrUnknown(data['entry_price']!, _entryPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_entryPriceMeta);
    }
    if (data.containsKey('exit_price')) {
      context.handle(
        _exitPriceMeta,
        exitPrice.isAcceptableOrUnknown(data['exit_price']!, _exitPriceMeta),
      );
    }
    if (data.containsKey('return_rate')) {
      context.handle(
        _returnRateMeta,
        returnRate.isAcceptableOrUnknown(data['return_rate']!, _returnRateMeta),
      );
    }
    if (data.containsKey('is_success')) {
      context.handle(
        _isSuccessMeta,
        isSuccess.isAcceptableOrUnknown(data['is_success']!, _isSuccessMeta),
      );
    }
    if (data.containsKey('validation_date')) {
      context.handle(
        _validationDateMeta,
        validationDate.isAcceptableOrUnknown(
          data['validation_date']!,
          _validationDateMeta,
        ),
      );
    }
    if (data.containsKey('holding_days')) {
      context.handle(
        _holdingDaysMeta,
        holdingDays.isAcceptableOrUnknown(
          data['holding_days']!,
          _holdingDaysMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecommendationValidationEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecommendationValidationEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recommendationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recommendation_date'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      primaryRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_rule_id'],
      )!,
      entryPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}entry_price'],
      )!,
      exitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}exit_price'],
      ),
      returnRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}return_rate'],
      ),
      isSuccess: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_success'],
      ),
      validationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}validation_date'],
      ),
      holdingDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}holding_days'],
      )!,
    );
  }

  @override
  $RecommendationValidationTable createAlias(String alias) {
    return $RecommendationValidationTable(attachedDatabase, alias);
  }
}

class RecommendationValidationEntry extends DataClass
    implements Insertable<RecommendationValidationEntry> {
  /// 自增 ID
  final int id;

  /// 推薦日期
  final DateTime recommendationDate;

  /// 股票代碼
  final String symbol;

  /// 主要觸發規則
  final String primaryRuleId;

  /// 推薦當日收盤價
  final double entryPrice;

  /// N 日後收盤價
  final double? exitPrice;

  /// N 日後報酬率（%）
  final double? returnRate;

  /// 是否成功（報酬 > 0）
  final bool? isSuccess;

  /// 驗證日期（N 日後的日期）
  final DateTime? validationDate;

  /// 驗證天數（預設 5 日）
  final int holdingDays;
  const RecommendationValidationEntry({
    required this.id,
    required this.recommendationDate,
    required this.symbol,
    required this.primaryRuleId,
    required this.entryPrice,
    this.exitPrice,
    this.returnRate,
    this.isSuccess,
    this.validationDate,
    required this.holdingDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recommendation_date'] = Variable<DateTime>(recommendationDate);
    map['symbol'] = Variable<String>(symbol);
    map['primary_rule_id'] = Variable<String>(primaryRuleId);
    map['entry_price'] = Variable<double>(entryPrice);
    if (!nullToAbsent || exitPrice != null) {
      map['exit_price'] = Variable<double>(exitPrice);
    }
    if (!nullToAbsent || returnRate != null) {
      map['return_rate'] = Variable<double>(returnRate);
    }
    if (!nullToAbsent || isSuccess != null) {
      map['is_success'] = Variable<bool>(isSuccess);
    }
    if (!nullToAbsent || validationDate != null) {
      map['validation_date'] = Variable<DateTime>(validationDate);
    }
    map['holding_days'] = Variable<int>(holdingDays);
    return map;
  }

  RecommendationValidationCompanion toCompanion(bool nullToAbsent) {
    return RecommendationValidationCompanion(
      id: Value(id),
      recommendationDate: Value(recommendationDate),
      symbol: Value(symbol),
      primaryRuleId: Value(primaryRuleId),
      entryPrice: Value(entryPrice),
      exitPrice: exitPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(exitPrice),
      returnRate: returnRate == null && nullToAbsent
          ? const Value.absent()
          : Value(returnRate),
      isSuccess: isSuccess == null && nullToAbsent
          ? const Value.absent()
          : Value(isSuccess),
      validationDate: validationDate == null && nullToAbsent
          ? const Value.absent()
          : Value(validationDate),
      holdingDays: Value(holdingDays),
    );
  }

  factory RecommendationValidationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecommendationValidationEntry(
      id: serializer.fromJson<int>(json['id']),
      recommendationDate: serializer.fromJson<DateTime>(
        json['recommendationDate'],
      ),
      symbol: serializer.fromJson<String>(json['symbol']),
      primaryRuleId: serializer.fromJson<String>(json['primaryRuleId']),
      entryPrice: serializer.fromJson<double>(json['entryPrice']),
      exitPrice: serializer.fromJson<double?>(json['exitPrice']),
      returnRate: serializer.fromJson<double?>(json['returnRate']),
      isSuccess: serializer.fromJson<bool?>(json['isSuccess']),
      validationDate: serializer.fromJson<DateTime?>(json['validationDate']),
      holdingDays: serializer.fromJson<int>(json['holdingDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recommendationDate': serializer.toJson<DateTime>(recommendationDate),
      'symbol': serializer.toJson<String>(symbol),
      'primaryRuleId': serializer.toJson<String>(primaryRuleId),
      'entryPrice': serializer.toJson<double>(entryPrice),
      'exitPrice': serializer.toJson<double?>(exitPrice),
      'returnRate': serializer.toJson<double?>(returnRate),
      'isSuccess': serializer.toJson<bool?>(isSuccess),
      'validationDate': serializer.toJson<DateTime?>(validationDate),
      'holdingDays': serializer.toJson<int>(holdingDays),
    };
  }

  RecommendationValidationEntry copyWith({
    int? id,
    DateTime? recommendationDate,
    String? symbol,
    String? primaryRuleId,
    double? entryPrice,
    Value<double?> exitPrice = const Value.absent(),
    Value<double?> returnRate = const Value.absent(),
    Value<bool?> isSuccess = const Value.absent(),
    Value<DateTime?> validationDate = const Value.absent(),
    int? holdingDays,
  }) => RecommendationValidationEntry(
    id: id ?? this.id,
    recommendationDate: recommendationDate ?? this.recommendationDate,
    symbol: symbol ?? this.symbol,
    primaryRuleId: primaryRuleId ?? this.primaryRuleId,
    entryPrice: entryPrice ?? this.entryPrice,
    exitPrice: exitPrice.present ? exitPrice.value : this.exitPrice,
    returnRate: returnRate.present ? returnRate.value : this.returnRate,
    isSuccess: isSuccess.present ? isSuccess.value : this.isSuccess,
    validationDate: validationDate.present
        ? validationDate.value
        : this.validationDate,
    holdingDays: holdingDays ?? this.holdingDays,
  );
  RecommendationValidationEntry copyWithCompanion(
    RecommendationValidationCompanion data,
  ) {
    return RecommendationValidationEntry(
      id: data.id.present ? data.id.value : this.id,
      recommendationDate: data.recommendationDate.present
          ? data.recommendationDate.value
          : this.recommendationDate,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      primaryRuleId: data.primaryRuleId.present
          ? data.primaryRuleId.value
          : this.primaryRuleId,
      entryPrice: data.entryPrice.present
          ? data.entryPrice.value
          : this.entryPrice,
      exitPrice: data.exitPrice.present ? data.exitPrice.value : this.exitPrice,
      returnRate: data.returnRate.present
          ? data.returnRate.value
          : this.returnRate,
      isSuccess: data.isSuccess.present ? data.isSuccess.value : this.isSuccess,
      validationDate: data.validationDate.present
          ? data.validationDate.value
          : this.validationDate,
      holdingDays: data.holdingDays.present
          ? data.holdingDays.value
          : this.holdingDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecommendationValidationEntry(')
          ..write('id: $id, ')
          ..write('recommendationDate: $recommendationDate, ')
          ..write('symbol: $symbol, ')
          ..write('primaryRuleId: $primaryRuleId, ')
          ..write('entryPrice: $entryPrice, ')
          ..write('exitPrice: $exitPrice, ')
          ..write('returnRate: $returnRate, ')
          ..write('isSuccess: $isSuccess, ')
          ..write('validationDate: $validationDate, ')
          ..write('holdingDays: $holdingDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recommendationDate,
    symbol,
    primaryRuleId,
    entryPrice,
    exitPrice,
    returnRate,
    isSuccess,
    validationDate,
    holdingDays,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecommendationValidationEntry &&
          other.id == this.id &&
          other.recommendationDate == this.recommendationDate &&
          other.symbol == this.symbol &&
          other.primaryRuleId == this.primaryRuleId &&
          other.entryPrice == this.entryPrice &&
          other.exitPrice == this.exitPrice &&
          other.returnRate == this.returnRate &&
          other.isSuccess == this.isSuccess &&
          other.validationDate == this.validationDate &&
          other.holdingDays == this.holdingDays);
}

class RecommendationValidationCompanion
    extends UpdateCompanion<RecommendationValidationEntry> {
  final Value<int> id;
  final Value<DateTime> recommendationDate;
  final Value<String> symbol;
  final Value<String> primaryRuleId;
  final Value<double> entryPrice;
  final Value<double?> exitPrice;
  final Value<double?> returnRate;
  final Value<bool?> isSuccess;
  final Value<DateTime?> validationDate;
  final Value<int> holdingDays;
  const RecommendationValidationCompanion({
    this.id = const Value.absent(),
    this.recommendationDate = const Value.absent(),
    this.symbol = const Value.absent(),
    this.primaryRuleId = const Value.absent(),
    this.entryPrice = const Value.absent(),
    this.exitPrice = const Value.absent(),
    this.returnRate = const Value.absent(),
    this.isSuccess = const Value.absent(),
    this.validationDate = const Value.absent(),
    this.holdingDays = const Value.absent(),
  });
  RecommendationValidationCompanion.insert({
    this.id = const Value.absent(),
    required DateTime recommendationDate,
    required String symbol,
    required String primaryRuleId,
    required double entryPrice,
    this.exitPrice = const Value.absent(),
    this.returnRate = const Value.absent(),
    this.isSuccess = const Value.absent(),
    this.validationDate = const Value.absent(),
    this.holdingDays = const Value.absent(),
  }) : recommendationDate = Value(recommendationDate),
       symbol = Value(symbol),
       primaryRuleId = Value(primaryRuleId),
       entryPrice = Value(entryPrice);
  static Insertable<RecommendationValidationEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? recommendationDate,
    Expression<String>? symbol,
    Expression<String>? primaryRuleId,
    Expression<double>? entryPrice,
    Expression<double>? exitPrice,
    Expression<double>? returnRate,
    Expression<bool>? isSuccess,
    Expression<DateTime>? validationDate,
    Expression<int>? holdingDays,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recommendationDate != null) 'recommendation_date': recommendationDate,
      if (symbol != null) 'symbol': symbol,
      if (primaryRuleId != null) 'primary_rule_id': primaryRuleId,
      if (entryPrice != null) 'entry_price': entryPrice,
      if (exitPrice != null) 'exit_price': exitPrice,
      if (returnRate != null) 'return_rate': returnRate,
      if (isSuccess != null) 'is_success': isSuccess,
      if (validationDate != null) 'validation_date': validationDate,
      if (holdingDays != null) 'holding_days': holdingDays,
    });
  }

  RecommendationValidationCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? recommendationDate,
    Value<String>? symbol,
    Value<String>? primaryRuleId,
    Value<double>? entryPrice,
    Value<double?>? exitPrice,
    Value<double?>? returnRate,
    Value<bool?>? isSuccess,
    Value<DateTime?>? validationDate,
    Value<int>? holdingDays,
  }) {
    return RecommendationValidationCompanion(
      id: id ?? this.id,
      recommendationDate: recommendationDate ?? this.recommendationDate,
      symbol: symbol ?? this.symbol,
      primaryRuleId: primaryRuleId ?? this.primaryRuleId,
      entryPrice: entryPrice ?? this.entryPrice,
      exitPrice: exitPrice ?? this.exitPrice,
      returnRate: returnRate ?? this.returnRate,
      isSuccess: isSuccess ?? this.isSuccess,
      validationDate: validationDate ?? this.validationDate,
      holdingDays: holdingDays ?? this.holdingDays,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recommendationDate.present) {
      map['recommendation_date'] = Variable<DateTime>(recommendationDate.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (primaryRuleId.present) {
      map['primary_rule_id'] = Variable<String>(primaryRuleId.value);
    }
    if (entryPrice.present) {
      map['entry_price'] = Variable<double>(entryPrice.value);
    }
    if (exitPrice.present) {
      map['exit_price'] = Variable<double>(exitPrice.value);
    }
    if (returnRate.present) {
      map['return_rate'] = Variable<double>(returnRate.value);
    }
    if (isSuccess.present) {
      map['is_success'] = Variable<bool>(isSuccess.value);
    }
    if (validationDate.present) {
      map['validation_date'] = Variable<DateTime>(validationDate.value);
    }
    if (holdingDays.present) {
      map['holding_days'] = Variable<int>(holdingDays.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecommendationValidationCompanion(')
          ..write('id: $id, ')
          ..write('recommendationDate: $recommendationDate, ')
          ..write('symbol: $symbol, ')
          ..write('primaryRuleId: $primaryRuleId, ')
          ..write('entryPrice: $entryPrice, ')
          ..write('exitPrice: $exitPrice, ')
          ..write('returnRate: $returnRate, ')
          ..write('isSuccess: $isSuccess, ')
          ..write('validationDate: $validationDate, ')
          ..write('holdingDays: $holdingDays')
          ..write(')'))
        .toString();
  }
}

class $WatchlistTable extends Watchlist
    with TableInfo<$WatchlistTable, WatchlistEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [symbol, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchlistEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol};
  @override
  WatchlistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WatchlistTable createAlias(String alias) {
    return $WatchlistTable(attachedDatabase, alias);
  }
}

class WatchlistEntry extends DataClass implements Insertable<WatchlistEntry> {
  /// 股票代碼
  final String symbol;

  /// 加入自選股的時間
  final DateTime createdAt;
  const WatchlistEntry({required this.symbol, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WatchlistCompanion toCompanion(bool nullToAbsent) {
    return WatchlistCompanion(
      symbol: Value(symbol),
      createdAt: Value(createdAt),
    );
  }

  factory WatchlistEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WatchlistEntry copyWith({String? symbol, DateTime? createdAt}) =>
      WatchlistEntry(
        symbol: symbol ?? this.symbol,
        createdAt: createdAt ?? this.createdAt,
      );
  WatchlistEntry copyWithCompanion(WatchlistCompanion data) {
    return WatchlistEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistEntry(')
          ..write('symbol: $symbol, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistEntry &&
          other.symbol == this.symbol &&
          other.createdAt == this.createdAt);
}

class WatchlistCompanion extends UpdateCompanion<WatchlistEntry> {
  final Value<String> symbol;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WatchlistCompanion({
    this.symbol = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchlistCompanion.insert({
    required String symbol,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol);
  static Insertable<WatchlistEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchlistCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WatchlistCompanion(
      symbol: symbol ?? this.symbol,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistCompanion(')
          ..write('symbol: $symbol, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserNoteTable extends UserNote
    with TableInfo<$UserNoteTable, UserNoteEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserNoteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    date,
    content,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_note';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserNoteEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserNoteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserNoteEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserNoteTable createAlias(String alias) {
    return $UserNoteTable(attachedDatabase, alias);
  }
}

class UserNoteEntry extends DataClass implements Insertable<UserNoteEntry> {
  /// 自動遞增 ID
  final int id;

  /// 股票代碼
  final String symbol;

  /// 筆記對應的日期（可為空）
  final DateTime? date;

  /// 筆記內容
  final String content;

  /// 建立時間
  final DateTime createdAt;

  /// 最後更新時間
  final DateTime updatedAt;
  const UserNoteEntry({
    required this.id,
    required this.symbol,
    this.date,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<DateTime>(date);
    }
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserNoteCompanion toCompanion(bool nullToAbsent) {
    return UserNoteCompanion(
      id: Value(id),
      symbol: Value(symbol),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      content: Value(content),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserNoteEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserNoteEntry(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime?>(json['date']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime?>(date),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserNoteEntry copyWith({
    int? id,
    String? symbol,
    Value<DateTime?> date = const Value.absent(),
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserNoteEntry(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    date: date.present ? date.value : this.date,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserNoteEntry copyWithCompanion(UserNoteCompanion data) {
    return UserNoteEntry(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserNoteEntry(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, symbol, date, content, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserNoteEntry &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserNoteCompanion extends UpdateCompanion<UserNoteEntry> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<DateTime?> date;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserNoteCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserNoteCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    this.date = const Value.absent(),
    required String content,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : symbol = Value(symbol),
       content = Value(content);
  static Insertable<UserNoteEntry> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserNoteCompanion copyWith({
    Value<int>? id,
    Value<String>? symbol,
    Value<DateTime?>? date,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UserNoteCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserNoteCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $StrategyCardTable extends StrategyCard
    with TableInfo<$StrategyCardTable, StrategyCardEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StrategyCardTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _forDateMeta = const VerificationMeta(
    'forDate',
  );
  @override
  late final GeneratedColumn<DateTime> forDate = GeneratedColumn<DateTime>(
    'for_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ifAMeta = const VerificationMeta('ifA');
  @override
  late final GeneratedColumn<String> ifA = GeneratedColumn<String>(
    'if_a',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thenAMeta = const VerificationMeta('thenA');
  @override
  late final GeneratedColumn<String> thenA = GeneratedColumn<String>(
    'then_a',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ifBMeta = const VerificationMeta('ifB');
  @override
  late final GeneratedColumn<String> ifB = GeneratedColumn<String>(
    'if_b',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thenBMeta = const VerificationMeta('thenB');
  @override
  late final GeneratedColumn<String> thenB = GeneratedColumn<String>(
    'then_b',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elsePlanMeta = const VerificationMeta(
    'elsePlan',
  );
  @override
  late final GeneratedColumn<String> elsePlan = GeneratedColumn<String>(
    'else_plan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    forDate,
    ifA,
    thenA,
    ifB,
    thenB,
    elsePlan,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'strategy_card';
  @override
  VerificationContext validateIntegrity(
    Insertable<StrategyCardEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('for_date')) {
      context.handle(
        _forDateMeta,
        forDate.isAcceptableOrUnknown(data['for_date']!, _forDateMeta),
      );
    }
    if (data.containsKey('if_a')) {
      context.handle(
        _ifAMeta,
        ifA.isAcceptableOrUnknown(data['if_a']!, _ifAMeta),
      );
    }
    if (data.containsKey('then_a')) {
      context.handle(
        _thenAMeta,
        thenA.isAcceptableOrUnknown(data['then_a']!, _thenAMeta),
      );
    }
    if (data.containsKey('if_b')) {
      context.handle(
        _ifBMeta,
        ifB.isAcceptableOrUnknown(data['if_b']!, _ifBMeta),
      );
    }
    if (data.containsKey('then_b')) {
      context.handle(
        _thenBMeta,
        thenB.isAcceptableOrUnknown(data['then_b']!, _thenBMeta),
      );
    }
    if (data.containsKey('else_plan')) {
      context.handle(
        _elsePlanMeta,
        elsePlan.isAcceptableOrUnknown(data['else_plan']!, _elsePlanMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StrategyCardEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StrategyCardEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      forDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}for_date'],
      ),
      ifA: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}if_a'],
      ),
      thenA: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}then_a'],
      ),
      ifB: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}if_b'],
      ),
      thenB: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}then_b'],
      ),
      elsePlan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}else_plan'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StrategyCardTable createAlias(String alias) {
    return $StrategyCardTable(attachedDatabase, alias);
  }
}

class StrategyCardEntry extends DataClass
    implements Insertable<StrategyCardEntry> {
  /// 自動遞增 ID
  final int id;

  /// 股票代碼
  final String symbol;

  /// 策略目標日期
  final DateTime? forDate;

  /// 條件 A
  final String? ifA;

  /// 條件 A 成立時的操作
  final String? thenA;

  /// 條件 B
  final String? ifB;

  /// 條件 B 成立時的操作
  final String? thenB;

  /// 其他情況的操作
  final String? elsePlan;

  /// 建立時間
  final DateTime createdAt;

  /// 最後更新時間
  final DateTime updatedAt;
  const StrategyCardEntry({
    required this.id,
    required this.symbol,
    this.forDate,
    this.ifA,
    this.thenA,
    this.ifB,
    this.thenB,
    this.elsePlan,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    if (!nullToAbsent || forDate != null) {
      map['for_date'] = Variable<DateTime>(forDate);
    }
    if (!nullToAbsent || ifA != null) {
      map['if_a'] = Variable<String>(ifA);
    }
    if (!nullToAbsent || thenA != null) {
      map['then_a'] = Variable<String>(thenA);
    }
    if (!nullToAbsent || ifB != null) {
      map['if_b'] = Variable<String>(ifB);
    }
    if (!nullToAbsent || thenB != null) {
      map['then_b'] = Variable<String>(thenB);
    }
    if (!nullToAbsent || elsePlan != null) {
      map['else_plan'] = Variable<String>(elsePlan);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StrategyCardCompanion toCompanion(bool nullToAbsent) {
    return StrategyCardCompanion(
      id: Value(id),
      symbol: Value(symbol),
      forDate: forDate == null && nullToAbsent
          ? const Value.absent()
          : Value(forDate),
      ifA: ifA == null && nullToAbsent ? const Value.absent() : Value(ifA),
      thenA: thenA == null && nullToAbsent
          ? const Value.absent()
          : Value(thenA),
      ifB: ifB == null && nullToAbsent ? const Value.absent() : Value(ifB),
      thenB: thenB == null && nullToAbsent
          ? const Value.absent()
          : Value(thenB),
      elsePlan: elsePlan == null && nullToAbsent
          ? const Value.absent()
          : Value(elsePlan),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StrategyCardEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StrategyCardEntry(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      forDate: serializer.fromJson<DateTime?>(json['forDate']),
      ifA: serializer.fromJson<String?>(json['ifA']),
      thenA: serializer.fromJson<String?>(json['thenA']),
      ifB: serializer.fromJson<String?>(json['ifB']),
      thenB: serializer.fromJson<String?>(json['thenB']),
      elsePlan: serializer.fromJson<String?>(json['elsePlan']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'forDate': serializer.toJson<DateTime?>(forDate),
      'ifA': serializer.toJson<String?>(ifA),
      'thenA': serializer.toJson<String?>(thenA),
      'ifB': serializer.toJson<String?>(ifB),
      'thenB': serializer.toJson<String?>(thenB),
      'elsePlan': serializer.toJson<String?>(elsePlan),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StrategyCardEntry copyWith({
    int? id,
    String? symbol,
    Value<DateTime?> forDate = const Value.absent(),
    Value<String?> ifA = const Value.absent(),
    Value<String?> thenA = const Value.absent(),
    Value<String?> ifB = const Value.absent(),
    Value<String?> thenB = const Value.absent(),
    Value<String?> elsePlan = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StrategyCardEntry(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    forDate: forDate.present ? forDate.value : this.forDate,
    ifA: ifA.present ? ifA.value : this.ifA,
    thenA: thenA.present ? thenA.value : this.thenA,
    ifB: ifB.present ? ifB.value : this.ifB,
    thenB: thenB.present ? thenB.value : this.thenB,
    elsePlan: elsePlan.present ? elsePlan.value : this.elsePlan,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StrategyCardEntry copyWithCompanion(StrategyCardCompanion data) {
    return StrategyCardEntry(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      forDate: data.forDate.present ? data.forDate.value : this.forDate,
      ifA: data.ifA.present ? data.ifA.value : this.ifA,
      thenA: data.thenA.present ? data.thenA.value : this.thenA,
      ifB: data.ifB.present ? data.ifB.value : this.ifB,
      thenB: data.thenB.present ? data.thenB.value : this.thenB,
      elsePlan: data.elsePlan.present ? data.elsePlan.value : this.elsePlan,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StrategyCardEntry(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('forDate: $forDate, ')
          ..write('ifA: $ifA, ')
          ..write('thenA: $thenA, ')
          ..write('ifB: $ifB, ')
          ..write('thenB: $thenB, ')
          ..write('elsePlan: $elsePlan, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    forDate,
    ifA,
    thenA,
    ifB,
    thenB,
    elsePlan,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StrategyCardEntry &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.forDate == this.forDate &&
          other.ifA == this.ifA &&
          other.thenA == this.thenA &&
          other.ifB == this.ifB &&
          other.thenB == this.thenB &&
          other.elsePlan == this.elsePlan &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StrategyCardCompanion extends UpdateCompanion<StrategyCardEntry> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<DateTime?> forDate;
  final Value<String?> ifA;
  final Value<String?> thenA;
  final Value<String?> ifB;
  final Value<String?> thenB;
  final Value<String?> elsePlan;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const StrategyCardCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.forDate = const Value.absent(),
    this.ifA = const Value.absent(),
    this.thenA = const Value.absent(),
    this.ifB = const Value.absent(),
    this.thenB = const Value.absent(),
    this.elsePlan = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StrategyCardCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    this.forDate = const Value.absent(),
    this.ifA = const Value.absent(),
    this.thenA = const Value.absent(),
    this.ifB = const Value.absent(),
    this.thenB = const Value.absent(),
    this.elsePlan = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : symbol = Value(symbol);
  static Insertable<StrategyCardEntry> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<DateTime>? forDate,
    Expression<String>? ifA,
    Expression<String>? thenA,
    Expression<String>? ifB,
    Expression<String>? thenB,
    Expression<String>? elsePlan,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (forDate != null) 'for_date': forDate,
      if (ifA != null) 'if_a': ifA,
      if (thenA != null) 'then_a': thenA,
      if (ifB != null) 'if_b': ifB,
      if (thenB != null) 'then_b': thenB,
      if (elsePlan != null) 'else_plan': elsePlan,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StrategyCardCompanion copyWith({
    Value<int>? id,
    Value<String>? symbol,
    Value<DateTime?>? forDate,
    Value<String?>? ifA,
    Value<String?>? thenA,
    Value<String?>? ifB,
    Value<String?>? thenB,
    Value<String?>? elsePlan,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return StrategyCardCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      forDate: forDate ?? this.forDate,
      ifA: ifA ?? this.ifA,
      thenA: thenA ?? this.thenA,
      ifB: ifB ?? this.ifB,
      thenB: thenB ?? this.thenB,
      elsePlan: elsePlan ?? this.elsePlan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (forDate.present) {
      map['for_date'] = Variable<DateTime>(forDate.value);
    }
    if (ifA.present) {
      map['if_a'] = Variable<String>(ifA.value);
    }
    if (thenA.present) {
      map['then_a'] = Variable<String>(thenA.value);
    }
    if (ifB.present) {
      map['if_b'] = Variable<String>(ifB.value);
    }
    if (thenB.present) {
      map['then_b'] = Variable<String>(thenB.value);
    }
    if (elsePlan.present) {
      map['else_plan'] = Variable<String>(elsePlan.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StrategyCardCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('forDate: $forDate, ')
          ..write('ifA: $ifA, ')
          ..write('thenA: $thenA, ')
          ..write('ifB: $ifB, ')
          ..write('thenB: $thenB, ')
          ..write('elsePlan: $elsePlan, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $UpdateRunTable extends UpdateRun
    with TableInfo<$UpdateRunTable, UpdateRunEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UpdateRunTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _runDateMeta = const VerificationMeta(
    'runDate',
  );
  @override
  late final GeneratedColumn<DateTime> runDate = GeneratedColumn<DateTime>(
    'run_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runDate,
    startedAt,
    finishedAt,
    status,
    message,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'update_run';
  @override
  VerificationContext validateIntegrity(
    Insertable<UpdateRunEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_date')) {
      context.handle(
        _runDateMeta,
        runDate.isAcceptableOrUnknown(data['run_date']!, _runDateMeta),
      );
    } else if (isInserting) {
      context.missing(_runDateMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UpdateRunEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UpdateRunEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      runDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}run_date'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      ),
    );
  }

  @override
  $UpdateRunTable createAlias(String alias) {
    return $UpdateRunTable(attachedDatabase, alias);
  }
}

class UpdateRunEntry extends DataClass implements Insertable<UpdateRunEntry> {
  /// 自動遞增 ID
  final int id;

  /// 更新的目標日期
  final DateTime runDate;

  /// 開始執行時間
  final DateTime startedAt;

  /// 完成時間（執行中則為空）
  final DateTime? finishedAt;

  /// 狀態：SUCCESS、FAILED、PARTIAL
  final String status;

  /// 訊息（錯誤詳情等）
  final String? message;
  const UpdateRunEntry({
    required this.id,
    required this.runDate,
    required this.startedAt,
    this.finishedAt,
    required this.status,
    this.message,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['run_date'] = Variable<DateTime>(runDate);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    return map;
  }

  UpdateRunCompanion toCompanion(bool nullToAbsent) {
    return UpdateRunCompanion(
      id: Value(id),
      runDate: Value(runDate),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      status: Value(status),
      message: message == null && nullToAbsent
          ? const Value.absent()
          : Value(message),
    );
  }

  factory UpdateRunEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UpdateRunEntry(
      id: serializer.fromJson<int>(json['id']),
      runDate: serializer.fromJson<DateTime>(json['runDate']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      status: serializer.fromJson<String>(json['status']),
      message: serializer.fromJson<String?>(json['message']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runDate': serializer.toJson<DateTime>(runDate),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'status': serializer.toJson<String>(status),
      'message': serializer.toJson<String?>(message),
    };
  }

  UpdateRunEntry copyWith({
    int? id,
    DateTime? runDate,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    String? status,
    Value<String?> message = const Value.absent(),
  }) => UpdateRunEntry(
    id: id ?? this.id,
    runDate: runDate ?? this.runDate,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    status: status ?? this.status,
    message: message.present ? message.value : this.message,
  );
  UpdateRunEntry copyWithCompanion(UpdateRunCompanion data) {
    return UpdateRunEntry(
      id: data.id.present ? data.id.value : this.id,
      runDate: data.runDate.present ? data.runDate.value : this.runDate,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      status: data.status.present ? data.status.value : this.status,
      message: data.message.present ? data.message.value : this.message,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UpdateRunEntry(')
          ..write('id: $id, ')
          ..write('runDate: $runDate, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('status: $status, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, runDate, startedAt, finishedAt, status, message);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpdateRunEntry &&
          other.id == this.id &&
          other.runDate == this.runDate &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.status == this.status &&
          other.message == this.message);
}

class UpdateRunCompanion extends UpdateCompanion<UpdateRunEntry> {
  final Value<int> id;
  final Value<DateTime> runDate;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<String> status;
  final Value<String?> message;
  const UpdateRunCompanion({
    this.id = const Value.absent(),
    this.runDate = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.message = const Value.absent(),
  });
  UpdateRunCompanion.insert({
    this.id = const Value.absent(),
    required DateTime runDate,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    required String status,
    this.message = const Value.absent(),
  }) : runDate = Value(runDate),
       status = Value(status);
  static Insertable<UpdateRunEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? runDate,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? status,
    Expression<String>? message,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runDate != null) 'run_date': runDate,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (status != null) 'status': status,
      if (message != null) 'message': message,
    });
  }

  UpdateRunCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? runDate,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<String>? status,
    Value<String?>? message,
  }) {
    return UpdateRunCompanion(
      id: id ?? this.id,
      runDate: runDate ?? this.runDate,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (runDate.present) {
      map['run_date'] = Variable<DateTime>(runDate.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UpdateRunCompanion(')
          ..write('id: $id, ')
          ..write('runDate: $runDate, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('status: $status, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingEntry extends DataClass implements Insertable<AppSettingEntry> {
  /// 設定鍵
  final String key;

  /// 設定值
  final String value;

  /// 最後更新時間
  final DateTime updatedAt;
  const AppSettingEntry({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSettingEntry copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppSettingEntry(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSettingEntry copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingEntry(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingEntry &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSettingEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PriceAlertTable extends PriceAlert
    with TableInfo<$PriceAlertTable, PriceAlertEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceAlertTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _alertTypeMeta = const VerificationMeta(
    'alertType',
  );
  @override
  late final GeneratedColumn<String> alertType = GeneratedColumn<String>(
    'alert_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetValueMeta = const VerificationMeta(
    'targetValue',
  );
  @override
  late final GeneratedColumn<double> targetValue = GeneratedColumn<double>(
    'target_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _triggeredAtMeta = const VerificationMeta(
    'triggeredAt',
  );
  @override
  late final GeneratedColumn<DateTime> triggeredAt = GeneratedColumn<DateTime>(
    'triggered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    alertType,
    targetValue,
    isActive,
    triggeredAt,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'price_alert';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriceAlertEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('alert_type')) {
      context.handle(
        _alertTypeMeta,
        alertType.isAcceptableOrUnknown(data['alert_type']!, _alertTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_alertTypeMeta);
    }
    if (data.containsKey('target_value')) {
      context.handle(
        _targetValueMeta,
        targetValue.isAcceptableOrUnknown(
          data['target_value']!,
          _targetValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetValueMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('triggered_at')) {
      context.handle(
        _triggeredAtMeta,
        triggeredAt.isAcceptableOrUnknown(
          data['triggered_at']!,
          _triggeredAtMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PriceAlertEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceAlertEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      alertType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alert_type'],
      )!,
      targetValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_value'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      triggeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}triggered_at'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PriceAlertTable createAlias(String alias) {
    return $PriceAlertTable(attachedDatabase, alias);
  }
}

class PriceAlertEntry extends DataClass implements Insertable<PriceAlertEntry> {
  /// 自動遞增 ID
  final int id;

  /// 股票代碼
  final String symbol;

  /// 提醒類型：ABOVE、BELOW、CHANGE_PCT
  final String alertType;

  /// 目標值（價格或百分比）
  final double targetValue;

  /// 是否啟用
  final bool isActive;

  /// 觸發時間（尚未觸發則為空）
  final DateTime? triggeredAt;

  /// 備註說明
  final String? note;

  /// 建立時間
  final DateTime createdAt;
  const PriceAlertEntry({
    required this.id,
    required this.symbol,
    required this.alertType,
    required this.targetValue,
    required this.isActive,
    this.triggeredAt,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    map['alert_type'] = Variable<String>(alertType);
    map['target_value'] = Variable<double>(targetValue);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || triggeredAt != null) {
      map['triggered_at'] = Variable<DateTime>(triggeredAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PriceAlertCompanion toCompanion(bool nullToAbsent) {
    return PriceAlertCompanion(
      id: Value(id),
      symbol: Value(symbol),
      alertType: Value(alertType),
      targetValue: Value(targetValue),
      isActive: Value(isActive),
      triggeredAt: triggeredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(triggeredAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory PriceAlertEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceAlertEntry(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      alertType: serializer.fromJson<String>(json['alertType']),
      targetValue: serializer.fromJson<double>(json['targetValue']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      triggeredAt: serializer.fromJson<DateTime?>(json['triggeredAt']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'alertType': serializer.toJson<String>(alertType),
      'targetValue': serializer.toJson<double>(targetValue),
      'isActive': serializer.toJson<bool>(isActive),
      'triggeredAt': serializer.toJson<DateTime?>(triggeredAt),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PriceAlertEntry copyWith({
    int? id,
    String? symbol,
    String? alertType,
    double? targetValue,
    bool? isActive,
    Value<DateTime?> triggeredAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => PriceAlertEntry(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    alertType: alertType ?? this.alertType,
    targetValue: targetValue ?? this.targetValue,
    isActive: isActive ?? this.isActive,
    triggeredAt: triggeredAt.present ? triggeredAt.value : this.triggeredAt,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  PriceAlertEntry copyWithCompanion(PriceAlertCompanion data) {
    return PriceAlertEntry(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      alertType: data.alertType.present ? data.alertType.value : this.alertType,
      targetValue: data.targetValue.present
          ? data.targetValue.value
          : this.targetValue,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      triggeredAt: data.triggeredAt.present
          ? data.triggeredAt.value
          : this.triggeredAt,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceAlertEntry(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('alertType: $alertType, ')
          ..write('targetValue: $targetValue, ')
          ..write('isActive: $isActive, ')
          ..write('triggeredAt: $triggeredAt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    alertType,
    targetValue,
    isActive,
    triggeredAt,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceAlertEntry &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.alertType == this.alertType &&
          other.targetValue == this.targetValue &&
          other.isActive == this.isActive &&
          other.triggeredAt == this.triggeredAt &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class PriceAlertCompanion extends UpdateCompanion<PriceAlertEntry> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<String> alertType;
  final Value<double> targetValue;
  final Value<bool> isActive;
  final Value<DateTime?> triggeredAt;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  const PriceAlertCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.alertType = const Value.absent(),
    this.targetValue = const Value.absent(),
    this.isActive = const Value.absent(),
    this.triggeredAt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PriceAlertCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    required String alertType,
    required double targetValue,
    this.isActive = const Value.absent(),
    this.triggeredAt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : symbol = Value(symbol),
       alertType = Value(alertType),
       targetValue = Value(targetValue);
  static Insertable<PriceAlertEntry> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<String>? alertType,
    Expression<double>? targetValue,
    Expression<bool>? isActive,
    Expression<DateTime>? triggeredAt,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (alertType != null) 'alert_type': alertType,
      if (targetValue != null) 'target_value': targetValue,
      if (isActive != null) 'is_active': isActive,
      if (triggeredAt != null) 'triggered_at': triggeredAt,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PriceAlertCompanion copyWith({
    Value<int>? id,
    Value<String>? symbol,
    Value<String>? alertType,
    Value<double>? targetValue,
    Value<bool>? isActive,
    Value<DateTime?>? triggeredAt,
    Value<String?>? note,
    Value<DateTime>? createdAt,
  }) {
    return PriceAlertCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      alertType: alertType ?? this.alertType,
      targetValue: targetValue ?? this.targetValue,
      isActive: isActive ?? this.isActive,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (alertType.present) {
      map['alert_type'] = Variable<String>(alertType.value);
    }
    if (targetValue.present) {
      map['target_value'] = Variable<double>(targetValue.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (triggeredAt.present) {
      map['triggered_at'] = Variable<DateTime>(triggeredAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriceAlertCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('alertType: $alertType, ')
          ..write('targetValue: $targetValue, ')
          ..write('isActive: $isActive, ')
          ..write('triggeredAt: $triggeredAt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserInteractionTable extends UserInteraction
    with TableInfo<$UserInteractionTable, UserInteractionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserInteractionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _interactionTypeMeta = const VerificationMeta(
    'interactionType',
  );
  @override
  late final GeneratedColumn<String> interactionType = GeneratedColumn<String>(
    'interaction_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcePageMeta = const VerificationMeta(
    'sourcePage',
  );
  @override
  late final GeneratedColumn<String> sourcePage = GeneratedColumn<String>(
    'source_page',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    interactionType,
    symbol,
    timestamp,
    durationSeconds,
    sourcePage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_interaction';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserInteractionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('interaction_type')) {
      context.handle(
        _interactionTypeMeta,
        interactionType.isAcceptableOrUnknown(
          data['interaction_type']!,
          _interactionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interactionTypeMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('source_page')) {
      context.handle(
        _sourcePageMeta,
        sourcePage.isAcceptableOrUnknown(data['source_page']!, _sourcePageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserInteractionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserInteractionEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      interactionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interaction_type'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      sourcePage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_page'],
      ),
    );
  }

  @override
  $UserInteractionTable createAlias(String alias) {
    return $UserInteractionTable(attachedDatabase, alias);
  }
}

class UserInteractionEntry extends DataClass
    implements Insertable<UserInteractionEntry> {
  /// 自動遞增 ID
  final int id;

  /// 互動類型：VIEW（查看）、ADD_WATCHLIST（加入自選）、
  /// REMOVE_WATCHLIST（移除自選）、ADD_POSITION（加入持倉）
  final String interactionType;

  /// 股票代碼
  final String symbol;

  /// 互動時間
  final DateTime timestamp;

  /// 停留時間（秒），僅 VIEW 類型使用
  final int? durationSeconds;

  /// 來源頁面（如 today、scan、watchlist）
  final String? sourcePage;
  const UserInteractionEntry({
    required this.id,
    required this.interactionType,
    required this.symbol,
    required this.timestamp,
    this.durationSeconds,
    this.sourcePage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['interaction_type'] = Variable<String>(interactionType);
    map['symbol'] = Variable<String>(symbol);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || sourcePage != null) {
      map['source_page'] = Variable<String>(sourcePage);
    }
    return map;
  }

  UserInteractionCompanion toCompanion(bool nullToAbsent) {
    return UserInteractionCompanion(
      id: Value(id),
      interactionType: Value(interactionType),
      symbol: Value(symbol),
      timestamp: Value(timestamp),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      sourcePage: sourcePage == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePage),
    );
  }

  factory UserInteractionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserInteractionEntry(
      id: serializer.fromJson<int>(json['id']),
      interactionType: serializer.fromJson<String>(json['interactionType']),
      symbol: serializer.fromJson<String>(json['symbol']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      sourcePage: serializer.fromJson<String?>(json['sourcePage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'interactionType': serializer.toJson<String>(interactionType),
      'symbol': serializer.toJson<String>(symbol),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'sourcePage': serializer.toJson<String?>(sourcePage),
    };
  }

  UserInteractionEntry copyWith({
    int? id,
    String? interactionType,
    String? symbol,
    DateTime? timestamp,
    Value<int?> durationSeconds = const Value.absent(),
    Value<String?> sourcePage = const Value.absent(),
  }) => UserInteractionEntry(
    id: id ?? this.id,
    interactionType: interactionType ?? this.interactionType,
    symbol: symbol ?? this.symbol,
    timestamp: timestamp ?? this.timestamp,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    sourcePage: sourcePage.present ? sourcePage.value : this.sourcePage,
  );
  UserInteractionEntry copyWithCompanion(UserInteractionCompanion data) {
    return UserInteractionEntry(
      id: data.id.present ? data.id.value : this.id,
      interactionType: data.interactionType.present
          ? data.interactionType.value
          : this.interactionType,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      sourcePage: data.sourcePage.present
          ? data.sourcePage.value
          : this.sourcePage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserInteractionEntry(')
          ..write('id: $id, ')
          ..write('interactionType: $interactionType, ')
          ..write('symbol: $symbol, ')
          ..write('timestamp: $timestamp, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sourcePage: $sourcePage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    interactionType,
    symbol,
    timestamp,
    durationSeconds,
    sourcePage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserInteractionEntry &&
          other.id == this.id &&
          other.interactionType == this.interactionType &&
          other.symbol == this.symbol &&
          other.timestamp == this.timestamp &&
          other.durationSeconds == this.durationSeconds &&
          other.sourcePage == this.sourcePage);
}

class UserInteractionCompanion extends UpdateCompanion<UserInteractionEntry> {
  final Value<int> id;
  final Value<String> interactionType;
  final Value<String> symbol;
  final Value<DateTime> timestamp;
  final Value<int?> durationSeconds;
  final Value<String?> sourcePage;
  const UserInteractionCompanion({
    this.id = const Value.absent(),
    this.interactionType = const Value.absent(),
    this.symbol = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sourcePage = const Value.absent(),
  });
  UserInteractionCompanion.insert({
    this.id = const Value.absent(),
    required String interactionType,
    required String symbol,
    this.timestamp = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sourcePage = const Value.absent(),
  }) : interactionType = Value(interactionType),
       symbol = Value(symbol);
  static Insertable<UserInteractionEntry> custom({
    Expression<int>? id,
    Expression<String>? interactionType,
    Expression<String>? symbol,
    Expression<DateTime>? timestamp,
    Expression<int>? durationSeconds,
    Expression<String>? sourcePage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (interactionType != null) 'interaction_type': interactionType,
      if (symbol != null) 'symbol': symbol,
      if (timestamp != null) 'timestamp': timestamp,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (sourcePage != null) 'source_page': sourcePage,
    });
  }

  UserInteractionCompanion copyWith({
    Value<int>? id,
    Value<String>? interactionType,
    Value<String>? symbol,
    Value<DateTime>? timestamp,
    Value<int?>? durationSeconds,
    Value<String?>? sourcePage,
  }) {
    return UserInteractionCompanion(
      id: id ?? this.id,
      interactionType: interactionType ?? this.interactionType,
      symbol: symbol ?? this.symbol,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sourcePage: sourcePage ?? this.sourcePage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (interactionType.present) {
      map['interaction_type'] = Variable<String>(interactionType.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (sourcePage.present) {
      map['source_page'] = Variable<String>(sourcePage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserInteractionCompanion(')
          ..write('id: $id, ')
          ..write('interactionType: $interactionType, ')
          ..write('symbol: $symbol, ')
          ..write('timestamp: $timestamp, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sourcePage: $sourcePage')
          ..write(')'))
        .toString();
  }
}

class $UserPreferenceTable extends UserPreference
    with TableInfo<$UserPreferenceTable, UserPreferenceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferenceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _preferenceTypeMeta = const VerificationMeta(
    'preferenceType',
  );
  @override
  late final GeneratedColumn<String> preferenceType = GeneratedColumn<String>(
    'preference_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preferenceValueMeta = const VerificationMeta(
    'preferenceValue',
  );
  @override
  late final GeneratedColumn<String> preferenceValue = GeneratedColumn<String>(
    'preference_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    preferenceType,
    preferenceValue,
    weight,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preference';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreferenceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('preference_type')) {
      context.handle(
        _preferenceTypeMeta,
        preferenceType.isAcceptableOrUnknown(
          data['preference_type']!,
          _preferenceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preferenceTypeMeta);
    }
    if (data.containsKey('preference_value')) {
      context.handle(
        _preferenceValueMeta,
        preferenceValue.isAcceptableOrUnknown(
          data['preference_value']!,
          _preferenceValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preferenceValueMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {preferenceType, preferenceValue};
  @override
  UserPreferenceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreferenceEntry(
      preferenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preference_type'],
      )!,
      preferenceValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preference_value'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserPreferenceTable createAlias(String alias) {
    return $UserPreferenceTable(attachedDatabase, alias);
  }
}

class UserPreferenceEntry extends DataClass
    implements Insertable<UserPreferenceEntry> {
  /// 偏好類型：INDUSTRY（產業）、MARKET_CAP（市值）、STYLE（風格）
  final String preferenceType;

  /// 偏好值（如 '半導體'、'large_cap'、'growth'）
  final String preferenceValue;

  /// 權重（0.0 ~ 1.0），基於互動頻率計算
  final double weight;

  /// 最後更新時間
  final DateTime updatedAt;
  const UserPreferenceEntry({
    required this.preferenceType,
    required this.preferenceValue,
    required this.weight,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['preference_type'] = Variable<String>(preferenceType);
    map['preference_value'] = Variable<String>(preferenceValue);
    map['weight'] = Variable<double>(weight);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserPreferenceCompanion toCompanion(bool nullToAbsent) {
    return UserPreferenceCompanion(
      preferenceType: Value(preferenceType),
      preferenceValue: Value(preferenceValue),
      weight: Value(weight),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserPreferenceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreferenceEntry(
      preferenceType: serializer.fromJson<String>(json['preferenceType']),
      preferenceValue: serializer.fromJson<String>(json['preferenceValue']),
      weight: serializer.fromJson<double>(json['weight']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'preferenceType': serializer.toJson<String>(preferenceType),
      'preferenceValue': serializer.toJson<String>(preferenceValue),
      'weight': serializer.toJson<double>(weight),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPreferenceEntry copyWith({
    String? preferenceType,
    String? preferenceValue,
    double? weight,
    DateTime? updatedAt,
  }) => UserPreferenceEntry(
    preferenceType: preferenceType ?? this.preferenceType,
    preferenceValue: preferenceValue ?? this.preferenceValue,
    weight: weight ?? this.weight,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserPreferenceEntry copyWithCompanion(UserPreferenceCompanion data) {
    return UserPreferenceEntry(
      preferenceType: data.preferenceType.present
          ? data.preferenceType.value
          : this.preferenceType,
      preferenceValue: data.preferenceValue.present
          ? data.preferenceValue.value
          : this.preferenceValue,
      weight: data.weight.present ? data.weight.value : this.weight,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferenceEntry(')
          ..write('preferenceType: $preferenceType, ')
          ..write('preferenceValue: $preferenceValue, ')
          ..write('weight: $weight, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(preferenceType, preferenceValue, weight, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreferenceEntry &&
          other.preferenceType == this.preferenceType &&
          other.preferenceValue == this.preferenceValue &&
          other.weight == this.weight &&
          other.updatedAt == this.updatedAt);
}

class UserPreferenceCompanion extends UpdateCompanion<UserPreferenceEntry> {
  final Value<String> preferenceType;
  final Value<String> preferenceValue;
  final Value<double> weight;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserPreferenceCompanion({
    this.preferenceType = const Value.absent(),
    this.preferenceValue = const Value.absent(),
    this.weight = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferenceCompanion.insert({
    required String preferenceType,
    required String preferenceValue,
    this.weight = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : preferenceType = Value(preferenceType),
       preferenceValue = Value(preferenceValue);
  static Insertable<UserPreferenceEntry> custom({
    Expression<String>? preferenceType,
    Expression<String>? preferenceValue,
    Expression<double>? weight,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (preferenceType != null) 'preference_type': preferenceType,
      if (preferenceValue != null) 'preference_value': preferenceValue,
      if (weight != null) 'weight': weight,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferenceCompanion copyWith({
    Value<String>? preferenceType,
    Value<String>? preferenceValue,
    Value<double>? weight,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserPreferenceCompanion(
      preferenceType: preferenceType ?? this.preferenceType,
      preferenceValue: preferenceValue ?? this.preferenceValue,
      weight: weight ?? this.weight,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (preferenceType.present) {
      map['preference_type'] = Variable<String>(preferenceType.value);
    }
    if (preferenceValue.present) {
      map['preference_value'] = Variable<String>(preferenceValue.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferenceCompanion(')
          ..write('preferenceType: $preferenceType, ')
          ..write('preferenceValue: $preferenceValue, ')
          ..write('weight: $weight, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShareholdingTable extends Shareholding
    with TableInfo<$ShareholdingTable, ShareholdingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShareholdingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foreignRemainingSharesMeta =
      const VerificationMeta('foreignRemainingShares');
  @override
  late final GeneratedColumn<double> foreignRemainingShares =
      GeneratedColumn<double>(
        'foreign_remaining_shares',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _foreignSharesRatioMeta =
      const VerificationMeta('foreignSharesRatio');
  @override
  late final GeneratedColumn<double> foreignSharesRatio =
      GeneratedColumn<double>(
        'foreign_shares_ratio',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _foreignUpperLimitRatioMeta =
      const VerificationMeta('foreignUpperLimitRatio');
  @override
  late final GeneratedColumn<double> foreignUpperLimitRatio =
      GeneratedColumn<double>(
        'foreign_upper_limit_ratio',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sharesIssuedMeta = const VerificationMeta(
    'sharesIssued',
  );
  @override
  late final GeneratedColumn<double> sharesIssued = GeneratedColumn<double>(
    'shares_issued',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    foreignRemainingShares,
    foreignSharesRatio,
    foreignUpperLimitRatio,
    sharesIssued,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shareholding';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShareholdingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('foreign_remaining_shares')) {
      context.handle(
        _foreignRemainingSharesMeta,
        foreignRemainingShares.isAcceptableOrUnknown(
          data['foreign_remaining_shares']!,
          _foreignRemainingSharesMeta,
        ),
      );
    }
    if (data.containsKey('foreign_shares_ratio')) {
      context.handle(
        _foreignSharesRatioMeta,
        foreignSharesRatio.isAcceptableOrUnknown(
          data['foreign_shares_ratio']!,
          _foreignSharesRatioMeta,
        ),
      );
    }
    if (data.containsKey('foreign_upper_limit_ratio')) {
      context.handle(
        _foreignUpperLimitRatioMeta,
        foreignUpperLimitRatio.isAcceptableOrUnknown(
          data['foreign_upper_limit_ratio']!,
          _foreignUpperLimitRatioMeta,
        ),
      );
    }
    if (data.containsKey('shares_issued')) {
      context.handle(
        _sharesIssuedMeta,
        sharesIssued.isAcceptableOrUnknown(
          data['shares_issued']!,
          _sharesIssuedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  ShareholdingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShareholdingEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      foreignRemainingShares: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}foreign_remaining_shares'],
      ),
      foreignSharesRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}foreign_shares_ratio'],
      ),
      foreignUpperLimitRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}foreign_upper_limit_ratio'],
      ),
      sharesIssued: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shares_issued'],
      ),
    );
  }

  @override
  $ShareholdingTable createAlias(String alias) {
    return $ShareholdingTable(attachedDatabase, alias);
  }
}

class ShareholdingEntry extends DataClass
    implements Insertable<ShareholdingEntry> {
  /// 股票代碼
  final String symbol;

  /// 交易日期
  final DateTime date;

  /// 外資持股餘額（股）
  final double? foreignRemainingShares;

  /// 外資持股比例（%）
  final double? foreignSharesRatio;

  /// 外資持股上限比例（%）
  final double? foreignUpperLimitRatio;

  /// 已發行股數
  final double? sharesIssued;
  const ShareholdingEntry({
    required this.symbol,
    required this.date,
    this.foreignRemainingShares,
    this.foreignSharesRatio,
    this.foreignUpperLimitRatio,
    this.sharesIssued,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || foreignRemainingShares != null) {
      map['foreign_remaining_shares'] = Variable<double>(
        foreignRemainingShares,
      );
    }
    if (!nullToAbsent || foreignSharesRatio != null) {
      map['foreign_shares_ratio'] = Variable<double>(foreignSharesRatio);
    }
    if (!nullToAbsent || foreignUpperLimitRatio != null) {
      map['foreign_upper_limit_ratio'] = Variable<double>(
        foreignUpperLimitRatio,
      );
    }
    if (!nullToAbsent || sharesIssued != null) {
      map['shares_issued'] = Variable<double>(sharesIssued);
    }
    return map;
  }

  ShareholdingCompanion toCompanion(bool nullToAbsent) {
    return ShareholdingCompanion(
      symbol: Value(symbol),
      date: Value(date),
      foreignRemainingShares: foreignRemainingShares == null && nullToAbsent
          ? const Value.absent()
          : Value(foreignRemainingShares),
      foreignSharesRatio: foreignSharesRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(foreignSharesRatio),
      foreignUpperLimitRatio: foreignUpperLimitRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(foreignUpperLimitRatio),
      sharesIssued: sharesIssued == null && nullToAbsent
          ? const Value.absent()
          : Value(sharesIssued),
    );
  }

  factory ShareholdingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShareholdingEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      foreignRemainingShares: serializer.fromJson<double?>(
        json['foreignRemainingShares'],
      ),
      foreignSharesRatio: serializer.fromJson<double?>(
        json['foreignSharesRatio'],
      ),
      foreignUpperLimitRatio: serializer.fromJson<double?>(
        json['foreignUpperLimitRatio'],
      ),
      sharesIssued: serializer.fromJson<double?>(json['sharesIssued']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'foreignRemainingShares': serializer.toJson<double?>(
        foreignRemainingShares,
      ),
      'foreignSharesRatio': serializer.toJson<double?>(foreignSharesRatio),
      'foreignUpperLimitRatio': serializer.toJson<double?>(
        foreignUpperLimitRatio,
      ),
      'sharesIssued': serializer.toJson<double?>(sharesIssued),
    };
  }

  ShareholdingEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> foreignRemainingShares = const Value.absent(),
    Value<double?> foreignSharesRatio = const Value.absent(),
    Value<double?> foreignUpperLimitRatio = const Value.absent(),
    Value<double?> sharesIssued = const Value.absent(),
  }) => ShareholdingEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    foreignRemainingShares: foreignRemainingShares.present
        ? foreignRemainingShares.value
        : this.foreignRemainingShares,
    foreignSharesRatio: foreignSharesRatio.present
        ? foreignSharesRatio.value
        : this.foreignSharesRatio,
    foreignUpperLimitRatio: foreignUpperLimitRatio.present
        ? foreignUpperLimitRatio.value
        : this.foreignUpperLimitRatio,
    sharesIssued: sharesIssued.present ? sharesIssued.value : this.sharesIssued,
  );
  ShareholdingEntry copyWithCompanion(ShareholdingCompanion data) {
    return ShareholdingEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      foreignRemainingShares: data.foreignRemainingShares.present
          ? data.foreignRemainingShares.value
          : this.foreignRemainingShares,
      foreignSharesRatio: data.foreignSharesRatio.present
          ? data.foreignSharesRatio.value
          : this.foreignSharesRatio,
      foreignUpperLimitRatio: data.foreignUpperLimitRatio.present
          ? data.foreignUpperLimitRatio.value
          : this.foreignUpperLimitRatio,
      sharesIssued: data.sharesIssued.present
          ? data.sharesIssued.value
          : this.sharesIssued,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShareholdingEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('foreignRemainingShares: $foreignRemainingShares, ')
          ..write('foreignSharesRatio: $foreignSharesRatio, ')
          ..write('foreignUpperLimitRatio: $foreignUpperLimitRatio, ')
          ..write('sharesIssued: $sharesIssued')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    date,
    foreignRemainingShares,
    foreignSharesRatio,
    foreignUpperLimitRatio,
    sharesIssued,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShareholdingEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.foreignRemainingShares == this.foreignRemainingShares &&
          other.foreignSharesRatio == this.foreignSharesRatio &&
          other.foreignUpperLimitRatio == this.foreignUpperLimitRatio &&
          other.sharesIssued == this.sharesIssued);
}

class ShareholdingCompanion extends UpdateCompanion<ShareholdingEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> foreignRemainingShares;
  final Value<double?> foreignSharesRatio;
  final Value<double?> foreignUpperLimitRatio;
  final Value<double?> sharesIssued;
  final Value<int> rowid;
  const ShareholdingCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.foreignRemainingShares = const Value.absent(),
    this.foreignSharesRatio = const Value.absent(),
    this.foreignUpperLimitRatio = const Value.absent(),
    this.sharesIssued = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShareholdingCompanion.insert({
    required String symbol,
    required DateTime date,
    this.foreignRemainingShares = const Value.absent(),
    this.foreignSharesRatio = const Value.absent(),
    this.foreignUpperLimitRatio = const Value.absent(),
    this.sharesIssued = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<ShareholdingEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? foreignRemainingShares,
    Expression<double>? foreignSharesRatio,
    Expression<double>? foreignUpperLimitRatio,
    Expression<double>? sharesIssued,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (foreignRemainingShares != null)
        'foreign_remaining_shares': foreignRemainingShares,
      if (foreignSharesRatio != null)
        'foreign_shares_ratio': foreignSharesRatio,
      if (foreignUpperLimitRatio != null)
        'foreign_upper_limit_ratio': foreignUpperLimitRatio,
      if (sharesIssued != null) 'shares_issued': sharesIssued,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShareholdingCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? foreignRemainingShares,
    Value<double?>? foreignSharesRatio,
    Value<double?>? foreignUpperLimitRatio,
    Value<double?>? sharesIssued,
    Value<int>? rowid,
  }) {
    return ShareholdingCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      foreignRemainingShares:
          foreignRemainingShares ?? this.foreignRemainingShares,
      foreignSharesRatio: foreignSharesRatio ?? this.foreignSharesRatio,
      foreignUpperLimitRatio:
          foreignUpperLimitRatio ?? this.foreignUpperLimitRatio,
      sharesIssued: sharesIssued ?? this.sharesIssued,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (foreignRemainingShares.present) {
      map['foreign_remaining_shares'] = Variable<double>(
        foreignRemainingShares.value,
      );
    }
    if (foreignSharesRatio.present) {
      map['foreign_shares_ratio'] = Variable<double>(foreignSharesRatio.value);
    }
    if (foreignUpperLimitRatio.present) {
      map['foreign_upper_limit_ratio'] = Variable<double>(
        foreignUpperLimitRatio.value,
      );
    }
    if (sharesIssued.present) {
      map['shares_issued'] = Variable<double>(sharesIssued.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShareholdingCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('foreignRemainingShares: $foreignRemainingShares, ')
          ..write('foreignSharesRatio: $foreignSharesRatio, ')
          ..write('foreignUpperLimitRatio: $foreignUpperLimitRatio, ')
          ..write('sharesIssued: $sharesIssued, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayTradingTable extends DayTrading
    with TableInfo<$DayTradingTable, DayTradingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayTradingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _buyVolumeMeta = const VerificationMeta(
    'buyVolume',
  );
  @override
  late final GeneratedColumn<double> buyVolume = GeneratedColumn<double>(
    'buy_volume',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sellVolumeMeta = const VerificationMeta(
    'sellVolume',
  );
  @override
  late final GeneratedColumn<double> sellVolume = GeneratedColumn<double>(
    'sell_volume',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayTradingRatioMeta = const VerificationMeta(
    'dayTradingRatio',
  );
  @override
  late final GeneratedColumn<double> dayTradingRatio = GeneratedColumn<double>(
    'day_trading_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tradeVolumeMeta = const VerificationMeta(
    'tradeVolume',
  );
  @override
  late final GeneratedColumn<double> tradeVolume = GeneratedColumn<double>(
    'trade_volume',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    buyVolume,
    sellVolume,
    dayTradingRatio,
    tradeVolume,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_trading';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayTradingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('buy_volume')) {
      context.handle(
        _buyVolumeMeta,
        buyVolume.isAcceptableOrUnknown(data['buy_volume']!, _buyVolumeMeta),
      );
    }
    if (data.containsKey('sell_volume')) {
      context.handle(
        _sellVolumeMeta,
        sellVolume.isAcceptableOrUnknown(data['sell_volume']!, _sellVolumeMeta),
      );
    }
    if (data.containsKey('day_trading_ratio')) {
      context.handle(
        _dayTradingRatioMeta,
        dayTradingRatio.isAcceptableOrUnknown(
          data['day_trading_ratio']!,
          _dayTradingRatioMeta,
        ),
      );
    }
    if (data.containsKey('trade_volume')) {
      context.handle(
        _tradeVolumeMeta,
        tradeVolume.isAcceptableOrUnknown(
          data['trade_volume']!,
          _tradeVolumeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  DayTradingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayTradingEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      buyVolume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}buy_volume'],
      ),
      sellVolume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sell_volume'],
      ),
      dayTradingRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}day_trading_ratio'],
      ),
      tradeVolume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}trade_volume'],
      ),
    );
  }

  @override
  $DayTradingTable createAlias(String alias) {
    return $DayTradingTable(attachedDatabase, alias);
  }
}

class DayTradingEntry extends DataClass implements Insertable<DayTradingEntry> {
  /// 股票代碼
  final String symbol;

  /// 交易日期
  final DateTime date;

  /// 當沖買進量/金額
  ///
  /// 註：TWSE API 提供金額（元），FinMind 提供股數
  final double? buyVolume;

  /// 當沖賣出量/金額
  ///
  /// 註：TWSE API 提供金額（元），FinMind 提供股數
  final double? sellVolume;

  /// 當沖比例（%）
  ///
  /// 此為主要指標，由總成交量計算。
  final double? dayTradingRatio;

  /// 當沖成交股數
  final double? tradeVolume;
  const DayTradingEntry({
    required this.symbol,
    required this.date,
    this.buyVolume,
    this.sellVolume,
    this.dayTradingRatio,
    this.tradeVolume,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || buyVolume != null) {
      map['buy_volume'] = Variable<double>(buyVolume);
    }
    if (!nullToAbsent || sellVolume != null) {
      map['sell_volume'] = Variable<double>(sellVolume);
    }
    if (!nullToAbsent || dayTradingRatio != null) {
      map['day_trading_ratio'] = Variable<double>(dayTradingRatio);
    }
    if (!nullToAbsent || tradeVolume != null) {
      map['trade_volume'] = Variable<double>(tradeVolume);
    }
    return map;
  }

  DayTradingCompanion toCompanion(bool nullToAbsent) {
    return DayTradingCompanion(
      symbol: Value(symbol),
      date: Value(date),
      buyVolume: buyVolume == null && nullToAbsent
          ? const Value.absent()
          : Value(buyVolume),
      sellVolume: sellVolume == null && nullToAbsent
          ? const Value.absent()
          : Value(sellVolume),
      dayTradingRatio: dayTradingRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(dayTradingRatio),
      tradeVolume: tradeVolume == null && nullToAbsent
          ? const Value.absent()
          : Value(tradeVolume),
    );
  }

  factory DayTradingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayTradingEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      buyVolume: serializer.fromJson<double?>(json['buyVolume']),
      sellVolume: serializer.fromJson<double?>(json['sellVolume']),
      dayTradingRatio: serializer.fromJson<double?>(json['dayTradingRatio']),
      tradeVolume: serializer.fromJson<double?>(json['tradeVolume']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'buyVolume': serializer.toJson<double?>(buyVolume),
      'sellVolume': serializer.toJson<double?>(sellVolume),
      'dayTradingRatio': serializer.toJson<double?>(dayTradingRatio),
      'tradeVolume': serializer.toJson<double?>(tradeVolume),
    };
  }

  DayTradingEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> buyVolume = const Value.absent(),
    Value<double?> sellVolume = const Value.absent(),
    Value<double?> dayTradingRatio = const Value.absent(),
    Value<double?> tradeVolume = const Value.absent(),
  }) => DayTradingEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    buyVolume: buyVolume.present ? buyVolume.value : this.buyVolume,
    sellVolume: sellVolume.present ? sellVolume.value : this.sellVolume,
    dayTradingRatio: dayTradingRatio.present
        ? dayTradingRatio.value
        : this.dayTradingRatio,
    tradeVolume: tradeVolume.present ? tradeVolume.value : this.tradeVolume,
  );
  DayTradingEntry copyWithCompanion(DayTradingCompanion data) {
    return DayTradingEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      buyVolume: data.buyVolume.present ? data.buyVolume.value : this.buyVolume,
      sellVolume: data.sellVolume.present
          ? data.sellVolume.value
          : this.sellVolume,
      dayTradingRatio: data.dayTradingRatio.present
          ? data.dayTradingRatio.value
          : this.dayTradingRatio,
      tradeVolume: data.tradeVolume.present
          ? data.tradeVolume.value
          : this.tradeVolume,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayTradingEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('buyVolume: $buyVolume, ')
          ..write('sellVolume: $sellVolume, ')
          ..write('dayTradingRatio: $dayTradingRatio, ')
          ..write('tradeVolume: $tradeVolume')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    date,
    buyVolume,
    sellVolume,
    dayTradingRatio,
    tradeVolume,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayTradingEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.buyVolume == this.buyVolume &&
          other.sellVolume == this.sellVolume &&
          other.dayTradingRatio == this.dayTradingRatio &&
          other.tradeVolume == this.tradeVolume);
}

class DayTradingCompanion extends UpdateCompanion<DayTradingEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> buyVolume;
  final Value<double?> sellVolume;
  final Value<double?> dayTradingRatio;
  final Value<double?> tradeVolume;
  final Value<int> rowid;
  const DayTradingCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.buyVolume = const Value.absent(),
    this.sellVolume = const Value.absent(),
    this.dayTradingRatio = const Value.absent(),
    this.tradeVolume = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayTradingCompanion.insert({
    required String symbol,
    required DateTime date,
    this.buyVolume = const Value.absent(),
    this.sellVolume = const Value.absent(),
    this.dayTradingRatio = const Value.absent(),
    this.tradeVolume = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<DayTradingEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? buyVolume,
    Expression<double>? sellVolume,
    Expression<double>? dayTradingRatio,
    Expression<double>? tradeVolume,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (buyVolume != null) 'buy_volume': buyVolume,
      if (sellVolume != null) 'sell_volume': sellVolume,
      if (dayTradingRatio != null) 'day_trading_ratio': dayTradingRatio,
      if (tradeVolume != null) 'trade_volume': tradeVolume,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayTradingCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? buyVolume,
    Value<double?>? sellVolume,
    Value<double?>? dayTradingRatio,
    Value<double?>? tradeVolume,
    Value<int>? rowid,
  }) {
    return DayTradingCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      buyVolume: buyVolume ?? this.buyVolume,
      sellVolume: sellVolume ?? this.sellVolume,
      dayTradingRatio: dayTradingRatio ?? this.dayTradingRatio,
      tradeVolume: tradeVolume ?? this.tradeVolume,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (buyVolume.present) {
      map['buy_volume'] = Variable<double>(buyVolume.value);
    }
    if (sellVolume.present) {
      map['sell_volume'] = Variable<double>(sellVolume.value);
    }
    if (dayTradingRatio.present) {
      map['day_trading_ratio'] = Variable<double>(dayTradingRatio.value);
    }
    if (tradeVolume.present) {
      map['trade_volume'] = Variable<double>(tradeVolume.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayTradingCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('buyVolume: $buyVolume, ')
          ..write('sellVolume: $sellVolume, ')
          ..write('dayTradingRatio: $dayTradingRatio, ')
          ..write('tradeVolume: $tradeVolume, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FinancialDataTable extends FinancialData
    with TableInfo<$FinancialDataTable, FinancialDataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinancialDataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statementTypeMeta = const VerificationMeta(
    'statementType',
  );
  @override
  late final GeneratedColumn<String> statementType = GeneratedColumn<String>(
    'statement_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataTypeMeta = const VerificationMeta(
    'dataType',
  );
  @override
  late final GeneratedColumn<String> dataType = GeneratedColumn<String>(
    'data_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originNameMeta = const VerificationMeta(
    'originName',
  );
  @override
  late final GeneratedColumn<String> originName = GeneratedColumn<String>(
    'origin_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    statementType,
    dataType,
    value,
    originName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'financial_data';
  @override
  VerificationContext validateIntegrity(
    Insertable<FinancialDataEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('statement_type')) {
      context.handle(
        _statementTypeMeta,
        statementType.isAcceptableOrUnknown(
          data['statement_type']!,
          _statementTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statementTypeMeta);
    }
    if (data.containsKey('data_type')) {
      context.handle(
        _dataTypeMeta,
        dataType.isAcceptableOrUnknown(data['data_type']!, _dataTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_dataTypeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('origin_name')) {
      context.handle(
        _originNameMeta,
        originName.isAcceptableOrUnknown(data['origin_name']!, _originNameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    symbol,
    date,
    statementType,
    dataType,
  };
  @override
  FinancialDataEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FinancialDataEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      statementType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statement_type'],
      )!,
      dataType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_type'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      ),
      originName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_name'],
      ),
    );
  }

  @override
  $FinancialDataTable createAlias(String alias) {
    return $FinancialDataTable(attachedDatabase, alias);
  }
}

class FinancialDataEntry extends DataClass
    implements Insertable<FinancialDataEntry> {
  /// 股票代碼
  final String symbol;

  /// 報告日期（季度以日期格式儲存）
  final DateTime date;

  /// 報表類型：INCOME、BALANCE、CASHFLOW
  final String statementType;

  /// 資料項目（如 Revenue、NetIncome、TotalAssets）
  final String dataType;

  /// 數值（千元）
  final double? value;

  /// 原始中文名稱
  final String? originName;
  const FinancialDataEntry({
    required this.symbol,
    required this.date,
    required this.statementType,
    required this.dataType,
    this.value,
    this.originName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    map['statement_type'] = Variable<String>(statementType);
    map['data_type'] = Variable<String>(dataType);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<double>(value);
    }
    if (!nullToAbsent || originName != null) {
      map['origin_name'] = Variable<String>(originName);
    }
    return map;
  }

  FinancialDataCompanion toCompanion(bool nullToAbsent) {
    return FinancialDataCompanion(
      symbol: Value(symbol),
      date: Value(date),
      statementType: Value(statementType),
      dataType: Value(dataType),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      originName: originName == null && nullToAbsent
          ? const Value.absent()
          : Value(originName),
    );
  }

  factory FinancialDataEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FinancialDataEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      statementType: serializer.fromJson<String>(json['statementType']),
      dataType: serializer.fromJson<String>(json['dataType']),
      value: serializer.fromJson<double?>(json['value']),
      originName: serializer.fromJson<String?>(json['originName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'statementType': serializer.toJson<String>(statementType),
      'dataType': serializer.toJson<String>(dataType),
      'value': serializer.toJson<double?>(value),
      'originName': serializer.toJson<String?>(originName),
    };
  }

  FinancialDataEntry copyWith({
    String? symbol,
    DateTime? date,
    String? statementType,
    String? dataType,
    Value<double?> value = const Value.absent(),
    Value<String?> originName = const Value.absent(),
  }) => FinancialDataEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    statementType: statementType ?? this.statementType,
    dataType: dataType ?? this.dataType,
    value: value.present ? value.value : this.value,
    originName: originName.present ? originName.value : this.originName,
  );
  FinancialDataEntry copyWithCompanion(FinancialDataCompanion data) {
    return FinancialDataEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      statementType: data.statementType.present
          ? data.statementType.value
          : this.statementType,
      dataType: data.dataType.present ? data.dataType.value : this.dataType,
      value: data.value.present ? data.value.value : this.value,
      originName: data.originName.present
          ? data.originName.value
          : this.originName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FinancialDataEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('statementType: $statementType, ')
          ..write('dataType: $dataType, ')
          ..write('value: $value, ')
          ..write('originName: $originName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(symbol, date, statementType, dataType, value, originName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FinancialDataEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.statementType == this.statementType &&
          other.dataType == this.dataType &&
          other.value == this.value &&
          other.originName == this.originName);
}

class FinancialDataCompanion extends UpdateCompanion<FinancialDataEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<String> statementType;
  final Value<String> dataType;
  final Value<double?> value;
  final Value<String?> originName;
  final Value<int> rowid;
  const FinancialDataCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.statementType = const Value.absent(),
    this.dataType = const Value.absent(),
    this.value = const Value.absent(),
    this.originName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FinancialDataCompanion.insert({
    required String symbol,
    required DateTime date,
    required String statementType,
    required String dataType,
    this.value = const Value.absent(),
    this.originName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date),
       statementType = Value(statementType),
       dataType = Value(dataType);
  static Insertable<FinancialDataEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<String>? statementType,
    Expression<String>? dataType,
    Expression<double>? value,
    Expression<String>? originName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (statementType != null) 'statement_type': statementType,
      if (dataType != null) 'data_type': dataType,
      if (value != null) 'value': value,
      if (originName != null) 'origin_name': originName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FinancialDataCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<String>? statementType,
    Value<String>? dataType,
    Value<double?>? value,
    Value<String?>? originName,
    Value<int>? rowid,
  }) {
    return FinancialDataCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      statementType: statementType ?? this.statementType,
      dataType: dataType ?? this.dataType,
      value: value ?? this.value,
      originName: originName ?? this.originName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (statementType.present) {
      map['statement_type'] = Variable<String>(statementType.value);
    }
    if (dataType.present) {
      map['data_type'] = Variable<String>(dataType.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (originName.present) {
      map['origin_name'] = Variable<String>(originName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinancialDataCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('statementType: $statementType, ')
          ..write('dataType: $dataType, ')
          ..write('value: $value, ')
          ..write('originName: $originName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AdjustedPriceTable extends AdjustedPrice
    with TableInfo<$AdjustedPriceTable, AdjustedPriceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AdjustedPriceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openMeta = const VerificationMeta('open');
  @override
  late final GeneratedColumn<double> open = GeneratedColumn<double>(
    'open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highMeta = const VerificationMeta('high');
  @override
  late final GeneratedColumn<double> high = GeneratedColumn<double>(
    'high',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lowMeta = const VerificationMeta('low');
  @override
  late final GeneratedColumn<double> low = GeneratedColumn<double>(
    'low',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closeMeta = const VerificationMeta('close');
  @override
  late final GeneratedColumn<double> close = GeneratedColumn<double>(
    'close',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    open,
    high,
    low,
    close,
    volume,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'adjusted_price';
  @override
  VerificationContext validateIntegrity(
    Insertable<AdjustedPriceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('open')) {
      context.handle(
        _openMeta,
        open.isAcceptableOrUnknown(data['open']!, _openMeta),
      );
    }
    if (data.containsKey('high')) {
      context.handle(
        _highMeta,
        high.isAcceptableOrUnknown(data['high']!, _highMeta),
      );
    }
    if (data.containsKey('low')) {
      context.handle(
        _lowMeta,
        low.isAcceptableOrUnknown(data['low']!, _lowMeta),
      );
    }
    if (data.containsKey('close')) {
      context.handle(
        _closeMeta,
        close.isAcceptableOrUnknown(data['close']!, _closeMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  AdjustedPriceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AdjustedPriceEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      open: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}open'],
      ),
      high: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}high'],
      ),
      low: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}low'],
      ),
      close: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}close'],
      ),
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      ),
    );
  }

  @override
  $AdjustedPriceTable createAlias(String alias) {
    return $AdjustedPriceTable(attachedDatabase, alias);
  }
}

class AdjustedPriceEntry extends DataClass
    implements Insertable<AdjustedPriceEntry> {
  /// 股票代碼
  final String symbol;

  /// 交易日期
  final DateTime date;

  /// 還原開盤價
  final double? open;

  /// 還原最高價
  final double? high;

  /// 還原最低價
  final double? low;

  /// 還原收盤價
  final double? close;

  /// 成交量
  final double? volume;
  const AdjustedPriceEntry({
    required this.symbol,
    required this.date,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || open != null) {
      map['open'] = Variable<double>(open);
    }
    if (!nullToAbsent || high != null) {
      map['high'] = Variable<double>(high);
    }
    if (!nullToAbsent || low != null) {
      map['low'] = Variable<double>(low);
    }
    if (!nullToAbsent || close != null) {
      map['close'] = Variable<double>(close);
    }
    if (!nullToAbsent || volume != null) {
      map['volume'] = Variable<double>(volume);
    }
    return map;
  }

  AdjustedPriceCompanion toCompanion(bool nullToAbsent) {
    return AdjustedPriceCompanion(
      symbol: Value(symbol),
      date: Value(date),
      open: open == null && nullToAbsent ? const Value.absent() : Value(open),
      high: high == null && nullToAbsent ? const Value.absent() : Value(high),
      low: low == null && nullToAbsent ? const Value.absent() : Value(low),
      close: close == null && nullToAbsent
          ? const Value.absent()
          : Value(close),
      volume: volume == null && nullToAbsent
          ? const Value.absent()
          : Value(volume),
    );
  }

  factory AdjustedPriceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AdjustedPriceEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      open: serializer.fromJson<double?>(json['open']),
      high: serializer.fromJson<double?>(json['high']),
      low: serializer.fromJson<double?>(json['low']),
      close: serializer.fromJson<double?>(json['close']),
      volume: serializer.fromJson<double?>(json['volume']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'open': serializer.toJson<double?>(open),
      'high': serializer.toJson<double?>(high),
      'low': serializer.toJson<double?>(low),
      'close': serializer.toJson<double?>(close),
      'volume': serializer.toJson<double?>(volume),
    };
  }

  AdjustedPriceEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> open = const Value.absent(),
    Value<double?> high = const Value.absent(),
    Value<double?> low = const Value.absent(),
    Value<double?> close = const Value.absent(),
    Value<double?> volume = const Value.absent(),
  }) => AdjustedPriceEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    open: open.present ? open.value : this.open,
    high: high.present ? high.value : this.high,
    low: low.present ? low.value : this.low,
    close: close.present ? close.value : this.close,
    volume: volume.present ? volume.value : this.volume,
  );
  AdjustedPriceEntry copyWithCompanion(AdjustedPriceCompanion data) {
    return AdjustedPriceEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      open: data.open.present ? data.open.value : this.open,
      high: data.high.present ? data.high.value : this.high,
      low: data.low.present ? data.low.value : this.low,
      close: data.close.present ? data.close.value : this.close,
      volume: data.volume.present ? data.volume.value : this.volume,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AdjustedPriceEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('open: $open, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('close: $close, ')
          ..write('volume: $volume')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, date, open, high, low, close, volume);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdjustedPriceEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.open == this.open &&
          other.high == this.high &&
          other.low == this.low &&
          other.close == this.close &&
          other.volume == this.volume);
}

class AdjustedPriceCompanion extends UpdateCompanion<AdjustedPriceEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> open;
  final Value<double?> high;
  final Value<double?> low;
  final Value<double?> close;
  final Value<double?> volume;
  final Value<int> rowid;
  const AdjustedPriceCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.open = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.close = const Value.absent(),
    this.volume = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AdjustedPriceCompanion.insert({
    required String symbol,
    required DateTime date,
    this.open = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.close = const Value.absent(),
    this.volume = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<AdjustedPriceEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? open,
    Expression<double>? high,
    Expression<double>? low,
    Expression<double>? close,
    Expression<double>? volume,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (open != null) 'open': open,
      if (high != null) 'high': high,
      if (low != null) 'low': low,
      if (close != null) 'close': close,
      if (volume != null) 'volume': volume,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AdjustedPriceCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? open,
    Value<double?>? high,
    Value<double?>? low,
    Value<double?>? close,
    Value<double?>? volume,
    Value<int>? rowid,
  }) {
    return AdjustedPriceCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (open.present) {
      map['open'] = Variable<double>(open.value);
    }
    if (high.present) {
      map['high'] = Variable<double>(high.value);
    }
    if (low.present) {
      map['low'] = Variable<double>(low.value);
    }
    if (close.present) {
      map['close'] = Variable<double>(close.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdjustedPriceCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('open: $open, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('close: $close, ')
          ..write('volume: $volume, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyPriceTable extends WeeklyPrice
    with TableInfo<$WeeklyPriceTable, WeeklyPriceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyPriceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openMeta = const VerificationMeta('open');
  @override
  late final GeneratedColumn<double> open = GeneratedColumn<double>(
    'open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highMeta = const VerificationMeta('high');
  @override
  late final GeneratedColumn<double> high = GeneratedColumn<double>(
    'high',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lowMeta = const VerificationMeta('low');
  @override
  late final GeneratedColumn<double> low = GeneratedColumn<double>(
    'low',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closeMeta = const VerificationMeta('close');
  @override
  late final GeneratedColumn<double> close = GeneratedColumn<double>(
    'close',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    open,
    high,
    low,
    close,
    volume,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_price';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyPriceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('open')) {
      context.handle(
        _openMeta,
        open.isAcceptableOrUnknown(data['open']!, _openMeta),
      );
    }
    if (data.containsKey('high')) {
      context.handle(
        _highMeta,
        high.isAcceptableOrUnknown(data['high']!, _highMeta),
      );
    }
    if (data.containsKey('low')) {
      context.handle(
        _lowMeta,
        low.isAcceptableOrUnknown(data['low']!, _lowMeta),
      );
    }
    if (data.containsKey('close')) {
      context.handle(
        _closeMeta,
        close.isAcceptableOrUnknown(data['close']!, _closeMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  WeeklyPriceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyPriceEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      open: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}open'],
      ),
      high: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}high'],
      ),
      low: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}low'],
      ),
      close: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}close'],
      ),
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      ),
    );
  }

  @override
  $WeeklyPriceTable createAlias(String alias) {
    return $WeeklyPriceTable(attachedDatabase, alias);
  }
}

class WeeklyPriceEntry extends DataClass
    implements Insertable<WeeklyPriceEntry> {
  /// 股票代碼
  final String symbol;

  /// 週結束日期
  final DateTime date;

  /// 週開盤價
  final double? open;

  /// 週最高價
  final double? high;

  /// 週最低價
  final double? low;

  /// 週收盤價
  final double? close;

  /// 週成交量
  final double? volume;
  const WeeklyPriceEntry({
    required this.symbol,
    required this.date,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || open != null) {
      map['open'] = Variable<double>(open);
    }
    if (!nullToAbsent || high != null) {
      map['high'] = Variable<double>(high);
    }
    if (!nullToAbsent || low != null) {
      map['low'] = Variable<double>(low);
    }
    if (!nullToAbsent || close != null) {
      map['close'] = Variable<double>(close);
    }
    if (!nullToAbsent || volume != null) {
      map['volume'] = Variable<double>(volume);
    }
    return map;
  }

  WeeklyPriceCompanion toCompanion(bool nullToAbsent) {
    return WeeklyPriceCompanion(
      symbol: Value(symbol),
      date: Value(date),
      open: open == null && nullToAbsent ? const Value.absent() : Value(open),
      high: high == null && nullToAbsent ? const Value.absent() : Value(high),
      low: low == null && nullToAbsent ? const Value.absent() : Value(low),
      close: close == null && nullToAbsent
          ? const Value.absent()
          : Value(close),
      volume: volume == null && nullToAbsent
          ? const Value.absent()
          : Value(volume),
    );
  }

  factory WeeklyPriceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyPriceEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      open: serializer.fromJson<double?>(json['open']),
      high: serializer.fromJson<double?>(json['high']),
      low: serializer.fromJson<double?>(json['low']),
      close: serializer.fromJson<double?>(json['close']),
      volume: serializer.fromJson<double?>(json['volume']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'open': serializer.toJson<double?>(open),
      'high': serializer.toJson<double?>(high),
      'low': serializer.toJson<double?>(low),
      'close': serializer.toJson<double?>(close),
      'volume': serializer.toJson<double?>(volume),
    };
  }

  WeeklyPriceEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> open = const Value.absent(),
    Value<double?> high = const Value.absent(),
    Value<double?> low = const Value.absent(),
    Value<double?> close = const Value.absent(),
    Value<double?> volume = const Value.absent(),
  }) => WeeklyPriceEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    open: open.present ? open.value : this.open,
    high: high.present ? high.value : this.high,
    low: low.present ? low.value : this.low,
    close: close.present ? close.value : this.close,
    volume: volume.present ? volume.value : this.volume,
  );
  WeeklyPriceEntry copyWithCompanion(WeeklyPriceCompanion data) {
    return WeeklyPriceEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      open: data.open.present ? data.open.value : this.open,
      high: data.high.present ? data.high.value : this.high,
      low: data.low.present ? data.low.value : this.low,
      close: data.close.present ? data.close.value : this.close,
      volume: data.volume.present ? data.volume.value : this.volume,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyPriceEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('open: $open, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('close: $close, ')
          ..write('volume: $volume')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, date, open, high, low, close, volume);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyPriceEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.open == this.open &&
          other.high == this.high &&
          other.low == this.low &&
          other.close == this.close &&
          other.volume == this.volume);
}

class WeeklyPriceCompanion extends UpdateCompanion<WeeklyPriceEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> open;
  final Value<double?> high;
  final Value<double?> low;
  final Value<double?> close;
  final Value<double?> volume;
  final Value<int> rowid;
  const WeeklyPriceCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.open = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.close = const Value.absent(),
    this.volume = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyPriceCompanion.insert({
    required String symbol,
    required DateTime date,
    this.open = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.close = const Value.absent(),
    this.volume = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<WeeklyPriceEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? open,
    Expression<double>? high,
    Expression<double>? low,
    Expression<double>? close,
    Expression<double>? volume,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (open != null) 'open': open,
      if (high != null) 'high': high,
      if (low != null) 'low': low,
      if (close != null) 'close': close,
      if (volume != null) 'volume': volume,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyPriceCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? open,
    Value<double?>? high,
    Value<double?>? low,
    Value<double?>? close,
    Value<double?>? volume,
    Value<int>? rowid,
  }) {
    return WeeklyPriceCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (open.present) {
      map['open'] = Variable<double>(open.value);
    }
    if (high.present) {
      map['high'] = Variable<double>(high.value);
    }
    if (low.present) {
      map['low'] = Variable<double>(low.value);
    }
    if (close.present) {
      map['close'] = Variable<double>(close.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyPriceCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('open: $open, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('close: $close, ')
          ..write('volume: $volume, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HoldingDistributionTable extends HoldingDistribution
    with TableInfo<$HoldingDistributionTable, HoldingDistributionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingDistributionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shareholdersMeta = const VerificationMeta(
    'shareholders',
  );
  @override
  late final GeneratedColumn<int> shareholders = GeneratedColumn<int>(
    'shareholders',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _percentMeta = const VerificationMeta(
    'percent',
  );
  @override
  late final GeneratedColumn<double> percent = GeneratedColumn<double>(
    'percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sharesMeta = const VerificationMeta('shares');
  @override
  late final GeneratedColumn<double> shares = GeneratedColumn<double>(
    'shares',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    level,
    shareholders,
    percent,
    shares,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holding_distribution';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoldingDistributionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('shareholders')) {
      context.handle(
        _shareholdersMeta,
        shareholders.isAcceptableOrUnknown(
          data['shareholders']!,
          _shareholdersMeta,
        ),
      );
    }
    if (data.containsKey('percent')) {
      context.handle(
        _percentMeta,
        percent.isAcceptableOrUnknown(data['percent']!, _percentMeta),
      );
    }
    if (data.containsKey('shares')) {
      context.handle(
        _sharesMeta,
        shares.isAcceptableOrUnknown(data['shares']!, _sharesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date, level};
  @override
  HoldingDistributionEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoldingDistributionEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      shareholders: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shareholders'],
      ),
      percent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percent'],
      ),
      shares: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shares'],
      ),
    );
  }

  @override
  $HoldingDistributionTable createAlias(String alias) {
    return $HoldingDistributionTable(attachedDatabase, alias);
  }
}

class HoldingDistributionEntry extends DataClass
    implements Insertable<HoldingDistributionEntry> {
  /// 股票代碼
  final String symbol;

  /// 報告日期
  final DateTime date;

  /// 持股級距（如 "1-999"、"1000-5000"）
  final String level;

  /// 該級距股東人數
  final int? shareholders;

  /// 佔總股數比例（%）
  final double? percent;

  /// 持股數（股）
  final double? shares;
  const HoldingDistributionEntry({
    required this.symbol,
    required this.date,
    required this.level,
    this.shareholders,
    this.percent,
    this.shares,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    map['level'] = Variable<String>(level);
    if (!nullToAbsent || shareholders != null) {
      map['shareholders'] = Variable<int>(shareholders);
    }
    if (!nullToAbsent || percent != null) {
      map['percent'] = Variable<double>(percent);
    }
    if (!nullToAbsent || shares != null) {
      map['shares'] = Variable<double>(shares);
    }
    return map;
  }

  HoldingDistributionCompanion toCompanion(bool nullToAbsent) {
    return HoldingDistributionCompanion(
      symbol: Value(symbol),
      date: Value(date),
      level: Value(level),
      shareholders: shareholders == null && nullToAbsent
          ? const Value.absent()
          : Value(shareholders),
      percent: percent == null && nullToAbsent
          ? const Value.absent()
          : Value(percent),
      shares: shares == null && nullToAbsent
          ? const Value.absent()
          : Value(shares),
    );
  }

  factory HoldingDistributionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoldingDistributionEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      level: serializer.fromJson<String>(json['level']),
      shareholders: serializer.fromJson<int?>(json['shareholders']),
      percent: serializer.fromJson<double?>(json['percent']),
      shares: serializer.fromJson<double?>(json['shares']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'level': serializer.toJson<String>(level),
      'shareholders': serializer.toJson<int?>(shareholders),
      'percent': serializer.toJson<double?>(percent),
      'shares': serializer.toJson<double?>(shares),
    };
  }

  HoldingDistributionEntry copyWith({
    String? symbol,
    DateTime? date,
    String? level,
    Value<int?> shareholders = const Value.absent(),
    Value<double?> percent = const Value.absent(),
    Value<double?> shares = const Value.absent(),
  }) => HoldingDistributionEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    level: level ?? this.level,
    shareholders: shareholders.present ? shareholders.value : this.shareholders,
    percent: percent.present ? percent.value : this.percent,
    shares: shares.present ? shares.value : this.shares,
  );
  HoldingDistributionEntry copyWithCompanion(
    HoldingDistributionCompanion data,
  ) {
    return HoldingDistributionEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      level: data.level.present ? data.level.value : this.level,
      shareholders: data.shareholders.present
          ? data.shareholders.value
          : this.shareholders,
      percent: data.percent.present ? data.percent.value : this.percent,
      shares: data.shares.present ? data.shares.value : this.shares,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoldingDistributionEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('level: $level, ')
          ..write('shareholders: $shareholders, ')
          ..write('percent: $percent, ')
          ..write('shares: $shares')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(symbol, date, level, shareholders, percent, shares);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoldingDistributionEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.level == this.level &&
          other.shareholders == this.shareholders &&
          other.percent == this.percent &&
          other.shares == this.shares);
}

class HoldingDistributionCompanion
    extends UpdateCompanion<HoldingDistributionEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<String> level;
  final Value<int?> shareholders;
  final Value<double?> percent;
  final Value<double?> shares;
  final Value<int> rowid;
  const HoldingDistributionCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.level = const Value.absent(),
    this.shareholders = const Value.absent(),
    this.percent = const Value.absent(),
    this.shares = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HoldingDistributionCompanion.insert({
    required String symbol,
    required DateTime date,
    required String level,
    this.shareholders = const Value.absent(),
    this.percent = const Value.absent(),
    this.shares = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date),
       level = Value(level);
  static Insertable<HoldingDistributionEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<String>? level,
    Expression<int>? shareholders,
    Expression<double>? percent,
    Expression<double>? shares,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (level != null) 'level': level,
      if (shareholders != null) 'shareholders': shareholders,
      if (percent != null) 'percent': percent,
      if (shares != null) 'shares': shares,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HoldingDistributionCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<String>? level,
    Value<int?>? shareholders,
    Value<double?>? percent,
    Value<double?>? shares,
    Value<int>? rowid,
  }) {
    return HoldingDistributionCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      level: level ?? this.level,
      shareholders: shareholders ?? this.shareholders,
      percent: percent ?? this.percent,
      shares: shares ?? this.shares,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (shareholders.present) {
      map['shareholders'] = Variable<int>(shareholders.value);
    }
    if (percent.present) {
      map['percent'] = Variable<double>(percent.value);
    }
    if (shares.present) {
      map['shares'] = Variable<double>(shares.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingDistributionCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('level: $level, ')
          ..write('shareholders: $shareholders, ')
          ..write('percent: $percent, ')
          ..write('shares: $shares, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MonthlyRevenueTable extends MonthlyRevenue
    with TableInfo<$MonthlyRevenueTable, MonthlyRevenueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthlyRevenueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revenueYearMeta = const VerificationMeta(
    'revenueYear',
  );
  @override
  late final GeneratedColumn<int> revenueYear = GeneratedColumn<int>(
    'revenue_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revenueMonthMeta = const VerificationMeta(
    'revenueMonth',
  );
  @override
  late final GeneratedColumn<int> revenueMonth = GeneratedColumn<int>(
    'revenue_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revenueMeta = const VerificationMeta(
    'revenue',
  );
  @override
  late final GeneratedColumn<double> revenue = GeneratedColumn<double>(
    'revenue',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _momGrowthMeta = const VerificationMeta(
    'momGrowth',
  );
  @override
  late final GeneratedColumn<double> momGrowth = GeneratedColumn<double>(
    'mom_growth',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yoyGrowthMeta = const VerificationMeta(
    'yoyGrowth',
  );
  @override
  late final GeneratedColumn<double> yoyGrowth = GeneratedColumn<double>(
    'yoy_growth',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    revenueYear,
    revenueMonth,
    revenue,
    momGrowth,
    yoyGrowth,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monthly_revenue';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthlyRevenueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('revenue_year')) {
      context.handle(
        _revenueYearMeta,
        revenueYear.isAcceptableOrUnknown(
          data['revenue_year']!,
          _revenueYearMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_revenueYearMeta);
    }
    if (data.containsKey('revenue_month')) {
      context.handle(
        _revenueMonthMeta,
        revenueMonth.isAcceptableOrUnknown(
          data['revenue_month']!,
          _revenueMonthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_revenueMonthMeta);
    }
    if (data.containsKey('revenue')) {
      context.handle(
        _revenueMeta,
        revenue.isAcceptableOrUnknown(data['revenue']!, _revenueMeta),
      );
    } else if (isInserting) {
      context.missing(_revenueMeta);
    }
    if (data.containsKey('mom_growth')) {
      context.handle(
        _momGrowthMeta,
        momGrowth.isAcceptableOrUnknown(data['mom_growth']!, _momGrowthMeta),
      );
    }
    if (data.containsKey('yoy_growth')) {
      context.handle(
        _yoyGrowthMeta,
        yoyGrowth.isAcceptableOrUnknown(data['yoy_growth']!, _yoyGrowthMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  MonthlyRevenueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthlyRevenueEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      revenueYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revenue_year'],
      )!,
      revenueMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revenue_month'],
      )!,
      revenue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}revenue'],
      )!,
      momGrowth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mom_growth'],
      ),
      yoyGrowth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}yoy_growth'],
      ),
    );
  }

  @override
  $MonthlyRevenueTable createAlias(String alias) {
    return $MonthlyRevenueTable(attachedDatabase, alias);
  }
}

class MonthlyRevenueEntry extends DataClass
    implements Insertable<MonthlyRevenueEntry> {
  /// 股票代碼
  final String symbol;

  /// 報告日期（統一使用當月第一天）
  final DateTime date;

  /// 營收年度
  final int revenueYear;

  /// 營收月份
  final int revenueMonth;

  /// 月營收（千元）
  final double revenue;

  /// 月增率（%）
  final double? momGrowth;

  /// 年增率（%）
  final double? yoyGrowth;
  const MonthlyRevenueEntry({
    required this.symbol,
    required this.date,
    required this.revenueYear,
    required this.revenueMonth,
    required this.revenue,
    this.momGrowth,
    this.yoyGrowth,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    map['revenue_year'] = Variable<int>(revenueYear);
    map['revenue_month'] = Variable<int>(revenueMonth);
    map['revenue'] = Variable<double>(revenue);
    if (!nullToAbsent || momGrowth != null) {
      map['mom_growth'] = Variable<double>(momGrowth);
    }
    if (!nullToAbsent || yoyGrowth != null) {
      map['yoy_growth'] = Variable<double>(yoyGrowth);
    }
    return map;
  }

  MonthlyRevenueCompanion toCompanion(bool nullToAbsent) {
    return MonthlyRevenueCompanion(
      symbol: Value(symbol),
      date: Value(date),
      revenueYear: Value(revenueYear),
      revenueMonth: Value(revenueMonth),
      revenue: Value(revenue),
      momGrowth: momGrowth == null && nullToAbsent
          ? const Value.absent()
          : Value(momGrowth),
      yoyGrowth: yoyGrowth == null && nullToAbsent
          ? const Value.absent()
          : Value(yoyGrowth),
    );
  }

  factory MonthlyRevenueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthlyRevenueEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      revenueYear: serializer.fromJson<int>(json['revenueYear']),
      revenueMonth: serializer.fromJson<int>(json['revenueMonth']),
      revenue: serializer.fromJson<double>(json['revenue']),
      momGrowth: serializer.fromJson<double?>(json['momGrowth']),
      yoyGrowth: serializer.fromJson<double?>(json['yoyGrowth']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'revenueYear': serializer.toJson<int>(revenueYear),
      'revenueMonth': serializer.toJson<int>(revenueMonth),
      'revenue': serializer.toJson<double>(revenue),
      'momGrowth': serializer.toJson<double?>(momGrowth),
      'yoyGrowth': serializer.toJson<double?>(yoyGrowth),
    };
  }

  MonthlyRevenueEntry copyWith({
    String? symbol,
    DateTime? date,
    int? revenueYear,
    int? revenueMonth,
    double? revenue,
    Value<double?> momGrowth = const Value.absent(),
    Value<double?> yoyGrowth = const Value.absent(),
  }) => MonthlyRevenueEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    revenueYear: revenueYear ?? this.revenueYear,
    revenueMonth: revenueMonth ?? this.revenueMonth,
    revenue: revenue ?? this.revenue,
    momGrowth: momGrowth.present ? momGrowth.value : this.momGrowth,
    yoyGrowth: yoyGrowth.present ? yoyGrowth.value : this.yoyGrowth,
  );
  MonthlyRevenueEntry copyWithCompanion(MonthlyRevenueCompanion data) {
    return MonthlyRevenueEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      revenueYear: data.revenueYear.present
          ? data.revenueYear.value
          : this.revenueYear,
      revenueMonth: data.revenueMonth.present
          ? data.revenueMonth.value
          : this.revenueMonth,
      revenue: data.revenue.present ? data.revenue.value : this.revenue,
      momGrowth: data.momGrowth.present ? data.momGrowth.value : this.momGrowth,
      yoyGrowth: data.yoyGrowth.present ? data.yoyGrowth.value : this.yoyGrowth,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthlyRevenueEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('revenueYear: $revenueYear, ')
          ..write('revenueMonth: $revenueMonth, ')
          ..write('revenue: $revenue, ')
          ..write('momGrowth: $momGrowth, ')
          ..write('yoyGrowth: $yoyGrowth')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    date,
    revenueYear,
    revenueMonth,
    revenue,
    momGrowth,
    yoyGrowth,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlyRevenueEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.revenueYear == this.revenueYear &&
          other.revenueMonth == this.revenueMonth &&
          other.revenue == this.revenue &&
          other.momGrowth == this.momGrowth &&
          other.yoyGrowth == this.yoyGrowth);
}

class MonthlyRevenueCompanion extends UpdateCompanion<MonthlyRevenueEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<int> revenueYear;
  final Value<int> revenueMonth;
  final Value<double> revenue;
  final Value<double?> momGrowth;
  final Value<double?> yoyGrowth;
  final Value<int> rowid;
  const MonthlyRevenueCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.revenueYear = const Value.absent(),
    this.revenueMonth = const Value.absent(),
    this.revenue = const Value.absent(),
    this.momGrowth = const Value.absent(),
    this.yoyGrowth = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MonthlyRevenueCompanion.insert({
    required String symbol,
    required DateTime date,
    required int revenueYear,
    required int revenueMonth,
    required double revenue,
    this.momGrowth = const Value.absent(),
    this.yoyGrowth = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date),
       revenueYear = Value(revenueYear),
       revenueMonth = Value(revenueMonth),
       revenue = Value(revenue);
  static Insertable<MonthlyRevenueEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<int>? revenueYear,
    Expression<int>? revenueMonth,
    Expression<double>? revenue,
    Expression<double>? momGrowth,
    Expression<double>? yoyGrowth,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (revenueYear != null) 'revenue_year': revenueYear,
      if (revenueMonth != null) 'revenue_month': revenueMonth,
      if (revenue != null) 'revenue': revenue,
      if (momGrowth != null) 'mom_growth': momGrowth,
      if (yoyGrowth != null) 'yoy_growth': yoyGrowth,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MonthlyRevenueCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<int>? revenueYear,
    Value<int>? revenueMonth,
    Value<double>? revenue,
    Value<double?>? momGrowth,
    Value<double?>? yoyGrowth,
    Value<int>? rowid,
  }) {
    return MonthlyRevenueCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      revenueYear: revenueYear ?? this.revenueYear,
      revenueMonth: revenueMonth ?? this.revenueMonth,
      revenue: revenue ?? this.revenue,
      momGrowth: momGrowth ?? this.momGrowth,
      yoyGrowth: yoyGrowth ?? this.yoyGrowth,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (revenueYear.present) {
      map['revenue_year'] = Variable<int>(revenueYear.value);
    }
    if (revenueMonth.present) {
      map['revenue_month'] = Variable<int>(revenueMonth.value);
    }
    if (revenue.present) {
      map['revenue'] = Variable<double>(revenue.value);
    }
    if (momGrowth.present) {
      map['mom_growth'] = Variable<double>(momGrowth.value);
    }
    if (yoyGrowth.present) {
      map['yoy_growth'] = Variable<double>(yoyGrowth.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthlyRevenueCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('revenueYear: $revenueYear, ')
          ..write('revenueMonth: $revenueMonth, ')
          ..write('revenue: $revenue, ')
          ..write('momGrowth: $momGrowth, ')
          ..write('yoyGrowth: $yoyGrowth, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockValuationTable extends StockValuation
    with TableInfo<$StockValuationTable, StockValuationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockValuationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _perMeta = const VerificationMeta('per');
  @override
  late final GeneratedColumn<double> per = GeneratedColumn<double>(
    'per',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pbrMeta = const VerificationMeta('pbr');
  @override
  late final GeneratedColumn<double> pbr = GeneratedColumn<double>(
    'pbr',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dividendYieldMeta = const VerificationMeta(
    'dividendYield',
  );
  @override
  late final GeneratedColumn<double> dividendYield = GeneratedColumn<double>(
    'dividend_yield',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [symbol, date, per, pbr, dividendYield];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_valuation';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockValuationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('per')) {
      context.handle(
        _perMeta,
        per.isAcceptableOrUnknown(data['per']!, _perMeta),
      );
    }
    if (data.containsKey('pbr')) {
      context.handle(
        _pbrMeta,
        pbr.isAcceptableOrUnknown(data['pbr']!, _pbrMeta),
      );
    }
    if (data.containsKey('dividend_yield')) {
      context.handle(
        _dividendYieldMeta,
        dividendYield.isAcceptableOrUnknown(
          data['dividend_yield']!,
          _dividendYieldMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  StockValuationEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockValuationEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      per: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}per'],
      ),
      pbr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pbr'],
      ),
      dividendYield: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dividend_yield'],
      ),
    );
  }

  @override
  $StockValuationTable createAlias(String alias) {
    return $StockValuationTable(attachedDatabase, alias);
  }
}

class StockValuationEntry extends DataClass
    implements Insertable<StockValuationEntry> {
  /// 股票代碼
  final String symbol;

  /// 交易日期
  final DateTime date;

  /// 本益比（PE ratio）
  final double? per;

  /// 股價淨值比（PB ratio）
  final double? pbr;

  /// 殖利率（%）
  final double? dividendYield;
  const StockValuationEntry({
    required this.symbol,
    required this.date,
    this.per,
    this.pbr,
    this.dividendYield,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || per != null) {
      map['per'] = Variable<double>(per);
    }
    if (!nullToAbsent || pbr != null) {
      map['pbr'] = Variable<double>(pbr);
    }
    if (!nullToAbsent || dividendYield != null) {
      map['dividend_yield'] = Variable<double>(dividendYield);
    }
    return map;
  }

  StockValuationCompanion toCompanion(bool nullToAbsent) {
    return StockValuationCompanion(
      symbol: Value(symbol),
      date: Value(date),
      per: per == null && nullToAbsent ? const Value.absent() : Value(per),
      pbr: pbr == null && nullToAbsent ? const Value.absent() : Value(pbr),
      dividendYield: dividendYield == null && nullToAbsent
          ? const Value.absent()
          : Value(dividendYield),
    );
  }

  factory StockValuationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockValuationEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      per: serializer.fromJson<double?>(json['per']),
      pbr: serializer.fromJson<double?>(json['pbr']),
      dividendYield: serializer.fromJson<double?>(json['dividendYield']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'per': serializer.toJson<double?>(per),
      'pbr': serializer.toJson<double?>(pbr),
      'dividendYield': serializer.toJson<double?>(dividendYield),
    };
  }

  StockValuationEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> per = const Value.absent(),
    Value<double?> pbr = const Value.absent(),
    Value<double?> dividendYield = const Value.absent(),
  }) => StockValuationEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    per: per.present ? per.value : this.per,
    pbr: pbr.present ? pbr.value : this.pbr,
    dividendYield: dividendYield.present
        ? dividendYield.value
        : this.dividendYield,
  );
  StockValuationEntry copyWithCompanion(StockValuationCompanion data) {
    return StockValuationEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      per: data.per.present ? data.per.value : this.per,
      pbr: data.pbr.present ? data.pbr.value : this.pbr,
      dividendYield: data.dividendYield.present
          ? data.dividendYield.value
          : this.dividendYield,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockValuationEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('per: $per, ')
          ..write('pbr: $pbr, ')
          ..write('dividendYield: $dividendYield')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(symbol, date, per, pbr, dividendYield);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockValuationEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.per == this.per &&
          other.pbr == this.pbr &&
          other.dividendYield == this.dividendYield);
}

class StockValuationCompanion extends UpdateCompanion<StockValuationEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> per;
  final Value<double?> pbr;
  final Value<double?> dividendYield;
  final Value<int> rowid;
  const StockValuationCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.per = const Value.absent(),
    this.pbr = const Value.absent(),
    this.dividendYield = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockValuationCompanion.insert({
    required String symbol,
    required DateTime date,
    this.per = const Value.absent(),
    this.pbr = const Value.absent(),
    this.dividendYield = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<StockValuationEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? per,
    Expression<double>? pbr,
    Expression<double>? dividendYield,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (per != null) 'per': per,
      if (pbr != null) 'pbr': pbr,
      if (dividendYield != null) 'dividend_yield': dividendYield,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockValuationCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? per,
    Value<double?>? pbr,
    Value<double?>? dividendYield,
    Value<int>? rowid,
  }) {
    return StockValuationCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      per: per ?? this.per,
      pbr: pbr ?? this.pbr,
      dividendYield: dividendYield ?? this.dividendYield,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (per.present) {
      map['per'] = Variable<double>(per.value);
    }
    if (pbr.present) {
      map['pbr'] = Variable<double>(pbr.value);
    }
    if (dividendYield.present) {
      map['dividend_yield'] = Variable<double>(dividendYield.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockValuationCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('per: $per, ')
          ..write('pbr: $pbr, ')
          ..write('dividendYield: $dividendYield, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DividendHistoryTable extends DividendHistory
    with TableInfo<$DividendHistoryTable, DividendHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DividendHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cashDividendMeta = const VerificationMeta(
    'cashDividend',
  );
  @override
  late final GeneratedColumn<double> cashDividend = GeneratedColumn<double>(
    'cash_dividend',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stockDividendMeta = const VerificationMeta(
    'stockDividend',
  );
  @override
  late final GeneratedColumn<double> stockDividend = GeneratedColumn<double>(
    'stock_dividend',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _exDividendDateMeta = const VerificationMeta(
    'exDividendDate',
  );
  @override
  late final GeneratedColumn<String> exDividendDate = GeneratedColumn<String>(
    'ex_dividend_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exRightsDateMeta = const VerificationMeta(
    'exRightsDate',
  );
  @override
  late final GeneratedColumn<String> exRightsDate = GeneratedColumn<String>(
    'ex_rights_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    year,
    cashDividend,
    stockDividend,
    exDividendDate,
    exRightsDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dividend_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<DividendHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('cash_dividend')) {
      context.handle(
        _cashDividendMeta,
        cashDividend.isAcceptableOrUnknown(
          data['cash_dividend']!,
          _cashDividendMeta,
        ),
      );
    }
    if (data.containsKey('stock_dividend')) {
      context.handle(
        _stockDividendMeta,
        stockDividend.isAcceptableOrUnknown(
          data['stock_dividend']!,
          _stockDividendMeta,
        ),
      );
    }
    if (data.containsKey('ex_dividend_date')) {
      context.handle(
        _exDividendDateMeta,
        exDividendDate.isAcceptableOrUnknown(
          data['ex_dividend_date']!,
          _exDividendDateMeta,
        ),
      );
    }
    if (data.containsKey('ex_rights_date')) {
      context.handle(
        _exRightsDateMeta,
        exRightsDate.isAcceptableOrUnknown(
          data['ex_rights_date']!,
          _exRightsDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, year};
  @override
  DividendHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DividendHistoryEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      cashDividend: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cash_dividend'],
      )!,
      stockDividend: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stock_dividend'],
      )!,
      exDividendDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ex_dividend_date'],
      ),
      exRightsDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ex_rights_date'],
      ),
    );
  }

  @override
  $DividendHistoryTable createAlias(String alias) {
    return $DividendHistoryTable(attachedDatabase, alias);
  }
}

class DividendHistoryEntry extends DataClass
    implements Insertable<DividendHistoryEntry> {
  /// 股票代碼
  final String symbol;

  /// 股利所屬年度
  final int year;

  /// 現金股利（元）
  final double cashDividend;

  /// 股票股利（元）
  final double stockDividend;

  /// 除息日（格式: yyyy-MM-dd）
  final String? exDividendDate;

  /// 除權日（格式: yyyy-MM-dd）
  final String? exRightsDate;
  const DividendHistoryEntry({
    required this.symbol,
    required this.year,
    required this.cashDividend,
    required this.stockDividend,
    this.exDividendDate,
    this.exRightsDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['year'] = Variable<int>(year);
    map['cash_dividend'] = Variable<double>(cashDividend);
    map['stock_dividend'] = Variable<double>(stockDividend);
    if (!nullToAbsent || exDividendDate != null) {
      map['ex_dividend_date'] = Variable<String>(exDividendDate);
    }
    if (!nullToAbsent || exRightsDate != null) {
      map['ex_rights_date'] = Variable<String>(exRightsDate);
    }
    return map;
  }

  DividendHistoryCompanion toCompanion(bool nullToAbsent) {
    return DividendHistoryCompanion(
      symbol: Value(symbol),
      year: Value(year),
      cashDividend: Value(cashDividend),
      stockDividend: Value(stockDividend),
      exDividendDate: exDividendDate == null && nullToAbsent
          ? const Value.absent()
          : Value(exDividendDate),
      exRightsDate: exRightsDate == null && nullToAbsent
          ? const Value.absent()
          : Value(exRightsDate),
    );
  }

  factory DividendHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DividendHistoryEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      year: serializer.fromJson<int>(json['year']),
      cashDividend: serializer.fromJson<double>(json['cashDividend']),
      stockDividend: serializer.fromJson<double>(json['stockDividend']),
      exDividendDate: serializer.fromJson<String?>(json['exDividendDate']),
      exRightsDate: serializer.fromJson<String?>(json['exRightsDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'year': serializer.toJson<int>(year),
      'cashDividend': serializer.toJson<double>(cashDividend),
      'stockDividend': serializer.toJson<double>(stockDividend),
      'exDividendDate': serializer.toJson<String?>(exDividendDate),
      'exRightsDate': serializer.toJson<String?>(exRightsDate),
    };
  }

  DividendHistoryEntry copyWith({
    String? symbol,
    int? year,
    double? cashDividend,
    double? stockDividend,
    Value<String?> exDividendDate = const Value.absent(),
    Value<String?> exRightsDate = const Value.absent(),
  }) => DividendHistoryEntry(
    symbol: symbol ?? this.symbol,
    year: year ?? this.year,
    cashDividend: cashDividend ?? this.cashDividend,
    stockDividend: stockDividend ?? this.stockDividend,
    exDividendDate: exDividendDate.present
        ? exDividendDate.value
        : this.exDividendDate,
    exRightsDate: exRightsDate.present ? exRightsDate.value : this.exRightsDate,
  );
  DividendHistoryEntry copyWithCompanion(DividendHistoryCompanion data) {
    return DividendHistoryEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      year: data.year.present ? data.year.value : this.year,
      cashDividend: data.cashDividend.present
          ? data.cashDividend.value
          : this.cashDividend,
      stockDividend: data.stockDividend.present
          ? data.stockDividend.value
          : this.stockDividend,
      exDividendDate: data.exDividendDate.present
          ? data.exDividendDate.value
          : this.exDividendDate,
      exRightsDate: data.exRightsDate.present
          ? data.exRightsDate.value
          : this.exRightsDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DividendHistoryEntry(')
          ..write('symbol: $symbol, ')
          ..write('year: $year, ')
          ..write('cashDividend: $cashDividend, ')
          ..write('stockDividend: $stockDividend, ')
          ..write('exDividendDate: $exDividendDate, ')
          ..write('exRightsDate: $exRightsDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    year,
    cashDividend,
    stockDividend,
    exDividendDate,
    exRightsDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DividendHistoryEntry &&
          other.symbol == this.symbol &&
          other.year == this.year &&
          other.cashDividend == this.cashDividend &&
          other.stockDividend == this.stockDividend &&
          other.exDividendDate == this.exDividendDate &&
          other.exRightsDate == this.exRightsDate);
}

class DividendHistoryCompanion extends UpdateCompanion<DividendHistoryEntry> {
  final Value<String> symbol;
  final Value<int> year;
  final Value<double> cashDividend;
  final Value<double> stockDividend;
  final Value<String?> exDividendDate;
  final Value<String?> exRightsDate;
  final Value<int> rowid;
  const DividendHistoryCompanion({
    this.symbol = const Value.absent(),
    this.year = const Value.absent(),
    this.cashDividend = const Value.absent(),
    this.stockDividend = const Value.absent(),
    this.exDividendDate = const Value.absent(),
    this.exRightsDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DividendHistoryCompanion.insert({
    required String symbol,
    required int year,
    this.cashDividend = const Value.absent(),
    this.stockDividend = const Value.absent(),
    this.exDividendDate = const Value.absent(),
    this.exRightsDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       year = Value(year);
  static Insertable<DividendHistoryEntry> custom({
    Expression<String>? symbol,
    Expression<int>? year,
    Expression<double>? cashDividend,
    Expression<double>? stockDividend,
    Expression<String>? exDividendDate,
    Expression<String>? exRightsDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (year != null) 'year': year,
      if (cashDividend != null) 'cash_dividend': cashDividend,
      if (stockDividend != null) 'stock_dividend': stockDividend,
      if (exDividendDate != null) 'ex_dividend_date': exDividendDate,
      if (exRightsDate != null) 'ex_rights_date': exRightsDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DividendHistoryCompanion copyWith({
    Value<String>? symbol,
    Value<int>? year,
    Value<double>? cashDividend,
    Value<double>? stockDividend,
    Value<String?>? exDividendDate,
    Value<String?>? exRightsDate,
    Value<int>? rowid,
  }) {
    return DividendHistoryCompanion(
      symbol: symbol ?? this.symbol,
      year: year ?? this.year,
      cashDividend: cashDividend ?? this.cashDividend,
      stockDividend: stockDividend ?? this.stockDividend,
      exDividendDate: exDividendDate ?? this.exDividendDate,
      exRightsDate: exRightsDate ?? this.exRightsDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (cashDividend.present) {
      map['cash_dividend'] = Variable<double>(cashDividend.value);
    }
    if (stockDividend.present) {
      map['stock_dividend'] = Variable<double>(stockDividend.value);
    }
    if (exDividendDate.present) {
      map['ex_dividend_date'] = Variable<String>(exDividendDate.value);
    }
    if (exRightsDate.present) {
      map['ex_rights_date'] = Variable<String>(exRightsDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DividendHistoryCompanion(')
          ..write('symbol: $symbol, ')
          ..write('year: $year, ')
          ..write('cashDividend: $cashDividend, ')
          ..write('stockDividend: $stockDividend, ')
          ..write('exDividendDate: $exDividendDate, ')
          ..write('exRightsDate: $exRightsDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarginTradingTable extends MarginTrading
    with TableInfo<$MarginTradingTable, MarginTradingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarginTradingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marginBuyMeta = const VerificationMeta(
    'marginBuy',
  );
  @override
  late final GeneratedColumn<double> marginBuy = GeneratedColumn<double>(
    'margin_buy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _marginSellMeta = const VerificationMeta(
    'marginSell',
  );
  @override
  late final GeneratedColumn<double> marginSell = GeneratedColumn<double>(
    'margin_sell',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _marginBalanceMeta = const VerificationMeta(
    'marginBalance',
  );
  @override
  late final GeneratedColumn<double> marginBalance = GeneratedColumn<double>(
    'margin_balance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shortBuyMeta = const VerificationMeta(
    'shortBuy',
  );
  @override
  late final GeneratedColumn<double> shortBuy = GeneratedColumn<double>(
    'short_buy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shortSellMeta = const VerificationMeta(
    'shortSell',
  );
  @override
  late final GeneratedColumn<double> shortSell = GeneratedColumn<double>(
    'short_sell',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shortBalanceMeta = const VerificationMeta(
    'shortBalance',
  );
  @override
  late final GeneratedColumn<double> shortBalance = GeneratedColumn<double>(
    'short_balance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    marginBuy,
    marginSell,
    marginBalance,
    shortBuy,
    shortSell,
    shortBalance,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'margin_trading';
  @override
  VerificationContext validateIntegrity(
    Insertable<MarginTradingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('margin_buy')) {
      context.handle(
        _marginBuyMeta,
        marginBuy.isAcceptableOrUnknown(data['margin_buy']!, _marginBuyMeta),
      );
    }
    if (data.containsKey('margin_sell')) {
      context.handle(
        _marginSellMeta,
        marginSell.isAcceptableOrUnknown(data['margin_sell']!, _marginSellMeta),
      );
    }
    if (data.containsKey('margin_balance')) {
      context.handle(
        _marginBalanceMeta,
        marginBalance.isAcceptableOrUnknown(
          data['margin_balance']!,
          _marginBalanceMeta,
        ),
      );
    }
    if (data.containsKey('short_buy')) {
      context.handle(
        _shortBuyMeta,
        shortBuy.isAcceptableOrUnknown(data['short_buy']!, _shortBuyMeta),
      );
    }
    if (data.containsKey('short_sell')) {
      context.handle(
        _shortSellMeta,
        shortSell.isAcceptableOrUnknown(data['short_sell']!, _shortSellMeta),
      );
    }
    if (data.containsKey('short_balance')) {
      context.handle(
        _shortBalanceMeta,
        shortBalance.isAcceptableOrUnknown(
          data['short_balance']!,
          _shortBalanceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  MarginTradingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarginTradingEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      marginBuy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}margin_buy'],
      ),
      marginSell: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}margin_sell'],
      ),
      marginBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}margin_balance'],
      ),
      shortBuy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}short_buy'],
      ),
      shortSell: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}short_sell'],
      ),
      shortBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}short_balance'],
      ),
    );
  }

  @override
  $MarginTradingTable createAlias(String alias) {
    return $MarginTradingTable(attachedDatabase, alias);
  }
}

class MarginTradingEntry extends DataClass
    implements Insertable<MarginTradingEntry> {
  /// 股票代碼
  final String symbol;

  /// 交易日期
  final DateTime date;

  /// 融資買進（張）
  final double? marginBuy;

  /// 融資賣出（張）
  final double? marginSell;

  /// 融資餘額（張）
  final double? marginBalance;

  /// 融券買進/回補（張）
  final double? shortBuy;

  /// 融券賣出（張）
  final double? shortSell;

  /// 融券餘額（張）
  final double? shortBalance;
  const MarginTradingEntry({
    required this.symbol,
    required this.date,
    this.marginBuy,
    this.marginSell,
    this.marginBalance,
    this.shortBuy,
    this.shortSell,
    this.shortBalance,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || marginBuy != null) {
      map['margin_buy'] = Variable<double>(marginBuy);
    }
    if (!nullToAbsent || marginSell != null) {
      map['margin_sell'] = Variable<double>(marginSell);
    }
    if (!nullToAbsent || marginBalance != null) {
      map['margin_balance'] = Variable<double>(marginBalance);
    }
    if (!nullToAbsent || shortBuy != null) {
      map['short_buy'] = Variable<double>(shortBuy);
    }
    if (!nullToAbsent || shortSell != null) {
      map['short_sell'] = Variable<double>(shortSell);
    }
    if (!nullToAbsent || shortBalance != null) {
      map['short_balance'] = Variable<double>(shortBalance);
    }
    return map;
  }

  MarginTradingCompanion toCompanion(bool nullToAbsent) {
    return MarginTradingCompanion(
      symbol: Value(symbol),
      date: Value(date),
      marginBuy: marginBuy == null && nullToAbsent
          ? const Value.absent()
          : Value(marginBuy),
      marginSell: marginSell == null && nullToAbsent
          ? const Value.absent()
          : Value(marginSell),
      marginBalance: marginBalance == null && nullToAbsent
          ? const Value.absent()
          : Value(marginBalance),
      shortBuy: shortBuy == null && nullToAbsent
          ? const Value.absent()
          : Value(shortBuy),
      shortSell: shortSell == null && nullToAbsent
          ? const Value.absent()
          : Value(shortSell),
      shortBalance: shortBalance == null && nullToAbsent
          ? const Value.absent()
          : Value(shortBalance),
    );
  }

  factory MarginTradingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarginTradingEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      marginBuy: serializer.fromJson<double?>(json['marginBuy']),
      marginSell: serializer.fromJson<double?>(json['marginSell']),
      marginBalance: serializer.fromJson<double?>(json['marginBalance']),
      shortBuy: serializer.fromJson<double?>(json['shortBuy']),
      shortSell: serializer.fromJson<double?>(json['shortSell']),
      shortBalance: serializer.fromJson<double?>(json['shortBalance']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'marginBuy': serializer.toJson<double?>(marginBuy),
      'marginSell': serializer.toJson<double?>(marginSell),
      'marginBalance': serializer.toJson<double?>(marginBalance),
      'shortBuy': serializer.toJson<double?>(shortBuy),
      'shortSell': serializer.toJson<double?>(shortSell),
      'shortBalance': serializer.toJson<double?>(shortBalance),
    };
  }

  MarginTradingEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> marginBuy = const Value.absent(),
    Value<double?> marginSell = const Value.absent(),
    Value<double?> marginBalance = const Value.absent(),
    Value<double?> shortBuy = const Value.absent(),
    Value<double?> shortSell = const Value.absent(),
    Value<double?> shortBalance = const Value.absent(),
  }) => MarginTradingEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    marginBuy: marginBuy.present ? marginBuy.value : this.marginBuy,
    marginSell: marginSell.present ? marginSell.value : this.marginSell,
    marginBalance: marginBalance.present
        ? marginBalance.value
        : this.marginBalance,
    shortBuy: shortBuy.present ? shortBuy.value : this.shortBuy,
    shortSell: shortSell.present ? shortSell.value : this.shortSell,
    shortBalance: shortBalance.present ? shortBalance.value : this.shortBalance,
  );
  MarginTradingEntry copyWithCompanion(MarginTradingCompanion data) {
    return MarginTradingEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      marginBuy: data.marginBuy.present ? data.marginBuy.value : this.marginBuy,
      marginSell: data.marginSell.present
          ? data.marginSell.value
          : this.marginSell,
      marginBalance: data.marginBalance.present
          ? data.marginBalance.value
          : this.marginBalance,
      shortBuy: data.shortBuy.present ? data.shortBuy.value : this.shortBuy,
      shortSell: data.shortSell.present ? data.shortSell.value : this.shortSell,
      shortBalance: data.shortBalance.present
          ? data.shortBalance.value
          : this.shortBalance,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarginTradingEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('marginBuy: $marginBuy, ')
          ..write('marginSell: $marginSell, ')
          ..write('marginBalance: $marginBalance, ')
          ..write('shortBuy: $shortBuy, ')
          ..write('shortSell: $shortSell, ')
          ..write('shortBalance: $shortBalance')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    date,
    marginBuy,
    marginSell,
    marginBalance,
    shortBuy,
    shortSell,
    shortBalance,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarginTradingEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.marginBuy == this.marginBuy &&
          other.marginSell == this.marginSell &&
          other.marginBalance == this.marginBalance &&
          other.shortBuy == this.shortBuy &&
          other.shortSell == this.shortSell &&
          other.shortBalance == this.shortBalance);
}

class MarginTradingCompanion extends UpdateCompanion<MarginTradingEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> marginBuy;
  final Value<double?> marginSell;
  final Value<double?> marginBalance;
  final Value<double?> shortBuy;
  final Value<double?> shortSell;
  final Value<double?> shortBalance;
  final Value<int> rowid;
  const MarginTradingCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.marginBuy = const Value.absent(),
    this.marginSell = const Value.absent(),
    this.marginBalance = const Value.absent(),
    this.shortBuy = const Value.absent(),
    this.shortSell = const Value.absent(),
    this.shortBalance = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarginTradingCompanion.insert({
    required String symbol,
    required DateTime date,
    this.marginBuy = const Value.absent(),
    this.marginSell = const Value.absent(),
    this.marginBalance = const Value.absent(),
    this.shortBuy = const Value.absent(),
    this.shortSell = const Value.absent(),
    this.shortBalance = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<MarginTradingEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? marginBuy,
    Expression<double>? marginSell,
    Expression<double>? marginBalance,
    Expression<double>? shortBuy,
    Expression<double>? shortSell,
    Expression<double>? shortBalance,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (marginBuy != null) 'margin_buy': marginBuy,
      if (marginSell != null) 'margin_sell': marginSell,
      if (marginBalance != null) 'margin_balance': marginBalance,
      if (shortBuy != null) 'short_buy': shortBuy,
      if (shortSell != null) 'short_sell': shortSell,
      if (shortBalance != null) 'short_balance': shortBalance,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarginTradingCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? marginBuy,
    Value<double?>? marginSell,
    Value<double?>? marginBalance,
    Value<double?>? shortBuy,
    Value<double?>? shortSell,
    Value<double?>? shortBalance,
    Value<int>? rowid,
  }) {
    return MarginTradingCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      marginBuy: marginBuy ?? this.marginBuy,
      marginSell: marginSell ?? this.marginSell,
      marginBalance: marginBalance ?? this.marginBalance,
      shortBuy: shortBuy ?? this.shortBuy,
      shortSell: shortSell ?? this.shortSell,
      shortBalance: shortBalance ?? this.shortBalance,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (marginBuy.present) {
      map['margin_buy'] = Variable<double>(marginBuy.value);
    }
    if (marginSell.present) {
      map['margin_sell'] = Variable<double>(marginSell.value);
    }
    if (marginBalance.present) {
      map['margin_balance'] = Variable<double>(marginBalance.value);
    }
    if (shortBuy.present) {
      map['short_buy'] = Variable<double>(shortBuy.value);
    }
    if (shortSell.present) {
      map['short_sell'] = Variable<double>(shortSell.value);
    }
    if (shortBalance.present) {
      map['short_balance'] = Variable<double>(shortBalance.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarginTradingCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('marginBuy: $marginBuy, ')
          ..write('marginSell: $marginSell, ')
          ..write('marginBalance: $marginBalance, ')
          ..write('shortBuy: $shortBuy, ')
          ..write('shortSell: $shortSell, ')
          ..write('shortBalance: $shortBalance, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TradingWarningTable extends TradingWarning
    with TableInfo<$TradingWarningTable, TradingWarningEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TradingWarningTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _warningTypeMeta = const VerificationMeta(
    'warningType',
  );
  @override
  late final GeneratedColumn<String> warningType = GeneratedColumn<String>(
    'warning_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonCodeMeta = const VerificationMeta(
    'reasonCode',
  );
  @override
  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
    'reason_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonDescriptionMeta = const VerificationMeta(
    'reasonDescription',
  );
  @override
  late final GeneratedColumn<String> reasonDescription =
      GeneratedColumn<String>(
        'reason_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _disposalMeasuresMeta = const VerificationMeta(
    'disposalMeasures',
  );
  @override
  late final GeneratedColumn<String> disposalMeasures = GeneratedColumn<String>(
    'disposal_measures',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _disposalStartDateMeta = const VerificationMeta(
    'disposalStartDate',
  );
  @override
  late final GeneratedColumn<DateTime> disposalStartDate =
      GeneratedColumn<DateTime>(
        'disposal_start_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _disposalEndDateMeta = const VerificationMeta(
    'disposalEndDate',
  );
  @override
  late final GeneratedColumn<DateTime> disposalEndDate =
      GeneratedColumn<DateTime>(
        'disposal_end_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    warningType,
    reasonCode,
    reasonDescription,
    disposalMeasures,
    disposalStartDate,
    disposalEndDate,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trading_warning';
  @override
  VerificationContext validateIntegrity(
    Insertable<TradingWarningEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('warning_type')) {
      context.handle(
        _warningTypeMeta,
        warningType.isAcceptableOrUnknown(
          data['warning_type']!,
          _warningTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_warningTypeMeta);
    }
    if (data.containsKey('reason_code')) {
      context.handle(
        _reasonCodeMeta,
        reasonCode.isAcceptableOrUnknown(data['reason_code']!, _reasonCodeMeta),
      );
    }
    if (data.containsKey('reason_description')) {
      context.handle(
        _reasonDescriptionMeta,
        reasonDescription.isAcceptableOrUnknown(
          data['reason_description']!,
          _reasonDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('disposal_measures')) {
      context.handle(
        _disposalMeasuresMeta,
        disposalMeasures.isAcceptableOrUnknown(
          data['disposal_measures']!,
          _disposalMeasuresMeta,
        ),
      );
    }
    if (data.containsKey('disposal_start_date')) {
      context.handle(
        _disposalStartDateMeta,
        disposalStartDate.isAcceptableOrUnknown(
          data['disposal_start_date']!,
          _disposalStartDateMeta,
        ),
      );
    }
    if (data.containsKey('disposal_end_date')) {
      context.handle(
        _disposalEndDateMeta,
        disposalEndDate.isAcceptableOrUnknown(
          data['disposal_end_date']!,
          _disposalEndDateMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date, warningType};
  @override
  TradingWarningEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TradingWarningEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      warningType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warning_type'],
      )!,
      reasonCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_code'],
      ),
      reasonDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_description'],
      ),
      disposalMeasures: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}disposal_measures'],
      ),
      disposalStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}disposal_start_date'],
      ),
      disposalEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}disposal_end_date'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $TradingWarningTable createAlias(String alias) {
    return $TradingWarningTable(attachedDatabase, alias);
  }
}

class TradingWarningEntry extends DataClass
    implements Insertable<TradingWarningEntry> {
  /// 股票代碼
  final String symbol;

  /// 公告日期
  final DateTime date;

  /// 警示類型：ATTENTION（注意）| DISPOSAL（處置）
  final String warningType;

  /// 列入原因代碼
  final String? reasonCode;

  /// 原因說明
  final String? reasonDescription;

  /// 處置措施（僅處置股）
  final String? disposalMeasures;

  /// 處置起始日
  final DateTime? disposalStartDate;

  /// 處置結束日
  final DateTime? disposalEndDate;

  /// 是否目前生效
  final bool isActive;
  const TradingWarningEntry({
    required this.symbol,
    required this.date,
    required this.warningType,
    this.reasonCode,
    this.reasonDescription,
    this.disposalMeasures,
    this.disposalStartDate,
    this.disposalEndDate,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    map['warning_type'] = Variable<String>(warningType);
    if (!nullToAbsent || reasonCode != null) {
      map['reason_code'] = Variable<String>(reasonCode);
    }
    if (!nullToAbsent || reasonDescription != null) {
      map['reason_description'] = Variable<String>(reasonDescription);
    }
    if (!nullToAbsent || disposalMeasures != null) {
      map['disposal_measures'] = Variable<String>(disposalMeasures);
    }
    if (!nullToAbsent || disposalStartDate != null) {
      map['disposal_start_date'] = Variable<DateTime>(disposalStartDate);
    }
    if (!nullToAbsent || disposalEndDate != null) {
      map['disposal_end_date'] = Variable<DateTime>(disposalEndDate);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  TradingWarningCompanion toCompanion(bool nullToAbsent) {
    return TradingWarningCompanion(
      symbol: Value(symbol),
      date: Value(date),
      warningType: Value(warningType),
      reasonCode: reasonCode == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonCode),
      reasonDescription: reasonDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonDescription),
      disposalMeasures: disposalMeasures == null && nullToAbsent
          ? const Value.absent()
          : Value(disposalMeasures),
      disposalStartDate: disposalStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(disposalStartDate),
      disposalEndDate: disposalEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(disposalEndDate),
      isActive: Value(isActive),
    );
  }

  factory TradingWarningEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TradingWarningEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      warningType: serializer.fromJson<String>(json['warningType']),
      reasonCode: serializer.fromJson<String?>(json['reasonCode']),
      reasonDescription: serializer.fromJson<String?>(
        json['reasonDescription'],
      ),
      disposalMeasures: serializer.fromJson<String?>(json['disposalMeasures']),
      disposalStartDate: serializer.fromJson<DateTime?>(
        json['disposalStartDate'],
      ),
      disposalEndDate: serializer.fromJson<DateTime?>(json['disposalEndDate']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'warningType': serializer.toJson<String>(warningType),
      'reasonCode': serializer.toJson<String?>(reasonCode),
      'reasonDescription': serializer.toJson<String?>(reasonDescription),
      'disposalMeasures': serializer.toJson<String?>(disposalMeasures),
      'disposalStartDate': serializer.toJson<DateTime?>(disposalStartDate),
      'disposalEndDate': serializer.toJson<DateTime?>(disposalEndDate),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  TradingWarningEntry copyWith({
    String? symbol,
    DateTime? date,
    String? warningType,
    Value<String?> reasonCode = const Value.absent(),
    Value<String?> reasonDescription = const Value.absent(),
    Value<String?> disposalMeasures = const Value.absent(),
    Value<DateTime?> disposalStartDate = const Value.absent(),
    Value<DateTime?> disposalEndDate = const Value.absent(),
    bool? isActive,
  }) => TradingWarningEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    warningType: warningType ?? this.warningType,
    reasonCode: reasonCode.present ? reasonCode.value : this.reasonCode,
    reasonDescription: reasonDescription.present
        ? reasonDescription.value
        : this.reasonDescription,
    disposalMeasures: disposalMeasures.present
        ? disposalMeasures.value
        : this.disposalMeasures,
    disposalStartDate: disposalStartDate.present
        ? disposalStartDate.value
        : this.disposalStartDate,
    disposalEndDate: disposalEndDate.present
        ? disposalEndDate.value
        : this.disposalEndDate,
    isActive: isActive ?? this.isActive,
  );
  TradingWarningEntry copyWithCompanion(TradingWarningCompanion data) {
    return TradingWarningEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      warningType: data.warningType.present
          ? data.warningType.value
          : this.warningType,
      reasonCode: data.reasonCode.present
          ? data.reasonCode.value
          : this.reasonCode,
      reasonDescription: data.reasonDescription.present
          ? data.reasonDescription.value
          : this.reasonDescription,
      disposalMeasures: data.disposalMeasures.present
          ? data.disposalMeasures.value
          : this.disposalMeasures,
      disposalStartDate: data.disposalStartDate.present
          ? data.disposalStartDate.value
          : this.disposalStartDate,
      disposalEndDate: data.disposalEndDate.present
          ? data.disposalEndDate.value
          : this.disposalEndDate,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TradingWarningEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('warningType: $warningType, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('reasonDescription: $reasonDescription, ')
          ..write('disposalMeasures: $disposalMeasures, ')
          ..write('disposalStartDate: $disposalStartDate, ')
          ..write('disposalEndDate: $disposalEndDate, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    date,
    warningType,
    reasonCode,
    reasonDescription,
    disposalMeasures,
    disposalStartDate,
    disposalEndDate,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TradingWarningEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.warningType == this.warningType &&
          other.reasonCode == this.reasonCode &&
          other.reasonDescription == this.reasonDescription &&
          other.disposalMeasures == this.disposalMeasures &&
          other.disposalStartDate == this.disposalStartDate &&
          other.disposalEndDate == this.disposalEndDate &&
          other.isActive == this.isActive);
}

class TradingWarningCompanion extends UpdateCompanion<TradingWarningEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<String> warningType;
  final Value<String?> reasonCode;
  final Value<String?> reasonDescription;
  final Value<String?> disposalMeasures;
  final Value<DateTime?> disposalStartDate;
  final Value<DateTime?> disposalEndDate;
  final Value<bool> isActive;
  final Value<int> rowid;
  const TradingWarningCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.warningType = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.reasonDescription = const Value.absent(),
    this.disposalMeasures = const Value.absent(),
    this.disposalStartDate = const Value.absent(),
    this.disposalEndDate = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TradingWarningCompanion.insert({
    required String symbol,
    required DateTime date,
    required String warningType,
    this.reasonCode = const Value.absent(),
    this.reasonDescription = const Value.absent(),
    this.disposalMeasures = const Value.absent(),
    this.disposalStartDate = const Value.absent(),
    this.disposalEndDate = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date),
       warningType = Value(warningType);
  static Insertable<TradingWarningEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<String>? warningType,
    Expression<String>? reasonCode,
    Expression<String>? reasonDescription,
    Expression<String>? disposalMeasures,
    Expression<DateTime>? disposalStartDate,
    Expression<DateTime>? disposalEndDate,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (warningType != null) 'warning_type': warningType,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (reasonDescription != null) 'reason_description': reasonDescription,
      if (disposalMeasures != null) 'disposal_measures': disposalMeasures,
      if (disposalStartDate != null) 'disposal_start_date': disposalStartDate,
      if (disposalEndDate != null) 'disposal_end_date': disposalEndDate,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TradingWarningCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<String>? warningType,
    Value<String?>? reasonCode,
    Value<String?>? reasonDescription,
    Value<String?>? disposalMeasures,
    Value<DateTime?>? disposalStartDate,
    Value<DateTime?>? disposalEndDate,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return TradingWarningCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      warningType: warningType ?? this.warningType,
      reasonCode: reasonCode ?? this.reasonCode,
      reasonDescription: reasonDescription ?? this.reasonDescription,
      disposalMeasures: disposalMeasures ?? this.disposalMeasures,
      disposalStartDate: disposalStartDate ?? this.disposalStartDate,
      disposalEndDate: disposalEndDate ?? this.disposalEndDate,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (warningType.present) {
      map['warning_type'] = Variable<String>(warningType.value);
    }
    if (reasonCode.present) {
      map['reason_code'] = Variable<String>(reasonCode.value);
    }
    if (reasonDescription.present) {
      map['reason_description'] = Variable<String>(reasonDescription.value);
    }
    if (disposalMeasures.present) {
      map['disposal_measures'] = Variable<String>(disposalMeasures.value);
    }
    if (disposalStartDate.present) {
      map['disposal_start_date'] = Variable<DateTime>(disposalStartDate.value);
    }
    if (disposalEndDate.present) {
      map['disposal_end_date'] = Variable<DateTime>(disposalEndDate.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TradingWarningCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('warningType: $warningType, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('reasonDescription: $reasonDescription, ')
          ..write('disposalMeasures: $disposalMeasures, ')
          ..write('disposalStartDate: $disposalStartDate, ')
          ..write('disposalEndDate: $disposalEndDate, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InsiderHoldingTable extends InsiderHolding
    with TableInfo<$InsiderHoldingTable, InsiderHoldingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InsiderHoldingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directorSharesMeta = const VerificationMeta(
    'directorShares',
  );
  @override
  late final GeneratedColumn<double> directorShares = GeneratedColumn<double>(
    'director_shares',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supervisorSharesMeta = const VerificationMeta(
    'supervisorShares',
  );
  @override
  late final GeneratedColumn<double> supervisorShares = GeneratedColumn<double>(
    'supervisor_shares',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _managerSharesMeta = const VerificationMeta(
    'managerShares',
  );
  @override
  late final GeneratedColumn<double> managerShares = GeneratedColumn<double>(
    'manager_shares',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _insiderRatioMeta = const VerificationMeta(
    'insiderRatio',
  );
  @override
  late final GeneratedColumn<double> insiderRatio = GeneratedColumn<double>(
    'insider_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pledgeRatioMeta = const VerificationMeta(
    'pledgeRatio',
  );
  @override
  late final GeneratedColumn<double> pledgeRatio = GeneratedColumn<double>(
    'pledge_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sharesChangeMeta = const VerificationMeta(
    'sharesChange',
  );
  @override
  late final GeneratedColumn<double> sharesChange = GeneratedColumn<double>(
    'shares_change',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sharesIssuedMeta = const VerificationMeta(
    'sharesIssued',
  );
  @override
  late final GeneratedColumn<double> sharesIssued = GeneratedColumn<double>(
    'shares_issued',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    date,
    directorShares,
    supervisorShares,
    managerShares,
    insiderRatio,
    pledgeRatio,
    sharesChange,
    sharesIssued,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'insider_holding';
  @override
  VerificationContext validateIntegrity(
    Insertable<InsiderHoldingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('director_shares')) {
      context.handle(
        _directorSharesMeta,
        directorShares.isAcceptableOrUnknown(
          data['director_shares']!,
          _directorSharesMeta,
        ),
      );
    }
    if (data.containsKey('supervisor_shares')) {
      context.handle(
        _supervisorSharesMeta,
        supervisorShares.isAcceptableOrUnknown(
          data['supervisor_shares']!,
          _supervisorSharesMeta,
        ),
      );
    }
    if (data.containsKey('manager_shares')) {
      context.handle(
        _managerSharesMeta,
        managerShares.isAcceptableOrUnknown(
          data['manager_shares']!,
          _managerSharesMeta,
        ),
      );
    }
    if (data.containsKey('insider_ratio')) {
      context.handle(
        _insiderRatioMeta,
        insiderRatio.isAcceptableOrUnknown(
          data['insider_ratio']!,
          _insiderRatioMeta,
        ),
      );
    }
    if (data.containsKey('pledge_ratio')) {
      context.handle(
        _pledgeRatioMeta,
        pledgeRatio.isAcceptableOrUnknown(
          data['pledge_ratio']!,
          _pledgeRatioMeta,
        ),
      );
    }
    if (data.containsKey('shares_change')) {
      context.handle(
        _sharesChangeMeta,
        sharesChange.isAcceptableOrUnknown(
          data['shares_change']!,
          _sharesChangeMeta,
        ),
      );
    }
    if (data.containsKey('shares_issued')) {
      context.handle(
        _sharesIssuedMeta,
        sharesIssued.isAcceptableOrUnknown(
          data['shares_issued']!,
          _sharesIssuedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  InsiderHoldingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InsiderHoldingEntry(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      directorShares: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}director_shares'],
      ),
      supervisorShares: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}supervisor_shares'],
      ),
      managerShares: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}manager_shares'],
      ),
      insiderRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}insider_ratio'],
      ),
      pledgeRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pledge_ratio'],
      ),
      sharesChange: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shares_change'],
      ),
      sharesIssued: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shares_issued'],
      ),
    );
  }

  @override
  $InsiderHoldingTable createAlias(String alias) {
    return $InsiderHoldingTable(attachedDatabase, alias);
  }
}

class InsiderHoldingEntry extends DataClass
    implements Insertable<InsiderHoldingEntry> {
  /// 股票代碼
  final String symbol;

  /// 報告日期（月報）
  final DateTime date;

  /// 董事持股總數（股）
  final double? directorShares;

  /// 監察人持股總數（股）
  final double? supervisorShares;

  /// 經理人持股總數（股）
  final double? managerShares;

  /// 董監持股比例（%）
  final double? insiderRatio;

  /// 質押比例（%）
  final double? pledgeRatio;

  /// 持股變動（股）- 與前期比較
  final double? sharesChange;

  /// 已發行股數
  final double? sharesIssued;
  const InsiderHoldingEntry({
    required this.symbol,
    required this.date,
    this.directorShares,
    this.supervisorShares,
    this.managerShares,
    this.insiderRatio,
    this.pledgeRatio,
    this.sharesChange,
    this.sharesIssued,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || directorShares != null) {
      map['director_shares'] = Variable<double>(directorShares);
    }
    if (!nullToAbsent || supervisorShares != null) {
      map['supervisor_shares'] = Variable<double>(supervisorShares);
    }
    if (!nullToAbsent || managerShares != null) {
      map['manager_shares'] = Variable<double>(managerShares);
    }
    if (!nullToAbsent || insiderRatio != null) {
      map['insider_ratio'] = Variable<double>(insiderRatio);
    }
    if (!nullToAbsent || pledgeRatio != null) {
      map['pledge_ratio'] = Variable<double>(pledgeRatio);
    }
    if (!nullToAbsent || sharesChange != null) {
      map['shares_change'] = Variable<double>(sharesChange);
    }
    if (!nullToAbsent || sharesIssued != null) {
      map['shares_issued'] = Variable<double>(sharesIssued);
    }
    return map;
  }

  InsiderHoldingCompanion toCompanion(bool nullToAbsent) {
    return InsiderHoldingCompanion(
      symbol: Value(symbol),
      date: Value(date),
      directorShares: directorShares == null && nullToAbsent
          ? const Value.absent()
          : Value(directorShares),
      supervisorShares: supervisorShares == null && nullToAbsent
          ? const Value.absent()
          : Value(supervisorShares),
      managerShares: managerShares == null && nullToAbsent
          ? const Value.absent()
          : Value(managerShares),
      insiderRatio: insiderRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(insiderRatio),
      pledgeRatio: pledgeRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(pledgeRatio),
      sharesChange: sharesChange == null && nullToAbsent
          ? const Value.absent()
          : Value(sharesChange),
      sharesIssued: sharesIssued == null && nullToAbsent
          ? const Value.absent()
          : Value(sharesIssued),
    );
  }

  factory InsiderHoldingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InsiderHoldingEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      date: serializer.fromJson<DateTime>(json['date']),
      directorShares: serializer.fromJson<double?>(json['directorShares']),
      supervisorShares: serializer.fromJson<double?>(json['supervisorShares']),
      managerShares: serializer.fromJson<double?>(json['managerShares']),
      insiderRatio: serializer.fromJson<double?>(json['insiderRatio']),
      pledgeRatio: serializer.fromJson<double?>(json['pledgeRatio']),
      sharesChange: serializer.fromJson<double?>(json['sharesChange']),
      sharesIssued: serializer.fromJson<double?>(json['sharesIssued']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'directorShares': serializer.toJson<double?>(directorShares),
      'supervisorShares': serializer.toJson<double?>(supervisorShares),
      'managerShares': serializer.toJson<double?>(managerShares),
      'insiderRatio': serializer.toJson<double?>(insiderRatio),
      'pledgeRatio': serializer.toJson<double?>(pledgeRatio),
      'sharesChange': serializer.toJson<double?>(sharesChange),
      'sharesIssued': serializer.toJson<double?>(sharesIssued),
    };
  }

  InsiderHoldingEntry copyWith({
    String? symbol,
    DateTime? date,
    Value<double?> directorShares = const Value.absent(),
    Value<double?> supervisorShares = const Value.absent(),
    Value<double?> managerShares = const Value.absent(),
    Value<double?> insiderRatio = const Value.absent(),
    Value<double?> pledgeRatio = const Value.absent(),
    Value<double?> sharesChange = const Value.absent(),
    Value<double?> sharesIssued = const Value.absent(),
  }) => InsiderHoldingEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    directorShares: directorShares.present
        ? directorShares.value
        : this.directorShares,
    supervisorShares: supervisorShares.present
        ? supervisorShares.value
        : this.supervisorShares,
    managerShares: managerShares.present
        ? managerShares.value
        : this.managerShares,
    insiderRatio: insiderRatio.present ? insiderRatio.value : this.insiderRatio,
    pledgeRatio: pledgeRatio.present ? pledgeRatio.value : this.pledgeRatio,
    sharesChange: sharesChange.present ? sharesChange.value : this.sharesChange,
    sharesIssued: sharesIssued.present ? sharesIssued.value : this.sharesIssued,
  );
  InsiderHoldingEntry copyWithCompanion(InsiderHoldingCompanion data) {
    return InsiderHoldingEntry(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      date: data.date.present ? data.date.value : this.date,
      directorShares: data.directorShares.present
          ? data.directorShares.value
          : this.directorShares,
      supervisorShares: data.supervisorShares.present
          ? data.supervisorShares.value
          : this.supervisorShares,
      managerShares: data.managerShares.present
          ? data.managerShares.value
          : this.managerShares,
      insiderRatio: data.insiderRatio.present
          ? data.insiderRatio.value
          : this.insiderRatio,
      pledgeRatio: data.pledgeRatio.present
          ? data.pledgeRatio.value
          : this.pledgeRatio,
      sharesChange: data.sharesChange.present
          ? data.sharesChange.value
          : this.sharesChange,
      sharesIssued: data.sharesIssued.present
          ? data.sharesIssued.value
          : this.sharesIssued,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InsiderHoldingEntry(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('directorShares: $directorShares, ')
          ..write('supervisorShares: $supervisorShares, ')
          ..write('managerShares: $managerShares, ')
          ..write('insiderRatio: $insiderRatio, ')
          ..write('pledgeRatio: $pledgeRatio, ')
          ..write('sharesChange: $sharesChange, ')
          ..write('sharesIssued: $sharesIssued')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    symbol,
    date,
    directorShares,
    supervisorShares,
    managerShares,
    insiderRatio,
    pledgeRatio,
    sharesChange,
    sharesIssued,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InsiderHoldingEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.directorShares == this.directorShares &&
          other.supervisorShares == this.supervisorShares &&
          other.managerShares == this.managerShares &&
          other.insiderRatio == this.insiderRatio &&
          other.pledgeRatio == this.pledgeRatio &&
          other.sharesChange == this.sharesChange &&
          other.sharesIssued == this.sharesIssued);
}

class InsiderHoldingCompanion extends UpdateCompanion<InsiderHoldingEntry> {
  final Value<String> symbol;
  final Value<DateTime> date;
  final Value<double?> directorShares;
  final Value<double?> supervisorShares;
  final Value<double?> managerShares;
  final Value<double?> insiderRatio;
  final Value<double?> pledgeRatio;
  final Value<double?> sharesChange;
  final Value<double?> sharesIssued;
  final Value<int> rowid;
  const InsiderHoldingCompanion({
    this.symbol = const Value.absent(),
    this.date = const Value.absent(),
    this.directorShares = const Value.absent(),
    this.supervisorShares = const Value.absent(),
    this.managerShares = const Value.absent(),
    this.insiderRatio = const Value.absent(),
    this.pledgeRatio = const Value.absent(),
    this.sharesChange = const Value.absent(),
    this.sharesIssued = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InsiderHoldingCompanion.insert({
    required String symbol,
    required DateTime date,
    this.directorShares = const Value.absent(),
    this.supervisorShares = const Value.absent(),
    this.managerShares = const Value.absent(),
    this.insiderRatio = const Value.absent(),
    this.pledgeRatio = const Value.absent(),
    this.sharesChange = const Value.absent(),
    this.sharesIssued = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       date = Value(date);
  static Insertable<InsiderHoldingEntry> custom({
    Expression<String>? symbol,
    Expression<DateTime>? date,
    Expression<double>? directorShares,
    Expression<double>? supervisorShares,
    Expression<double>? managerShares,
    Expression<double>? insiderRatio,
    Expression<double>? pledgeRatio,
    Expression<double>? sharesChange,
    Expression<double>? sharesIssued,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (directorShares != null) 'director_shares': directorShares,
      if (supervisorShares != null) 'supervisor_shares': supervisorShares,
      if (managerShares != null) 'manager_shares': managerShares,
      if (insiderRatio != null) 'insider_ratio': insiderRatio,
      if (pledgeRatio != null) 'pledge_ratio': pledgeRatio,
      if (sharesChange != null) 'shares_change': sharesChange,
      if (sharesIssued != null) 'shares_issued': sharesIssued,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InsiderHoldingCompanion copyWith({
    Value<String>? symbol,
    Value<DateTime>? date,
    Value<double?>? directorShares,
    Value<double?>? supervisorShares,
    Value<double?>? managerShares,
    Value<double?>? insiderRatio,
    Value<double?>? pledgeRatio,
    Value<double?>? sharesChange,
    Value<double?>? sharesIssued,
    Value<int>? rowid,
  }) {
    return InsiderHoldingCompanion(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      directorShares: directorShares ?? this.directorShares,
      supervisorShares: supervisorShares ?? this.supervisorShares,
      managerShares: managerShares ?? this.managerShares,
      insiderRatio: insiderRatio ?? this.insiderRatio,
      pledgeRatio: pledgeRatio ?? this.pledgeRatio,
      sharesChange: sharesChange ?? this.sharesChange,
      sharesIssued: sharesIssued ?? this.sharesIssued,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (directorShares.present) {
      map['director_shares'] = Variable<double>(directorShares.value);
    }
    if (supervisorShares.present) {
      map['supervisor_shares'] = Variable<double>(supervisorShares.value);
    }
    if (managerShares.present) {
      map['manager_shares'] = Variable<double>(managerShares.value);
    }
    if (insiderRatio.present) {
      map['insider_ratio'] = Variable<double>(insiderRatio.value);
    }
    if (pledgeRatio.present) {
      map['pledge_ratio'] = Variable<double>(pledgeRatio.value);
    }
    if (sharesChange.present) {
      map['shares_change'] = Variable<double>(sharesChange.value);
    }
    if (sharesIssued.present) {
      map['shares_issued'] = Variable<double>(sharesIssued.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InsiderHoldingCompanion(')
          ..write('symbol: $symbol, ')
          ..write('date: $date, ')
          ..write('directorShares: $directorShares, ')
          ..write('supervisorShares: $supervisorShares, ')
          ..write('managerShares: $managerShares, ')
          ..write('insiderRatio: $insiderRatio, ')
          ..write('pledgeRatio: $pledgeRatio, ')
          ..write('sharesChange: $sharesChange, ')
          ..write('sharesIssued: $sharesIssued, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScreeningStrategyTableTable extends ScreeningStrategyTable
    with TableInfo<$ScreeningStrategyTableTable, ScreeningStrategyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScreeningStrategyTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conditionsJsonMeta = const VerificationMeta(
    'conditionsJson',
  );
  @override
  late final GeneratedColumn<String> conditionsJson = GeneratedColumn<String>(
    'conditions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    conditionsJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'screening_strategy_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScreeningStrategyEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('conditions_json')) {
      context.handle(
        _conditionsJsonMeta,
        conditionsJson.isAcceptableOrUnknown(
          data['conditions_json']!,
          _conditionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conditionsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScreeningStrategyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScreeningStrategyEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      conditionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conditions_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScreeningStrategyTableTable createAlias(String alias) {
    return $ScreeningStrategyTableTable(attachedDatabase, alias);
  }
}

class ScreeningStrategyEntry extends DataClass
    implements Insertable<ScreeningStrategyEntry> {
  /// 自動遞增 ID
  final int id;

  /// 策略名稱
  final String name;

  /// 篩選條件（JSON array）
  final String conditionsJson;

  /// 建立時間
  final DateTime createdAt;

  /// 最後更新時間
  final DateTime updatedAt;
  const ScreeningStrategyEntry({
    required this.id,
    required this.name,
    required this.conditionsJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['conditions_json'] = Variable<String>(conditionsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScreeningStrategyTableCompanion toCompanion(bool nullToAbsent) {
    return ScreeningStrategyTableCompanion(
      id: Value(id),
      name: Value(name),
      conditionsJson: Value(conditionsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScreeningStrategyEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScreeningStrategyEntry(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      conditionsJson: serializer.fromJson<String>(json['conditionsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'conditionsJson': serializer.toJson<String>(conditionsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScreeningStrategyEntry copyWith({
    int? id,
    String? name,
    String? conditionsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ScreeningStrategyEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    conditionsJson: conditionsJson ?? this.conditionsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScreeningStrategyEntry copyWithCompanion(
    ScreeningStrategyTableCompanion data,
  ) {
    return ScreeningStrategyEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      conditionsJson: data.conditionsJson.present
          ? data.conditionsJson.value
          : this.conditionsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScreeningStrategyEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('conditionsJson: $conditionsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, conditionsJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScreeningStrategyEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.conditionsJson == this.conditionsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScreeningStrategyTableCompanion
    extends UpdateCompanion<ScreeningStrategyEntry> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> conditionsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ScreeningStrategyTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.conditionsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ScreeningStrategyTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String conditionsJson,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name),
       conditionsJson = Value(conditionsJson);
  static Insertable<ScreeningStrategyEntry> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? conditionsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (conditionsJson != null) 'conditions_json': conditionsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ScreeningStrategyTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? conditionsJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ScreeningStrategyTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      conditionsJson: conditionsJson ?? this.conditionsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (conditionsJson.present) {
      map['conditions_json'] = Variable<String>(conditionsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScreeningStrategyTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('conditionsJson: $conditionsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PortfolioPositionTable extends PortfolioPosition
    with TableInfo<$PortfolioPositionTable, PortfolioPositionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfolioPositionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgCostMeta = const VerificationMeta(
    'avgCost',
  );
  @override
  late final GeneratedColumn<double> avgCost = GeneratedColumn<double>(
    'avg_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _realizedPnlMeta = const VerificationMeta(
    'realizedPnl',
  );
  @override
  late final GeneratedColumn<double> realizedPnl = GeneratedColumn<double>(
    'realized_pnl',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalDividendReceivedMeta =
      const VerificationMeta('totalDividendReceived');
  @override
  late final GeneratedColumn<double> totalDividendReceived =
      GeneratedColumn<double>(
        'total_dividend_received',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    quantity,
    avgCost,
    realizedPnl,
    totalDividendReceived,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portfolio_position';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortfolioPositionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('avg_cost')) {
      context.handle(
        _avgCostMeta,
        avgCost.isAcceptableOrUnknown(data['avg_cost']!, _avgCostMeta),
      );
    }
    if (data.containsKey('realized_pnl')) {
      context.handle(
        _realizedPnlMeta,
        realizedPnl.isAcceptableOrUnknown(
          data['realized_pnl']!,
          _realizedPnlMeta,
        ),
      );
    }
    if (data.containsKey('total_dividend_received')) {
      context.handle(
        _totalDividendReceivedMeta,
        totalDividendReceived.isAcceptableOrUnknown(
          data['total_dividend_received']!,
          _totalDividendReceivedMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PortfolioPositionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortfolioPositionEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      avgCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_cost'],
      )!,
      realizedPnl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}realized_pnl'],
      )!,
      totalDividendReceived: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_dividend_received'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PortfolioPositionTable createAlias(String alias) {
    return $PortfolioPositionTable(attachedDatabase, alias);
  }
}

class PortfolioPositionEntry extends DataClass
    implements Insertable<PortfolioPositionEntry> {
  /// 自動遞增 ID
  final int id;

  /// 股票代碼
  final String symbol;

  /// 持有股數（可為 0，代表已清倉但保留記錄）
  final double quantity;

  /// 平均成本（元/股）
  final double avgCost;

  /// 已實現損益（元）
  final double realizedPnl;

  /// 累計收到的現金股利（元）
  final double totalDividendReceived;

  /// 備註
  final String? note;

  /// 建立時間
  final DateTime createdAt;

  /// 最後更新時間
  final DateTime updatedAt;
  const PortfolioPositionEntry({
    required this.id,
    required this.symbol,
    required this.quantity,
    required this.avgCost,
    required this.realizedPnl,
    required this.totalDividendReceived,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    map['quantity'] = Variable<double>(quantity);
    map['avg_cost'] = Variable<double>(avgCost);
    map['realized_pnl'] = Variable<double>(realizedPnl);
    map['total_dividend_received'] = Variable<double>(totalDividendReceived);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PortfolioPositionCompanion toCompanion(bool nullToAbsent) {
    return PortfolioPositionCompanion(
      id: Value(id),
      symbol: Value(symbol),
      quantity: Value(quantity),
      avgCost: Value(avgCost),
      realizedPnl: Value(realizedPnl),
      totalDividendReceived: Value(totalDividendReceived),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PortfolioPositionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortfolioPositionEntry(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      quantity: serializer.fromJson<double>(json['quantity']),
      avgCost: serializer.fromJson<double>(json['avgCost']),
      realizedPnl: serializer.fromJson<double>(json['realizedPnl']),
      totalDividendReceived: serializer.fromJson<double>(
        json['totalDividendReceived'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'quantity': serializer.toJson<double>(quantity),
      'avgCost': serializer.toJson<double>(avgCost),
      'realizedPnl': serializer.toJson<double>(realizedPnl),
      'totalDividendReceived': serializer.toJson<double>(totalDividendReceived),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PortfolioPositionEntry copyWith({
    int? id,
    String? symbol,
    double? quantity,
    double? avgCost,
    double? realizedPnl,
    double? totalDividendReceived,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PortfolioPositionEntry(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    quantity: quantity ?? this.quantity,
    avgCost: avgCost ?? this.avgCost,
    realizedPnl: realizedPnl ?? this.realizedPnl,
    totalDividendReceived: totalDividendReceived ?? this.totalDividendReceived,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PortfolioPositionEntry copyWithCompanion(PortfolioPositionCompanion data) {
    return PortfolioPositionEntry(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      avgCost: data.avgCost.present ? data.avgCost.value : this.avgCost,
      realizedPnl: data.realizedPnl.present
          ? data.realizedPnl.value
          : this.realizedPnl,
      totalDividendReceived: data.totalDividendReceived.present
          ? data.totalDividendReceived.value
          : this.totalDividendReceived,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioPositionEntry(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('quantity: $quantity, ')
          ..write('avgCost: $avgCost, ')
          ..write('realizedPnl: $realizedPnl, ')
          ..write('totalDividendReceived: $totalDividendReceived, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    quantity,
    avgCost,
    realizedPnl,
    totalDividendReceived,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortfolioPositionEntry &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.quantity == this.quantity &&
          other.avgCost == this.avgCost &&
          other.realizedPnl == this.realizedPnl &&
          other.totalDividendReceived == this.totalDividendReceived &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PortfolioPositionCompanion
    extends UpdateCompanion<PortfolioPositionEntry> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<double> quantity;
  final Value<double> avgCost;
  final Value<double> realizedPnl;
  final Value<double> totalDividendReceived;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PortfolioPositionCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.quantity = const Value.absent(),
    this.avgCost = const Value.absent(),
    this.realizedPnl = const Value.absent(),
    this.totalDividendReceived = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PortfolioPositionCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    this.quantity = const Value.absent(),
    this.avgCost = const Value.absent(),
    this.realizedPnl = const Value.absent(),
    this.totalDividendReceived = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : symbol = Value(symbol);
  static Insertable<PortfolioPositionEntry> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<double>? quantity,
    Expression<double>? avgCost,
    Expression<double>? realizedPnl,
    Expression<double>? totalDividendReceived,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (quantity != null) 'quantity': quantity,
      if (avgCost != null) 'avg_cost': avgCost,
      if (realizedPnl != null) 'realized_pnl': realizedPnl,
      if (totalDividendReceived != null)
        'total_dividend_received': totalDividendReceived,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PortfolioPositionCompanion copyWith({
    Value<int>? id,
    Value<String>? symbol,
    Value<double>? quantity,
    Value<double>? avgCost,
    Value<double>? realizedPnl,
    Value<double>? totalDividendReceived,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PortfolioPositionCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      quantity: quantity ?? this.quantity,
      avgCost: avgCost ?? this.avgCost,
      realizedPnl: realizedPnl ?? this.realizedPnl,
      totalDividendReceived:
          totalDividendReceived ?? this.totalDividendReceived,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (avgCost.present) {
      map['avg_cost'] = Variable<double>(avgCost.value);
    }
    if (realizedPnl.present) {
      map['realized_pnl'] = Variable<double>(realizedPnl.value);
    }
    if (totalDividendReceived.present) {
      map['total_dividend_received'] = Variable<double>(
        totalDividendReceived.value,
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioPositionCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('quantity: $quantity, ')
          ..write('avgCost: $avgCost, ')
          ..write('realizedPnl: $realizedPnl, ')
          ..write('totalDividendReceived: $totalDividendReceived, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PortfolioTransactionTable extends PortfolioTransaction
    with TableInfo<$PortfolioTransactionTable, PortfolioTransactionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfolioTransactionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _txTypeMeta = const VerificationMeta('txType');
  @override
  late final GeneratedColumn<String> txType = GeneratedColumn<String>(
    'tx_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feeMeta = const VerificationMeta('fee');
  @override
  late final GeneratedColumn<double> fee = GeneratedColumn<double>(
    'fee',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<double> tax = GeneratedColumn<double>(
    'tax',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    txType,
    date,
    quantity,
    price,
    fee,
    tax,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portfolio_transaction';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortfolioTransactionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('tx_type')) {
      context.handle(
        _txTypeMeta,
        txType.isAcceptableOrUnknown(data['tx_type']!, _txTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_txTypeMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('fee')) {
      context.handle(
        _feeMeta,
        fee.isAcceptableOrUnknown(data['fee']!, _feeMeta),
      );
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PortfolioTransactionEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortfolioTransactionEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      txType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_type'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      fee: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fee'],
      )!,
      tax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PortfolioTransactionTable createAlias(String alias) {
    return $PortfolioTransactionTable(attachedDatabase, alias);
  }
}

class PortfolioTransactionEntry extends DataClass
    implements Insertable<PortfolioTransactionEntry> {
  /// 自動遞增 ID
  final int id;

  /// 股票代碼
  final String symbol;

  /// 交易類型：BUY, SELL, DIVIDEND_CASH, DIVIDEND_STOCK
  final String txType;

  /// 交易日期
  final DateTime date;

  /// 數量（股）
  final double quantity;

  /// 單價（元/股）
  final double price;

  /// 手續費（元）
  final double fee;

  /// 交易稅（元）
  final double tax;

  /// 備註
  final String? note;

  /// 建立時間
  final DateTime createdAt;
  const PortfolioTransactionEntry({
    required this.id,
    required this.symbol,
    required this.txType,
    required this.date,
    required this.quantity,
    required this.price,
    required this.fee,
    required this.tax,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    map['tx_type'] = Variable<String>(txType);
    map['date'] = Variable<DateTime>(date);
    map['quantity'] = Variable<double>(quantity);
    map['price'] = Variable<double>(price);
    map['fee'] = Variable<double>(fee);
    map['tax'] = Variable<double>(tax);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PortfolioTransactionCompanion toCompanion(bool nullToAbsent) {
    return PortfolioTransactionCompanion(
      id: Value(id),
      symbol: Value(symbol),
      txType: Value(txType),
      date: Value(date),
      quantity: Value(quantity),
      price: Value(price),
      fee: Value(fee),
      tax: Value(tax),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory PortfolioTransactionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortfolioTransactionEntry(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      txType: serializer.fromJson<String>(json['txType']),
      date: serializer.fromJson<DateTime>(json['date']),
      quantity: serializer.fromJson<double>(json['quantity']),
      price: serializer.fromJson<double>(json['price']),
      fee: serializer.fromJson<double>(json['fee']),
      tax: serializer.fromJson<double>(json['tax']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'txType': serializer.toJson<String>(txType),
      'date': serializer.toJson<DateTime>(date),
      'quantity': serializer.toJson<double>(quantity),
      'price': serializer.toJson<double>(price),
      'fee': serializer.toJson<double>(fee),
      'tax': serializer.toJson<double>(tax),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PortfolioTransactionEntry copyWith({
    int? id,
    String? symbol,
    String? txType,
    DateTime? date,
    double? quantity,
    double? price,
    double? fee,
    double? tax,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => PortfolioTransactionEntry(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    txType: txType ?? this.txType,
    date: date ?? this.date,
    quantity: quantity ?? this.quantity,
    price: price ?? this.price,
    fee: fee ?? this.fee,
    tax: tax ?? this.tax,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  PortfolioTransactionEntry copyWithCompanion(
    PortfolioTransactionCompanion data,
  ) {
    return PortfolioTransactionEntry(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      txType: data.txType.present ? data.txType.value : this.txType,
      date: data.date.present ? data.date.value : this.date,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      price: data.price.present ? data.price.value : this.price,
      fee: data.fee.present ? data.fee.value : this.fee,
      tax: data.tax.present ? data.tax.value : this.tax,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioTransactionEntry(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('txType: $txType, ')
          ..write('date: $date, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('fee: $fee, ')
          ..write('tax: $tax, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    txType,
    date,
    quantity,
    price,
    fee,
    tax,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortfolioTransactionEntry &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.txType == this.txType &&
          other.date == this.date &&
          other.quantity == this.quantity &&
          other.price == this.price &&
          other.fee == this.fee &&
          other.tax == this.tax &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class PortfolioTransactionCompanion
    extends UpdateCompanion<PortfolioTransactionEntry> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<String> txType;
  final Value<DateTime> date;
  final Value<double> quantity;
  final Value<double> price;
  final Value<double> fee;
  final Value<double> tax;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  const PortfolioTransactionCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.txType = const Value.absent(),
    this.date = const Value.absent(),
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
    this.fee = const Value.absent(),
    this.tax = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PortfolioTransactionCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    required String txType,
    required DateTime date,
    required double quantity,
    required double price,
    this.fee = const Value.absent(),
    this.tax = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : symbol = Value(symbol),
       txType = Value(txType),
       date = Value(date),
       quantity = Value(quantity),
       price = Value(price);
  static Insertable<PortfolioTransactionEntry> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<String>? txType,
    Expression<DateTime>? date,
    Expression<double>? quantity,
    Expression<double>? price,
    Expression<double>? fee,
    Expression<double>? tax,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (txType != null) 'tx_type': txType,
      if (date != null) 'date': date,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (fee != null) 'fee': fee,
      if (tax != null) 'tax': tax,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PortfolioTransactionCompanion copyWith({
    Value<int>? id,
    Value<String>? symbol,
    Value<String>? txType,
    Value<DateTime>? date,
    Value<double>? quantity,
    Value<double>? price,
    Value<double>? fee,
    Value<double>? tax,
    Value<String?>? note,
    Value<DateTime>? createdAt,
  }) {
    return PortfolioTransactionCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      txType: txType ?? this.txType,
      date: date ?? this.date,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      fee: fee ?? this.fee,
      tax: tax ?? this.tax,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (txType.present) {
      map['tx_type'] = Variable<String>(txType.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (fee.present) {
      map['fee'] = Variable<double>(fee.value);
    }
    if (tax.present) {
      map['tax'] = Variable<double>(tax.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioTransactionCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('txType: $txType, ')
          ..write('date: $date, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('fee: $fee, ')
          ..write('tax: $tax, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StockEventTable extends StockEvent
    with TableInfo<$StockEventTable, StockEventEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockEventTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<DateTime> eventDate = GeneratedColumn<DateTime>(
    'event_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAutoGeneratedMeta = const VerificationMeta(
    'isAutoGenerated',
  );
  @override
  late final GeneratedColumn<bool> isAutoGenerated = GeneratedColumn<bool>(
    'is_auto_generated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_auto_generated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    eventType,
    eventDate,
    title,
    description,
    isAutoGenerated,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_event';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockEventEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    } else if (isInserting) {
      context.missing(_eventDateMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_auto_generated')) {
      context.handle(
        _isAutoGeneratedMeta,
        isAutoGenerated.isAcceptableOrUnknown(
          data['is_auto_generated']!,
          _isAutoGeneratedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockEventEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockEventEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      ),
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_date'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isAutoGenerated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_auto_generated'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StockEventTable createAlias(String alias) {
    return $StockEventTable(attachedDatabase, alias);
  }
}

class StockEventEntry extends DataClass implements Insertable<StockEventEntry> {
  /// 自動遞增 ID
  final int id;

  /// 股票代碼（可為空，允許純個人備忘事件）
  final String? symbol;

  /// 事件類型：EX_DIVIDEND, EX_RIGHTS, EARNINGS, CUSTOM
  final String eventType;

  /// 事件日期
  final DateTime eventDate;

  /// 事件標題
  final String title;

  /// 事件描述/備註
  final String? description;

  /// 是否為系統自動產生
  final bool isAutoGenerated;

  /// 建立時間
  final DateTime createdAt;
  const StockEventEntry({
    required this.id,
    this.symbol,
    required this.eventType,
    required this.eventDate,
    required this.title,
    this.description,
    required this.isAutoGenerated,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || symbol != null) {
      map['symbol'] = Variable<String>(symbol);
    }
    map['event_type'] = Variable<String>(eventType);
    map['event_date'] = Variable<DateTime>(eventDate);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_auto_generated'] = Variable<bool>(isAutoGenerated);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StockEventCompanion toCompanion(bool nullToAbsent) {
    return StockEventCompanion(
      id: Value(id),
      symbol: symbol == null && nullToAbsent
          ? const Value.absent()
          : Value(symbol),
      eventType: Value(eventType),
      eventDate: Value(eventDate),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isAutoGenerated: Value(isAutoGenerated),
      createdAt: Value(createdAt),
    );
  }

  factory StockEventEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockEventEntry(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String?>(json['symbol']),
      eventType: serializer.fromJson<String>(json['eventType']),
      eventDate: serializer.fromJson<DateTime>(json['eventDate']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      isAutoGenerated: serializer.fromJson<bool>(json['isAutoGenerated']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String?>(symbol),
      'eventType': serializer.toJson<String>(eventType),
      'eventDate': serializer.toJson<DateTime>(eventDate),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'isAutoGenerated': serializer.toJson<bool>(isAutoGenerated),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StockEventEntry copyWith({
    int? id,
    Value<String?> symbol = const Value.absent(),
    String? eventType,
    DateTime? eventDate,
    String? title,
    Value<String?> description = const Value.absent(),
    bool? isAutoGenerated,
    DateTime? createdAt,
  }) => StockEventEntry(
    id: id ?? this.id,
    symbol: symbol.present ? symbol.value : this.symbol,
    eventType: eventType ?? this.eventType,
    eventDate: eventDate ?? this.eventDate,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    isAutoGenerated: isAutoGenerated ?? this.isAutoGenerated,
    createdAt: createdAt ?? this.createdAt,
  );
  StockEventEntry copyWithCompanion(StockEventCompanion data) {
    return StockEventEntry(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      isAutoGenerated: data.isAutoGenerated.present
          ? data.isAutoGenerated.value
          : this.isAutoGenerated,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockEventEntry(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('eventType: $eventType, ')
          ..write('eventDate: $eventDate, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isAutoGenerated: $isAutoGenerated, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    eventType,
    eventDate,
    title,
    description,
    isAutoGenerated,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockEventEntry &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.eventType == this.eventType &&
          other.eventDate == this.eventDate &&
          other.title == this.title &&
          other.description == this.description &&
          other.isAutoGenerated == this.isAutoGenerated &&
          other.createdAt == this.createdAt);
}

class StockEventCompanion extends UpdateCompanion<StockEventEntry> {
  final Value<int> id;
  final Value<String?> symbol;
  final Value<String> eventType;
  final Value<DateTime> eventDate;
  final Value<String> title;
  final Value<String?> description;
  final Value<bool> isAutoGenerated;
  final Value<DateTime> createdAt;
  const StockEventCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.eventType = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.isAutoGenerated = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StockEventCompanion.insert({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    required String eventType,
    required DateTime eventDate,
    required String title,
    this.description = const Value.absent(),
    this.isAutoGenerated = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : eventType = Value(eventType),
       eventDate = Value(eventDate),
       title = Value(title);
  static Insertable<StockEventEntry> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<String>? eventType,
    Expression<DateTime>? eventDate,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? isAutoGenerated,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (eventType != null) 'event_type': eventType,
      if (eventDate != null) 'event_date': eventDate,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (isAutoGenerated != null) 'is_auto_generated': isAutoGenerated,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StockEventCompanion copyWith({
    Value<int>? id,
    Value<String?>? symbol,
    Value<String>? eventType,
    Value<DateTime>? eventDate,
    Value<String>? title,
    Value<String?>? description,
    Value<bool>? isAutoGenerated,
    Value<DateTime>? createdAt,
  }) {
    return StockEventCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      eventType: eventType ?? this.eventType,
      eventDate: eventDate ?? this.eventDate,
      title: title ?? this.title,
      description: description ?? this.description,
      isAutoGenerated: isAutoGenerated ?? this.isAutoGenerated,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<DateTime>(eventDate.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isAutoGenerated.present) {
      map['is_auto_generated'] = Variable<bool>(isAutoGenerated.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockEventCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('eventType: $eventType, ')
          ..write('eventDate: $eventDate, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('isAutoGenerated: $isAutoGenerated, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MarketIndexTable extends MarketIndex
    with TableInfo<$MarketIndexTable, MarketIndexEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarketIndexTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closeMeta = const VerificationMeta('close');
  @override
  late final GeneratedColumn<double> close = GeneratedColumn<double>(
    'close',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changeMeta = const VerificationMeta('change');
  @override
  late final GeneratedColumn<double> change = GeneratedColumn<double>(
    'change',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changePercentMeta = const VerificationMeta(
    'changePercent',
  );
  @override
  late final GeneratedColumn<double> changePercent = GeneratedColumn<double>(
    'change_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    name,
    close,
    change,
    changePercent,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'market_index';
  @override
  VerificationContext validateIntegrity(
    Insertable<MarketIndexEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('close')) {
      context.handle(
        _closeMeta,
        close.isAcceptableOrUnknown(data['close']!, _closeMeta),
      );
    } else if (isInserting) {
      context.missing(_closeMeta);
    }
    if (data.containsKey('change')) {
      context.handle(
        _changeMeta,
        change.isAcceptableOrUnknown(data['change']!, _changeMeta),
      );
    } else if (isInserting) {
      context.missing(_changeMeta);
    }
    if (data.containsKey('change_percent')) {
      context.handle(
        _changePercentMeta,
        changePercent.isAcceptableOrUnknown(
          data['change_percent']!,
          _changePercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changePercentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date, name},
  ];
  @override
  MarketIndexEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarketIndexEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      close: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}close'],
      )!,
      change: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}change'],
      )!,
      changePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}change_percent'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MarketIndexTable createAlias(String alias) {
    return $MarketIndexTable(attachedDatabase, alias);
  }
}

class MarketIndexEntry extends DataClass
    implements Insertable<MarketIndexEntry> {
  /// 自動遞增 ID
  final int id;

  /// 交易日期
  final DateTime date;

  /// 指數名稱（原始全名，如「發行量加權股價指數」）
  final String name;

  /// 收盤值
  final double close;

  /// 漲跌點數
  final double change;

  /// 漲跌幅 (%)
  final double changePercent;

  /// 建立時間
  final DateTime createdAt;
  const MarketIndexEntry({
    required this.id,
    required this.date,
    required this.name,
    required this.close,
    required this.change,
    required this.changePercent,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['name'] = Variable<String>(name);
    map['close'] = Variable<double>(close);
    map['change'] = Variable<double>(change);
    map['change_percent'] = Variable<double>(changePercent);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MarketIndexCompanion toCompanion(bool nullToAbsent) {
    return MarketIndexCompanion(
      id: Value(id),
      date: Value(date),
      name: Value(name),
      close: Value(close),
      change: Value(change),
      changePercent: Value(changePercent),
      createdAt: Value(createdAt),
    );
  }

  factory MarketIndexEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarketIndexEntry(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      name: serializer.fromJson<String>(json['name']),
      close: serializer.fromJson<double>(json['close']),
      change: serializer.fromJson<double>(json['change']),
      changePercent: serializer.fromJson<double>(json['changePercent']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'name': serializer.toJson<String>(name),
      'close': serializer.toJson<double>(close),
      'change': serializer.toJson<double>(change),
      'changePercent': serializer.toJson<double>(changePercent),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MarketIndexEntry copyWith({
    int? id,
    DateTime? date,
    String? name,
    double? close,
    double? change,
    double? changePercent,
    DateTime? createdAt,
  }) => MarketIndexEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    name: name ?? this.name,
    close: close ?? this.close,
    change: change ?? this.change,
    changePercent: changePercent ?? this.changePercent,
    createdAt: createdAt ?? this.createdAt,
  );
  MarketIndexEntry copyWithCompanion(MarketIndexCompanion data) {
    return MarketIndexEntry(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      name: data.name.present ? data.name.value : this.name,
      close: data.close.present ? data.close.value : this.close,
      change: data.change.present ? data.change.value : this.change,
      changePercent: data.changePercent.present
          ? data.changePercent.value
          : this.changePercent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarketIndexEntry(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('name: $name, ')
          ..write('close: $close, ')
          ..write('change: $change, ')
          ..write('changePercent: $changePercent, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, name, close, change, changePercent, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarketIndexEntry &&
          other.id == this.id &&
          other.date == this.date &&
          other.name == this.name &&
          other.close == this.close &&
          other.change == this.change &&
          other.changePercent == this.changePercent &&
          other.createdAt == this.createdAt);
}

class MarketIndexCompanion extends UpdateCompanion<MarketIndexEntry> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> name;
  final Value<double> close;
  final Value<double> change;
  final Value<double> changePercent;
  final Value<DateTime> createdAt;
  const MarketIndexCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.name = const Value.absent(),
    this.close = const Value.absent(),
    this.change = const Value.absent(),
    this.changePercent = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MarketIndexCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String name,
    required double close,
    required double change,
    required double changePercent,
    this.createdAt = const Value.absent(),
  }) : date = Value(date),
       name = Value(name),
       close = Value(close),
       change = Value(change),
       changePercent = Value(changePercent);
  static Insertable<MarketIndexEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? name,
    Expression<double>? close,
    Expression<double>? change,
    Expression<double>? changePercent,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (name != null) 'name': name,
      if (close != null) 'close': close,
      if (change != null) 'change': change,
      if (changePercent != null) 'change_percent': changePercent,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MarketIndexCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? name,
    Value<double>? close,
    Value<double>? change,
    Value<double>? changePercent,
    Value<DateTime>? createdAt,
  }) {
    return MarketIndexCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      name: name ?? this.name,
      close: close ?? this.close,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (close.present) {
      map['close'] = Variable<double>(close.value);
    }
    if (change.present) {
      map['change'] = Variable<double>(change.value);
    }
    if (changePercent.present) {
      map['change_percent'] = Variable<double>(changePercent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarketIndexCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('name: $name, ')
          ..write('close: $close, ')
          ..write('change: $change, ')
          ..write('changePercent: $changePercent, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StockMasterTable stockMaster = $StockMasterTable(this);
  late final $DailyPriceTable dailyPrice = $DailyPriceTable(this);
  late final $DailyInstitutionalTable dailyInstitutional =
      $DailyInstitutionalTable(this);
  late final $NewsItemTable newsItem = $NewsItemTable(this);
  late final $NewsStockMapTable newsStockMap = $NewsStockMapTable(this);
  late final $DailyAnalysisTable dailyAnalysis = $DailyAnalysisTable(this);
  late final $DailyReasonTable dailyReason = $DailyReasonTable(this);
  late final $DailyRecommendationTable dailyRecommendation =
      $DailyRecommendationTable(this);
  late final $RuleAccuracyTable ruleAccuracy = $RuleAccuracyTable(this);
  late final $RecommendationValidationTable recommendationValidation =
      $RecommendationValidationTable(this);
  late final $WatchlistTable watchlist = $WatchlistTable(this);
  late final $UserNoteTable userNote = $UserNoteTable(this);
  late final $StrategyCardTable strategyCard = $StrategyCardTable(this);
  late final $UpdateRunTable updateRun = $UpdateRunTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $PriceAlertTable priceAlert = $PriceAlertTable(this);
  late final $UserInteractionTable userInteraction = $UserInteractionTable(
    this,
  );
  late final $UserPreferenceTable userPreference = $UserPreferenceTable(this);
  late final $ShareholdingTable shareholding = $ShareholdingTable(this);
  late final $DayTradingTable dayTrading = $DayTradingTable(this);
  late final $FinancialDataTable financialData = $FinancialDataTable(this);
  late final $AdjustedPriceTable adjustedPrice = $AdjustedPriceTable(this);
  late final $WeeklyPriceTable weeklyPrice = $WeeklyPriceTable(this);
  late final $HoldingDistributionTable holdingDistribution =
      $HoldingDistributionTable(this);
  late final $MonthlyRevenueTable monthlyRevenue = $MonthlyRevenueTable(this);
  late final $StockValuationTable stockValuation = $StockValuationTable(this);
  late final $DividendHistoryTable dividendHistory = $DividendHistoryTable(
    this,
  );
  late final $MarginTradingTable marginTrading = $MarginTradingTable(this);
  late final $TradingWarningTable tradingWarning = $TradingWarningTable(this);
  late final $InsiderHoldingTable insiderHolding = $InsiderHoldingTable(this);
  late final $ScreeningStrategyTableTable screeningStrategyTable =
      $ScreeningStrategyTableTable(this);
  late final $PortfolioPositionTable portfolioPosition =
      $PortfolioPositionTable(this);
  late final $PortfolioTransactionTable portfolioTransaction =
      $PortfolioTransactionTable(this);
  late final $StockEventTable stockEvent = $StockEventTable(this);
  late final $MarketIndexTable marketIndex = $MarketIndexTable(this);
  late final Index idxDailyPriceSymbol = Index(
    'idx_daily_price_symbol',
    'CREATE INDEX idx_daily_price_symbol ON daily_price (symbol)',
  );
  late final Index idxDailyPriceDate = Index(
    'idx_daily_price_date',
    'CREATE INDEX idx_daily_price_date ON daily_price (date)',
  );
  late final Index idxDailyPriceSymbolDate = Index(
    'idx_daily_price_symbol_date',
    'CREATE INDEX idx_daily_price_symbol_date ON daily_price (symbol, date)',
  );
  late final Index idxDailyInstitutionalSymbol = Index(
    'idx_daily_institutional_symbol',
    'CREATE INDEX idx_daily_institutional_symbol ON daily_institutional (symbol)',
  );
  late final Index idxDailyInstitutionalDate = Index(
    'idx_daily_institutional_date',
    'CREATE INDEX idx_daily_institutional_date ON daily_institutional (date)',
  );
  late final Index idxNewsItemPublishedAt = Index(
    'idx_news_item_published_at',
    'CREATE INDEX idx_news_item_published_at ON news_item (published_at)',
  );
  late final Index idxNewsItemSource = Index(
    'idx_news_item_source',
    'CREATE INDEX idx_news_item_source ON news_item (source)',
  );
  late final Index idxNewsStockMapSymbol = Index(
    'idx_news_stock_map_symbol',
    'CREATE INDEX idx_news_stock_map_symbol ON news_stock_map (symbol)',
  );
  late final Index idxNewsStockMapNewsId = Index(
    'idx_news_stock_map_news_id',
    'CREATE INDEX idx_news_stock_map_news_id ON news_stock_map (news_id)',
  );
  late final Index idxDailyAnalysisDate = Index(
    'idx_daily_analysis_date',
    'CREATE INDEX idx_daily_analysis_date ON daily_analysis (date)',
  );
  late final Index idxDailyAnalysisScore = Index(
    'idx_daily_analysis_score',
    'CREATE INDEX idx_daily_analysis_score ON daily_analysis (score)',
  );
  late final Index idxDailyAnalysisSymbolDate = Index(
    'idx_daily_analysis_symbol_date',
    'CREATE INDEX idx_daily_analysis_symbol_date ON daily_analysis (symbol, date)',
  );
  late final Index idxDailyReasonSymbolDate = Index(
    'idx_daily_reason_symbol_date',
    'CREATE INDEX idx_daily_reason_symbol_date ON daily_reason (symbol, date)',
  );
  late final Index idxDailyRecommendationDate = Index(
    'idx_daily_recommendation_date',
    'CREATE INDEX idx_daily_recommendation_date ON daily_recommendation (date)',
  );
  late final Index idxDailyRecommendationSymbol = Index(
    'idx_daily_recommendation_symbol',
    'CREATE INDEX idx_daily_recommendation_symbol ON daily_recommendation (symbol)',
  );
  late final Index idxDailyRecommendationDateSymbol = Index(
    'idx_daily_recommendation_date_symbol',
    'CREATE INDEX idx_daily_recommendation_date_symbol ON daily_recommendation (date, symbol)',
  );
  late final Index idxRuleAccuracyRule = Index(
    'idx_rule_accuracy_rule',
    'CREATE INDEX idx_rule_accuracy_rule ON rule_accuracy (rule_id)',
  );
  late final Index idxRecValidationDate = Index(
    'idx_rec_validation_date',
    'CREATE INDEX idx_rec_validation_date ON recommendation_validation (recommendation_date)',
  );
  late final Index idxRecValidationSymbol = Index(
    'idx_rec_validation_symbol',
    'CREATE INDEX idx_rec_validation_symbol ON recommendation_validation (symbol)',
  );
  late final Index idxUserInteractionSymbol = Index(
    'idx_user_interaction_symbol',
    'CREATE INDEX idx_user_interaction_symbol ON user_interaction (symbol)',
  );
  late final Index idxUserInteractionType = Index(
    'idx_user_interaction_type',
    'CREATE INDEX idx_user_interaction_type ON user_interaction (interaction_type)',
  );
  late final Index idxUserInteractionTime = Index(
    'idx_user_interaction_time',
    'CREATE INDEX idx_user_interaction_time ON user_interaction (timestamp)',
  );
  late final Index idxShareholdingSymbol = Index(
    'idx_shareholding_symbol',
    'CREATE INDEX idx_shareholding_symbol ON shareholding (symbol)',
  );
  late final Index idxShareholdingDate = Index(
    'idx_shareholding_date',
    'CREATE INDEX idx_shareholding_date ON shareholding (date)',
  );
  late final Index idxDayTradingSymbol = Index(
    'idx_day_trading_symbol',
    'CREATE INDEX idx_day_trading_symbol ON day_trading (symbol)',
  );
  late final Index idxDayTradingDate = Index(
    'idx_day_trading_date',
    'CREATE INDEX idx_day_trading_date ON day_trading (date)',
  );
  late final Index idxFinancialDataSymbol = Index(
    'idx_financial_data_symbol',
    'CREATE INDEX idx_financial_data_symbol ON financial_data (symbol)',
  );
  late final Index idxFinancialDataDate = Index(
    'idx_financial_data_date',
    'CREATE INDEX idx_financial_data_date ON financial_data (date)',
  );
  late final Index idxFinancialDataType = Index(
    'idx_financial_data_type',
    'CREATE INDEX idx_financial_data_type ON financial_data (data_type)',
  );
  late final Index idxAdjustedPriceSymbol = Index(
    'idx_adjusted_price_symbol',
    'CREATE INDEX idx_adjusted_price_symbol ON adjusted_price (symbol)',
  );
  late final Index idxAdjustedPriceDate = Index(
    'idx_adjusted_price_date',
    'CREATE INDEX idx_adjusted_price_date ON adjusted_price (date)',
  );
  late final Index idxWeeklyPriceSymbol = Index(
    'idx_weekly_price_symbol',
    'CREATE INDEX idx_weekly_price_symbol ON weekly_price (symbol)',
  );
  late final Index idxWeeklyPriceDate = Index(
    'idx_weekly_price_date',
    'CREATE INDEX idx_weekly_price_date ON weekly_price (date)',
  );
  late final Index idxHoldingDistSymbol = Index(
    'idx_holding_dist_symbol',
    'CREATE INDEX idx_holding_dist_symbol ON holding_distribution (symbol)',
  );
  late final Index idxHoldingDistDate = Index(
    'idx_holding_dist_date',
    'CREATE INDEX idx_holding_dist_date ON holding_distribution (date)',
  );
  late final Index idxMonthlyRevenueSymbol = Index(
    'idx_monthly_revenue_symbol',
    'CREATE INDEX idx_monthly_revenue_symbol ON monthly_revenue (symbol)',
  );
  late final Index idxMonthlyRevenueDate = Index(
    'idx_monthly_revenue_date',
    'CREATE INDEX idx_monthly_revenue_date ON monthly_revenue (date)',
  );
  late final Index idxStockValuationSymbol = Index(
    'idx_stock_valuation_symbol',
    'CREATE INDEX idx_stock_valuation_symbol ON stock_valuation (symbol)',
  );
  late final Index idxStockValuationDate = Index(
    'idx_stock_valuation_date',
    'CREATE INDEX idx_stock_valuation_date ON stock_valuation (date)',
  );
  late final Index idxDividendHistorySymbol = Index(
    'idx_dividend_history_symbol',
    'CREATE INDEX idx_dividend_history_symbol ON dividend_history (symbol)',
  );
  late final Index idxMarginTradingSymbol = Index(
    'idx_margin_trading_symbol',
    'CREATE INDEX idx_margin_trading_symbol ON margin_trading (symbol)',
  );
  late final Index idxMarginTradingDate = Index(
    'idx_margin_trading_date',
    'CREATE INDEX idx_margin_trading_date ON margin_trading (date)',
  );
  late final Index idxTradingWarningSymbol = Index(
    'idx_trading_warning_symbol',
    'CREATE INDEX idx_trading_warning_symbol ON trading_warning (symbol)',
  );
  late final Index idxTradingWarningDate = Index(
    'idx_trading_warning_date',
    'CREATE INDEX idx_trading_warning_date ON trading_warning (date)',
  );
  late final Index idxTradingWarningType = Index(
    'idx_trading_warning_type',
    'CREATE INDEX idx_trading_warning_type ON trading_warning (warning_type)',
  );
  late final Index idxInsiderHoldingSymbol = Index(
    'idx_insider_holding_symbol',
    'CREATE INDEX idx_insider_holding_symbol ON insider_holding (symbol)',
  );
  late final Index idxInsiderHoldingDate = Index(
    'idx_insider_holding_date',
    'CREATE INDEX idx_insider_holding_date ON insider_holding (date)',
  );
  late final Index idxPortfolioPositionSymbol = Index(
    'idx_portfolio_position_symbol',
    'CREATE INDEX idx_portfolio_position_symbol ON portfolio_position (symbol)',
  );
  late final Index idxPortfolioTxSymbol = Index(
    'idx_portfolio_tx_symbol',
    'CREATE INDEX idx_portfolio_tx_symbol ON portfolio_transaction (symbol)',
  );
  late final Index idxPortfolioTxDate = Index(
    'idx_portfolio_tx_date',
    'CREATE INDEX idx_portfolio_tx_date ON portfolio_transaction (date)',
  );
  late final Index idxStockEventDate = Index(
    'idx_stock_event_date',
    'CREATE INDEX idx_stock_event_date ON stock_event (event_date)',
  );
  late final Index idxStockEventSymbol = Index(
    'idx_stock_event_symbol',
    'CREATE INDEX idx_stock_event_symbol ON stock_event (symbol)',
  );
  late final Index idxMarketIndexDate = Index(
    'idx_market_index_date',
    'CREATE INDEX idx_market_index_date ON market_index (date)',
  );
  late final Index idxMarketIndexName = Index(
    'idx_market_index_name',
    'CREATE INDEX idx_market_index_name ON market_index (name)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stockMaster,
    dailyPrice,
    dailyInstitutional,
    newsItem,
    newsStockMap,
    dailyAnalysis,
    dailyReason,
    dailyRecommendation,
    ruleAccuracy,
    recommendationValidation,
    watchlist,
    userNote,
    strategyCard,
    updateRun,
    appSettings,
    priceAlert,
    userInteraction,
    userPreference,
    shareholding,
    dayTrading,
    financialData,
    adjustedPrice,
    weeklyPrice,
    holdingDistribution,
    monthlyRevenue,
    stockValuation,
    dividendHistory,
    marginTrading,
    tradingWarning,
    insiderHolding,
    screeningStrategyTable,
    portfolioPosition,
    portfolioTransaction,
    stockEvent,
    marketIndex,
    idxDailyPriceSymbol,
    idxDailyPriceDate,
    idxDailyPriceSymbolDate,
    idxDailyInstitutionalSymbol,
    idxDailyInstitutionalDate,
    idxNewsItemPublishedAt,
    idxNewsItemSource,
    idxNewsStockMapSymbol,
    idxNewsStockMapNewsId,
    idxDailyAnalysisDate,
    idxDailyAnalysisScore,
    idxDailyAnalysisSymbolDate,
    idxDailyReasonSymbolDate,
    idxDailyRecommendationDate,
    idxDailyRecommendationSymbol,
    idxDailyRecommendationDateSymbol,
    idxRuleAccuracyRule,
    idxRecValidationDate,
    idxRecValidationSymbol,
    idxUserInteractionSymbol,
    idxUserInteractionType,
    idxUserInteractionTime,
    idxShareholdingSymbol,
    idxShareholdingDate,
    idxDayTradingSymbol,
    idxDayTradingDate,
    idxFinancialDataSymbol,
    idxFinancialDataDate,
    idxFinancialDataType,
    idxAdjustedPriceSymbol,
    idxAdjustedPriceDate,
    idxWeeklyPriceSymbol,
    idxWeeklyPriceDate,
    idxHoldingDistSymbol,
    idxHoldingDistDate,
    idxMonthlyRevenueSymbol,
    idxMonthlyRevenueDate,
    idxStockValuationSymbol,
    idxStockValuationDate,
    idxDividendHistorySymbol,
    idxMarginTradingSymbol,
    idxMarginTradingDate,
    idxTradingWarningSymbol,
    idxTradingWarningDate,
    idxTradingWarningType,
    idxInsiderHoldingSymbol,
    idxInsiderHoldingDate,
    idxPortfolioPositionSymbol,
    idxPortfolioTxSymbol,
    idxPortfolioTxDate,
    idxStockEventDate,
    idxStockEventSymbol,
    idxMarketIndexDate,
    idxMarketIndexName,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('daily_price', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('daily_institutional', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'news_item',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('news_stock_map', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('news_stock_map', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('daily_analysis', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('daily_reason', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('daily_recommendation', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('watchlist', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('user_note', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('strategy_card', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('price_alert', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shareholding', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('day_trading', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('financial_data', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('adjusted_price', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('weekly_price', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('holding_distribution', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('monthly_revenue', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stock_valuation', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dividend_history', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('margin_trading', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trading_warning', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('insider_holding', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('portfolio_position', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stock_master',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('portfolio_transaction', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$StockMasterTableCreateCompanionBuilder =
    StockMasterCompanion Function({
      required String symbol,
      required String name,
      required String market,
      Value<String?> industry,
      Value<bool> isActive,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StockMasterTableUpdateCompanionBuilder =
    StockMasterCompanion Function({
      Value<String> symbol,
      Value<String> name,
      Value<String> market,
      Value<String?> industry,
      Value<bool> isActive,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$StockMasterTableReferences
    extends BaseReferences<_$AppDatabase, $StockMasterTable, StockMasterEntry> {
  $$StockMasterTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DailyPriceTable, List<DailyPriceEntry>>
  _dailyPriceRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dailyPrice,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.dailyPrice.symbol,
    ),
  );

  $$DailyPriceTableProcessedTableManager get dailyPriceRefs {
    final manager = $$DailyPriceTableTableManager(
      $_db,
      $_db.dailyPrice,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_dailyPriceRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $DailyInstitutionalTable,
    List<DailyInstitutionalEntry>
  >
  _dailyInstitutionalRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dailyInstitutional,
        aliasName: $_aliasNameGenerator(
          db.stockMaster.symbol,
          db.dailyInstitutional.symbol,
        ),
      );

  $$DailyInstitutionalTableProcessedTableManager get dailyInstitutionalRefs {
    final manager = $$DailyInstitutionalTableTableManager(
      $_db,
      $_db.dailyInstitutional,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(
      _dailyInstitutionalRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NewsStockMapTable, List<NewsStockMapEntry>>
  _newsStockMapRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.newsStockMap,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.newsStockMap.symbol,
    ),
  );

  $$NewsStockMapTableProcessedTableManager get newsStockMapRefs {
    final manager = $$NewsStockMapTableTableManager(
      $_db,
      $_db.newsStockMap,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_newsStockMapRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DailyAnalysisTable, List<DailyAnalysisEntry>>
  _dailyAnalysisRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dailyAnalysis,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.dailyAnalysis.symbol,
    ),
  );

  $$DailyAnalysisTableProcessedTableManager get dailyAnalysisRefs {
    final manager = $$DailyAnalysisTableTableManager(
      $_db,
      $_db.dailyAnalysis,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_dailyAnalysisRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DailyReasonTable, List<DailyReasonEntry>>
  _dailyReasonRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dailyReason,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.dailyReason.symbol,
    ),
  );

  $$DailyReasonTableProcessedTableManager get dailyReasonRefs {
    final manager = $$DailyReasonTableTableManager(
      $_db,
      $_db.dailyReason,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_dailyReasonRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $DailyRecommendationTable,
    List<DailyRecommendationEntry>
  >
  _dailyRecommendationRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dailyRecommendation,
        aliasName: $_aliasNameGenerator(
          db.stockMaster.symbol,
          db.dailyRecommendation.symbol,
        ),
      );

  $$DailyRecommendationTableProcessedTableManager get dailyRecommendationRefs {
    final manager = $$DailyRecommendationTableTableManager(
      $_db,
      $_db.dailyRecommendation,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(
      _dailyRecommendationRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WatchlistTable, List<WatchlistEntry>>
  _watchlistRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.watchlist,
    aliasName: $_aliasNameGenerator(db.stockMaster.symbol, db.watchlist.symbol),
  );

  $$WatchlistTableProcessedTableManager get watchlistRefs {
    final manager = $$WatchlistTableTableManager(
      $_db,
      $_db.watchlist,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_watchlistRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UserNoteTable, List<UserNoteEntry>>
  _userNoteRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.userNote,
    aliasName: $_aliasNameGenerator(db.stockMaster.symbol, db.userNote.symbol),
  );

  $$UserNoteTableProcessedTableManager get userNoteRefs {
    final manager = $$UserNoteTableTableManager(
      $_db,
      $_db.userNote,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_userNoteRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StrategyCardTable, List<StrategyCardEntry>>
  _strategyCardRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.strategyCard,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.strategyCard.symbol,
    ),
  );

  $$StrategyCardTableProcessedTableManager get strategyCardRefs {
    final manager = $$StrategyCardTableTableManager(
      $_db,
      $_db.strategyCard,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_strategyCardRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PriceAlertTable, List<PriceAlertEntry>>
  _priceAlertRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.priceAlert,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.priceAlert.symbol,
    ),
  );

  $$PriceAlertTableProcessedTableManager get priceAlertRefs {
    final manager = $$PriceAlertTableTableManager(
      $_db,
      $_db.priceAlert,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_priceAlertRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShareholdingTable, List<ShareholdingEntry>>
  _shareholdingRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shareholding,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.shareholding.symbol,
    ),
  );

  $$ShareholdingTableProcessedTableManager get shareholdingRefs {
    final manager = $$ShareholdingTableTableManager(
      $_db,
      $_db.shareholding,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_shareholdingRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DayTradingTable, List<DayTradingEntry>>
  _dayTradingRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dayTrading,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.dayTrading.symbol,
    ),
  );

  $$DayTradingTableProcessedTableManager get dayTradingRefs {
    final manager = $$DayTradingTableTableManager(
      $_db,
      $_db.dayTrading,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_dayTradingRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FinancialDataTable, List<FinancialDataEntry>>
  _financialDataRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.financialData,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.financialData.symbol,
    ),
  );

  $$FinancialDataTableProcessedTableManager get financialDataRefs {
    final manager = $$FinancialDataTableTableManager(
      $_db,
      $_db.financialData,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_financialDataRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AdjustedPriceTable, List<AdjustedPriceEntry>>
  _adjustedPriceRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.adjustedPrice,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.adjustedPrice.symbol,
    ),
  );

  $$AdjustedPriceTableProcessedTableManager get adjustedPriceRefs {
    final manager = $$AdjustedPriceTableTableManager(
      $_db,
      $_db.adjustedPrice,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_adjustedPriceRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WeeklyPriceTable, List<WeeklyPriceEntry>>
  _weeklyPriceRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.weeklyPrice,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.weeklyPrice.symbol,
    ),
  );

  $$WeeklyPriceTableProcessedTableManager get weeklyPriceRefs {
    final manager = $$WeeklyPriceTableTableManager(
      $_db,
      $_db.weeklyPrice,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_weeklyPriceRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $HoldingDistributionTable,
    List<HoldingDistributionEntry>
  >
  _holdingDistributionRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.holdingDistribution,
        aliasName: $_aliasNameGenerator(
          db.stockMaster.symbol,
          db.holdingDistribution.symbol,
        ),
      );

  $$HoldingDistributionTableProcessedTableManager get holdingDistributionRefs {
    final manager = $$HoldingDistributionTableTableManager(
      $_db,
      $_db.holdingDistribution,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(
      _holdingDistributionRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MonthlyRevenueTable, List<MonthlyRevenueEntry>>
  _monthlyRevenueRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.monthlyRevenue,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.monthlyRevenue.symbol,
    ),
  );

  $$MonthlyRevenueTableProcessedTableManager get monthlyRevenueRefs {
    final manager = $$MonthlyRevenueTableTableManager(
      $_db,
      $_db.monthlyRevenue,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_monthlyRevenueRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StockValuationTable, List<StockValuationEntry>>
  _stockValuationRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockValuation,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.stockValuation.symbol,
    ),
  );

  $$StockValuationTableProcessedTableManager get stockValuationRefs {
    final manager = $$StockValuationTableTableManager(
      $_db,
      $_db.stockValuation,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_stockValuationRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DividendHistoryTable, List<DividendHistoryEntry>>
  _dividendHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dividendHistory,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.dividendHistory.symbol,
    ),
  );

  $$DividendHistoryTableProcessedTableManager get dividendHistoryRefs {
    final manager = $$DividendHistoryTableTableManager(
      $_db,
      $_db.dividendHistory,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(
      _dividendHistoryRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MarginTradingTable, List<MarginTradingEntry>>
  _marginTradingRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.marginTrading,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.marginTrading.symbol,
    ),
  );

  $$MarginTradingTableProcessedTableManager get marginTradingRefs {
    final manager = $$MarginTradingTableTableManager(
      $_db,
      $_db.marginTrading,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_marginTradingRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TradingWarningTable, List<TradingWarningEntry>>
  _tradingWarningRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tradingWarning,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.tradingWarning.symbol,
    ),
  );

  $$TradingWarningTableProcessedTableManager get tradingWarningRefs {
    final manager = $$TradingWarningTableTableManager(
      $_db,
      $_db.tradingWarning,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_tradingWarningRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InsiderHoldingTable, List<InsiderHoldingEntry>>
  _insiderHoldingRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.insiderHolding,
    aliasName: $_aliasNameGenerator(
      db.stockMaster.symbol,
      db.insiderHolding.symbol,
    ),
  );

  $$InsiderHoldingTableProcessedTableManager get insiderHoldingRefs {
    final manager = $$InsiderHoldingTableTableManager(
      $_db,
      $_db.insiderHolding,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(_insiderHoldingRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PortfolioPositionTable,
    List<PortfolioPositionEntry>
  >
  _portfolioPositionRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.portfolioPosition,
        aliasName: $_aliasNameGenerator(
          db.stockMaster.symbol,
          db.portfolioPosition.symbol,
        ),
      );

  $$PortfolioPositionTableProcessedTableManager get portfolioPositionRefs {
    final manager = $$PortfolioPositionTableTableManager(
      $_db,
      $_db.portfolioPosition,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(
      _portfolioPositionRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PortfolioTransactionTable,
    List<PortfolioTransactionEntry>
  >
  _portfolioTransactionRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.portfolioTransaction,
        aliasName: $_aliasNameGenerator(
          db.stockMaster.symbol,
          db.portfolioTransaction.symbol,
        ),
      );

  $$PortfolioTransactionTableProcessedTableManager
  get portfolioTransactionRefs {
    final manager = $$PortfolioTransactionTableTableManager(
      $_db,
      $_db.portfolioTransaction,
    ).filter((f) => f.symbol.symbol.sqlEquals($_itemColumn<String>('symbol')!));

    final cache = $_typedResult.readTableOrNull(
      _portfolioTransactionRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StockMasterTableFilterComposer
    extends Composer<_$AppDatabase, $StockMasterTable> {
  $$StockMasterTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get market => $composableBuilder(
    column: $table.market,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> dailyPriceRefs(
    Expression<bool> Function($$DailyPriceTableFilterComposer f) f,
  ) {
    final $$DailyPriceTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dailyPrice,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyPriceTableFilterComposer(
            $db: $db,
            $table: $db.dailyPrice,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dailyInstitutionalRefs(
    Expression<bool> Function($$DailyInstitutionalTableFilterComposer f) f,
  ) {
    final $$DailyInstitutionalTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dailyInstitutional,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyInstitutionalTableFilterComposer(
            $db: $db,
            $table: $db.dailyInstitutional,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> newsStockMapRefs(
    Expression<bool> Function($$NewsStockMapTableFilterComposer f) f,
  ) {
    final $$NewsStockMapTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.newsStockMap,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NewsStockMapTableFilterComposer(
            $db: $db,
            $table: $db.newsStockMap,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dailyAnalysisRefs(
    Expression<bool> Function($$DailyAnalysisTableFilterComposer f) f,
  ) {
    final $$DailyAnalysisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dailyAnalysis,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyAnalysisTableFilterComposer(
            $db: $db,
            $table: $db.dailyAnalysis,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dailyReasonRefs(
    Expression<bool> Function($$DailyReasonTableFilterComposer f) f,
  ) {
    final $$DailyReasonTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dailyReason,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyReasonTableFilterComposer(
            $db: $db,
            $table: $db.dailyReason,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dailyRecommendationRefs(
    Expression<bool> Function($$DailyRecommendationTableFilterComposer f) f,
  ) {
    final $$DailyRecommendationTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dailyRecommendation,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyRecommendationTableFilterComposer(
            $db: $db,
            $table: $db.dailyRecommendation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> watchlistRefs(
    Expression<bool> Function($$WatchlistTableFilterComposer f) f,
  ) {
    final $$WatchlistTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.watchlist,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchlistTableFilterComposer(
            $db: $db,
            $table: $db.watchlist,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> userNoteRefs(
    Expression<bool> Function($$UserNoteTableFilterComposer f) f,
  ) {
    final $$UserNoteTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.userNote,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserNoteTableFilterComposer(
            $db: $db,
            $table: $db.userNote,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> strategyCardRefs(
    Expression<bool> Function($$StrategyCardTableFilterComposer f) f,
  ) {
    final $$StrategyCardTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.strategyCard,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StrategyCardTableFilterComposer(
            $db: $db,
            $table: $db.strategyCard,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> priceAlertRefs(
    Expression<bool> Function($$PriceAlertTableFilterComposer f) f,
  ) {
    final $$PriceAlertTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.priceAlert,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PriceAlertTableFilterComposer(
            $db: $db,
            $table: $db.priceAlert,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shareholdingRefs(
    Expression<bool> Function($$ShareholdingTableFilterComposer f) f,
  ) {
    final $$ShareholdingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.shareholding,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShareholdingTableFilterComposer(
            $db: $db,
            $table: $db.shareholding,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dayTradingRefs(
    Expression<bool> Function($$DayTradingTableFilterComposer f) f,
  ) {
    final $$DayTradingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dayTrading,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTradingTableFilterComposer(
            $db: $db,
            $table: $db.dayTrading,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> financialDataRefs(
    Expression<bool> Function($$FinancialDataTableFilterComposer f) f,
  ) {
    final $$FinancialDataTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.financialData,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinancialDataTableFilterComposer(
            $db: $db,
            $table: $db.financialData,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> adjustedPriceRefs(
    Expression<bool> Function($$AdjustedPriceTableFilterComposer f) f,
  ) {
    final $$AdjustedPriceTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.adjustedPrice,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AdjustedPriceTableFilterComposer(
            $db: $db,
            $table: $db.adjustedPrice,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> weeklyPriceRefs(
    Expression<bool> Function($$WeeklyPriceTableFilterComposer f) f,
  ) {
    final $$WeeklyPriceTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.weeklyPrice,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeeklyPriceTableFilterComposer(
            $db: $db,
            $table: $db.weeklyPrice,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> holdingDistributionRefs(
    Expression<bool> Function($$HoldingDistributionTableFilterComposer f) f,
  ) {
    final $$HoldingDistributionTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.holdingDistribution,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoldingDistributionTableFilterComposer(
            $db: $db,
            $table: $db.holdingDistribution,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> monthlyRevenueRefs(
    Expression<bool> Function($$MonthlyRevenueTableFilterComposer f) f,
  ) {
    final $$MonthlyRevenueTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.monthlyRevenue,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthlyRevenueTableFilterComposer(
            $db: $db,
            $table: $db.monthlyRevenue,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stockValuationRefs(
    Expression<bool> Function($$StockValuationTableFilterComposer f) f,
  ) {
    final $$StockValuationTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockValuation,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockValuationTableFilterComposer(
            $db: $db,
            $table: $db.stockValuation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dividendHistoryRefs(
    Expression<bool> Function($$DividendHistoryTableFilterComposer f) f,
  ) {
    final $$DividendHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dividendHistory,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DividendHistoryTableFilterComposer(
            $db: $db,
            $table: $db.dividendHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> marginTradingRefs(
    Expression<bool> Function($$MarginTradingTableFilterComposer f) f,
  ) {
    final $$MarginTradingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.marginTrading,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarginTradingTableFilterComposer(
            $db: $db,
            $table: $db.marginTrading,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tradingWarningRefs(
    Expression<bool> Function($$TradingWarningTableFilterComposer f) f,
  ) {
    final $$TradingWarningTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.tradingWarning,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TradingWarningTableFilterComposer(
            $db: $db,
            $table: $db.tradingWarning,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> insiderHoldingRefs(
    Expression<bool> Function($$InsiderHoldingTableFilterComposer f) f,
  ) {
    final $$InsiderHoldingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.insiderHolding,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InsiderHoldingTableFilterComposer(
            $db: $db,
            $table: $db.insiderHolding,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> portfolioPositionRefs(
    Expression<bool> Function($$PortfolioPositionTableFilterComposer f) f,
  ) {
    final $$PortfolioPositionTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.portfolioPosition,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfolioPositionTableFilterComposer(
            $db: $db,
            $table: $db.portfolioPosition,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> portfolioTransactionRefs(
    Expression<bool> Function($$PortfolioTransactionTableFilterComposer f) f,
  ) {
    final $$PortfolioTransactionTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.portfolioTransaction,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfolioTransactionTableFilterComposer(
            $db: $db,
            $table: $db.portfolioTransaction,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StockMasterTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMasterTable> {
  $$StockMasterTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get market => $composableBuilder(
    column: $table.market,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockMasterTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMasterTable> {
  $$StockMasterTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get market =>
      $composableBuilder(column: $table.market, builder: (column) => column);

  GeneratedColumn<String> get industry =>
      $composableBuilder(column: $table.industry, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> dailyPriceRefs<T extends Object>(
    Expression<T> Function($$DailyPriceTableAnnotationComposer a) f,
  ) {
    final $$DailyPriceTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dailyPrice,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyPriceTableAnnotationComposer(
            $db: $db,
            $table: $db.dailyPrice,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dailyInstitutionalRefs<T extends Object>(
    Expression<T> Function($$DailyInstitutionalTableAnnotationComposer a) f,
  ) {
    final $$DailyInstitutionalTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.symbol,
          referencedTable: $db.dailyInstitutional,
          getReferencedColumn: (t) => t.symbol,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DailyInstitutionalTableAnnotationComposer(
                $db: $db,
                $table: $db.dailyInstitutional,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> newsStockMapRefs<T extends Object>(
    Expression<T> Function($$NewsStockMapTableAnnotationComposer a) f,
  ) {
    final $$NewsStockMapTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.newsStockMap,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NewsStockMapTableAnnotationComposer(
            $db: $db,
            $table: $db.newsStockMap,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dailyAnalysisRefs<T extends Object>(
    Expression<T> Function($$DailyAnalysisTableAnnotationComposer a) f,
  ) {
    final $$DailyAnalysisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dailyAnalysis,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyAnalysisTableAnnotationComposer(
            $db: $db,
            $table: $db.dailyAnalysis,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dailyReasonRefs<T extends Object>(
    Expression<T> Function($$DailyReasonTableAnnotationComposer a) f,
  ) {
    final $$DailyReasonTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dailyReason,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyReasonTableAnnotationComposer(
            $db: $db,
            $table: $db.dailyReason,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dailyRecommendationRefs<T extends Object>(
    Expression<T> Function($$DailyRecommendationTableAnnotationComposer a) f,
  ) {
    final $$DailyRecommendationTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.symbol,
          referencedTable: $db.dailyRecommendation,
          getReferencedColumn: (t) => t.symbol,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DailyRecommendationTableAnnotationComposer(
                $db: $db,
                $table: $db.dailyRecommendation,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> watchlistRefs<T extends Object>(
    Expression<T> Function($$WatchlistTableAnnotationComposer a) f,
  ) {
    final $$WatchlistTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.watchlist,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchlistTableAnnotationComposer(
            $db: $db,
            $table: $db.watchlist,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> userNoteRefs<T extends Object>(
    Expression<T> Function($$UserNoteTableAnnotationComposer a) f,
  ) {
    final $$UserNoteTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.userNote,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserNoteTableAnnotationComposer(
            $db: $db,
            $table: $db.userNote,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> strategyCardRefs<T extends Object>(
    Expression<T> Function($$StrategyCardTableAnnotationComposer a) f,
  ) {
    final $$StrategyCardTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.strategyCard,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StrategyCardTableAnnotationComposer(
            $db: $db,
            $table: $db.strategyCard,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> priceAlertRefs<T extends Object>(
    Expression<T> Function($$PriceAlertTableAnnotationComposer a) f,
  ) {
    final $$PriceAlertTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.priceAlert,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PriceAlertTableAnnotationComposer(
            $db: $db,
            $table: $db.priceAlert,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shareholdingRefs<T extends Object>(
    Expression<T> Function($$ShareholdingTableAnnotationComposer a) f,
  ) {
    final $$ShareholdingTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.shareholding,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShareholdingTableAnnotationComposer(
            $db: $db,
            $table: $db.shareholding,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dayTradingRefs<T extends Object>(
    Expression<T> Function($$DayTradingTableAnnotationComposer a) f,
  ) {
    final $$DayTradingTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dayTrading,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTradingTableAnnotationComposer(
            $db: $db,
            $table: $db.dayTrading,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> financialDataRefs<T extends Object>(
    Expression<T> Function($$FinancialDataTableAnnotationComposer a) f,
  ) {
    final $$FinancialDataTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.financialData,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinancialDataTableAnnotationComposer(
            $db: $db,
            $table: $db.financialData,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> adjustedPriceRefs<T extends Object>(
    Expression<T> Function($$AdjustedPriceTableAnnotationComposer a) f,
  ) {
    final $$AdjustedPriceTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.adjustedPrice,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AdjustedPriceTableAnnotationComposer(
            $db: $db,
            $table: $db.adjustedPrice,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> weeklyPriceRefs<T extends Object>(
    Expression<T> Function($$WeeklyPriceTableAnnotationComposer a) f,
  ) {
    final $$WeeklyPriceTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.weeklyPrice,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeeklyPriceTableAnnotationComposer(
            $db: $db,
            $table: $db.weeklyPrice,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> holdingDistributionRefs<T extends Object>(
    Expression<T> Function($$HoldingDistributionTableAnnotationComposer a) f,
  ) {
    final $$HoldingDistributionTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.symbol,
          referencedTable: $db.holdingDistribution,
          getReferencedColumn: (t) => t.symbol,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HoldingDistributionTableAnnotationComposer(
                $db: $db,
                $table: $db.holdingDistribution,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> monthlyRevenueRefs<T extends Object>(
    Expression<T> Function($$MonthlyRevenueTableAnnotationComposer a) f,
  ) {
    final $$MonthlyRevenueTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.monthlyRevenue,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthlyRevenueTableAnnotationComposer(
            $db: $db,
            $table: $db.monthlyRevenue,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stockValuationRefs<T extends Object>(
    Expression<T> Function($$StockValuationTableAnnotationComposer a) f,
  ) {
    final $$StockValuationTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockValuation,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockValuationTableAnnotationComposer(
            $db: $db,
            $table: $db.stockValuation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dividendHistoryRefs<T extends Object>(
    Expression<T> Function($$DividendHistoryTableAnnotationComposer a) f,
  ) {
    final $$DividendHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.dividendHistory,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DividendHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.dividendHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> marginTradingRefs<T extends Object>(
    Expression<T> Function($$MarginTradingTableAnnotationComposer a) f,
  ) {
    final $$MarginTradingTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.marginTrading,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarginTradingTableAnnotationComposer(
            $db: $db,
            $table: $db.marginTrading,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tradingWarningRefs<T extends Object>(
    Expression<T> Function($$TradingWarningTableAnnotationComposer a) f,
  ) {
    final $$TradingWarningTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.tradingWarning,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TradingWarningTableAnnotationComposer(
            $db: $db,
            $table: $db.tradingWarning,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> insiderHoldingRefs<T extends Object>(
    Expression<T> Function($$InsiderHoldingTableAnnotationComposer a) f,
  ) {
    final $$InsiderHoldingTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.insiderHolding,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InsiderHoldingTableAnnotationComposer(
            $db: $db,
            $table: $db.insiderHolding,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> portfolioPositionRefs<T extends Object>(
    Expression<T> Function($$PortfolioPositionTableAnnotationComposer a) f,
  ) {
    final $$PortfolioPositionTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.symbol,
          referencedTable: $db.portfolioPosition,
          getReferencedColumn: (t) => t.symbol,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PortfolioPositionTableAnnotationComposer(
                $db: $db,
                $table: $db.portfolioPosition,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> portfolioTransactionRefs<T extends Object>(
    Expression<T> Function($$PortfolioTransactionTableAnnotationComposer a) f,
  ) {
    final $$PortfolioTransactionTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.symbol,
          referencedTable: $db.portfolioTransaction,
          getReferencedColumn: (t) => t.symbol,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PortfolioTransactionTableAnnotationComposer(
                $db: $db,
                $table: $db.portfolioTransaction,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$StockMasterTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockMasterTable,
          StockMasterEntry,
          $$StockMasterTableFilterComposer,
          $$StockMasterTableOrderingComposer,
          $$StockMasterTableAnnotationComposer,
          $$StockMasterTableCreateCompanionBuilder,
          $$StockMasterTableUpdateCompanionBuilder,
          (StockMasterEntry, $$StockMasterTableReferences),
          StockMasterEntry,
          PrefetchHooks Function({
            bool dailyPriceRefs,
            bool dailyInstitutionalRefs,
            bool newsStockMapRefs,
            bool dailyAnalysisRefs,
            bool dailyReasonRefs,
            bool dailyRecommendationRefs,
            bool watchlistRefs,
            bool userNoteRefs,
            bool strategyCardRefs,
            bool priceAlertRefs,
            bool shareholdingRefs,
            bool dayTradingRefs,
            bool financialDataRefs,
            bool adjustedPriceRefs,
            bool weeklyPriceRefs,
            bool holdingDistributionRefs,
            bool monthlyRevenueRefs,
            bool stockValuationRefs,
            bool dividendHistoryRefs,
            bool marginTradingRefs,
            bool tradingWarningRefs,
            bool insiderHoldingRefs,
            bool portfolioPositionRefs,
            bool portfolioTransactionRefs,
          })
        > {
  $$StockMasterTableTableManager(_$AppDatabase db, $StockMasterTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMasterTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMasterTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMasterTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> market = const Value.absent(),
                Value<String?> industry = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockMasterCompanion(
                symbol: symbol,
                name: name,
                market: market,
                industry: industry,
                isActive: isActive,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required String name,
                required String market,
                Value<String?> industry = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockMasterCompanion.insert(
                symbol: symbol,
                name: name,
                market: market,
                industry: industry,
                isActive: isActive,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StockMasterTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                dailyPriceRefs = false,
                dailyInstitutionalRefs = false,
                newsStockMapRefs = false,
                dailyAnalysisRefs = false,
                dailyReasonRefs = false,
                dailyRecommendationRefs = false,
                watchlistRefs = false,
                userNoteRefs = false,
                strategyCardRefs = false,
                priceAlertRefs = false,
                shareholdingRefs = false,
                dayTradingRefs = false,
                financialDataRefs = false,
                adjustedPriceRefs = false,
                weeklyPriceRefs = false,
                holdingDistributionRefs = false,
                monthlyRevenueRefs = false,
                stockValuationRefs = false,
                dividendHistoryRefs = false,
                marginTradingRefs = false,
                tradingWarningRefs = false,
                insiderHoldingRefs = false,
                portfolioPositionRefs = false,
                portfolioTransactionRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (dailyPriceRefs) db.dailyPrice,
                    if (dailyInstitutionalRefs) db.dailyInstitutional,
                    if (newsStockMapRefs) db.newsStockMap,
                    if (dailyAnalysisRefs) db.dailyAnalysis,
                    if (dailyReasonRefs) db.dailyReason,
                    if (dailyRecommendationRefs) db.dailyRecommendation,
                    if (watchlistRefs) db.watchlist,
                    if (userNoteRefs) db.userNote,
                    if (strategyCardRefs) db.strategyCard,
                    if (priceAlertRefs) db.priceAlert,
                    if (shareholdingRefs) db.shareholding,
                    if (dayTradingRefs) db.dayTrading,
                    if (financialDataRefs) db.financialData,
                    if (adjustedPriceRefs) db.adjustedPrice,
                    if (weeklyPriceRefs) db.weeklyPrice,
                    if (holdingDistributionRefs) db.holdingDistribution,
                    if (monthlyRevenueRefs) db.monthlyRevenue,
                    if (stockValuationRefs) db.stockValuation,
                    if (dividendHistoryRefs) db.dividendHistory,
                    if (marginTradingRefs) db.marginTrading,
                    if (tradingWarningRefs) db.tradingWarning,
                    if (insiderHoldingRefs) db.insiderHolding,
                    if (portfolioPositionRefs) db.portfolioPosition,
                    if (portfolioTransactionRefs) db.portfolioTransaction,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (dailyPriceRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          DailyPriceEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._dailyPriceRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).dailyPriceRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (dailyInstitutionalRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          DailyInstitutionalEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._dailyInstitutionalRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).dailyInstitutionalRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (newsStockMapRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          NewsStockMapEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._newsStockMapRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).newsStockMapRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (dailyAnalysisRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          DailyAnalysisEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._dailyAnalysisRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).dailyAnalysisRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (dailyReasonRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          DailyReasonEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._dailyReasonRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).dailyReasonRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (dailyRecommendationRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          DailyRecommendationEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._dailyRecommendationRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).dailyRecommendationRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (watchlistRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          WatchlistEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._watchlistRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).watchlistRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (userNoteRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          UserNoteEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._userNoteRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).userNoteRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (strategyCardRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          StrategyCardEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._strategyCardRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).strategyCardRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (priceAlertRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          PriceAlertEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._priceAlertRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).priceAlertRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (shareholdingRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          ShareholdingEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._shareholdingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).shareholdingRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (dayTradingRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          DayTradingEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._dayTradingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).dayTradingRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (financialDataRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          FinancialDataEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._financialDataRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).financialDataRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (adjustedPriceRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          AdjustedPriceEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._adjustedPriceRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).adjustedPriceRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (weeklyPriceRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          WeeklyPriceEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._weeklyPriceRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).weeklyPriceRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (holdingDistributionRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          HoldingDistributionEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._holdingDistributionRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).holdingDistributionRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (monthlyRevenueRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          MonthlyRevenueEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._monthlyRevenueRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).monthlyRevenueRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (stockValuationRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          StockValuationEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._stockValuationRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).stockValuationRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (dividendHistoryRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          DividendHistoryEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._dividendHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).dividendHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (marginTradingRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          MarginTradingEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._marginTradingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).marginTradingRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (tradingWarningRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          TradingWarningEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._tradingWarningRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).tradingWarningRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (insiderHoldingRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          InsiderHoldingEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._insiderHoldingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).insiderHoldingRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (portfolioPositionRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          PortfolioPositionEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._portfolioPositionRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).portfolioPositionRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                      if (portfolioTransactionRefs)
                        await $_getPrefetchedData<
                          StockMasterEntry,
                          $StockMasterTable,
                          PortfolioTransactionEntry
                        >(
                          currentTable: table,
                          referencedTable: $$StockMasterTableReferences
                              ._portfolioTransactionRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockMasterTableReferences(
                                db,
                                table,
                                p0,
                              ).portfolioTransactionRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.symbol == item.symbol,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StockMasterTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockMasterTable,
      StockMasterEntry,
      $$StockMasterTableFilterComposer,
      $$StockMasterTableOrderingComposer,
      $$StockMasterTableAnnotationComposer,
      $$StockMasterTableCreateCompanionBuilder,
      $$StockMasterTableUpdateCompanionBuilder,
      (StockMasterEntry, $$StockMasterTableReferences),
      StockMasterEntry,
      PrefetchHooks Function({
        bool dailyPriceRefs,
        bool dailyInstitutionalRefs,
        bool newsStockMapRefs,
        bool dailyAnalysisRefs,
        bool dailyReasonRefs,
        bool dailyRecommendationRefs,
        bool watchlistRefs,
        bool userNoteRefs,
        bool strategyCardRefs,
        bool priceAlertRefs,
        bool shareholdingRefs,
        bool dayTradingRefs,
        bool financialDataRefs,
        bool adjustedPriceRefs,
        bool weeklyPriceRefs,
        bool holdingDistributionRefs,
        bool monthlyRevenueRefs,
        bool stockValuationRefs,
        bool dividendHistoryRefs,
        bool marginTradingRefs,
        bool tradingWarningRefs,
        bool insiderHoldingRefs,
        bool portfolioPositionRefs,
        bool portfolioTransactionRefs,
      })
    >;
typedef $$DailyPriceTableCreateCompanionBuilder =
    DailyPriceCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> open,
      Value<double?> high,
      Value<double?> low,
      Value<double?> close,
      Value<double?> volume,
      Value<double?> priceChange,
      Value<int> rowid,
    });
typedef $$DailyPriceTableUpdateCompanionBuilder =
    DailyPriceCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> open,
      Value<double?> high,
      Value<double?> low,
      Value<double?> close,
      Value<double?> volume,
      Value<double?> priceChange,
      Value<int> rowid,
    });

final class $$DailyPriceTableReferences
    extends BaseReferences<_$AppDatabase, $DailyPriceTable, DailyPriceEntry> {
  $$DailyPriceTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.dailyPrice.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyPriceTableFilterComposer
    extends Composer<_$AppDatabase, $DailyPriceTable> {
  $$DailyPriceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get open => $composableBuilder(
    column: $table.open,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get high => $composableBuilder(
    column: $table.high,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get low => $composableBuilder(
    column: $table.low,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get priceChange => $composableBuilder(
    column: $table.priceChange,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyPriceTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyPriceTable> {
  $$DailyPriceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get open => $composableBuilder(
    column: $table.open,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get high => $composableBuilder(
    column: $table.high,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get low => $composableBuilder(
    column: $table.low,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get priceChange => $composableBuilder(
    column: $table.priceChange,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyPriceTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyPriceTable> {
  $$DailyPriceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get open =>
      $composableBuilder(column: $table.open, builder: (column) => column);

  GeneratedColumn<double> get high =>
      $composableBuilder(column: $table.high, builder: (column) => column);

  GeneratedColumn<double> get low =>
      $composableBuilder(column: $table.low, builder: (column) => column);

  GeneratedColumn<double> get close =>
      $composableBuilder(column: $table.close, builder: (column) => column);

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<double> get priceChange => $composableBuilder(
    column: $table.priceChange,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyPriceTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyPriceTable,
          DailyPriceEntry,
          $$DailyPriceTableFilterComposer,
          $$DailyPriceTableOrderingComposer,
          $$DailyPriceTableAnnotationComposer,
          $$DailyPriceTableCreateCompanionBuilder,
          $$DailyPriceTableUpdateCompanionBuilder,
          (DailyPriceEntry, $$DailyPriceTableReferences),
          DailyPriceEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$DailyPriceTableTableManager(_$AppDatabase db, $DailyPriceTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyPriceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyPriceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyPriceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> open = const Value.absent(),
                Value<double?> high = const Value.absent(),
                Value<double?> low = const Value.absent(),
                Value<double?> close = const Value.absent(),
                Value<double?> volume = const Value.absent(),
                Value<double?> priceChange = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyPriceCompanion(
                symbol: symbol,
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                priceChange: priceChange,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> open = const Value.absent(),
                Value<double?> high = const Value.absent(),
                Value<double?> low = const Value.absent(),
                Value<double?> close = const Value.absent(),
                Value<double?> volume = const Value.absent(),
                Value<double?> priceChange = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyPriceCompanion.insert(
                symbol: symbol,
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                priceChange: priceChange,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DailyPriceTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$DailyPriceTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$DailyPriceTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DailyPriceTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyPriceTable,
      DailyPriceEntry,
      $$DailyPriceTableFilterComposer,
      $$DailyPriceTableOrderingComposer,
      $$DailyPriceTableAnnotationComposer,
      $$DailyPriceTableCreateCompanionBuilder,
      $$DailyPriceTableUpdateCompanionBuilder,
      (DailyPriceEntry, $$DailyPriceTableReferences),
      DailyPriceEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$DailyInstitutionalTableCreateCompanionBuilder =
    DailyInstitutionalCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> foreignNet,
      Value<double?> investmentTrustNet,
      Value<double?> dealerNet,
      Value<int> rowid,
    });
typedef $$DailyInstitutionalTableUpdateCompanionBuilder =
    DailyInstitutionalCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> foreignNet,
      Value<double?> investmentTrustNet,
      Value<double?> dealerNet,
      Value<int> rowid,
    });

final class $$DailyInstitutionalTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DailyInstitutionalTable,
          DailyInstitutionalEntry
        > {
  $$DailyInstitutionalTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(
          db.dailyInstitutional.symbol,
          db.stockMaster.symbol,
        ),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyInstitutionalTableFilterComposer
    extends Composer<_$AppDatabase, $DailyInstitutionalTable> {
  $$DailyInstitutionalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get foreignNet => $composableBuilder(
    column: $table.foreignNet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get investmentTrustNet => $composableBuilder(
    column: $table.investmentTrustNet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dealerNet => $composableBuilder(
    column: $table.dealerNet,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyInstitutionalTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyInstitutionalTable> {
  $$DailyInstitutionalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get foreignNet => $composableBuilder(
    column: $table.foreignNet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get investmentTrustNet => $composableBuilder(
    column: $table.investmentTrustNet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dealerNet => $composableBuilder(
    column: $table.dealerNet,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyInstitutionalTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyInstitutionalTable> {
  $$DailyInstitutionalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get foreignNet => $composableBuilder(
    column: $table.foreignNet,
    builder: (column) => column,
  );

  GeneratedColumn<double> get investmentTrustNet => $composableBuilder(
    column: $table.investmentTrustNet,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dealerNet =>
      $composableBuilder(column: $table.dealerNet, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyInstitutionalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyInstitutionalTable,
          DailyInstitutionalEntry,
          $$DailyInstitutionalTableFilterComposer,
          $$DailyInstitutionalTableOrderingComposer,
          $$DailyInstitutionalTableAnnotationComposer,
          $$DailyInstitutionalTableCreateCompanionBuilder,
          $$DailyInstitutionalTableUpdateCompanionBuilder,
          (DailyInstitutionalEntry, $$DailyInstitutionalTableReferences),
          DailyInstitutionalEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$DailyInstitutionalTableTableManager(
    _$AppDatabase db,
    $DailyInstitutionalTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyInstitutionalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyInstitutionalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyInstitutionalTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> foreignNet = const Value.absent(),
                Value<double?> investmentTrustNet = const Value.absent(),
                Value<double?> dealerNet = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyInstitutionalCompanion(
                symbol: symbol,
                date: date,
                foreignNet: foreignNet,
                investmentTrustNet: investmentTrustNet,
                dealerNet: dealerNet,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> foreignNet = const Value.absent(),
                Value<double?> investmentTrustNet = const Value.absent(),
                Value<double?> dealerNet = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyInstitutionalCompanion.insert(
                symbol: symbol,
                date: date,
                foreignNet: foreignNet,
                investmentTrustNet: investmentTrustNet,
                dealerNet: dealerNet,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DailyInstitutionalTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable:
                                    $$DailyInstitutionalTableReferences
                                        ._symbolTable(db),
                                referencedColumn:
                                    $$DailyInstitutionalTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DailyInstitutionalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyInstitutionalTable,
      DailyInstitutionalEntry,
      $$DailyInstitutionalTableFilterComposer,
      $$DailyInstitutionalTableOrderingComposer,
      $$DailyInstitutionalTableAnnotationComposer,
      $$DailyInstitutionalTableCreateCompanionBuilder,
      $$DailyInstitutionalTableUpdateCompanionBuilder,
      (DailyInstitutionalEntry, $$DailyInstitutionalTableReferences),
      DailyInstitutionalEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$NewsItemTableCreateCompanionBuilder =
    NewsItemCompanion Function({
      required String id,
      required String source,
      required String title,
      Value<String?> content,
      required String url,
      required String category,
      required DateTime publishedAt,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });
typedef $$NewsItemTableUpdateCompanionBuilder =
    NewsItemCompanion Function({
      Value<String> id,
      Value<String> source,
      Value<String> title,
      Value<String?> content,
      Value<String> url,
      Value<String> category,
      Value<DateTime> publishedAt,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

final class $$NewsItemTableReferences
    extends BaseReferences<_$AppDatabase, $NewsItemTable, NewsItemEntry> {
  $$NewsItemTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NewsStockMapTable, List<NewsStockMapEntry>>
  _newsStockMapRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.newsStockMap,
    aliasName: $_aliasNameGenerator(db.newsItem.id, db.newsStockMap.newsId),
  );

  $$NewsStockMapTableProcessedTableManager get newsStockMapRefs {
    final manager = $$NewsStockMapTableTableManager(
      $_db,
      $_db.newsStockMap,
    ).filter((f) => f.newsId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_newsStockMapRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NewsItemTableFilterComposer
    extends Composer<_$AppDatabase, $NewsItemTable> {
  $$NewsItemTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> newsStockMapRefs(
    Expression<bool> Function($$NewsStockMapTableFilterComposer f) f,
  ) {
    final $$NewsStockMapTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.newsStockMap,
      getReferencedColumn: (t) => t.newsId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NewsStockMapTableFilterComposer(
            $db: $db,
            $table: $db.newsStockMap,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NewsItemTableOrderingComposer
    extends Composer<_$AppDatabase, $NewsItemTable> {
  $$NewsItemTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NewsItemTableAnnotationComposer
    extends Composer<_$AppDatabase, $NewsItemTable> {
  $$NewsItemTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  Expression<T> newsStockMapRefs<T extends Object>(
    Expression<T> Function($$NewsStockMapTableAnnotationComposer a) f,
  ) {
    final $$NewsStockMapTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.newsStockMap,
      getReferencedColumn: (t) => t.newsId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NewsStockMapTableAnnotationComposer(
            $db: $db,
            $table: $db.newsStockMap,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NewsItemTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NewsItemTable,
          NewsItemEntry,
          $$NewsItemTableFilterComposer,
          $$NewsItemTableOrderingComposer,
          $$NewsItemTableAnnotationComposer,
          $$NewsItemTableCreateCompanionBuilder,
          $$NewsItemTableUpdateCompanionBuilder,
          (NewsItemEntry, $$NewsItemTableReferences),
          NewsItemEntry,
          PrefetchHooks Function({bool newsStockMapRefs})
        > {
  $$NewsItemTableTableManager(_$AppDatabase db, $NewsItemTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NewsItemTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NewsItemTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NewsItemTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<DateTime> publishedAt = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NewsItemCompanion(
                id: id,
                source: source,
                title: title,
                content: content,
                url: url,
                category: category,
                publishedAt: publishedAt,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String source,
                required String title,
                Value<String?> content = const Value.absent(),
                required String url,
                required String category,
                required DateTime publishedAt,
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NewsItemCompanion.insert(
                id: id,
                source: source,
                title: title,
                content: content,
                url: url,
                category: category,
                publishedAt: publishedAt,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NewsItemTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({newsStockMapRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (newsStockMapRefs) db.newsStockMap],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (newsStockMapRefs)
                    await $_getPrefetchedData<
                      NewsItemEntry,
                      $NewsItemTable,
                      NewsStockMapEntry
                    >(
                      currentTable: table,
                      referencedTable: $$NewsItemTableReferences
                          ._newsStockMapRefsTable(db),
                      managerFromTypedResult: (p0) => $$NewsItemTableReferences(
                        db,
                        table,
                        p0,
                      ).newsStockMapRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.newsId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NewsItemTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NewsItemTable,
      NewsItemEntry,
      $$NewsItemTableFilterComposer,
      $$NewsItemTableOrderingComposer,
      $$NewsItemTableAnnotationComposer,
      $$NewsItemTableCreateCompanionBuilder,
      $$NewsItemTableUpdateCompanionBuilder,
      (NewsItemEntry, $$NewsItemTableReferences),
      NewsItemEntry,
      PrefetchHooks Function({bool newsStockMapRefs})
    >;
typedef $$NewsStockMapTableCreateCompanionBuilder =
    NewsStockMapCompanion Function({
      required String newsId,
      required String symbol,
      Value<int> rowid,
    });
typedef $$NewsStockMapTableUpdateCompanionBuilder =
    NewsStockMapCompanion Function({
      Value<String> newsId,
      Value<String> symbol,
      Value<int> rowid,
    });

final class $$NewsStockMapTableReferences
    extends
        BaseReferences<_$AppDatabase, $NewsStockMapTable, NewsStockMapEntry> {
  $$NewsStockMapTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NewsItemTable _newsIdTable(_$AppDatabase db) =>
      db.newsItem.createAlias(
        $_aliasNameGenerator(db.newsStockMap.newsId, db.newsItem.id),
      );

  $$NewsItemTableProcessedTableManager get newsId {
    final $_column = $_itemColumn<String>('news_id')!;

    final manager = $$NewsItemTableTableManager(
      $_db,
      $_db.newsItem,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_newsIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.newsStockMap.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NewsStockMapTableFilterComposer
    extends Composer<_$AppDatabase, $NewsStockMapTable> {
  $$NewsStockMapTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NewsItemTableFilterComposer get newsId {
    final $$NewsItemTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.newsId,
      referencedTable: $db.newsItem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NewsItemTableFilterComposer(
            $db: $db,
            $table: $db.newsItem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NewsStockMapTableOrderingComposer
    extends Composer<_$AppDatabase, $NewsStockMapTable> {
  $$NewsStockMapTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NewsItemTableOrderingComposer get newsId {
    final $$NewsItemTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.newsId,
      referencedTable: $db.newsItem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NewsItemTableOrderingComposer(
            $db: $db,
            $table: $db.newsItem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NewsStockMapTableAnnotationComposer
    extends Composer<_$AppDatabase, $NewsStockMapTable> {
  $$NewsStockMapTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NewsItemTableAnnotationComposer get newsId {
    final $$NewsItemTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.newsId,
      referencedTable: $db.newsItem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NewsItemTableAnnotationComposer(
            $db: $db,
            $table: $db.newsItem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NewsStockMapTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NewsStockMapTable,
          NewsStockMapEntry,
          $$NewsStockMapTableFilterComposer,
          $$NewsStockMapTableOrderingComposer,
          $$NewsStockMapTableAnnotationComposer,
          $$NewsStockMapTableCreateCompanionBuilder,
          $$NewsStockMapTableUpdateCompanionBuilder,
          (NewsStockMapEntry, $$NewsStockMapTableReferences),
          NewsStockMapEntry,
          PrefetchHooks Function({bool newsId, bool symbol})
        > {
  $$NewsStockMapTableTableManager(_$AppDatabase db, $NewsStockMapTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NewsStockMapTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NewsStockMapTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NewsStockMapTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> newsId = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NewsStockMapCompanion(
                newsId: newsId,
                symbol: symbol,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String newsId,
                required String symbol,
                Value<int> rowid = const Value.absent(),
              }) => NewsStockMapCompanion.insert(
                newsId: newsId,
                symbol: symbol,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NewsStockMapTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({newsId = false, symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (newsId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.newsId,
                                referencedTable: $$NewsStockMapTableReferences
                                    ._newsIdTable(db),
                                referencedColumn: $$NewsStockMapTableReferences
                                    ._newsIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$NewsStockMapTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$NewsStockMapTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NewsStockMapTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NewsStockMapTable,
      NewsStockMapEntry,
      $$NewsStockMapTableFilterComposer,
      $$NewsStockMapTableOrderingComposer,
      $$NewsStockMapTableAnnotationComposer,
      $$NewsStockMapTableCreateCompanionBuilder,
      $$NewsStockMapTableUpdateCompanionBuilder,
      (NewsStockMapEntry, $$NewsStockMapTableReferences),
      NewsStockMapEntry,
      PrefetchHooks Function({bool newsId, bool symbol})
    >;
typedef $$DailyAnalysisTableCreateCompanionBuilder =
    DailyAnalysisCompanion Function({
      required String symbol,
      required DateTime date,
      required String trendState,
      Value<String> reversalState,
      Value<double?> supportLevel,
      Value<double?> resistanceLevel,
      Value<double> score,
      Value<DateTime> computedAt,
      Value<int> rowid,
    });
typedef $$DailyAnalysisTableUpdateCompanionBuilder =
    DailyAnalysisCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<String> trendState,
      Value<String> reversalState,
      Value<double?> supportLevel,
      Value<double?> resistanceLevel,
      Value<double> score,
      Value<DateTime> computedAt,
      Value<int> rowid,
    });

final class $$DailyAnalysisTableReferences
    extends
        BaseReferences<_$AppDatabase, $DailyAnalysisTable, DailyAnalysisEntry> {
  $$DailyAnalysisTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.dailyAnalysis.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyAnalysisTableFilterComposer
    extends Composer<_$AppDatabase, $DailyAnalysisTable> {
  $$DailyAnalysisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trendState => $composableBuilder(
    column: $table.trendState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reversalState => $composableBuilder(
    column: $table.reversalState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get supportLevel => $composableBuilder(
    column: $table.supportLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyAnalysisTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyAnalysisTable> {
  $$DailyAnalysisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trendState => $composableBuilder(
    column: $table.trendState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reversalState => $composableBuilder(
    column: $table.reversalState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get supportLevel => $composableBuilder(
    column: $table.supportLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyAnalysisTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyAnalysisTable> {
  $$DailyAnalysisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get trendState => $composableBuilder(
    column: $table.trendState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reversalState => $composableBuilder(
    column: $table.reversalState,
    builder: (column) => column,
  );

  GeneratedColumn<double> get supportLevel => $composableBuilder(
    column: $table.supportLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyAnalysisTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyAnalysisTable,
          DailyAnalysisEntry,
          $$DailyAnalysisTableFilterComposer,
          $$DailyAnalysisTableOrderingComposer,
          $$DailyAnalysisTableAnnotationComposer,
          $$DailyAnalysisTableCreateCompanionBuilder,
          $$DailyAnalysisTableUpdateCompanionBuilder,
          (DailyAnalysisEntry, $$DailyAnalysisTableReferences),
          DailyAnalysisEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$DailyAnalysisTableTableManager(_$AppDatabase db, $DailyAnalysisTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyAnalysisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyAnalysisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyAnalysisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> trendState = const Value.absent(),
                Value<String> reversalState = const Value.absent(),
                Value<double?> supportLevel = const Value.absent(),
                Value<double?> resistanceLevel = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<DateTime> computedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyAnalysisCompanion(
                symbol: symbol,
                date: date,
                trendState: trendState,
                reversalState: reversalState,
                supportLevel: supportLevel,
                resistanceLevel: resistanceLevel,
                score: score,
                computedAt: computedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                required String trendState,
                Value<String> reversalState = const Value.absent(),
                Value<double?> supportLevel = const Value.absent(),
                Value<double?> resistanceLevel = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<DateTime> computedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyAnalysisCompanion.insert(
                symbol: symbol,
                date: date,
                trendState: trendState,
                reversalState: reversalState,
                supportLevel: supportLevel,
                resistanceLevel: resistanceLevel,
                score: score,
                computedAt: computedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DailyAnalysisTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$DailyAnalysisTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$DailyAnalysisTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DailyAnalysisTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyAnalysisTable,
      DailyAnalysisEntry,
      $$DailyAnalysisTableFilterComposer,
      $$DailyAnalysisTableOrderingComposer,
      $$DailyAnalysisTableAnnotationComposer,
      $$DailyAnalysisTableCreateCompanionBuilder,
      $$DailyAnalysisTableUpdateCompanionBuilder,
      (DailyAnalysisEntry, $$DailyAnalysisTableReferences),
      DailyAnalysisEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$DailyReasonTableCreateCompanionBuilder =
    DailyReasonCompanion Function({
      required String symbol,
      required DateTime date,
      required int rank,
      required String reasonType,
      required String evidenceJson,
      Value<double> ruleScore,
      Value<int> rowid,
    });
typedef $$DailyReasonTableUpdateCompanionBuilder =
    DailyReasonCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<int> rank,
      Value<String> reasonType,
      Value<String> evidenceJson,
      Value<double> ruleScore,
      Value<int> rowid,
    });

final class $$DailyReasonTableReferences
    extends BaseReferences<_$AppDatabase, $DailyReasonTable, DailyReasonEntry> {
  $$DailyReasonTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.dailyReason.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyReasonTableFilterComposer
    extends Composer<_$AppDatabase, $DailyReasonTable> {
  $$DailyReasonTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonType => $composableBuilder(
    column: $table.reasonType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ruleScore => $composableBuilder(
    column: $table.ruleScore,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyReasonTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyReasonTable> {
  $$DailyReasonTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonType => $composableBuilder(
    column: $table.reasonType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ruleScore => $composableBuilder(
    column: $table.ruleScore,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyReasonTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyReasonTable> {
  $$DailyReasonTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<String> get reasonType => $composableBuilder(
    column: $table.reasonType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get ruleScore =>
      $composableBuilder(column: $table.ruleScore, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyReasonTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyReasonTable,
          DailyReasonEntry,
          $$DailyReasonTableFilterComposer,
          $$DailyReasonTableOrderingComposer,
          $$DailyReasonTableAnnotationComposer,
          $$DailyReasonTableCreateCompanionBuilder,
          $$DailyReasonTableUpdateCompanionBuilder,
          (DailyReasonEntry, $$DailyReasonTableReferences),
          DailyReasonEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$DailyReasonTableTableManager(_$AppDatabase db, $DailyReasonTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyReasonTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyReasonTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyReasonTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> rank = const Value.absent(),
                Value<String> reasonType = const Value.absent(),
                Value<String> evidenceJson = const Value.absent(),
                Value<double> ruleScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyReasonCompanion(
                symbol: symbol,
                date: date,
                rank: rank,
                reasonType: reasonType,
                evidenceJson: evidenceJson,
                ruleScore: ruleScore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                required int rank,
                required String reasonType,
                required String evidenceJson,
                Value<double> ruleScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyReasonCompanion.insert(
                symbol: symbol,
                date: date,
                rank: rank,
                reasonType: reasonType,
                evidenceJson: evidenceJson,
                ruleScore: ruleScore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DailyReasonTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$DailyReasonTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$DailyReasonTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DailyReasonTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyReasonTable,
      DailyReasonEntry,
      $$DailyReasonTableFilterComposer,
      $$DailyReasonTableOrderingComposer,
      $$DailyReasonTableAnnotationComposer,
      $$DailyReasonTableCreateCompanionBuilder,
      $$DailyReasonTableUpdateCompanionBuilder,
      (DailyReasonEntry, $$DailyReasonTableReferences),
      DailyReasonEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$DailyRecommendationTableCreateCompanionBuilder =
    DailyRecommendationCompanion Function({
      required DateTime date,
      required int rank,
      required String symbol,
      required double score,
      Value<int> rowid,
    });
typedef $$DailyRecommendationTableUpdateCompanionBuilder =
    DailyRecommendationCompanion Function({
      Value<DateTime> date,
      Value<int> rank,
      Value<String> symbol,
      Value<double> score,
      Value<int> rowid,
    });

final class $$DailyRecommendationTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DailyRecommendationTable,
          DailyRecommendationEntry
        > {
  $$DailyRecommendationTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(
          db.dailyRecommendation.symbol,
          db.stockMaster.symbol,
        ),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyRecommendationTableFilterComposer
    extends Composer<_$AppDatabase, $DailyRecommendationTable> {
  $$DailyRecommendationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyRecommendationTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyRecommendationTable> {
  $$DailyRecommendationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyRecommendationTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyRecommendationTable> {
  $$DailyRecommendationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyRecommendationTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyRecommendationTable,
          DailyRecommendationEntry,
          $$DailyRecommendationTableFilterComposer,
          $$DailyRecommendationTableOrderingComposer,
          $$DailyRecommendationTableAnnotationComposer,
          $$DailyRecommendationTableCreateCompanionBuilder,
          $$DailyRecommendationTableUpdateCompanionBuilder,
          (DailyRecommendationEntry, $$DailyRecommendationTableReferences),
          DailyRecommendationEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$DailyRecommendationTableTableManager(
    _$AppDatabase db,
    $DailyRecommendationTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyRecommendationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyRecommendationTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DailyRecommendationTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<int> rank = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyRecommendationCompanion(
                date: date,
                rank: rank,
                symbol: symbol,
                score: score,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required int rank,
                required String symbol,
                required double score,
                Value<int> rowid = const Value.absent(),
              }) => DailyRecommendationCompanion.insert(
                date: date,
                rank: rank,
                symbol: symbol,
                score: score,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DailyRecommendationTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable:
                                    $$DailyRecommendationTableReferences
                                        ._symbolTable(db),
                                referencedColumn:
                                    $$DailyRecommendationTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DailyRecommendationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyRecommendationTable,
      DailyRecommendationEntry,
      $$DailyRecommendationTableFilterComposer,
      $$DailyRecommendationTableOrderingComposer,
      $$DailyRecommendationTableAnnotationComposer,
      $$DailyRecommendationTableCreateCompanionBuilder,
      $$DailyRecommendationTableUpdateCompanionBuilder,
      (DailyRecommendationEntry, $$DailyRecommendationTableReferences),
      DailyRecommendationEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$RuleAccuracyTableCreateCompanionBuilder =
    RuleAccuracyCompanion Function({
      required String ruleId,
      required String period,
      Value<int> triggerCount,
      Value<int> successCount,
      Value<double> avgReturn,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$RuleAccuracyTableUpdateCompanionBuilder =
    RuleAccuracyCompanion Function({
      Value<String> ruleId,
      Value<String> period,
      Value<int> triggerCount,
      Value<int> successCount,
      Value<double> avgReturn,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RuleAccuracyTableFilterComposer
    extends Composer<_$AppDatabase, $RuleAccuracyTable> {
  $$RuleAccuracyTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgReturn => $composableBuilder(
    column: $table.avgReturn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuleAccuracyTableOrderingComposer
    extends Composer<_$AppDatabase, $RuleAccuracyTable> {
  $$RuleAccuracyTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgReturn => $composableBuilder(
    column: $table.avgReturn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuleAccuracyTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuleAccuracyTable> {
  $$RuleAccuracyTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgReturn =>
      $composableBuilder(column: $table.avgReturn, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RuleAccuracyTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuleAccuracyTable,
          RuleAccuracyEntry,
          $$RuleAccuracyTableFilterComposer,
          $$RuleAccuracyTableOrderingComposer,
          $$RuleAccuracyTableAnnotationComposer,
          $$RuleAccuracyTableCreateCompanionBuilder,
          $$RuleAccuracyTableUpdateCompanionBuilder,
          (
            RuleAccuracyEntry,
            BaseReferences<
              _$AppDatabase,
              $RuleAccuracyTable,
              RuleAccuracyEntry
            >,
          ),
          RuleAccuracyEntry,
          PrefetchHooks Function()
        > {
  $$RuleAccuracyTableTableManager(_$AppDatabase db, $RuleAccuracyTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuleAccuracyTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuleAccuracyTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RuleAccuracyTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ruleId = const Value.absent(),
                Value<String> period = const Value.absent(),
                Value<int> triggerCount = const Value.absent(),
                Value<int> successCount = const Value.absent(),
                Value<double> avgReturn = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleAccuracyCompanion(
                ruleId: ruleId,
                period: period,
                triggerCount: triggerCount,
                successCount: successCount,
                avgReturn: avgReturn,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ruleId,
                required String period,
                Value<int> triggerCount = const Value.absent(),
                Value<int> successCount = const Value.absent(),
                Value<double> avgReturn = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleAccuracyCompanion.insert(
                ruleId: ruleId,
                period: period,
                triggerCount: triggerCount,
                successCount: successCount,
                avgReturn: avgReturn,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuleAccuracyTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuleAccuracyTable,
      RuleAccuracyEntry,
      $$RuleAccuracyTableFilterComposer,
      $$RuleAccuracyTableOrderingComposer,
      $$RuleAccuracyTableAnnotationComposer,
      $$RuleAccuracyTableCreateCompanionBuilder,
      $$RuleAccuracyTableUpdateCompanionBuilder,
      (
        RuleAccuracyEntry,
        BaseReferences<_$AppDatabase, $RuleAccuracyTable, RuleAccuracyEntry>,
      ),
      RuleAccuracyEntry,
      PrefetchHooks Function()
    >;
typedef $$RecommendationValidationTableCreateCompanionBuilder =
    RecommendationValidationCompanion Function({
      Value<int> id,
      required DateTime recommendationDate,
      required String symbol,
      required String primaryRuleId,
      required double entryPrice,
      Value<double?> exitPrice,
      Value<double?> returnRate,
      Value<bool?> isSuccess,
      Value<DateTime?> validationDate,
      Value<int> holdingDays,
    });
typedef $$RecommendationValidationTableUpdateCompanionBuilder =
    RecommendationValidationCompanion Function({
      Value<int> id,
      Value<DateTime> recommendationDate,
      Value<String> symbol,
      Value<String> primaryRuleId,
      Value<double> entryPrice,
      Value<double?> exitPrice,
      Value<double?> returnRate,
      Value<bool?> isSuccess,
      Value<DateTime?> validationDate,
      Value<int> holdingDays,
    });

class $$RecommendationValidationTableFilterComposer
    extends Composer<_$AppDatabase, $RecommendationValidationTable> {
  $$RecommendationValidationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recommendationDate => $composableBuilder(
    column: $table.recommendationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryRuleId => $composableBuilder(
    column: $table.primaryRuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get exitPrice => $composableBuilder(
    column: $table.exitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get returnRate => $composableBuilder(
    column: $table.returnRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSuccess => $composableBuilder(
    column: $table.isSuccess,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get validationDate => $composableBuilder(
    column: $table.validationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holdingDays => $composableBuilder(
    column: $table.holdingDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecommendationValidationTableOrderingComposer
    extends Composer<_$AppDatabase, $RecommendationValidationTable> {
  $$RecommendationValidationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recommendationDate => $composableBuilder(
    column: $table.recommendationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryRuleId => $composableBuilder(
    column: $table.primaryRuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get exitPrice => $composableBuilder(
    column: $table.exitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get returnRate => $composableBuilder(
    column: $table.returnRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSuccess => $composableBuilder(
    column: $table.isSuccess,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get validationDate => $composableBuilder(
    column: $table.validationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holdingDays => $composableBuilder(
    column: $table.holdingDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecommendationValidationTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecommendationValidationTable> {
  $$RecommendationValidationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get recommendationDate => $composableBuilder(
    column: $table.recommendationDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get primaryRuleId => $composableBuilder(
    column: $table.primaryRuleId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => column,
  );

  GeneratedColumn<double> get exitPrice =>
      $composableBuilder(column: $table.exitPrice, builder: (column) => column);

  GeneratedColumn<double> get returnRate => $composableBuilder(
    column: $table.returnRate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSuccess =>
      $composableBuilder(column: $table.isSuccess, builder: (column) => column);

  GeneratedColumn<DateTime> get validationDate => $composableBuilder(
    column: $table.validationDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get holdingDays => $composableBuilder(
    column: $table.holdingDays,
    builder: (column) => column,
  );
}

class $$RecommendationValidationTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecommendationValidationTable,
          RecommendationValidationEntry,
          $$RecommendationValidationTableFilterComposer,
          $$RecommendationValidationTableOrderingComposer,
          $$RecommendationValidationTableAnnotationComposer,
          $$RecommendationValidationTableCreateCompanionBuilder,
          $$RecommendationValidationTableUpdateCompanionBuilder,
          (
            RecommendationValidationEntry,
            BaseReferences<
              _$AppDatabase,
              $RecommendationValidationTable,
              RecommendationValidationEntry
            >,
          ),
          RecommendationValidationEntry,
          PrefetchHooks Function()
        > {
  $$RecommendationValidationTableTableManager(
    _$AppDatabase db,
    $RecommendationValidationTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecommendationValidationTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecommendationValidationTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecommendationValidationTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> recommendationDate = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String> primaryRuleId = const Value.absent(),
                Value<double> entryPrice = const Value.absent(),
                Value<double?> exitPrice = const Value.absent(),
                Value<double?> returnRate = const Value.absent(),
                Value<bool?> isSuccess = const Value.absent(),
                Value<DateTime?> validationDate = const Value.absent(),
                Value<int> holdingDays = const Value.absent(),
              }) => RecommendationValidationCompanion(
                id: id,
                recommendationDate: recommendationDate,
                symbol: symbol,
                primaryRuleId: primaryRuleId,
                entryPrice: entryPrice,
                exitPrice: exitPrice,
                returnRate: returnRate,
                isSuccess: isSuccess,
                validationDate: validationDate,
                holdingDays: holdingDays,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime recommendationDate,
                required String symbol,
                required String primaryRuleId,
                required double entryPrice,
                Value<double?> exitPrice = const Value.absent(),
                Value<double?> returnRate = const Value.absent(),
                Value<bool?> isSuccess = const Value.absent(),
                Value<DateTime?> validationDate = const Value.absent(),
                Value<int> holdingDays = const Value.absent(),
              }) => RecommendationValidationCompanion.insert(
                id: id,
                recommendationDate: recommendationDate,
                symbol: symbol,
                primaryRuleId: primaryRuleId,
                entryPrice: entryPrice,
                exitPrice: exitPrice,
                returnRate: returnRate,
                isSuccess: isSuccess,
                validationDate: validationDate,
                holdingDays: holdingDays,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecommendationValidationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecommendationValidationTable,
      RecommendationValidationEntry,
      $$RecommendationValidationTableFilterComposer,
      $$RecommendationValidationTableOrderingComposer,
      $$RecommendationValidationTableAnnotationComposer,
      $$RecommendationValidationTableCreateCompanionBuilder,
      $$RecommendationValidationTableUpdateCompanionBuilder,
      (
        RecommendationValidationEntry,
        BaseReferences<
          _$AppDatabase,
          $RecommendationValidationTable,
          RecommendationValidationEntry
        >,
      ),
      RecommendationValidationEntry,
      PrefetchHooks Function()
    >;
typedef $$WatchlistTableCreateCompanionBuilder =
    WatchlistCompanion Function({
      required String symbol,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$WatchlistTableUpdateCompanionBuilder =
    WatchlistCompanion Function({
      Value<String> symbol,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$WatchlistTableReferences
    extends BaseReferences<_$AppDatabase, $WatchlistTable, WatchlistEntry> {
  $$WatchlistTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.watchlist.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WatchlistTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistTable> {
  $$WatchlistTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchlistTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistTable> {
  $$WatchlistTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchlistTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistTable> {
  $$WatchlistTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchlistTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchlistTable,
          WatchlistEntry,
          $$WatchlistTableFilterComposer,
          $$WatchlistTableOrderingComposer,
          $$WatchlistTableAnnotationComposer,
          $$WatchlistTableCreateCompanionBuilder,
          $$WatchlistTableUpdateCompanionBuilder,
          (WatchlistEntry, $$WatchlistTableReferences),
          WatchlistEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$WatchlistTableTableManager(_$AppDatabase db, $WatchlistTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchlistCompanion(
                symbol: symbol,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchlistCompanion.insert(
                symbol: symbol,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WatchlistTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$WatchlistTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$WatchlistTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WatchlistTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchlistTable,
      WatchlistEntry,
      $$WatchlistTableFilterComposer,
      $$WatchlistTableOrderingComposer,
      $$WatchlistTableAnnotationComposer,
      $$WatchlistTableCreateCompanionBuilder,
      $$WatchlistTableUpdateCompanionBuilder,
      (WatchlistEntry, $$WatchlistTableReferences),
      WatchlistEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$UserNoteTableCreateCompanionBuilder =
    UserNoteCompanion Function({
      Value<int> id,
      required String symbol,
      Value<DateTime?> date,
      required String content,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$UserNoteTableUpdateCompanionBuilder =
    UserNoteCompanion Function({
      Value<int> id,
      Value<String> symbol,
      Value<DateTime?> date,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$UserNoteTableReferences
    extends BaseReferences<_$AppDatabase, $UserNoteTable, UserNoteEntry> {
  $$UserNoteTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.userNote.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserNoteTableFilterComposer
    extends Composer<_$AppDatabase, $UserNoteTable> {
  $$UserNoteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserNoteTableOrderingComposer
    extends Composer<_$AppDatabase, $UserNoteTable> {
  $$UserNoteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserNoteTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserNoteTable> {
  $$UserNoteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserNoteTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserNoteTable,
          UserNoteEntry,
          $$UserNoteTableFilterComposer,
          $$UserNoteTableOrderingComposer,
          $$UserNoteTableAnnotationComposer,
          $$UserNoteTableCreateCompanionBuilder,
          $$UserNoteTableUpdateCompanionBuilder,
          (UserNoteEntry, $$UserNoteTableReferences),
          UserNoteEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$UserNoteTableTableManager(_$AppDatabase db, $UserNoteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserNoteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserNoteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserNoteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<DateTime?> date = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserNoteCompanion(
                id: id,
                symbol: symbol,
                date: date,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String symbol,
                Value<DateTime?> date = const Value.absent(),
                required String content,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserNoteCompanion.insert(
                id: id,
                symbol: symbol,
                date: date,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserNoteTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$UserNoteTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$UserNoteTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UserNoteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserNoteTable,
      UserNoteEntry,
      $$UserNoteTableFilterComposer,
      $$UserNoteTableOrderingComposer,
      $$UserNoteTableAnnotationComposer,
      $$UserNoteTableCreateCompanionBuilder,
      $$UserNoteTableUpdateCompanionBuilder,
      (UserNoteEntry, $$UserNoteTableReferences),
      UserNoteEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$StrategyCardTableCreateCompanionBuilder =
    StrategyCardCompanion Function({
      Value<int> id,
      required String symbol,
      Value<DateTime?> forDate,
      Value<String?> ifA,
      Value<String?> thenA,
      Value<String?> ifB,
      Value<String?> thenB,
      Value<String?> elsePlan,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$StrategyCardTableUpdateCompanionBuilder =
    StrategyCardCompanion Function({
      Value<int> id,
      Value<String> symbol,
      Value<DateTime?> forDate,
      Value<String?> ifA,
      Value<String?> thenA,
      Value<String?> ifB,
      Value<String?> thenB,
      Value<String?> elsePlan,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$StrategyCardTableReferences
    extends
        BaseReferences<_$AppDatabase, $StrategyCardTable, StrategyCardEntry> {
  $$StrategyCardTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.strategyCard.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StrategyCardTableFilterComposer
    extends Composer<_$AppDatabase, $StrategyCardTable> {
  $$StrategyCardTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get forDate => $composableBuilder(
    column: $table.forDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ifA => $composableBuilder(
    column: $table.ifA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thenA => $composableBuilder(
    column: $table.thenA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ifB => $composableBuilder(
    column: $table.ifB,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thenB => $composableBuilder(
    column: $table.thenB,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get elsePlan => $composableBuilder(
    column: $table.elsePlan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StrategyCardTableOrderingComposer
    extends Composer<_$AppDatabase, $StrategyCardTable> {
  $$StrategyCardTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get forDate => $composableBuilder(
    column: $table.forDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ifA => $composableBuilder(
    column: $table.ifA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thenA => $composableBuilder(
    column: $table.thenA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ifB => $composableBuilder(
    column: $table.ifB,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thenB => $composableBuilder(
    column: $table.thenB,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get elsePlan => $composableBuilder(
    column: $table.elsePlan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StrategyCardTableAnnotationComposer
    extends Composer<_$AppDatabase, $StrategyCardTable> {
  $$StrategyCardTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get forDate =>
      $composableBuilder(column: $table.forDate, builder: (column) => column);

  GeneratedColumn<String> get ifA =>
      $composableBuilder(column: $table.ifA, builder: (column) => column);

  GeneratedColumn<String> get thenA =>
      $composableBuilder(column: $table.thenA, builder: (column) => column);

  GeneratedColumn<String> get ifB =>
      $composableBuilder(column: $table.ifB, builder: (column) => column);

  GeneratedColumn<String> get thenB =>
      $composableBuilder(column: $table.thenB, builder: (column) => column);

  GeneratedColumn<String> get elsePlan =>
      $composableBuilder(column: $table.elsePlan, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StrategyCardTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StrategyCardTable,
          StrategyCardEntry,
          $$StrategyCardTableFilterComposer,
          $$StrategyCardTableOrderingComposer,
          $$StrategyCardTableAnnotationComposer,
          $$StrategyCardTableCreateCompanionBuilder,
          $$StrategyCardTableUpdateCompanionBuilder,
          (StrategyCardEntry, $$StrategyCardTableReferences),
          StrategyCardEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$StrategyCardTableTableManager(_$AppDatabase db, $StrategyCardTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StrategyCardTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StrategyCardTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StrategyCardTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<DateTime?> forDate = const Value.absent(),
                Value<String?> ifA = const Value.absent(),
                Value<String?> thenA = const Value.absent(),
                Value<String?> ifB = const Value.absent(),
                Value<String?> thenB = const Value.absent(),
                Value<String?> elsePlan = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => StrategyCardCompanion(
                id: id,
                symbol: symbol,
                forDate: forDate,
                ifA: ifA,
                thenA: thenA,
                ifB: ifB,
                thenB: thenB,
                elsePlan: elsePlan,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String symbol,
                Value<DateTime?> forDate = const Value.absent(),
                Value<String?> ifA = const Value.absent(),
                Value<String?> thenA = const Value.absent(),
                Value<String?> ifB = const Value.absent(),
                Value<String?> thenB = const Value.absent(),
                Value<String?> elsePlan = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => StrategyCardCompanion.insert(
                id: id,
                symbol: symbol,
                forDate: forDate,
                ifA: ifA,
                thenA: thenA,
                ifB: ifB,
                thenB: thenB,
                elsePlan: elsePlan,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StrategyCardTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$StrategyCardTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$StrategyCardTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StrategyCardTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StrategyCardTable,
      StrategyCardEntry,
      $$StrategyCardTableFilterComposer,
      $$StrategyCardTableOrderingComposer,
      $$StrategyCardTableAnnotationComposer,
      $$StrategyCardTableCreateCompanionBuilder,
      $$StrategyCardTableUpdateCompanionBuilder,
      (StrategyCardEntry, $$StrategyCardTableReferences),
      StrategyCardEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$UpdateRunTableCreateCompanionBuilder =
    UpdateRunCompanion Function({
      Value<int> id,
      required DateTime runDate,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      required String status,
      Value<String?> message,
    });
typedef $$UpdateRunTableUpdateCompanionBuilder =
    UpdateRunCompanion Function({
      Value<int> id,
      Value<DateTime> runDate,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<String> status,
      Value<String?> message,
    });

class $$UpdateRunTableFilterComposer
    extends Composer<_$AppDatabase, $UpdateRunTable> {
  $$UpdateRunTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get runDate => $composableBuilder(
    column: $table.runDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UpdateRunTableOrderingComposer
    extends Composer<_$AppDatabase, $UpdateRunTable> {
  $$UpdateRunTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get runDate => $composableBuilder(
    column: $table.runDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UpdateRunTableAnnotationComposer
    extends Composer<_$AppDatabase, $UpdateRunTable> {
  $$UpdateRunTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get runDate =>
      $composableBuilder(column: $table.runDate, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);
}

class $$UpdateRunTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UpdateRunTable,
          UpdateRunEntry,
          $$UpdateRunTableFilterComposer,
          $$UpdateRunTableOrderingComposer,
          $$UpdateRunTableAnnotationComposer,
          $$UpdateRunTableCreateCompanionBuilder,
          $$UpdateRunTableUpdateCompanionBuilder,
          (
            UpdateRunEntry,
            BaseReferences<_$AppDatabase, $UpdateRunTable, UpdateRunEntry>,
          ),
          UpdateRunEntry,
          PrefetchHooks Function()
        > {
  $$UpdateRunTableTableManager(_$AppDatabase db, $UpdateRunTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UpdateRunTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UpdateRunTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UpdateRunTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> runDate = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> message = const Value.absent(),
              }) => UpdateRunCompanion(
                id: id,
                runDate: runDate,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
                message: message,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime runDate,
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                required String status,
                Value<String?> message = const Value.absent(),
              }) => UpdateRunCompanion.insert(
                id: id,
                runDate: runDate,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
                message: message,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UpdateRunTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UpdateRunTable,
      UpdateRunEntry,
      $$UpdateRunTableFilterComposer,
      $$UpdateRunTableOrderingComposer,
      $$UpdateRunTableAnnotationComposer,
      $$UpdateRunTableCreateCompanionBuilder,
      $$UpdateRunTableUpdateCompanionBuilder,
      (
        UpdateRunEntry,
        BaseReferences<_$AppDatabase, $UpdateRunTable, UpdateRunEntry>,
      ),
      UpdateRunEntry,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingEntry,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingEntry,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingEntry>,
          ),
          AppSettingEntry,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingEntry,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingEntry,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingEntry>,
      ),
      AppSettingEntry,
      PrefetchHooks Function()
    >;
typedef $$PriceAlertTableCreateCompanionBuilder =
    PriceAlertCompanion Function({
      Value<int> id,
      required String symbol,
      required String alertType,
      required double targetValue,
      Value<bool> isActive,
      Value<DateTime?> triggeredAt,
      Value<String?> note,
      Value<DateTime> createdAt,
    });
typedef $$PriceAlertTableUpdateCompanionBuilder =
    PriceAlertCompanion Function({
      Value<int> id,
      Value<String> symbol,
      Value<String> alertType,
      Value<double> targetValue,
      Value<bool> isActive,
      Value<DateTime?> triggeredAt,
      Value<String?> note,
      Value<DateTime> createdAt,
    });

final class $$PriceAlertTableReferences
    extends BaseReferences<_$AppDatabase, $PriceAlertTable, PriceAlertEntry> {
  $$PriceAlertTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.priceAlert.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PriceAlertTableFilterComposer
    extends Composer<_$AppDatabase, $PriceAlertTable> {
  $$PriceAlertTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alertType => $composableBuilder(
    column: $table.alertType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceAlertTableOrderingComposer
    extends Composer<_$AppDatabase, $PriceAlertTable> {
  $$PriceAlertTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alertType => $composableBuilder(
    column: $table.alertType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceAlertTableAnnotationComposer
    extends Composer<_$AppDatabase, $PriceAlertTable> {
  $$PriceAlertTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alertType =>
      $composableBuilder(column: $table.alertType, builder: (column) => column);

  GeneratedColumn<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceAlertTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PriceAlertTable,
          PriceAlertEntry,
          $$PriceAlertTableFilterComposer,
          $$PriceAlertTableOrderingComposer,
          $$PriceAlertTableAnnotationComposer,
          $$PriceAlertTableCreateCompanionBuilder,
          $$PriceAlertTableUpdateCompanionBuilder,
          (PriceAlertEntry, $$PriceAlertTableReferences),
          PriceAlertEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$PriceAlertTableTableManager(_$AppDatabase db, $PriceAlertTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PriceAlertTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PriceAlertTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PriceAlertTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String> alertType = const Value.absent(),
                Value<double> targetValue = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> triggeredAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PriceAlertCompanion(
                id: id,
                symbol: symbol,
                alertType: alertType,
                targetValue: targetValue,
                isActive: isActive,
                triggeredAt: triggeredAt,
                note: note,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String symbol,
                required String alertType,
                required double targetValue,
                Value<bool> isActive = const Value.absent(),
                Value<DateTime?> triggeredAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PriceAlertCompanion.insert(
                id: id,
                symbol: symbol,
                alertType: alertType,
                targetValue: targetValue,
                isActive: isActive,
                triggeredAt: triggeredAt,
                note: note,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PriceAlertTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$PriceAlertTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$PriceAlertTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PriceAlertTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PriceAlertTable,
      PriceAlertEntry,
      $$PriceAlertTableFilterComposer,
      $$PriceAlertTableOrderingComposer,
      $$PriceAlertTableAnnotationComposer,
      $$PriceAlertTableCreateCompanionBuilder,
      $$PriceAlertTableUpdateCompanionBuilder,
      (PriceAlertEntry, $$PriceAlertTableReferences),
      PriceAlertEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$UserInteractionTableCreateCompanionBuilder =
    UserInteractionCompanion Function({
      Value<int> id,
      required String interactionType,
      required String symbol,
      Value<DateTime> timestamp,
      Value<int?> durationSeconds,
      Value<String?> sourcePage,
    });
typedef $$UserInteractionTableUpdateCompanionBuilder =
    UserInteractionCompanion Function({
      Value<int> id,
      Value<String> interactionType,
      Value<String> symbol,
      Value<DateTime> timestamp,
      Value<int?> durationSeconds,
      Value<String?> sourcePage,
    });

class $$UserInteractionTableFilterComposer
    extends Composer<_$AppDatabase, $UserInteractionTable> {
  $$UserInteractionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePage => $composableBuilder(
    column: $table.sourcePage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserInteractionTableOrderingComposer
    extends Composer<_$AppDatabase, $UserInteractionTable> {
  $$UserInteractionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePage => $composableBuilder(
    column: $table.sourcePage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserInteractionTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserInteractionTable> {
  $$UserInteractionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePage => $composableBuilder(
    column: $table.sourcePage,
    builder: (column) => column,
  );
}

class $$UserInteractionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserInteractionTable,
          UserInteractionEntry,
          $$UserInteractionTableFilterComposer,
          $$UserInteractionTableOrderingComposer,
          $$UserInteractionTableAnnotationComposer,
          $$UserInteractionTableCreateCompanionBuilder,
          $$UserInteractionTableUpdateCompanionBuilder,
          (
            UserInteractionEntry,
            BaseReferences<
              _$AppDatabase,
              $UserInteractionTable,
              UserInteractionEntry
            >,
          ),
          UserInteractionEntry,
          PrefetchHooks Function()
        > {
  $$UserInteractionTableTableManager(
    _$AppDatabase db,
    $UserInteractionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserInteractionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserInteractionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserInteractionTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> interactionType = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> sourcePage = const Value.absent(),
              }) => UserInteractionCompanion(
                id: id,
                interactionType: interactionType,
                symbol: symbol,
                timestamp: timestamp,
                durationSeconds: durationSeconds,
                sourcePage: sourcePage,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String interactionType,
                required String symbol,
                Value<DateTime> timestamp = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> sourcePage = const Value.absent(),
              }) => UserInteractionCompanion.insert(
                id: id,
                interactionType: interactionType,
                symbol: symbol,
                timestamp: timestamp,
                durationSeconds: durationSeconds,
                sourcePage: sourcePage,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserInteractionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserInteractionTable,
      UserInteractionEntry,
      $$UserInteractionTableFilterComposer,
      $$UserInteractionTableOrderingComposer,
      $$UserInteractionTableAnnotationComposer,
      $$UserInteractionTableCreateCompanionBuilder,
      $$UserInteractionTableUpdateCompanionBuilder,
      (
        UserInteractionEntry,
        BaseReferences<
          _$AppDatabase,
          $UserInteractionTable,
          UserInteractionEntry
        >,
      ),
      UserInteractionEntry,
      PrefetchHooks Function()
    >;
typedef $$UserPreferenceTableCreateCompanionBuilder =
    UserPreferenceCompanion Function({
      required String preferenceType,
      required String preferenceValue,
      Value<double> weight,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$UserPreferenceTableUpdateCompanionBuilder =
    UserPreferenceCompanion Function({
      Value<String> preferenceType,
      Value<String> preferenceValue,
      Value<double> weight,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserPreferenceTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferenceTable> {
  $$UserPreferenceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get preferenceType => $composableBuilder(
    column: $table.preferenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferenceValue => $composableBuilder(
    column: $table.preferenceValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferenceTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferenceTable> {
  $$UserPreferenceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get preferenceType => $composableBuilder(
    column: $table.preferenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferenceValue => $composableBuilder(
    column: $table.preferenceValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferenceTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferenceTable> {
  $$UserPreferenceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get preferenceType => $composableBuilder(
    column: $table.preferenceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferenceValue => $composableBuilder(
    column: $table.preferenceValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPreferenceTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPreferenceTable,
          UserPreferenceEntry,
          $$UserPreferenceTableFilterComposer,
          $$UserPreferenceTableOrderingComposer,
          $$UserPreferenceTableAnnotationComposer,
          $$UserPreferenceTableCreateCompanionBuilder,
          $$UserPreferenceTableUpdateCompanionBuilder,
          (
            UserPreferenceEntry,
            BaseReferences<
              _$AppDatabase,
              $UserPreferenceTable,
              UserPreferenceEntry
            >,
          ),
          UserPreferenceEntry,
          PrefetchHooks Function()
        > {
  $$UserPreferenceTableTableManager(
    _$AppDatabase db,
    $UserPreferenceTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferenceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferenceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferenceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> preferenceType = const Value.absent(),
                Value<String> preferenceValue = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferenceCompanion(
                preferenceType: preferenceType,
                preferenceValue: preferenceValue,
                weight: weight,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String preferenceType,
                required String preferenceValue,
                Value<double> weight = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferenceCompanion.insert(
                preferenceType: preferenceType,
                preferenceValue: preferenceValue,
                weight: weight,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferenceTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPreferenceTable,
      UserPreferenceEntry,
      $$UserPreferenceTableFilterComposer,
      $$UserPreferenceTableOrderingComposer,
      $$UserPreferenceTableAnnotationComposer,
      $$UserPreferenceTableCreateCompanionBuilder,
      $$UserPreferenceTableUpdateCompanionBuilder,
      (
        UserPreferenceEntry,
        BaseReferences<
          _$AppDatabase,
          $UserPreferenceTable,
          UserPreferenceEntry
        >,
      ),
      UserPreferenceEntry,
      PrefetchHooks Function()
    >;
typedef $$ShareholdingTableCreateCompanionBuilder =
    ShareholdingCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> foreignRemainingShares,
      Value<double?> foreignSharesRatio,
      Value<double?> foreignUpperLimitRatio,
      Value<double?> sharesIssued,
      Value<int> rowid,
    });
typedef $$ShareholdingTableUpdateCompanionBuilder =
    ShareholdingCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> foreignRemainingShares,
      Value<double?> foreignSharesRatio,
      Value<double?> foreignUpperLimitRatio,
      Value<double?> sharesIssued,
      Value<int> rowid,
    });

final class $$ShareholdingTableReferences
    extends
        BaseReferences<_$AppDatabase, $ShareholdingTable, ShareholdingEntry> {
  $$ShareholdingTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.shareholding.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShareholdingTableFilterComposer
    extends Composer<_$AppDatabase, $ShareholdingTable> {
  $$ShareholdingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get foreignRemainingShares => $composableBuilder(
    column: $table.foreignRemainingShares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get foreignSharesRatio => $composableBuilder(
    column: $table.foreignSharesRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get foreignUpperLimitRatio => $composableBuilder(
    column: $table.foreignUpperLimitRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sharesIssued => $composableBuilder(
    column: $table.sharesIssued,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShareholdingTableOrderingComposer
    extends Composer<_$AppDatabase, $ShareholdingTable> {
  $$ShareholdingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get foreignRemainingShares => $composableBuilder(
    column: $table.foreignRemainingShares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get foreignSharesRatio => $composableBuilder(
    column: $table.foreignSharesRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get foreignUpperLimitRatio => $composableBuilder(
    column: $table.foreignUpperLimitRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sharesIssued => $composableBuilder(
    column: $table.sharesIssued,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShareholdingTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShareholdingTable> {
  $$ShareholdingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get foreignRemainingShares => $composableBuilder(
    column: $table.foreignRemainingShares,
    builder: (column) => column,
  );

  GeneratedColumn<double> get foreignSharesRatio => $composableBuilder(
    column: $table.foreignSharesRatio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get foreignUpperLimitRatio => $composableBuilder(
    column: $table.foreignUpperLimitRatio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sharesIssued => $composableBuilder(
    column: $table.sharesIssued,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShareholdingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShareholdingTable,
          ShareholdingEntry,
          $$ShareholdingTableFilterComposer,
          $$ShareholdingTableOrderingComposer,
          $$ShareholdingTableAnnotationComposer,
          $$ShareholdingTableCreateCompanionBuilder,
          $$ShareholdingTableUpdateCompanionBuilder,
          (ShareholdingEntry, $$ShareholdingTableReferences),
          ShareholdingEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$ShareholdingTableTableManager(_$AppDatabase db, $ShareholdingTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShareholdingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShareholdingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShareholdingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> foreignRemainingShares = const Value.absent(),
                Value<double?> foreignSharesRatio = const Value.absent(),
                Value<double?> foreignUpperLimitRatio = const Value.absent(),
                Value<double?> sharesIssued = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShareholdingCompanion(
                symbol: symbol,
                date: date,
                foreignRemainingShares: foreignRemainingShares,
                foreignSharesRatio: foreignSharesRatio,
                foreignUpperLimitRatio: foreignUpperLimitRatio,
                sharesIssued: sharesIssued,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> foreignRemainingShares = const Value.absent(),
                Value<double?> foreignSharesRatio = const Value.absent(),
                Value<double?> foreignUpperLimitRatio = const Value.absent(),
                Value<double?> sharesIssued = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShareholdingCompanion.insert(
                symbol: symbol,
                date: date,
                foreignRemainingShares: foreignRemainingShares,
                foreignSharesRatio: foreignSharesRatio,
                foreignUpperLimitRatio: foreignUpperLimitRatio,
                sharesIssued: sharesIssued,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShareholdingTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$ShareholdingTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$ShareholdingTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShareholdingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShareholdingTable,
      ShareholdingEntry,
      $$ShareholdingTableFilterComposer,
      $$ShareholdingTableOrderingComposer,
      $$ShareholdingTableAnnotationComposer,
      $$ShareholdingTableCreateCompanionBuilder,
      $$ShareholdingTableUpdateCompanionBuilder,
      (ShareholdingEntry, $$ShareholdingTableReferences),
      ShareholdingEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$DayTradingTableCreateCompanionBuilder =
    DayTradingCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> buyVolume,
      Value<double?> sellVolume,
      Value<double?> dayTradingRatio,
      Value<double?> tradeVolume,
      Value<int> rowid,
    });
typedef $$DayTradingTableUpdateCompanionBuilder =
    DayTradingCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> buyVolume,
      Value<double?> sellVolume,
      Value<double?> dayTradingRatio,
      Value<double?> tradeVolume,
      Value<int> rowid,
    });

final class $$DayTradingTableReferences
    extends BaseReferences<_$AppDatabase, $DayTradingTable, DayTradingEntry> {
  $$DayTradingTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.dayTrading.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DayTradingTableFilterComposer
    extends Composer<_$AppDatabase, $DayTradingTable> {
  $$DayTradingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get buyVolume => $composableBuilder(
    column: $table.buyVolume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sellVolume => $composableBuilder(
    column: $table.sellVolume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dayTradingRatio => $composableBuilder(
    column: $table.dayTradingRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tradeVolume => $composableBuilder(
    column: $table.tradeVolume,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTradingTableOrderingComposer
    extends Composer<_$AppDatabase, $DayTradingTable> {
  $$DayTradingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get buyVolume => $composableBuilder(
    column: $table.buyVolume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sellVolume => $composableBuilder(
    column: $table.sellVolume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dayTradingRatio => $composableBuilder(
    column: $table.dayTradingRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tradeVolume => $composableBuilder(
    column: $table.tradeVolume,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTradingTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayTradingTable> {
  $$DayTradingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get buyVolume =>
      $composableBuilder(column: $table.buyVolume, builder: (column) => column);

  GeneratedColumn<double> get sellVolume => $composableBuilder(
    column: $table.sellVolume,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dayTradingRatio => $composableBuilder(
    column: $table.dayTradingRatio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tradeVolume => $composableBuilder(
    column: $table.tradeVolume,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTradingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayTradingTable,
          DayTradingEntry,
          $$DayTradingTableFilterComposer,
          $$DayTradingTableOrderingComposer,
          $$DayTradingTableAnnotationComposer,
          $$DayTradingTableCreateCompanionBuilder,
          $$DayTradingTableUpdateCompanionBuilder,
          (DayTradingEntry, $$DayTradingTableReferences),
          DayTradingEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$DayTradingTableTableManager(_$AppDatabase db, $DayTradingTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayTradingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayTradingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayTradingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> buyVolume = const Value.absent(),
                Value<double?> sellVolume = const Value.absent(),
                Value<double?> dayTradingRatio = const Value.absent(),
                Value<double?> tradeVolume = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayTradingCompanion(
                symbol: symbol,
                date: date,
                buyVolume: buyVolume,
                sellVolume: sellVolume,
                dayTradingRatio: dayTradingRatio,
                tradeVolume: tradeVolume,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> buyVolume = const Value.absent(),
                Value<double?> sellVolume = const Value.absent(),
                Value<double?> dayTradingRatio = const Value.absent(),
                Value<double?> tradeVolume = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayTradingCompanion.insert(
                symbol: symbol,
                date: date,
                buyVolume: buyVolume,
                sellVolume: sellVolume,
                dayTradingRatio: dayTradingRatio,
                tradeVolume: tradeVolume,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DayTradingTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$DayTradingTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$DayTradingTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DayTradingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayTradingTable,
      DayTradingEntry,
      $$DayTradingTableFilterComposer,
      $$DayTradingTableOrderingComposer,
      $$DayTradingTableAnnotationComposer,
      $$DayTradingTableCreateCompanionBuilder,
      $$DayTradingTableUpdateCompanionBuilder,
      (DayTradingEntry, $$DayTradingTableReferences),
      DayTradingEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$FinancialDataTableCreateCompanionBuilder =
    FinancialDataCompanion Function({
      required String symbol,
      required DateTime date,
      required String statementType,
      required String dataType,
      Value<double?> value,
      Value<String?> originName,
      Value<int> rowid,
    });
typedef $$FinancialDataTableUpdateCompanionBuilder =
    FinancialDataCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<String> statementType,
      Value<String> dataType,
      Value<double?> value,
      Value<String?> originName,
      Value<int> rowid,
    });

final class $$FinancialDataTableReferences
    extends
        BaseReferences<_$AppDatabase, $FinancialDataTable, FinancialDataEntry> {
  $$FinancialDataTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.financialData.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FinancialDataTableFilterComposer
    extends Composer<_$AppDatabase, $FinancialDataTable> {
  $$FinancialDataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statementType => $composableBuilder(
    column: $table.statementType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataType => $composableBuilder(
    column: $table.dataType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinancialDataTableOrderingComposer
    extends Composer<_$AppDatabase, $FinancialDataTable> {
  $$FinancialDataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statementType => $composableBuilder(
    column: $table.statementType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataType => $composableBuilder(
    column: $table.dataType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinancialDataTableAnnotationComposer
    extends Composer<_$AppDatabase, $FinancialDataTable> {
  $$FinancialDataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get statementType => $composableBuilder(
    column: $table.statementType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataType =>
      $composableBuilder(column: $table.dataType, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinancialDataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FinancialDataTable,
          FinancialDataEntry,
          $$FinancialDataTableFilterComposer,
          $$FinancialDataTableOrderingComposer,
          $$FinancialDataTableAnnotationComposer,
          $$FinancialDataTableCreateCompanionBuilder,
          $$FinancialDataTableUpdateCompanionBuilder,
          (FinancialDataEntry, $$FinancialDataTableReferences),
          FinancialDataEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$FinancialDataTableTableManager(_$AppDatabase db, $FinancialDataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinancialDataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FinancialDataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FinancialDataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> statementType = const Value.absent(),
                Value<String> dataType = const Value.absent(),
                Value<double?> value = const Value.absent(),
                Value<String?> originName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FinancialDataCompanion(
                symbol: symbol,
                date: date,
                statementType: statementType,
                dataType: dataType,
                value: value,
                originName: originName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                required String statementType,
                required String dataType,
                Value<double?> value = const Value.absent(),
                Value<String?> originName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FinancialDataCompanion.insert(
                symbol: symbol,
                date: date,
                statementType: statementType,
                dataType: dataType,
                value: value,
                originName: originName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FinancialDataTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$FinancialDataTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$FinancialDataTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FinancialDataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FinancialDataTable,
      FinancialDataEntry,
      $$FinancialDataTableFilterComposer,
      $$FinancialDataTableOrderingComposer,
      $$FinancialDataTableAnnotationComposer,
      $$FinancialDataTableCreateCompanionBuilder,
      $$FinancialDataTableUpdateCompanionBuilder,
      (FinancialDataEntry, $$FinancialDataTableReferences),
      FinancialDataEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$AdjustedPriceTableCreateCompanionBuilder =
    AdjustedPriceCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> open,
      Value<double?> high,
      Value<double?> low,
      Value<double?> close,
      Value<double?> volume,
      Value<int> rowid,
    });
typedef $$AdjustedPriceTableUpdateCompanionBuilder =
    AdjustedPriceCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> open,
      Value<double?> high,
      Value<double?> low,
      Value<double?> close,
      Value<double?> volume,
      Value<int> rowid,
    });

final class $$AdjustedPriceTableReferences
    extends
        BaseReferences<_$AppDatabase, $AdjustedPriceTable, AdjustedPriceEntry> {
  $$AdjustedPriceTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.adjustedPrice.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AdjustedPriceTableFilterComposer
    extends Composer<_$AppDatabase, $AdjustedPriceTable> {
  $$AdjustedPriceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get open => $composableBuilder(
    column: $table.open,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get high => $composableBuilder(
    column: $table.high,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get low => $composableBuilder(
    column: $table.low,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AdjustedPriceTableOrderingComposer
    extends Composer<_$AppDatabase, $AdjustedPriceTable> {
  $$AdjustedPriceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get open => $composableBuilder(
    column: $table.open,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get high => $composableBuilder(
    column: $table.high,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get low => $composableBuilder(
    column: $table.low,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AdjustedPriceTableAnnotationComposer
    extends Composer<_$AppDatabase, $AdjustedPriceTable> {
  $$AdjustedPriceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get open =>
      $composableBuilder(column: $table.open, builder: (column) => column);

  GeneratedColumn<double> get high =>
      $composableBuilder(column: $table.high, builder: (column) => column);

  GeneratedColumn<double> get low =>
      $composableBuilder(column: $table.low, builder: (column) => column);

  GeneratedColumn<double> get close =>
      $composableBuilder(column: $table.close, builder: (column) => column);

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AdjustedPriceTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AdjustedPriceTable,
          AdjustedPriceEntry,
          $$AdjustedPriceTableFilterComposer,
          $$AdjustedPriceTableOrderingComposer,
          $$AdjustedPriceTableAnnotationComposer,
          $$AdjustedPriceTableCreateCompanionBuilder,
          $$AdjustedPriceTableUpdateCompanionBuilder,
          (AdjustedPriceEntry, $$AdjustedPriceTableReferences),
          AdjustedPriceEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$AdjustedPriceTableTableManager(_$AppDatabase db, $AdjustedPriceTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AdjustedPriceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AdjustedPriceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AdjustedPriceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> open = const Value.absent(),
                Value<double?> high = const Value.absent(),
                Value<double?> low = const Value.absent(),
                Value<double?> close = const Value.absent(),
                Value<double?> volume = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdjustedPriceCompanion(
                symbol: symbol,
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> open = const Value.absent(),
                Value<double?> high = const Value.absent(),
                Value<double?> low = const Value.absent(),
                Value<double?> close = const Value.absent(),
                Value<double?> volume = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdjustedPriceCompanion.insert(
                symbol: symbol,
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AdjustedPriceTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$AdjustedPriceTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$AdjustedPriceTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AdjustedPriceTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AdjustedPriceTable,
      AdjustedPriceEntry,
      $$AdjustedPriceTableFilterComposer,
      $$AdjustedPriceTableOrderingComposer,
      $$AdjustedPriceTableAnnotationComposer,
      $$AdjustedPriceTableCreateCompanionBuilder,
      $$AdjustedPriceTableUpdateCompanionBuilder,
      (AdjustedPriceEntry, $$AdjustedPriceTableReferences),
      AdjustedPriceEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$WeeklyPriceTableCreateCompanionBuilder =
    WeeklyPriceCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> open,
      Value<double?> high,
      Value<double?> low,
      Value<double?> close,
      Value<double?> volume,
      Value<int> rowid,
    });
typedef $$WeeklyPriceTableUpdateCompanionBuilder =
    WeeklyPriceCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> open,
      Value<double?> high,
      Value<double?> low,
      Value<double?> close,
      Value<double?> volume,
      Value<int> rowid,
    });

final class $$WeeklyPriceTableReferences
    extends BaseReferences<_$AppDatabase, $WeeklyPriceTable, WeeklyPriceEntry> {
  $$WeeklyPriceTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.weeklyPrice.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WeeklyPriceTableFilterComposer
    extends Composer<_$AppDatabase, $WeeklyPriceTable> {
  $$WeeklyPriceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get open => $composableBuilder(
    column: $table.open,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get high => $composableBuilder(
    column: $table.high,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get low => $composableBuilder(
    column: $table.low,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeeklyPriceTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeklyPriceTable> {
  $$WeeklyPriceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get open => $composableBuilder(
    column: $table.open,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get high => $composableBuilder(
    column: $table.high,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get low => $composableBuilder(
    column: $table.low,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeeklyPriceTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeklyPriceTable> {
  $$WeeklyPriceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get open =>
      $composableBuilder(column: $table.open, builder: (column) => column);

  GeneratedColumn<double> get high =>
      $composableBuilder(column: $table.high, builder: (column) => column);

  GeneratedColumn<double> get low =>
      $composableBuilder(column: $table.low, builder: (column) => column);

  GeneratedColumn<double> get close =>
      $composableBuilder(column: $table.close, builder: (column) => column);

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeeklyPriceTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeeklyPriceTable,
          WeeklyPriceEntry,
          $$WeeklyPriceTableFilterComposer,
          $$WeeklyPriceTableOrderingComposer,
          $$WeeklyPriceTableAnnotationComposer,
          $$WeeklyPriceTableCreateCompanionBuilder,
          $$WeeklyPriceTableUpdateCompanionBuilder,
          (WeeklyPriceEntry, $$WeeklyPriceTableReferences),
          WeeklyPriceEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$WeeklyPriceTableTableManager(_$AppDatabase db, $WeeklyPriceTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyPriceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyPriceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyPriceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> open = const Value.absent(),
                Value<double?> high = const Value.absent(),
                Value<double?> low = const Value.absent(),
                Value<double?> close = const Value.absent(),
                Value<double?> volume = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyPriceCompanion(
                symbol: symbol,
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> open = const Value.absent(),
                Value<double?> high = const Value.absent(),
                Value<double?> low = const Value.absent(),
                Value<double?> close = const Value.absent(),
                Value<double?> volume = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyPriceCompanion.insert(
                symbol: symbol,
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WeeklyPriceTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$WeeklyPriceTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$WeeklyPriceTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WeeklyPriceTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeeklyPriceTable,
      WeeklyPriceEntry,
      $$WeeklyPriceTableFilterComposer,
      $$WeeklyPriceTableOrderingComposer,
      $$WeeklyPriceTableAnnotationComposer,
      $$WeeklyPriceTableCreateCompanionBuilder,
      $$WeeklyPriceTableUpdateCompanionBuilder,
      (WeeklyPriceEntry, $$WeeklyPriceTableReferences),
      WeeklyPriceEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$HoldingDistributionTableCreateCompanionBuilder =
    HoldingDistributionCompanion Function({
      required String symbol,
      required DateTime date,
      required String level,
      Value<int?> shareholders,
      Value<double?> percent,
      Value<double?> shares,
      Value<int> rowid,
    });
typedef $$HoldingDistributionTableUpdateCompanionBuilder =
    HoldingDistributionCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<String> level,
      Value<int?> shareholders,
      Value<double?> percent,
      Value<double?> shares,
      Value<int> rowid,
    });

final class $$HoldingDistributionTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $HoldingDistributionTable,
          HoldingDistributionEntry
        > {
  $$HoldingDistributionTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(
          db.holdingDistribution.symbol,
          db.stockMaster.symbol,
        ),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HoldingDistributionTableFilterComposer
    extends Composer<_$AppDatabase, $HoldingDistributionTable> {
  $$HoldingDistributionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shareholders => $composableBuilder(
    column: $table.shareholders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shares => $composableBuilder(
    column: $table.shares,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoldingDistributionTableOrderingComposer
    extends Composer<_$AppDatabase, $HoldingDistributionTable> {
  $$HoldingDistributionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shareholders => $composableBuilder(
    column: $table.shareholders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shares => $composableBuilder(
    column: $table.shares,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoldingDistributionTableAnnotationComposer
    extends Composer<_$AppDatabase, $HoldingDistributionTable> {
  $$HoldingDistributionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get shareholders => $composableBuilder(
    column: $table.shareholders,
    builder: (column) => column,
  );

  GeneratedColumn<double> get percent =>
      $composableBuilder(column: $table.percent, builder: (column) => column);

  GeneratedColumn<double> get shares =>
      $composableBuilder(column: $table.shares, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoldingDistributionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HoldingDistributionTable,
          HoldingDistributionEntry,
          $$HoldingDistributionTableFilterComposer,
          $$HoldingDistributionTableOrderingComposer,
          $$HoldingDistributionTableAnnotationComposer,
          $$HoldingDistributionTableCreateCompanionBuilder,
          $$HoldingDistributionTableUpdateCompanionBuilder,
          (HoldingDistributionEntry, $$HoldingDistributionTableReferences),
          HoldingDistributionEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$HoldingDistributionTableTableManager(
    _$AppDatabase db,
    $HoldingDistributionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingDistributionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingDistributionTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HoldingDistributionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<int?> shareholders = const Value.absent(),
                Value<double?> percent = const Value.absent(),
                Value<double?> shares = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingDistributionCompanion(
                symbol: symbol,
                date: date,
                level: level,
                shareholders: shareholders,
                percent: percent,
                shares: shares,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                required String level,
                Value<int?> shareholders = const Value.absent(),
                Value<double?> percent = const Value.absent(),
                Value<double?> shares = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingDistributionCompanion.insert(
                symbol: symbol,
                date: date,
                level: level,
                shareholders: shareholders,
                percent: percent,
                shares: shares,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HoldingDistributionTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable:
                                    $$HoldingDistributionTableReferences
                                        ._symbolTable(db),
                                referencedColumn:
                                    $$HoldingDistributionTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HoldingDistributionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HoldingDistributionTable,
      HoldingDistributionEntry,
      $$HoldingDistributionTableFilterComposer,
      $$HoldingDistributionTableOrderingComposer,
      $$HoldingDistributionTableAnnotationComposer,
      $$HoldingDistributionTableCreateCompanionBuilder,
      $$HoldingDistributionTableUpdateCompanionBuilder,
      (HoldingDistributionEntry, $$HoldingDistributionTableReferences),
      HoldingDistributionEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$MonthlyRevenueTableCreateCompanionBuilder =
    MonthlyRevenueCompanion Function({
      required String symbol,
      required DateTime date,
      required int revenueYear,
      required int revenueMonth,
      required double revenue,
      Value<double?> momGrowth,
      Value<double?> yoyGrowth,
      Value<int> rowid,
    });
typedef $$MonthlyRevenueTableUpdateCompanionBuilder =
    MonthlyRevenueCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<int> revenueYear,
      Value<int> revenueMonth,
      Value<double> revenue,
      Value<double?> momGrowth,
      Value<double?> yoyGrowth,
      Value<int> rowid,
    });

final class $$MonthlyRevenueTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MonthlyRevenueTable,
          MonthlyRevenueEntry
        > {
  $$MonthlyRevenueTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.monthlyRevenue.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MonthlyRevenueTableFilterComposer
    extends Composer<_$AppDatabase, $MonthlyRevenueTable> {
  $$MonthlyRevenueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revenueYear => $composableBuilder(
    column: $table.revenueYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revenueMonth => $composableBuilder(
    column: $table.revenueMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get revenue => $composableBuilder(
    column: $table.revenue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get momGrowth => $composableBuilder(
    column: $table.momGrowth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get yoyGrowth => $composableBuilder(
    column: $table.yoyGrowth,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyRevenueTableOrderingComposer
    extends Composer<_$AppDatabase, $MonthlyRevenueTable> {
  $$MonthlyRevenueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revenueYear => $composableBuilder(
    column: $table.revenueYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revenueMonth => $composableBuilder(
    column: $table.revenueMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get revenue => $composableBuilder(
    column: $table.revenue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get momGrowth => $composableBuilder(
    column: $table.momGrowth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get yoyGrowth => $composableBuilder(
    column: $table.yoyGrowth,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyRevenueTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonthlyRevenueTable> {
  $$MonthlyRevenueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get revenueYear => $composableBuilder(
    column: $table.revenueYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revenueMonth => $composableBuilder(
    column: $table.revenueMonth,
    builder: (column) => column,
  );

  GeneratedColumn<double> get revenue =>
      $composableBuilder(column: $table.revenue, builder: (column) => column);

  GeneratedColumn<double> get momGrowth =>
      $composableBuilder(column: $table.momGrowth, builder: (column) => column);

  GeneratedColumn<double> get yoyGrowth =>
      $composableBuilder(column: $table.yoyGrowth, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyRevenueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonthlyRevenueTable,
          MonthlyRevenueEntry,
          $$MonthlyRevenueTableFilterComposer,
          $$MonthlyRevenueTableOrderingComposer,
          $$MonthlyRevenueTableAnnotationComposer,
          $$MonthlyRevenueTableCreateCompanionBuilder,
          $$MonthlyRevenueTableUpdateCompanionBuilder,
          (MonthlyRevenueEntry, $$MonthlyRevenueTableReferences),
          MonthlyRevenueEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$MonthlyRevenueTableTableManager(
    _$AppDatabase db,
    $MonthlyRevenueTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthlyRevenueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonthlyRevenueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonthlyRevenueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> revenueYear = const Value.absent(),
                Value<int> revenueMonth = const Value.absent(),
                Value<double> revenue = const Value.absent(),
                Value<double?> momGrowth = const Value.absent(),
                Value<double?> yoyGrowth = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthlyRevenueCompanion(
                symbol: symbol,
                date: date,
                revenueYear: revenueYear,
                revenueMonth: revenueMonth,
                revenue: revenue,
                momGrowth: momGrowth,
                yoyGrowth: yoyGrowth,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                required int revenueYear,
                required int revenueMonth,
                required double revenue,
                Value<double?> momGrowth = const Value.absent(),
                Value<double?> yoyGrowth = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthlyRevenueCompanion.insert(
                symbol: symbol,
                date: date,
                revenueYear: revenueYear,
                revenueMonth: revenueMonth,
                revenue: revenue,
                momGrowth: momGrowth,
                yoyGrowth: yoyGrowth,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MonthlyRevenueTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$MonthlyRevenueTableReferences
                                    ._symbolTable(db),
                                referencedColumn:
                                    $$MonthlyRevenueTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MonthlyRevenueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonthlyRevenueTable,
      MonthlyRevenueEntry,
      $$MonthlyRevenueTableFilterComposer,
      $$MonthlyRevenueTableOrderingComposer,
      $$MonthlyRevenueTableAnnotationComposer,
      $$MonthlyRevenueTableCreateCompanionBuilder,
      $$MonthlyRevenueTableUpdateCompanionBuilder,
      (MonthlyRevenueEntry, $$MonthlyRevenueTableReferences),
      MonthlyRevenueEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$StockValuationTableCreateCompanionBuilder =
    StockValuationCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> per,
      Value<double?> pbr,
      Value<double?> dividendYield,
      Value<int> rowid,
    });
typedef $$StockValuationTableUpdateCompanionBuilder =
    StockValuationCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> per,
      Value<double?> pbr,
      Value<double?> dividendYield,
      Value<int> rowid,
    });

final class $$StockValuationTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $StockValuationTable,
          StockValuationEntry
        > {
  $$StockValuationTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.stockValuation.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StockValuationTableFilterComposer
    extends Composer<_$AppDatabase, $StockValuationTable> {
  $$StockValuationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get per => $composableBuilder(
    column: $table.per,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pbr => $composableBuilder(
    column: $table.pbr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dividendYield => $composableBuilder(
    column: $table.dividendYield,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockValuationTableOrderingComposer
    extends Composer<_$AppDatabase, $StockValuationTable> {
  $$StockValuationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get per => $composableBuilder(
    column: $table.per,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pbr => $composableBuilder(
    column: $table.pbr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dividendYield => $composableBuilder(
    column: $table.dividendYield,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockValuationTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockValuationTable> {
  $$StockValuationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get per =>
      $composableBuilder(column: $table.per, builder: (column) => column);

  GeneratedColumn<double> get pbr =>
      $composableBuilder(column: $table.pbr, builder: (column) => column);

  GeneratedColumn<double> get dividendYield => $composableBuilder(
    column: $table.dividendYield,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockValuationTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockValuationTable,
          StockValuationEntry,
          $$StockValuationTableFilterComposer,
          $$StockValuationTableOrderingComposer,
          $$StockValuationTableAnnotationComposer,
          $$StockValuationTableCreateCompanionBuilder,
          $$StockValuationTableUpdateCompanionBuilder,
          (StockValuationEntry, $$StockValuationTableReferences),
          StockValuationEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$StockValuationTableTableManager(
    _$AppDatabase db,
    $StockValuationTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockValuationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockValuationTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockValuationTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> per = const Value.absent(),
                Value<double?> pbr = const Value.absent(),
                Value<double?> dividendYield = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockValuationCompanion(
                symbol: symbol,
                date: date,
                per: per,
                pbr: pbr,
                dividendYield: dividendYield,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> per = const Value.absent(),
                Value<double?> pbr = const Value.absent(),
                Value<double?> dividendYield = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockValuationCompanion.insert(
                symbol: symbol,
                date: date,
                per: per,
                pbr: pbr,
                dividendYield: dividendYield,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StockValuationTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$StockValuationTableReferences
                                    ._symbolTable(db),
                                referencedColumn:
                                    $$StockValuationTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StockValuationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockValuationTable,
      StockValuationEntry,
      $$StockValuationTableFilterComposer,
      $$StockValuationTableOrderingComposer,
      $$StockValuationTableAnnotationComposer,
      $$StockValuationTableCreateCompanionBuilder,
      $$StockValuationTableUpdateCompanionBuilder,
      (StockValuationEntry, $$StockValuationTableReferences),
      StockValuationEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$DividendHistoryTableCreateCompanionBuilder =
    DividendHistoryCompanion Function({
      required String symbol,
      required int year,
      Value<double> cashDividend,
      Value<double> stockDividend,
      Value<String?> exDividendDate,
      Value<String?> exRightsDate,
      Value<int> rowid,
    });
typedef $$DividendHistoryTableUpdateCompanionBuilder =
    DividendHistoryCompanion Function({
      Value<String> symbol,
      Value<int> year,
      Value<double> cashDividend,
      Value<double> stockDividend,
      Value<String?> exDividendDate,
      Value<String?> exRightsDate,
      Value<int> rowid,
    });

final class $$DividendHistoryTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DividendHistoryTable,
          DividendHistoryEntry
        > {
  $$DividendHistoryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.dividendHistory.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DividendHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $DividendHistoryTable> {
  $$DividendHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cashDividend => $composableBuilder(
    column: $table.cashDividend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stockDividend => $composableBuilder(
    column: $table.stockDividend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exDividendDate => $composableBuilder(
    column: $table.exDividendDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exRightsDate => $composableBuilder(
    column: $table.exRightsDate,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DividendHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $DividendHistoryTable> {
  $$DividendHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cashDividend => $composableBuilder(
    column: $table.cashDividend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stockDividend => $composableBuilder(
    column: $table.stockDividend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exDividendDate => $composableBuilder(
    column: $table.exDividendDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exRightsDate => $composableBuilder(
    column: $table.exRightsDate,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DividendHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $DividendHistoryTable> {
  $$DividendHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<double> get cashDividend => $composableBuilder(
    column: $table.cashDividend,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stockDividend => $composableBuilder(
    column: $table.stockDividend,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exDividendDate => $composableBuilder(
    column: $table.exDividendDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exRightsDate => $composableBuilder(
    column: $table.exRightsDate,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DividendHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DividendHistoryTable,
          DividendHistoryEntry,
          $$DividendHistoryTableFilterComposer,
          $$DividendHistoryTableOrderingComposer,
          $$DividendHistoryTableAnnotationComposer,
          $$DividendHistoryTableCreateCompanionBuilder,
          $$DividendHistoryTableUpdateCompanionBuilder,
          (DividendHistoryEntry, $$DividendHistoryTableReferences),
          DividendHistoryEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$DividendHistoryTableTableManager(
    _$AppDatabase db,
    $DividendHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DividendHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DividendHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DividendHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<double> cashDividend = const Value.absent(),
                Value<double> stockDividend = const Value.absent(),
                Value<String?> exDividendDate = const Value.absent(),
                Value<String?> exRightsDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DividendHistoryCompanion(
                symbol: symbol,
                year: year,
                cashDividend: cashDividend,
                stockDividend: stockDividend,
                exDividendDate: exDividendDate,
                exRightsDate: exRightsDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required int year,
                Value<double> cashDividend = const Value.absent(),
                Value<double> stockDividend = const Value.absent(),
                Value<String?> exDividendDate = const Value.absent(),
                Value<String?> exRightsDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DividendHistoryCompanion.insert(
                symbol: symbol,
                year: year,
                cashDividend: cashDividend,
                stockDividend: stockDividend,
                exDividendDate: exDividendDate,
                exRightsDate: exRightsDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DividendHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable:
                                    $$DividendHistoryTableReferences
                                        ._symbolTable(db),
                                referencedColumn:
                                    $$DividendHistoryTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DividendHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DividendHistoryTable,
      DividendHistoryEntry,
      $$DividendHistoryTableFilterComposer,
      $$DividendHistoryTableOrderingComposer,
      $$DividendHistoryTableAnnotationComposer,
      $$DividendHistoryTableCreateCompanionBuilder,
      $$DividendHistoryTableUpdateCompanionBuilder,
      (DividendHistoryEntry, $$DividendHistoryTableReferences),
      DividendHistoryEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$MarginTradingTableCreateCompanionBuilder =
    MarginTradingCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> marginBuy,
      Value<double?> marginSell,
      Value<double?> marginBalance,
      Value<double?> shortBuy,
      Value<double?> shortSell,
      Value<double?> shortBalance,
      Value<int> rowid,
    });
typedef $$MarginTradingTableUpdateCompanionBuilder =
    MarginTradingCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> marginBuy,
      Value<double?> marginSell,
      Value<double?> marginBalance,
      Value<double?> shortBuy,
      Value<double?> shortSell,
      Value<double?> shortBalance,
      Value<int> rowid,
    });

final class $$MarginTradingTableReferences
    extends
        BaseReferences<_$AppDatabase, $MarginTradingTable, MarginTradingEntry> {
  $$MarginTradingTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.marginTrading.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MarginTradingTableFilterComposer
    extends Composer<_$AppDatabase, $MarginTradingTable> {
  $$MarginTradingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get marginBuy => $composableBuilder(
    column: $table.marginBuy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get marginSell => $composableBuilder(
    column: $table.marginSell,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get marginBalance => $composableBuilder(
    column: $table.marginBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shortBuy => $composableBuilder(
    column: $table.shortBuy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shortSell => $composableBuilder(
    column: $table.shortSell,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shortBalance => $composableBuilder(
    column: $table.shortBalance,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarginTradingTableOrderingComposer
    extends Composer<_$AppDatabase, $MarginTradingTable> {
  $$MarginTradingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get marginBuy => $composableBuilder(
    column: $table.marginBuy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get marginSell => $composableBuilder(
    column: $table.marginSell,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get marginBalance => $composableBuilder(
    column: $table.marginBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shortBuy => $composableBuilder(
    column: $table.shortBuy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shortSell => $composableBuilder(
    column: $table.shortSell,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shortBalance => $composableBuilder(
    column: $table.shortBalance,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarginTradingTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarginTradingTable> {
  $$MarginTradingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get marginBuy =>
      $composableBuilder(column: $table.marginBuy, builder: (column) => column);

  GeneratedColumn<double> get marginSell => $composableBuilder(
    column: $table.marginSell,
    builder: (column) => column,
  );

  GeneratedColumn<double> get marginBalance => $composableBuilder(
    column: $table.marginBalance,
    builder: (column) => column,
  );

  GeneratedColumn<double> get shortBuy =>
      $composableBuilder(column: $table.shortBuy, builder: (column) => column);

  GeneratedColumn<double> get shortSell =>
      $composableBuilder(column: $table.shortSell, builder: (column) => column);

  GeneratedColumn<double> get shortBalance => $composableBuilder(
    column: $table.shortBalance,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarginTradingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarginTradingTable,
          MarginTradingEntry,
          $$MarginTradingTableFilterComposer,
          $$MarginTradingTableOrderingComposer,
          $$MarginTradingTableAnnotationComposer,
          $$MarginTradingTableCreateCompanionBuilder,
          $$MarginTradingTableUpdateCompanionBuilder,
          (MarginTradingEntry, $$MarginTradingTableReferences),
          MarginTradingEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$MarginTradingTableTableManager(_$AppDatabase db, $MarginTradingTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarginTradingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarginTradingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarginTradingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> marginBuy = const Value.absent(),
                Value<double?> marginSell = const Value.absent(),
                Value<double?> marginBalance = const Value.absent(),
                Value<double?> shortBuy = const Value.absent(),
                Value<double?> shortSell = const Value.absent(),
                Value<double?> shortBalance = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarginTradingCompanion(
                symbol: symbol,
                date: date,
                marginBuy: marginBuy,
                marginSell: marginSell,
                marginBalance: marginBalance,
                shortBuy: shortBuy,
                shortSell: shortSell,
                shortBalance: shortBalance,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> marginBuy = const Value.absent(),
                Value<double?> marginSell = const Value.absent(),
                Value<double?> marginBalance = const Value.absent(),
                Value<double?> shortBuy = const Value.absent(),
                Value<double?> shortSell = const Value.absent(),
                Value<double?> shortBalance = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarginTradingCompanion.insert(
                symbol: symbol,
                date: date,
                marginBuy: marginBuy,
                marginSell: marginSell,
                marginBalance: marginBalance,
                shortBuy: shortBuy,
                shortSell: shortSell,
                shortBalance: shortBalance,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MarginTradingTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$MarginTradingTableReferences
                                    ._symbolTable(db),
                                referencedColumn: $$MarginTradingTableReferences
                                    ._symbolTable(db)
                                    .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MarginTradingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarginTradingTable,
      MarginTradingEntry,
      $$MarginTradingTableFilterComposer,
      $$MarginTradingTableOrderingComposer,
      $$MarginTradingTableAnnotationComposer,
      $$MarginTradingTableCreateCompanionBuilder,
      $$MarginTradingTableUpdateCompanionBuilder,
      (MarginTradingEntry, $$MarginTradingTableReferences),
      MarginTradingEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$TradingWarningTableCreateCompanionBuilder =
    TradingWarningCompanion Function({
      required String symbol,
      required DateTime date,
      required String warningType,
      Value<String?> reasonCode,
      Value<String?> reasonDescription,
      Value<String?> disposalMeasures,
      Value<DateTime?> disposalStartDate,
      Value<DateTime?> disposalEndDate,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$TradingWarningTableUpdateCompanionBuilder =
    TradingWarningCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<String> warningType,
      Value<String?> reasonCode,
      Value<String?> reasonDescription,
      Value<String?> disposalMeasures,
      Value<DateTime?> disposalStartDate,
      Value<DateTime?> disposalEndDate,
      Value<bool> isActive,
      Value<int> rowid,
    });

final class $$TradingWarningTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TradingWarningTable,
          TradingWarningEntry
        > {
  $$TradingWarningTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.tradingWarning.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TradingWarningTableFilterComposer
    extends Composer<_$AppDatabase, $TradingWarningTable> {
  $$TradingWarningTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get warningType => $composableBuilder(
    column: $table.warningType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonDescription => $composableBuilder(
    column: $table.reasonDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get disposalMeasures => $composableBuilder(
    column: $table.disposalMeasures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get disposalStartDate => $composableBuilder(
    column: $table.disposalStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get disposalEndDate => $composableBuilder(
    column: $table.disposalEndDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TradingWarningTableOrderingComposer
    extends Composer<_$AppDatabase, $TradingWarningTable> {
  $$TradingWarningTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get warningType => $composableBuilder(
    column: $table.warningType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonDescription => $composableBuilder(
    column: $table.reasonDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get disposalMeasures => $composableBuilder(
    column: $table.disposalMeasures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get disposalStartDate => $composableBuilder(
    column: $table.disposalStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get disposalEndDate => $composableBuilder(
    column: $table.disposalEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TradingWarningTableAnnotationComposer
    extends Composer<_$AppDatabase, $TradingWarningTable> {
  $$TradingWarningTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get warningType => $composableBuilder(
    column: $table.warningType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reasonDescription => $composableBuilder(
    column: $table.reasonDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get disposalMeasures => $composableBuilder(
    column: $table.disposalMeasures,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get disposalStartDate => $composableBuilder(
    column: $table.disposalStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get disposalEndDate => $composableBuilder(
    column: $table.disposalEndDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TradingWarningTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TradingWarningTable,
          TradingWarningEntry,
          $$TradingWarningTableFilterComposer,
          $$TradingWarningTableOrderingComposer,
          $$TradingWarningTableAnnotationComposer,
          $$TradingWarningTableCreateCompanionBuilder,
          $$TradingWarningTableUpdateCompanionBuilder,
          (TradingWarningEntry, $$TradingWarningTableReferences),
          TradingWarningEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$TradingWarningTableTableManager(
    _$AppDatabase db,
    $TradingWarningTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TradingWarningTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TradingWarningTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TradingWarningTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> warningType = const Value.absent(),
                Value<String?> reasonCode = const Value.absent(),
                Value<String?> reasonDescription = const Value.absent(),
                Value<String?> disposalMeasures = const Value.absent(),
                Value<DateTime?> disposalStartDate = const Value.absent(),
                Value<DateTime?> disposalEndDate = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradingWarningCompanion(
                symbol: symbol,
                date: date,
                warningType: warningType,
                reasonCode: reasonCode,
                reasonDescription: reasonDescription,
                disposalMeasures: disposalMeasures,
                disposalStartDate: disposalStartDate,
                disposalEndDate: disposalEndDate,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                required String warningType,
                Value<String?> reasonCode = const Value.absent(),
                Value<String?> reasonDescription = const Value.absent(),
                Value<String?> disposalMeasures = const Value.absent(),
                Value<DateTime?> disposalStartDate = const Value.absent(),
                Value<DateTime?> disposalEndDate = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradingWarningCompanion.insert(
                symbol: symbol,
                date: date,
                warningType: warningType,
                reasonCode: reasonCode,
                reasonDescription: reasonDescription,
                disposalMeasures: disposalMeasures,
                disposalStartDate: disposalStartDate,
                disposalEndDate: disposalEndDate,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TradingWarningTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$TradingWarningTableReferences
                                    ._symbolTable(db),
                                referencedColumn:
                                    $$TradingWarningTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TradingWarningTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TradingWarningTable,
      TradingWarningEntry,
      $$TradingWarningTableFilterComposer,
      $$TradingWarningTableOrderingComposer,
      $$TradingWarningTableAnnotationComposer,
      $$TradingWarningTableCreateCompanionBuilder,
      $$TradingWarningTableUpdateCompanionBuilder,
      (TradingWarningEntry, $$TradingWarningTableReferences),
      TradingWarningEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$InsiderHoldingTableCreateCompanionBuilder =
    InsiderHoldingCompanion Function({
      required String symbol,
      required DateTime date,
      Value<double?> directorShares,
      Value<double?> supervisorShares,
      Value<double?> managerShares,
      Value<double?> insiderRatio,
      Value<double?> pledgeRatio,
      Value<double?> sharesChange,
      Value<double?> sharesIssued,
      Value<int> rowid,
    });
typedef $$InsiderHoldingTableUpdateCompanionBuilder =
    InsiderHoldingCompanion Function({
      Value<String> symbol,
      Value<DateTime> date,
      Value<double?> directorShares,
      Value<double?> supervisorShares,
      Value<double?> managerShares,
      Value<double?> insiderRatio,
      Value<double?> pledgeRatio,
      Value<double?> sharesChange,
      Value<double?> sharesIssued,
      Value<int> rowid,
    });

final class $$InsiderHoldingTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $InsiderHoldingTable,
          InsiderHoldingEntry
        > {
  $$InsiderHoldingTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(db.insiderHolding.symbol, db.stockMaster.symbol),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InsiderHoldingTableFilterComposer
    extends Composer<_$AppDatabase, $InsiderHoldingTable> {
  $$InsiderHoldingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get directorShares => $composableBuilder(
    column: $table.directorShares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get supervisorShares => $composableBuilder(
    column: $table.supervisorShares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get managerShares => $composableBuilder(
    column: $table.managerShares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get insiderRatio => $composableBuilder(
    column: $table.insiderRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pledgeRatio => $composableBuilder(
    column: $table.pledgeRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sharesChange => $composableBuilder(
    column: $table.sharesChange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sharesIssued => $composableBuilder(
    column: $table.sharesIssued,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsiderHoldingTableOrderingComposer
    extends Composer<_$AppDatabase, $InsiderHoldingTable> {
  $$InsiderHoldingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get directorShares => $composableBuilder(
    column: $table.directorShares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get supervisorShares => $composableBuilder(
    column: $table.supervisorShares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get managerShares => $composableBuilder(
    column: $table.managerShares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get insiderRatio => $composableBuilder(
    column: $table.insiderRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pledgeRatio => $composableBuilder(
    column: $table.pledgeRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sharesChange => $composableBuilder(
    column: $table.sharesChange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sharesIssued => $composableBuilder(
    column: $table.sharesIssued,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsiderHoldingTableAnnotationComposer
    extends Composer<_$AppDatabase, $InsiderHoldingTable> {
  $$InsiderHoldingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get directorShares => $composableBuilder(
    column: $table.directorShares,
    builder: (column) => column,
  );

  GeneratedColumn<double> get supervisorShares => $composableBuilder(
    column: $table.supervisorShares,
    builder: (column) => column,
  );

  GeneratedColumn<double> get managerShares => $composableBuilder(
    column: $table.managerShares,
    builder: (column) => column,
  );

  GeneratedColumn<double> get insiderRatio => $composableBuilder(
    column: $table.insiderRatio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pledgeRatio => $composableBuilder(
    column: $table.pledgeRatio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sharesChange => $composableBuilder(
    column: $table.sharesChange,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sharesIssued => $composableBuilder(
    column: $table.sharesIssued,
    builder: (column) => column,
  );

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsiderHoldingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InsiderHoldingTable,
          InsiderHoldingEntry,
          $$InsiderHoldingTableFilterComposer,
          $$InsiderHoldingTableOrderingComposer,
          $$InsiderHoldingTableAnnotationComposer,
          $$InsiderHoldingTableCreateCompanionBuilder,
          $$InsiderHoldingTableUpdateCompanionBuilder,
          (InsiderHoldingEntry, $$InsiderHoldingTableReferences),
          InsiderHoldingEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$InsiderHoldingTableTableManager(
    _$AppDatabase db,
    $InsiderHoldingTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InsiderHoldingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InsiderHoldingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InsiderHoldingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> directorShares = const Value.absent(),
                Value<double?> supervisorShares = const Value.absent(),
                Value<double?> managerShares = const Value.absent(),
                Value<double?> insiderRatio = const Value.absent(),
                Value<double?> pledgeRatio = const Value.absent(),
                Value<double?> sharesChange = const Value.absent(),
                Value<double?> sharesIssued = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InsiderHoldingCompanion(
                symbol: symbol,
                date: date,
                directorShares: directorShares,
                supervisorShares: supervisorShares,
                managerShares: managerShares,
                insiderRatio: insiderRatio,
                pledgeRatio: pledgeRatio,
                sharesChange: sharesChange,
                sharesIssued: sharesIssued,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required DateTime date,
                Value<double?> directorShares = const Value.absent(),
                Value<double?> supervisorShares = const Value.absent(),
                Value<double?> managerShares = const Value.absent(),
                Value<double?> insiderRatio = const Value.absent(),
                Value<double?> pledgeRatio = const Value.absent(),
                Value<double?> sharesChange = const Value.absent(),
                Value<double?> sharesIssued = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InsiderHoldingCompanion.insert(
                symbol: symbol,
                date: date,
                directorShares: directorShares,
                supervisorShares: supervisorShares,
                managerShares: managerShares,
                insiderRatio: insiderRatio,
                pledgeRatio: pledgeRatio,
                sharesChange: sharesChange,
                sharesIssued: sharesIssued,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$InsiderHoldingTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable: $$InsiderHoldingTableReferences
                                    ._symbolTable(db),
                                referencedColumn:
                                    $$InsiderHoldingTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InsiderHoldingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InsiderHoldingTable,
      InsiderHoldingEntry,
      $$InsiderHoldingTableFilterComposer,
      $$InsiderHoldingTableOrderingComposer,
      $$InsiderHoldingTableAnnotationComposer,
      $$InsiderHoldingTableCreateCompanionBuilder,
      $$InsiderHoldingTableUpdateCompanionBuilder,
      (InsiderHoldingEntry, $$InsiderHoldingTableReferences),
      InsiderHoldingEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$ScreeningStrategyTableTableCreateCompanionBuilder =
    ScreeningStrategyTableCompanion Function({
      Value<int> id,
      required String name,
      required String conditionsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ScreeningStrategyTableTableUpdateCompanionBuilder =
    ScreeningStrategyTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> conditionsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$ScreeningStrategyTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScreeningStrategyTableTable> {
  $$ScreeningStrategyTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScreeningStrategyTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScreeningStrategyTableTable> {
  $$ScreeningStrategyTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScreeningStrategyTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScreeningStrategyTableTable> {
  $$ScreeningStrategyTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ScreeningStrategyTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScreeningStrategyTableTable,
          ScreeningStrategyEntry,
          $$ScreeningStrategyTableTableFilterComposer,
          $$ScreeningStrategyTableTableOrderingComposer,
          $$ScreeningStrategyTableTableAnnotationComposer,
          $$ScreeningStrategyTableTableCreateCompanionBuilder,
          $$ScreeningStrategyTableTableUpdateCompanionBuilder,
          (
            ScreeningStrategyEntry,
            BaseReferences<
              _$AppDatabase,
              $ScreeningStrategyTableTable,
              ScreeningStrategyEntry
            >,
          ),
          ScreeningStrategyEntry,
          PrefetchHooks Function()
        > {
  $$ScreeningStrategyTableTableTableManager(
    _$AppDatabase db,
    $ScreeningStrategyTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScreeningStrategyTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScreeningStrategyTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScreeningStrategyTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> conditionsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ScreeningStrategyTableCompanion(
                id: id,
                name: name,
                conditionsJson: conditionsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String conditionsJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ScreeningStrategyTableCompanion.insert(
                id: id,
                name: name,
                conditionsJson: conditionsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScreeningStrategyTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScreeningStrategyTableTable,
      ScreeningStrategyEntry,
      $$ScreeningStrategyTableTableFilterComposer,
      $$ScreeningStrategyTableTableOrderingComposer,
      $$ScreeningStrategyTableTableAnnotationComposer,
      $$ScreeningStrategyTableTableCreateCompanionBuilder,
      $$ScreeningStrategyTableTableUpdateCompanionBuilder,
      (
        ScreeningStrategyEntry,
        BaseReferences<
          _$AppDatabase,
          $ScreeningStrategyTableTable,
          ScreeningStrategyEntry
        >,
      ),
      ScreeningStrategyEntry,
      PrefetchHooks Function()
    >;
typedef $$PortfolioPositionTableCreateCompanionBuilder =
    PortfolioPositionCompanion Function({
      Value<int> id,
      required String symbol,
      Value<double> quantity,
      Value<double> avgCost,
      Value<double> realizedPnl,
      Value<double> totalDividendReceived,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$PortfolioPositionTableUpdateCompanionBuilder =
    PortfolioPositionCompanion Function({
      Value<int> id,
      Value<String> symbol,
      Value<double> quantity,
      Value<double> avgCost,
      Value<double> realizedPnl,
      Value<double> totalDividendReceived,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$PortfolioPositionTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PortfolioPositionTable,
          PortfolioPositionEntry
        > {
  $$PortfolioPositionTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(
          db.portfolioPosition.symbol,
          db.stockMaster.symbol,
        ),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PortfolioPositionTableFilterComposer
    extends Composer<_$AppDatabase, $PortfolioPositionTable> {
  $$PortfolioPositionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgCost => $composableBuilder(
    column: $table.avgCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalDividendReceived => $composableBuilder(
    column: $table.totalDividendReceived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortfolioPositionTableOrderingComposer
    extends Composer<_$AppDatabase, $PortfolioPositionTable> {
  $$PortfolioPositionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgCost => $composableBuilder(
    column: $table.avgCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalDividendReceived => $composableBuilder(
    column: $table.totalDividendReceived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortfolioPositionTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortfolioPositionTable> {
  $$PortfolioPositionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get avgCost =>
      $composableBuilder(column: $table.avgCost, builder: (column) => column);

  GeneratedColumn<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalDividendReceived => $composableBuilder(
    column: $table.totalDividendReceived,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortfolioPositionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PortfolioPositionTable,
          PortfolioPositionEntry,
          $$PortfolioPositionTableFilterComposer,
          $$PortfolioPositionTableOrderingComposer,
          $$PortfolioPositionTableAnnotationComposer,
          $$PortfolioPositionTableCreateCompanionBuilder,
          $$PortfolioPositionTableUpdateCompanionBuilder,
          (PortfolioPositionEntry, $$PortfolioPositionTableReferences),
          PortfolioPositionEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$PortfolioPositionTableTableManager(
    _$AppDatabase db,
    $PortfolioPositionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortfolioPositionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortfolioPositionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortfolioPositionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> avgCost = const Value.absent(),
                Value<double> realizedPnl = const Value.absent(),
                Value<double> totalDividendReceived = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PortfolioPositionCompanion(
                id: id,
                symbol: symbol,
                quantity: quantity,
                avgCost: avgCost,
                realizedPnl: realizedPnl,
                totalDividendReceived: totalDividendReceived,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String symbol,
                Value<double> quantity = const Value.absent(),
                Value<double> avgCost = const Value.absent(),
                Value<double> realizedPnl = const Value.absent(),
                Value<double> totalDividendReceived = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PortfolioPositionCompanion.insert(
                id: id,
                symbol: symbol,
                quantity: quantity,
                avgCost: avgCost,
                realizedPnl: realizedPnl,
                totalDividendReceived: totalDividendReceived,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PortfolioPositionTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable:
                                    $$PortfolioPositionTableReferences
                                        ._symbolTable(db),
                                referencedColumn:
                                    $$PortfolioPositionTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PortfolioPositionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PortfolioPositionTable,
      PortfolioPositionEntry,
      $$PortfolioPositionTableFilterComposer,
      $$PortfolioPositionTableOrderingComposer,
      $$PortfolioPositionTableAnnotationComposer,
      $$PortfolioPositionTableCreateCompanionBuilder,
      $$PortfolioPositionTableUpdateCompanionBuilder,
      (PortfolioPositionEntry, $$PortfolioPositionTableReferences),
      PortfolioPositionEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$PortfolioTransactionTableCreateCompanionBuilder =
    PortfolioTransactionCompanion Function({
      Value<int> id,
      required String symbol,
      required String txType,
      required DateTime date,
      required double quantity,
      required double price,
      Value<double> fee,
      Value<double> tax,
      Value<String?> note,
      Value<DateTime> createdAt,
    });
typedef $$PortfolioTransactionTableUpdateCompanionBuilder =
    PortfolioTransactionCompanion Function({
      Value<int> id,
      Value<String> symbol,
      Value<String> txType,
      Value<DateTime> date,
      Value<double> quantity,
      Value<double> price,
      Value<double> fee,
      Value<double> tax,
      Value<String?> note,
      Value<DateTime> createdAt,
    });

final class $$PortfolioTransactionTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PortfolioTransactionTable,
          PortfolioTransactionEntry
        > {
  $$PortfolioTransactionTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockMasterTable _symbolTable(_$AppDatabase db) =>
      db.stockMaster.createAlias(
        $_aliasNameGenerator(
          db.portfolioTransaction.symbol,
          db.stockMaster.symbol,
        ),
      );

  $$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = $$StockMasterTableTableManager(
      $_db,
      $_db.stockMaster,
    ).filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PortfolioTransactionTableFilterComposer
    extends Composer<_$AppDatabase, $PortfolioTransactionTable> {
  $$PortfolioTransactionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get txType => $composableBuilder(
    column: $table.txType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fee => $composableBuilder(
    column: $table.fee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StockMasterTableFilterComposer get symbol {
    final $$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableFilterComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortfolioTransactionTableOrderingComposer
    extends Composer<_$AppDatabase, $PortfolioTransactionTable> {
  $$PortfolioTransactionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get txType => $composableBuilder(
    column: $table.txType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fee => $composableBuilder(
    column: $table.fee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockMasterTableOrderingComposer get symbol {
    final $$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableOrderingComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortfolioTransactionTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortfolioTransactionTable> {
  $$PortfolioTransactionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get txType =>
      $composableBuilder(column: $table.txType, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<double> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => column);

  GeneratedColumn<double> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$StockMasterTableAnnotationComposer get symbol {
    final $$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: $db.stockMaster,
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMaster,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortfolioTransactionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PortfolioTransactionTable,
          PortfolioTransactionEntry,
          $$PortfolioTransactionTableFilterComposer,
          $$PortfolioTransactionTableOrderingComposer,
          $$PortfolioTransactionTableAnnotationComposer,
          $$PortfolioTransactionTableCreateCompanionBuilder,
          $$PortfolioTransactionTableUpdateCompanionBuilder,
          (PortfolioTransactionEntry, $$PortfolioTransactionTableReferences),
          PortfolioTransactionEntry,
          PrefetchHooks Function({bool symbol})
        > {
  $$PortfolioTransactionTableTableManager(
    _$AppDatabase db,
    $PortfolioTransactionTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortfolioTransactionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortfolioTransactionTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PortfolioTransactionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String> txType = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<double> fee = const Value.absent(),
                Value<double> tax = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PortfolioTransactionCompanion(
                id: id,
                symbol: symbol,
                txType: txType,
                date: date,
                quantity: quantity,
                price: price,
                fee: fee,
                tax: tax,
                note: note,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String symbol,
                required String txType,
                required DateTime date,
                required double quantity,
                required double price,
                Value<double> fee = const Value.absent(),
                Value<double> tax = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PortfolioTransactionCompanion.insert(
                id: id,
                symbol: symbol,
                txType: txType,
                date: date,
                quantity: quantity,
                price: price,
                fee: fee,
                tax: tax,
                note: note,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PortfolioTransactionTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (symbol) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.symbol,
                                referencedTable:
                                    $$PortfolioTransactionTableReferences
                                        ._symbolTable(db),
                                referencedColumn:
                                    $$PortfolioTransactionTableReferences
                                        ._symbolTable(db)
                                        .symbol,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PortfolioTransactionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PortfolioTransactionTable,
      PortfolioTransactionEntry,
      $$PortfolioTransactionTableFilterComposer,
      $$PortfolioTransactionTableOrderingComposer,
      $$PortfolioTransactionTableAnnotationComposer,
      $$PortfolioTransactionTableCreateCompanionBuilder,
      $$PortfolioTransactionTableUpdateCompanionBuilder,
      (PortfolioTransactionEntry, $$PortfolioTransactionTableReferences),
      PortfolioTransactionEntry,
      PrefetchHooks Function({bool symbol})
    >;
typedef $$StockEventTableCreateCompanionBuilder =
    StockEventCompanion Function({
      Value<int> id,
      Value<String?> symbol,
      required String eventType,
      required DateTime eventDate,
      required String title,
      Value<String?> description,
      Value<bool> isAutoGenerated,
      Value<DateTime> createdAt,
    });
typedef $$StockEventTableUpdateCompanionBuilder =
    StockEventCompanion Function({
      Value<int> id,
      Value<String?> symbol,
      Value<String> eventType,
      Value<DateTime> eventDate,
      Value<String> title,
      Value<String?> description,
      Value<bool> isAutoGenerated,
      Value<DateTime> createdAt,
    });

class $$StockEventTableFilterComposer
    extends Composer<_$AppDatabase, $StockEventTable> {
  $$StockEventTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAutoGenerated => $composableBuilder(
    column: $table.isAutoGenerated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockEventTableOrderingComposer
    extends Composer<_$AppDatabase, $StockEventTable> {
  $$StockEventTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAutoGenerated => $composableBuilder(
    column: $table.isAutoGenerated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockEventTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockEventTable> {
  $$StockEventTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<DateTime> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAutoGenerated => $composableBuilder(
    column: $table.isAutoGenerated,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StockEventTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockEventTable,
          StockEventEntry,
          $$StockEventTableFilterComposer,
          $$StockEventTableOrderingComposer,
          $$StockEventTableAnnotationComposer,
          $$StockEventTableCreateCompanionBuilder,
          $$StockEventTableUpdateCompanionBuilder,
          (
            StockEventEntry,
            BaseReferences<_$AppDatabase, $StockEventTable, StockEventEntry>,
          ),
          StockEventEntry,
          PrefetchHooks Function()
        > {
  $$StockEventTableTableManager(_$AppDatabase db, $StockEventTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockEventTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockEventTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockEventTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> symbol = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<DateTime> eventDate = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isAutoGenerated = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StockEventCompanion(
                id: id,
                symbol: symbol,
                eventType: eventType,
                eventDate: eventDate,
                title: title,
                description: description,
                isAutoGenerated: isAutoGenerated,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> symbol = const Value.absent(),
                required String eventType,
                required DateTime eventDate,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<bool> isAutoGenerated = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StockEventCompanion.insert(
                id: id,
                symbol: symbol,
                eventType: eventType,
                eventDate: eventDate,
                title: title,
                description: description,
                isAutoGenerated: isAutoGenerated,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockEventTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockEventTable,
      StockEventEntry,
      $$StockEventTableFilterComposer,
      $$StockEventTableOrderingComposer,
      $$StockEventTableAnnotationComposer,
      $$StockEventTableCreateCompanionBuilder,
      $$StockEventTableUpdateCompanionBuilder,
      (
        StockEventEntry,
        BaseReferences<_$AppDatabase, $StockEventTable, StockEventEntry>,
      ),
      StockEventEntry,
      PrefetchHooks Function()
    >;
typedef $$MarketIndexTableCreateCompanionBuilder =
    MarketIndexCompanion Function({
      Value<int> id,
      required DateTime date,
      required String name,
      required double close,
      required double change,
      required double changePercent,
      Value<DateTime> createdAt,
    });
typedef $$MarketIndexTableUpdateCompanionBuilder =
    MarketIndexCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> name,
      Value<double> close,
      Value<double> change,
      Value<double> changePercent,
      Value<DateTime> createdAt,
    });

class $$MarketIndexTableFilterComposer
    extends Composer<_$AppDatabase, $MarketIndexTable> {
  $$MarketIndexTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get change => $composableBuilder(
    column: $table.change,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get changePercent => $composableBuilder(
    column: $table.changePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MarketIndexTableOrderingComposer
    extends Composer<_$AppDatabase, $MarketIndexTable> {
  $$MarketIndexTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get change => $composableBuilder(
    column: $table.change,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get changePercent => $composableBuilder(
    column: $table.changePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MarketIndexTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarketIndexTable> {
  $$MarketIndexTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get close =>
      $composableBuilder(column: $table.close, builder: (column) => column);

  GeneratedColumn<double> get change =>
      $composableBuilder(column: $table.change, builder: (column) => column);

  GeneratedColumn<double> get changePercent => $composableBuilder(
    column: $table.changePercent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MarketIndexTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarketIndexTable,
          MarketIndexEntry,
          $$MarketIndexTableFilterComposer,
          $$MarketIndexTableOrderingComposer,
          $$MarketIndexTableAnnotationComposer,
          $$MarketIndexTableCreateCompanionBuilder,
          $$MarketIndexTableUpdateCompanionBuilder,
          (
            MarketIndexEntry,
            BaseReferences<_$AppDatabase, $MarketIndexTable, MarketIndexEntry>,
          ),
          MarketIndexEntry,
          PrefetchHooks Function()
        > {
  $$MarketIndexTableTableManager(_$AppDatabase db, $MarketIndexTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarketIndexTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarketIndexTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarketIndexTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> close = const Value.absent(),
                Value<double> change = const Value.absent(),
                Value<double> changePercent = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MarketIndexCompanion(
                id: id,
                date: date,
                name: name,
                close: close,
                change: change,
                changePercent: changePercent,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String name,
                required double close,
                required double change,
                required double changePercent,
                Value<DateTime> createdAt = const Value.absent(),
              }) => MarketIndexCompanion.insert(
                id: id,
                date: date,
                name: name,
                close: close,
                change: change,
                changePercent: changePercent,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MarketIndexTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarketIndexTable,
      MarketIndexEntry,
      $$MarketIndexTableFilterComposer,
      $$MarketIndexTableOrderingComposer,
      $$MarketIndexTableAnnotationComposer,
      $$MarketIndexTableCreateCompanionBuilder,
      $$MarketIndexTableUpdateCompanionBuilder,
      (
        MarketIndexEntry,
        BaseReferences<_$AppDatabase, $MarketIndexTable, MarketIndexEntry>,
      ),
      MarketIndexEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StockMasterTableTableManager get stockMaster =>
      $$StockMasterTableTableManager(_db, _db.stockMaster);
  $$DailyPriceTableTableManager get dailyPrice =>
      $$DailyPriceTableTableManager(_db, _db.dailyPrice);
  $$DailyInstitutionalTableTableManager get dailyInstitutional =>
      $$DailyInstitutionalTableTableManager(_db, _db.dailyInstitutional);
  $$NewsItemTableTableManager get newsItem =>
      $$NewsItemTableTableManager(_db, _db.newsItem);
  $$NewsStockMapTableTableManager get newsStockMap =>
      $$NewsStockMapTableTableManager(_db, _db.newsStockMap);
  $$DailyAnalysisTableTableManager get dailyAnalysis =>
      $$DailyAnalysisTableTableManager(_db, _db.dailyAnalysis);
  $$DailyReasonTableTableManager get dailyReason =>
      $$DailyReasonTableTableManager(_db, _db.dailyReason);
  $$DailyRecommendationTableTableManager get dailyRecommendation =>
      $$DailyRecommendationTableTableManager(_db, _db.dailyRecommendation);
  $$RuleAccuracyTableTableManager get ruleAccuracy =>
      $$RuleAccuracyTableTableManager(_db, _db.ruleAccuracy);
  $$RecommendationValidationTableTableManager get recommendationValidation =>
      $$RecommendationValidationTableTableManager(
        _db,
        _db.recommendationValidation,
      );
  $$WatchlistTableTableManager get watchlist =>
      $$WatchlistTableTableManager(_db, _db.watchlist);
  $$UserNoteTableTableManager get userNote =>
      $$UserNoteTableTableManager(_db, _db.userNote);
  $$StrategyCardTableTableManager get strategyCard =>
      $$StrategyCardTableTableManager(_db, _db.strategyCard);
  $$UpdateRunTableTableManager get updateRun =>
      $$UpdateRunTableTableManager(_db, _db.updateRun);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$PriceAlertTableTableManager get priceAlert =>
      $$PriceAlertTableTableManager(_db, _db.priceAlert);
  $$UserInteractionTableTableManager get userInteraction =>
      $$UserInteractionTableTableManager(_db, _db.userInteraction);
  $$UserPreferenceTableTableManager get userPreference =>
      $$UserPreferenceTableTableManager(_db, _db.userPreference);
  $$ShareholdingTableTableManager get shareholding =>
      $$ShareholdingTableTableManager(_db, _db.shareholding);
  $$DayTradingTableTableManager get dayTrading =>
      $$DayTradingTableTableManager(_db, _db.dayTrading);
  $$FinancialDataTableTableManager get financialData =>
      $$FinancialDataTableTableManager(_db, _db.financialData);
  $$AdjustedPriceTableTableManager get adjustedPrice =>
      $$AdjustedPriceTableTableManager(_db, _db.adjustedPrice);
  $$WeeklyPriceTableTableManager get weeklyPrice =>
      $$WeeklyPriceTableTableManager(_db, _db.weeklyPrice);
  $$HoldingDistributionTableTableManager get holdingDistribution =>
      $$HoldingDistributionTableTableManager(_db, _db.holdingDistribution);
  $$MonthlyRevenueTableTableManager get monthlyRevenue =>
      $$MonthlyRevenueTableTableManager(_db, _db.monthlyRevenue);
  $$StockValuationTableTableManager get stockValuation =>
      $$StockValuationTableTableManager(_db, _db.stockValuation);
  $$DividendHistoryTableTableManager get dividendHistory =>
      $$DividendHistoryTableTableManager(_db, _db.dividendHistory);
  $$MarginTradingTableTableManager get marginTrading =>
      $$MarginTradingTableTableManager(_db, _db.marginTrading);
  $$TradingWarningTableTableManager get tradingWarning =>
      $$TradingWarningTableTableManager(_db, _db.tradingWarning);
  $$InsiderHoldingTableTableManager get insiderHolding =>
      $$InsiderHoldingTableTableManager(_db, _db.insiderHolding);
  $$ScreeningStrategyTableTableTableManager get screeningStrategyTable =>
      $$ScreeningStrategyTableTableTableManager(
        _db,
        _db.screeningStrategyTable,
      );
  $$PortfolioPositionTableTableManager get portfolioPosition =>
      $$PortfolioPositionTableTableManager(_db, _db.portfolioPosition);
  $$PortfolioTransactionTableTableManager get portfolioTransaction =>
      $$PortfolioTransactionTableTableManager(_db, _db.portfolioTransaction);
  $$StockEventTableTableManager get stockEvent =>
      $$StockEventTableTableManager(_db, _db.stockEvent);
  $$MarketIndexTableTableManager get marketIndex =>
      $$MarketIndexTableTableManager(_db, _db.marketIndex);
}
