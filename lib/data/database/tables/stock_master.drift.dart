// dart format width=80
// ignore_for_file: type=lint
import 'package:drift/drift.dart' as i0;
import 'package:afterclose/data/database/tables/stock_master.drift.dart' as i1;
import 'package:afterclose/data/database/tables/stock_master.dart' as i2;
import 'package:drift/src/runtime/query_builder/query_builder.dart' as i3;

typedef $$StockMasterTableCreateCompanionBuilder =
    i1.StockMasterCompanion Function({
      required String symbol,
      required String name,
      required String market,
      i0.Value<String?> industry,
      i0.Value<bool> isActive,
      i0.Value<DateTime> updatedAt,
      i0.Value<int> rowid,
    });
typedef $$StockMasterTableUpdateCompanionBuilder =
    i1.StockMasterCompanion Function({
      i0.Value<String> symbol,
      i0.Value<String> name,
      i0.Value<String> market,
      i0.Value<String?> industry,
      i0.Value<bool> isActive,
      i0.Value<DateTime> updatedAt,
      i0.Value<int> rowid,
    });

class $$StockMasterTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$StockMasterTable> {
  $$StockMasterTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get market => $composableBuilder(
    column: $table.market,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => i0.ColumnFilters(column),
  );
}

class $$StockMasterTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$StockMasterTable> {
  $$StockMasterTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get market => $composableBuilder(
    column: $table.market,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );
}

class $$StockMasterTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$StockMasterTable> {
  $$StockMasterTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  i0.GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  i0.GeneratedColumn<String> get market =>
      $composableBuilder(column: $table.market, builder: (column) => column);

  i0.GeneratedColumn<String> get industry =>
      $composableBuilder(column: $table.industry, builder: (column) => column);

  i0.GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StockMasterTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$StockMasterTable,
          i1.StockMasterEntry,
          i1.$$StockMasterTableFilterComposer,
          i1.$$StockMasterTableOrderingComposer,
          i1.$$StockMasterTableAnnotationComposer,
          $$StockMasterTableCreateCompanionBuilder,
          $$StockMasterTableUpdateCompanionBuilder,
          (
            i1.StockMasterEntry,
            i0.BaseReferences<
              i0.GeneratedDatabase,
              i1.$StockMasterTable,
              i1.StockMasterEntry
            >,
          ),
          i1.StockMasterEntry,
          i0.PrefetchHooks Function()
        > {
  $$StockMasterTableTableManager(
    i0.GeneratedDatabase db,
    i1.$StockMasterTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$StockMasterTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$StockMasterTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$StockMasterTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<String> name = const i0.Value.absent(),
                i0.Value<String> market = const i0.Value.absent(),
                i0.Value<String?> industry = const i0.Value.absent(),
                i0.Value<bool> isActive = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.StockMasterCompanion(
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
                i0.Value<String?> industry = const i0.Value.absent(),
                i0.Value<bool> isActive = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.StockMasterCompanion.insert(
                symbol: symbol,
                name: name,
                market: market,
                industry: industry,
                isActive: isActive,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), i0.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockMasterTableProcessedTableManager =
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$StockMasterTable,
      i1.StockMasterEntry,
      i1.$$StockMasterTableFilterComposer,
      i1.$$StockMasterTableOrderingComposer,
      i1.$$StockMasterTableAnnotationComposer,
      $$StockMasterTableCreateCompanionBuilder,
      $$StockMasterTableUpdateCompanionBuilder,
      (
        i1.StockMasterEntry,
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$StockMasterTable,
          i1.StockMasterEntry
        >,
      ),
      i1.StockMasterEntry,
      i0.PrefetchHooks Function()
    >;
i0.Index get idxStockMasterIndustry => i0.Index(
  'idx_stock_master_industry',
  'CREATE INDEX idx_stock_master_industry ON stock_master (industry)',
);

class $StockMasterTable extends i2.StockMaster
    with i0.TableInfo<$StockMasterTable, i1.StockMasterEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMasterTable(this.attachedDatabase, [this._alias]);
  static const i0.VerificationMeta _symbolMeta = const i0.VerificationMeta(
    'symbol',
  );
  @override
  late final i0.GeneratedColumn<String> symbol = i0.GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _nameMeta = const i0.VerificationMeta(
    'name',
  );
  @override
  late final i0.GeneratedColumn<String> name = i0.GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _marketMeta = const i0.VerificationMeta(
    'market',
  );
  @override
  late final i0.GeneratedColumn<String> market = i0.GeneratedColumn<String>(
    'market',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _industryMeta = const i0.VerificationMeta(
    'industry',
  );
  @override
  late final i0.GeneratedColumn<String> industry = i0.GeneratedColumn<String>(
    'industry',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _isActiveMeta = const i0.VerificationMeta(
    'isActive',
  );
  @override
  late final i0.GeneratedColumn<bool> isActive = i0.GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: i0.DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: i0.GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const i3.Constant(true),
  );
  static const i0.VerificationMeta _updatedAtMeta = const i0.VerificationMeta(
    'updatedAt',
  );
  @override
  late final i0.GeneratedColumn<DateTime> updatedAt =
      i0.GeneratedColumn<DateTime>(
        'updated_at',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: i3.currentDateAndTime,
      );
  @override
  List<i0.GeneratedColumn> get $columns => [
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.StockMasterEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {symbol};
  @override
  i1.StockMasterEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.StockMasterEntry(
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      name: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      market: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}market'],
      )!,
      industry: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}industry'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StockMasterTable createAlias(String alias) {
    return $StockMasterTable(attachedDatabase, alias);
  }
}

class StockMasterEntry extends i0.DataClass
    implements i0.Insertable<i1.StockMasterEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['symbol'] = i0.Variable<String>(symbol);
    map['name'] = i0.Variable<String>(name);
    map['market'] = i0.Variable<String>(market);
    if (!nullToAbsent || industry != null) {
      map['industry'] = i0.Variable<String>(industry);
    }
    map['is_active'] = i0.Variable<bool>(isActive);
    map['updated_at'] = i0.Variable<DateTime>(updatedAt);
    return map;
  }

  i1.StockMasterCompanion toCompanion(bool nullToAbsent) {
    return i1.StockMasterCompanion(
      symbol: i0.Value(symbol),
      name: i0.Value(name),
      market: i0.Value(market),
      industry: industry == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(industry),
      isActive: i0.Value(isActive),
      updatedAt: i0.Value(updatedAt),
    );
  }

  factory StockMasterEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'market': serializer.toJson<String>(market),
      'industry': serializer.toJson<String?>(industry),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  i1.StockMasterEntry copyWith({
    String? symbol,
    String? name,
    String? market,
    i0.Value<String?> industry = const i0.Value.absent(),
    bool? isActive,
    DateTime? updatedAt,
  }) => i1.StockMasterEntry(
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    market: market ?? this.market,
    industry: industry.present ? industry.value : this.industry,
    isActive: isActive ?? this.isActive,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StockMasterEntry copyWithCompanion(i1.StockMasterCompanion data) {
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
      (other is i1.StockMasterEntry &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.market == this.market &&
          other.industry == this.industry &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class StockMasterCompanion extends i0.UpdateCompanion<i1.StockMasterEntry> {
  final i0.Value<String> symbol;
  final i0.Value<String> name;
  final i0.Value<String> market;
  final i0.Value<String?> industry;
  final i0.Value<bool> isActive;
  final i0.Value<DateTime> updatedAt;
  final i0.Value<int> rowid;
  const StockMasterCompanion({
    this.symbol = const i0.Value.absent(),
    this.name = const i0.Value.absent(),
    this.market = const i0.Value.absent(),
    this.industry = const i0.Value.absent(),
    this.isActive = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  StockMasterCompanion.insert({
    required String symbol,
    required String name,
    required String market,
    this.industry = const i0.Value.absent(),
    this.isActive = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol),
       name = i0.Value(name),
       market = i0.Value(market);
  static i0.Insertable<i1.StockMasterEntry> custom({
    i0.Expression<String>? symbol,
    i0.Expression<String>? name,
    i0.Expression<String>? market,
    i0.Expression<String>? industry,
    i0.Expression<bool>? isActive,
    i0.Expression<DateTime>? updatedAt,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (market != null) 'market': market,
      if (industry != null) 'industry': industry,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  i1.StockMasterCompanion copyWith({
    i0.Value<String>? symbol,
    i0.Value<String>? name,
    i0.Value<String>? market,
    i0.Value<String?>? industry,
    i0.Value<bool>? isActive,
    i0.Value<DateTime>? updatedAt,
    i0.Value<int>? rowid,
  }) {
    return i1.StockMasterCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = i0.Variable<String>(name.value);
    }
    if (market.present) {
      map['market'] = i0.Variable<String>(market.value);
    }
    if (industry.present) {
      map['industry'] = i0.Variable<String>(industry.value);
    }
    if (isActive.present) {
      map['is_active'] = i0.Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = i0.Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = i0.Variable<int>(rowid.value);
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
