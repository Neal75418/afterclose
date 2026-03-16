// dart format width=80
// ignore_for_file: type=lint
import 'package:drift/drift.dart' as i0;
import 'package:afterclose/data/database/tables/market_index_tables.drift.dart'
    as i1;
import 'package:afterclose/data/database/tables/market_index_tables.dart' as i2;
import 'package:drift/src/runtime/query_builder/query_builder.dart' as i3;

typedef $$MarketIndexTableCreateCompanionBuilder =
    i1.MarketIndexCompanion Function({
      i0.Value<int> id,
      required DateTime date,
      required String name,
      required double close,
      required double change,
      required double changePercent,
      i0.Value<DateTime> createdAt,
    });
typedef $$MarketIndexTableUpdateCompanionBuilder =
    i1.MarketIndexCompanion Function({
      i0.Value<int> id,
      i0.Value<DateTime> date,
      i0.Value<String> name,
      i0.Value<double> close,
      i0.Value<double> change,
      i0.Value<double> changePercent,
      i0.Value<DateTime> createdAt,
    });

class $$MarketIndexTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$MarketIndexTable> {
  $$MarketIndexTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get change => $composableBuilder(
    column: $table.change,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get changePercent => $composableBuilder(
    column: $table.changePercent,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => i0.ColumnFilters(column),
  );
}

class $$MarketIndexTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$MarketIndexTable> {
  $$MarketIndexTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get close => $composableBuilder(
    column: $table.close,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get change => $composableBuilder(
    column: $table.change,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get changePercent => $composableBuilder(
    column: $table.changePercent,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => i0.ColumnOrderings(column),
  );
}

class $$MarketIndexTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$MarketIndexTable> {
  $$MarketIndexTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  i0.GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  i0.GeneratedColumn<double> get close =>
      $composableBuilder(column: $table.close, builder: (column) => column);

  i0.GeneratedColumn<double> get change =>
      $composableBuilder(column: $table.change, builder: (column) => column);

  i0.GeneratedColumn<double> get changePercent => $composableBuilder(
    column: $table.changePercent,
    builder: (column) => column,
  );

  i0.GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MarketIndexTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$MarketIndexTable,
          i1.MarketIndexEntry,
          i1.$$MarketIndexTableFilterComposer,
          i1.$$MarketIndexTableOrderingComposer,
          i1.$$MarketIndexTableAnnotationComposer,
          $$MarketIndexTableCreateCompanionBuilder,
          $$MarketIndexTableUpdateCompanionBuilder,
          (
            i1.MarketIndexEntry,
            i0.BaseReferences<
              i0.GeneratedDatabase,
              i1.$MarketIndexTable,
              i1.MarketIndexEntry
            >,
          ),
          i1.MarketIndexEntry,
          i0.PrefetchHooks Function()
        > {
  $$MarketIndexTableTableManager(
    i0.GeneratedDatabase db,
    i1.$MarketIndexTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$MarketIndexTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$MarketIndexTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$MarketIndexTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<DateTime> date = const i0.Value.absent(),
                i0.Value<String> name = const i0.Value.absent(),
                i0.Value<double> close = const i0.Value.absent(),
                i0.Value<double> change = const i0.Value.absent(),
                i0.Value<double> changePercent = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
              }) => i1.MarketIndexCompanion(
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
                i0.Value<int> id = const i0.Value.absent(),
                required DateTime date,
                required String name,
                required double close,
                required double change,
                required double changePercent,
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
              }) => i1.MarketIndexCompanion.insert(
                id: id,
                date: date,
                name: name,
                close: close,
                change: change,
                changePercent: changePercent,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), i0.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MarketIndexTableProcessedTableManager =
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$MarketIndexTable,
      i1.MarketIndexEntry,
      i1.$$MarketIndexTableFilterComposer,
      i1.$$MarketIndexTableOrderingComposer,
      i1.$$MarketIndexTableAnnotationComposer,
      $$MarketIndexTableCreateCompanionBuilder,
      $$MarketIndexTableUpdateCompanionBuilder,
      (
        i1.MarketIndexEntry,
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$MarketIndexTable,
          i1.MarketIndexEntry
        >,
      ),
      i1.MarketIndexEntry,
      i0.PrefetchHooks Function()
    >;
i0.Index get idxMarketIndexDate => i0.Index(
  'idx_market_index_date',
  'CREATE INDEX idx_market_index_date ON market_index (date)',
);

class $MarketIndexTable extends i2.MarketIndex
    with i0.TableInfo<$MarketIndexTable, i1.MarketIndexEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarketIndexTable(this.attachedDatabase, [this._alias]);
  static const i0.VerificationMeta _idMeta = const i0.VerificationMeta('id');
  @override
  late final i0.GeneratedColumn<int> id = i0.GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: i0.DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: i0.GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const i0.VerificationMeta _dateMeta = const i0.VerificationMeta(
    'date',
  );
  @override
  late final i0.GeneratedColumn<DateTime> date = i0.GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: i0.DriftSqlType.dateTime,
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
  static const i0.VerificationMeta _closeMeta = const i0.VerificationMeta(
    'close',
  );
  @override
  late final i0.GeneratedColumn<double> close = i0.GeneratedColumn<double>(
    'close',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _changeMeta = const i0.VerificationMeta(
    'change',
  );
  @override
  late final i0.GeneratedColumn<double> change = i0.GeneratedColumn<double>(
    'change',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _changePercentMeta =
      const i0.VerificationMeta('changePercent');
  @override
  late final i0.GeneratedColumn<double> changePercent =
      i0.GeneratedColumn<double>(
        'change_percent',
        aliasedName,
        false,
        type: i0.DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const i0.VerificationMeta _createdAtMeta = const i0.VerificationMeta(
    'createdAt',
  );
  @override
  late final i0.GeneratedColumn<DateTime> createdAt =
      i0.GeneratedColumn<DateTime>(
        'created_at',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: i3.currentDateAndTime,
      );
  @override
  List<i0.GeneratedColumn> get $columns => [
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.MarketIndexEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<i0.GeneratedColumn>> get uniqueKeys => [
    {date, name},
  ];
  @override
  i1.MarketIndexEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.MarketIndexEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      name: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      close: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}close'],
      )!,
      change: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}change'],
      )!,
      changePercent: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}change_percent'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MarketIndexTable createAlias(String alias) {
    return $MarketIndexTable(attachedDatabase, alias);
  }
}

class MarketIndexEntry extends i0.DataClass
    implements i0.Insertable<i1.MarketIndexEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['date'] = i0.Variable<DateTime>(date);
    map['name'] = i0.Variable<String>(name);
    map['close'] = i0.Variable<double>(close);
    map['change'] = i0.Variable<double>(change);
    map['change_percent'] = i0.Variable<double>(changePercent);
    map['created_at'] = i0.Variable<DateTime>(createdAt);
    return map;
  }

  i1.MarketIndexCompanion toCompanion(bool nullToAbsent) {
    return i1.MarketIndexCompanion(
      id: i0.Value(id),
      date: i0.Value(date),
      name: i0.Value(name),
      close: i0.Value(close),
      change: i0.Value(change),
      changePercent: i0.Value(changePercent),
      createdAt: i0.Value(createdAt),
    );
  }

  factory MarketIndexEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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

  i1.MarketIndexEntry copyWith({
    int? id,
    DateTime? date,
    String? name,
    double? close,
    double? change,
    double? changePercent,
    DateTime? createdAt,
  }) => i1.MarketIndexEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    name: name ?? this.name,
    close: close ?? this.close,
    change: change ?? this.change,
    changePercent: changePercent ?? this.changePercent,
    createdAt: createdAt ?? this.createdAt,
  );
  MarketIndexEntry copyWithCompanion(i1.MarketIndexCompanion data) {
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
      (other is i1.MarketIndexEntry &&
          other.id == this.id &&
          other.date == this.date &&
          other.name == this.name &&
          other.close == this.close &&
          other.change == this.change &&
          other.changePercent == this.changePercent &&
          other.createdAt == this.createdAt);
}

class MarketIndexCompanion extends i0.UpdateCompanion<i1.MarketIndexEntry> {
  final i0.Value<int> id;
  final i0.Value<DateTime> date;
  final i0.Value<String> name;
  final i0.Value<double> close;
  final i0.Value<double> change;
  final i0.Value<double> changePercent;
  final i0.Value<DateTime> createdAt;
  const MarketIndexCompanion({
    this.id = const i0.Value.absent(),
    this.date = const i0.Value.absent(),
    this.name = const i0.Value.absent(),
    this.close = const i0.Value.absent(),
    this.change = const i0.Value.absent(),
    this.changePercent = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
  });
  MarketIndexCompanion.insert({
    this.id = const i0.Value.absent(),
    required DateTime date,
    required String name,
    required double close,
    required double change,
    required double changePercent,
    this.createdAt = const i0.Value.absent(),
  }) : date = i0.Value(date),
       name = i0.Value(name),
       close = i0.Value(close),
       change = i0.Value(change),
       changePercent = i0.Value(changePercent);
  static i0.Insertable<i1.MarketIndexEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<DateTime>? date,
    i0.Expression<String>? name,
    i0.Expression<double>? close,
    i0.Expression<double>? change,
    i0.Expression<double>? changePercent,
    i0.Expression<DateTime>? createdAt,
  }) {
    return i0.RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (name != null) 'name': name,
      if (close != null) 'close': close,
      if (change != null) 'change': change,
      if (changePercent != null) 'change_percent': changePercent,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  i1.MarketIndexCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<DateTime>? date,
    i0.Value<String>? name,
    i0.Value<double>? close,
    i0.Value<double>? change,
    i0.Value<double>? changePercent,
    i0.Value<DateTime>? createdAt,
  }) {
    return i1.MarketIndexCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (id.present) {
      map['id'] = i0.Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = i0.Variable<DateTime>(date.value);
    }
    if (name.present) {
      map['name'] = i0.Variable<String>(name.value);
    }
    if (close.present) {
      map['close'] = i0.Variable<double>(close.value);
    }
    if (change.present) {
      map['change'] = i0.Variable<double>(change.value);
    }
    if (changePercent.present) {
      map['change_percent'] = i0.Variable<double>(changePercent.value);
    }
    if (createdAt.present) {
      map['created_at'] = i0.Variable<DateTime>(createdAt.value);
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

i0.Index get idxMarketIndexName => i0.Index(
  'idx_market_index_name',
  'CREATE INDEX idx_market_index_name ON market_index (name)',
);
