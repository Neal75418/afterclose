// dart format width=80
// ignore_for_file: type=lint
import 'package:drift/drift.dart' as i0;
import 'package:afterclose/data/database/tables/analysis_tables.drift.dart'
    as i1;
import 'package:afterclose/data/database/tables/analysis_tables.dart' as i2;
import 'package:drift/src/runtime/query_builder/query_builder.dart' as i3;
import 'package:afterclose/data/database/tables/stock_master.drift.dart' as i4;
import 'package:drift/internal/modular.dart' as i5;

typedef $$DailyAnalysisTableCreateCompanionBuilder =
    i1.DailyAnalysisCompanion Function({
      required String symbol,
      required DateTime date,
      required String trendState,
      i0.Value<String> reversalState,
      i0.Value<double?> supportLevel,
      i0.Value<double?> resistanceLevel,
      i0.Value<double> score,
      i0.Value<DateTime> computedAt,
      i0.Value<int> rowid,
    });
typedef $$DailyAnalysisTableUpdateCompanionBuilder =
    i1.DailyAnalysisCompanion Function({
      i0.Value<String> symbol,
      i0.Value<DateTime> date,
      i0.Value<String> trendState,
      i0.Value<String> reversalState,
      i0.Value<double?> supportLevel,
      i0.Value<double?> resistanceLevel,
      i0.Value<double> score,
      i0.Value<DateTime> computedAt,
      i0.Value<int> rowid,
    });

final class $$DailyAnalysisTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$DailyAnalysisTable,
          i1.DailyAnalysisEntry
        > {
  $$DailyAnalysisTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static i4.$StockMasterTable _symbolTable(i0.GeneratedDatabase db) =>
      i5.ReadDatabaseContainer(db)
          .resultSet<i4.$StockMasterTable>('stock_master')
          .createAlias(
            i0.$_aliasNameGenerator(
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$DailyAnalysisTable>('daily_analysis').symbol,
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i4.$StockMasterTable>('stock_master').symbol,
            ),
          );

  i4.$$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = i4
        .$$StockMasterTableTableManager(
          $_db,
          i5.ReadDatabaseContainer(
            $_db,
          ).resultSet<i4.$StockMasterTable>('stock_master'),
        )
        .filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return i0.ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyAnalysisTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyAnalysisTable> {
  $$DailyAnalysisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get trendState => $composableBuilder(
    column: $table.trendState,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get reversalState => $composableBuilder(
    column: $table.reversalState,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get supportLevel => $composableBuilder(
    column: $table.supportLevel,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => i0.ColumnFilters(column),
  );

  i4.$$StockMasterTableFilterComposer get symbol {
    final i4.$$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableFilterComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyAnalysisTable> {
  $$DailyAnalysisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get trendState => $composableBuilder(
    column: $table.trendState,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get reversalState => $composableBuilder(
    column: $table.reversalState,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get supportLevel => $composableBuilder(
    column: $table.supportLevel,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i4.$$StockMasterTableOrderingComposer get symbol {
    final i4.$$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableOrderingComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyAnalysisTable> {
  $$DailyAnalysisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  i0.GeneratedColumn<String> get trendState => $composableBuilder(
    column: $table.trendState,
    builder: (column) => column,
  );

  i0.GeneratedColumn<String> get reversalState => $composableBuilder(
    column: $table.reversalState,
    builder: (column) => column,
  );

  i0.GeneratedColumn<double> get supportLevel => $composableBuilder(
    column: $table.supportLevel,
    builder: (column) => column,
  );

  i0.GeneratedColumn<double> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => column,
  );

  i0.GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get computedAt => $composableBuilder(
    column: $table.computedAt,
    builder: (column) => column,
  );

  i4.$$StockMasterTableAnnotationComposer get symbol {
    final i4.$$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$DailyAnalysisTable,
          i1.DailyAnalysisEntry,
          i1.$$DailyAnalysisTableFilterComposer,
          i1.$$DailyAnalysisTableOrderingComposer,
          i1.$$DailyAnalysisTableAnnotationComposer,
          $$DailyAnalysisTableCreateCompanionBuilder,
          $$DailyAnalysisTableUpdateCompanionBuilder,
          (i1.DailyAnalysisEntry, i1.$$DailyAnalysisTableReferences),
          i1.DailyAnalysisEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$DailyAnalysisTableTableManager(
    i0.GeneratedDatabase db,
    i1.$DailyAnalysisTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$DailyAnalysisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$DailyAnalysisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$DailyAnalysisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<DateTime> date = const i0.Value.absent(),
                i0.Value<String> trendState = const i0.Value.absent(),
                i0.Value<String> reversalState = const i0.Value.absent(),
                i0.Value<double?> supportLevel = const i0.Value.absent(),
                i0.Value<double?> resistanceLevel = const i0.Value.absent(),
                i0.Value<double> score = const i0.Value.absent(),
                i0.Value<DateTime> computedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.DailyAnalysisCompanion(
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
                i0.Value<String> reversalState = const i0.Value.absent(),
                i0.Value<double?> supportLevel = const i0.Value.absent(),
                i0.Value<double?> resistanceLevel = const i0.Value.absent(),
                i0.Value<double> score = const i0.Value.absent(),
                i0.Value<DateTime> computedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.DailyAnalysisCompanion.insert(
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
                  i1.$$DailyAnalysisTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return i0.PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends i0.TableManagerState<
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
                                referencedTable: i1
                                    .$$DailyAnalysisTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1
                                    .$$DailyAnalysisTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$DailyAnalysisTable,
      i1.DailyAnalysisEntry,
      i1.$$DailyAnalysisTableFilterComposer,
      i1.$$DailyAnalysisTableOrderingComposer,
      i1.$$DailyAnalysisTableAnnotationComposer,
      $$DailyAnalysisTableCreateCompanionBuilder,
      $$DailyAnalysisTableUpdateCompanionBuilder,
      (i1.DailyAnalysisEntry, i1.$$DailyAnalysisTableReferences),
      i1.DailyAnalysisEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
typedef $$DailyReasonTableCreateCompanionBuilder =
    i1.DailyReasonCompanion Function({
      required String symbol,
      required DateTime date,
      required int rank,
      required String reasonType,
      required String evidenceJson,
      i0.Value<double> ruleScore,
      i0.Value<int> rowid,
    });
typedef $$DailyReasonTableUpdateCompanionBuilder =
    i1.DailyReasonCompanion Function({
      i0.Value<String> symbol,
      i0.Value<DateTime> date,
      i0.Value<int> rank,
      i0.Value<String> reasonType,
      i0.Value<String> evidenceJson,
      i0.Value<double> ruleScore,
      i0.Value<int> rowid,
    });

final class $$DailyReasonTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$DailyReasonTable,
          i1.DailyReasonEntry
        > {
  $$DailyReasonTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static i4.$StockMasterTable _symbolTable(i0.GeneratedDatabase db) =>
      i5.ReadDatabaseContainer(db)
          .resultSet<i4.$StockMasterTable>('stock_master')
          .createAlias(
            i0.$_aliasNameGenerator(
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$DailyReasonTable>('daily_reason').symbol,
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i4.$StockMasterTable>('stock_master').symbol,
            ),
          );

  i4.$$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = i4
        .$$StockMasterTableTableManager(
          $_db,
          i5.ReadDatabaseContainer(
            $_db,
          ).resultSet<i4.$StockMasterTable>('stock_master'),
        )
        .filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return i0.ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyReasonTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyReasonTable> {
  $$DailyReasonTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get reasonType => $composableBuilder(
    column: $table.reasonType,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get ruleScore => $composableBuilder(
    column: $table.ruleScore,
    builder: (column) => i0.ColumnFilters(column),
  );

  i4.$$StockMasterTableFilterComposer get symbol {
    final i4.$$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableFilterComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyReasonTable> {
  $$DailyReasonTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get reasonType => $composableBuilder(
    column: $table.reasonType,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get ruleScore => $composableBuilder(
    column: $table.ruleScore,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i4.$$StockMasterTableOrderingComposer get symbol {
    final i4.$$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableOrderingComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyReasonTable> {
  $$DailyReasonTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  i0.GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  i0.GeneratedColumn<String> get reasonType => $composableBuilder(
    column: $table.reasonType,
    builder: (column) => column,
  );

  i0.GeneratedColumn<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => column,
  );

  i0.GeneratedColumn<double> get ruleScore =>
      $composableBuilder(column: $table.ruleScore, builder: (column) => column);

  i4.$$StockMasterTableAnnotationComposer get symbol {
    final i4.$$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$DailyReasonTable,
          i1.DailyReasonEntry,
          i1.$$DailyReasonTableFilterComposer,
          i1.$$DailyReasonTableOrderingComposer,
          i1.$$DailyReasonTableAnnotationComposer,
          $$DailyReasonTableCreateCompanionBuilder,
          $$DailyReasonTableUpdateCompanionBuilder,
          (i1.DailyReasonEntry, i1.$$DailyReasonTableReferences),
          i1.DailyReasonEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$DailyReasonTableTableManager(
    i0.GeneratedDatabase db,
    i1.$DailyReasonTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$DailyReasonTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$DailyReasonTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$DailyReasonTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<DateTime> date = const i0.Value.absent(),
                i0.Value<int> rank = const i0.Value.absent(),
                i0.Value<String> reasonType = const i0.Value.absent(),
                i0.Value<String> evidenceJson = const i0.Value.absent(),
                i0.Value<double> ruleScore = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.DailyReasonCompanion(
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
                i0.Value<double> ruleScore = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.DailyReasonCompanion.insert(
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
                  i1.$$DailyReasonTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return i0.PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends i0.TableManagerState<
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
                                referencedTable: i1.$$DailyReasonTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1
                                    .$$DailyReasonTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$DailyReasonTable,
      i1.DailyReasonEntry,
      i1.$$DailyReasonTableFilterComposer,
      i1.$$DailyReasonTableOrderingComposer,
      i1.$$DailyReasonTableAnnotationComposer,
      $$DailyReasonTableCreateCompanionBuilder,
      $$DailyReasonTableUpdateCompanionBuilder,
      (i1.DailyReasonEntry, i1.$$DailyReasonTableReferences),
      i1.DailyReasonEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
typedef $$DailyRecommendationTableCreateCompanionBuilder =
    i1.DailyRecommendationCompanion Function({
      required DateTime date,
      required int rank,
      required String symbol,
      required double score,
      i0.Value<int> rowid,
    });
typedef $$DailyRecommendationTableUpdateCompanionBuilder =
    i1.DailyRecommendationCompanion Function({
      i0.Value<DateTime> date,
      i0.Value<int> rank,
      i0.Value<String> symbol,
      i0.Value<double> score,
      i0.Value<int> rowid,
    });

final class $$DailyRecommendationTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$DailyRecommendationTable,
          i1.DailyRecommendationEntry
        > {
  $$DailyRecommendationTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static i4.$StockMasterTable _symbolTable(i0.GeneratedDatabase db) =>
      i5.ReadDatabaseContainer(db)
          .resultSet<i4.$StockMasterTable>('stock_master')
          .createAlias(
            i0.$_aliasNameGenerator(
              i5.ReadDatabaseContainer(db)
                  .resultSet<i1.$DailyRecommendationTable>(
                    'daily_recommendation',
                  )
                  .symbol,
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i4.$StockMasterTable>('stock_master').symbol,
            ),
          );

  i4.$$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = i4
        .$$StockMasterTableTableManager(
          $_db,
          i5.ReadDatabaseContainer(
            $_db,
          ).resultSet<i4.$StockMasterTable>('stock_master'),
        )
        .filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return i0.ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyRecommendationTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyRecommendationTable> {
  $$DailyRecommendationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => i0.ColumnFilters(column),
  );

  i4.$$StockMasterTableFilterComposer get symbol {
    final i4.$$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableFilterComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyRecommendationTable> {
  $$DailyRecommendationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i4.$$StockMasterTableOrderingComposer get symbol {
    final i4.$$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableOrderingComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$DailyRecommendationTable> {
  $$DailyRecommendationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  i0.GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  i0.GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  i4.$$StockMasterTableAnnotationComposer get symbol {
    final i4.$$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i5.ReadDatabaseContainer(
        $db,
      ).resultSet<i4.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i4.$$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: i5.ReadDatabaseContainer(
              $db,
            ).resultSet<i4.$StockMasterTable>('stock_master'),
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
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$DailyRecommendationTable,
          i1.DailyRecommendationEntry,
          i1.$$DailyRecommendationTableFilterComposer,
          i1.$$DailyRecommendationTableOrderingComposer,
          i1.$$DailyRecommendationTableAnnotationComposer,
          $$DailyRecommendationTableCreateCompanionBuilder,
          $$DailyRecommendationTableUpdateCompanionBuilder,
          (
            i1.DailyRecommendationEntry,
            i1.$$DailyRecommendationTableReferences,
          ),
          i1.DailyRecommendationEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$DailyRecommendationTableTableManager(
    i0.GeneratedDatabase db,
    i1.$DailyRecommendationTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => i1
              .$$DailyRecommendationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$DailyRecommendationTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              i1.$$DailyRecommendationTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                i0.Value<DateTime> date = const i0.Value.absent(),
                i0.Value<int> rank = const i0.Value.absent(),
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<double> score = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.DailyRecommendationCompanion(
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
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.DailyRecommendationCompanion.insert(
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
                  i1.$$DailyRecommendationTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({symbol = false}) {
            return i0.PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends i0.TableManagerState<
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
                                referencedTable: i1
                                    .$$DailyRecommendationTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1
                                    .$$DailyRecommendationTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$DailyRecommendationTable,
      i1.DailyRecommendationEntry,
      i1.$$DailyRecommendationTableFilterComposer,
      i1.$$DailyRecommendationTableOrderingComposer,
      i1.$$DailyRecommendationTableAnnotationComposer,
      $$DailyRecommendationTableCreateCompanionBuilder,
      $$DailyRecommendationTableUpdateCompanionBuilder,
      (i1.DailyRecommendationEntry, i1.$$DailyRecommendationTableReferences),
      i1.DailyRecommendationEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
typedef $$RuleAccuracyTableCreateCompanionBuilder =
    i1.RuleAccuracyCompanion Function({
      required String ruleId,
      required String period,
      i0.Value<int> triggerCount,
      i0.Value<int> successCount,
      i0.Value<double> avgReturn,
      i0.Value<DateTime> updatedAt,
      i0.Value<int> rowid,
    });
typedef $$RuleAccuracyTableUpdateCompanionBuilder =
    i1.RuleAccuracyCompanion Function({
      i0.Value<String> ruleId,
      i0.Value<String> period,
      i0.Value<int> triggerCount,
      i0.Value<int> successCount,
      i0.Value<double> avgReturn,
      i0.Value<DateTime> updatedAt,
      i0.Value<int> rowid,
    });

class $$RuleAccuracyTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$RuleAccuracyTable> {
  $$RuleAccuracyTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get avgReturn => $composableBuilder(
    column: $table.avgReturn,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => i0.ColumnFilters(column),
  );
}

class $$RuleAccuracyTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$RuleAccuracyTable> {
  $$RuleAccuracyTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get avgReturn => $composableBuilder(
    column: $table.avgReturn,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );
}

class $$RuleAccuracyTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$RuleAccuracyTable> {
  $$RuleAccuracyTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<String> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  i0.GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  i0.GeneratedColumn<int> get triggerCount => $composableBuilder(
    column: $table.triggerCount,
    builder: (column) => column,
  );

  i0.GeneratedColumn<int> get successCount => $composableBuilder(
    column: $table.successCount,
    builder: (column) => column,
  );

  i0.GeneratedColumn<double> get avgReturn =>
      $composableBuilder(column: $table.avgReturn, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RuleAccuracyTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$RuleAccuracyTable,
          i1.RuleAccuracyEntry,
          i1.$$RuleAccuracyTableFilterComposer,
          i1.$$RuleAccuracyTableOrderingComposer,
          i1.$$RuleAccuracyTableAnnotationComposer,
          $$RuleAccuracyTableCreateCompanionBuilder,
          $$RuleAccuracyTableUpdateCompanionBuilder,
          (
            i1.RuleAccuracyEntry,
            i0.BaseReferences<
              i0.GeneratedDatabase,
              i1.$RuleAccuracyTable,
              i1.RuleAccuracyEntry
            >,
          ),
          i1.RuleAccuracyEntry,
          i0.PrefetchHooks Function()
        > {
  $$RuleAccuracyTableTableManager(
    i0.GeneratedDatabase db,
    i1.$RuleAccuracyTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$RuleAccuracyTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$RuleAccuracyTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$RuleAccuracyTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<String> ruleId = const i0.Value.absent(),
                i0.Value<String> period = const i0.Value.absent(),
                i0.Value<int> triggerCount = const i0.Value.absent(),
                i0.Value<int> successCount = const i0.Value.absent(),
                i0.Value<double> avgReturn = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.RuleAccuracyCompanion(
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
                i0.Value<int> triggerCount = const i0.Value.absent(),
                i0.Value<int> successCount = const i0.Value.absent(),
                i0.Value<double> avgReturn = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.RuleAccuracyCompanion.insert(
                ruleId: ruleId,
                period: period,
                triggerCount: triggerCount,
                successCount: successCount,
                avgReturn: avgReturn,
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

typedef $$RuleAccuracyTableProcessedTableManager =
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$RuleAccuracyTable,
      i1.RuleAccuracyEntry,
      i1.$$RuleAccuracyTableFilterComposer,
      i1.$$RuleAccuracyTableOrderingComposer,
      i1.$$RuleAccuracyTableAnnotationComposer,
      $$RuleAccuracyTableCreateCompanionBuilder,
      $$RuleAccuracyTableUpdateCompanionBuilder,
      (
        i1.RuleAccuracyEntry,
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$RuleAccuracyTable,
          i1.RuleAccuracyEntry
        >,
      ),
      i1.RuleAccuracyEntry,
      i0.PrefetchHooks Function()
    >;
typedef $$RecommendationValidationTableCreateCompanionBuilder =
    i1.RecommendationValidationCompanion Function({
      i0.Value<int> id,
      required DateTime recommendationDate,
      required String symbol,
      required String primaryRuleId,
      required double entryPrice,
      i0.Value<double?> exitPrice,
      i0.Value<double?> returnRate,
      i0.Value<bool?> isSuccess,
      i0.Value<DateTime?> validationDate,
      i0.Value<int> holdingDays,
    });
typedef $$RecommendationValidationTableUpdateCompanionBuilder =
    i1.RecommendationValidationCompanion Function({
      i0.Value<int> id,
      i0.Value<DateTime> recommendationDate,
      i0.Value<String> symbol,
      i0.Value<String> primaryRuleId,
      i0.Value<double> entryPrice,
      i0.Value<double?> exitPrice,
      i0.Value<double?> returnRate,
      i0.Value<bool?> isSuccess,
      i0.Value<DateTime?> validationDate,
      i0.Value<int> holdingDays,
    });

class $$RecommendationValidationTableFilterComposer
    extends
        i0.Composer<i0.GeneratedDatabase, i1.$RecommendationValidationTable> {
  $$RecommendationValidationTableFilterComposer({
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

  i0.ColumnFilters<DateTime> get recommendationDate => $composableBuilder(
    column: $table.recommendationDate,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get primaryRuleId => $composableBuilder(
    column: $table.primaryRuleId,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get exitPrice => $composableBuilder(
    column: $table.exitPrice,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get returnRate => $composableBuilder(
    column: $table.returnRate,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<bool> get isSuccess => $composableBuilder(
    column: $table.isSuccess,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get validationDate => $composableBuilder(
    column: $table.validationDate,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<int> get holdingDays => $composableBuilder(
    column: $table.holdingDays,
    builder: (column) => i0.ColumnFilters(column),
  );
}

class $$RecommendationValidationTableOrderingComposer
    extends
        i0.Composer<i0.GeneratedDatabase, i1.$RecommendationValidationTable> {
  $$RecommendationValidationTableOrderingComposer({
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

  i0.ColumnOrderings<DateTime> get recommendationDate => $composableBuilder(
    column: $table.recommendationDate,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get primaryRuleId => $composableBuilder(
    column: $table.primaryRuleId,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get exitPrice => $composableBuilder(
    column: $table.exitPrice,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get returnRate => $composableBuilder(
    column: $table.returnRate,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<bool> get isSuccess => $composableBuilder(
    column: $table.isSuccess,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get validationDate => $composableBuilder(
    column: $table.validationDate,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<int> get holdingDays => $composableBuilder(
    column: $table.holdingDays,
    builder: (column) => i0.ColumnOrderings(column),
  );
}

class $$RecommendationValidationTableAnnotationComposer
    extends
        i0.Composer<i0.GeneratedDatabase, i1.$RecommendationValidationTable> {
  $$RecommendationValidationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get recommendationDate => $composableBuilder(
    column: $table.recommendationDate,
    builder: (column) => column,
  );

  i0.GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  i0.GeneratedColumn<String> get primaryRuleId => $composableBuilder(
    column: $table.primaryRuleId,
    builder: (column) => column,
  );

  i0.GeneratedColumn<double> get entryPrice => $composableBuilder(
    column: $table.entryPrice,
    builder: (column) => column,
  );

  i0.GeneratedColumn<double> get exitPrice =>
      $composableBuilder(column: $table.exitPrice, builder: (column) => column);

  i0.GeneratedColumn<double> get returnRate => $composableBuilder(
    column: $table.returnRate,
    builder: (column) => column,
  );

  i0.GeneratedColumn<bool> get isSuccess =>
      $composableBuilder(column: $table.isSuccess, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get validationDate => $composableBuilder(
    column: $table.validationDate,
    builder: (column) => column,
  );

  i0.GeneratedColumn<int> get holdingDays => $composableBuilder(
    column: $table.holdingDays,
    builder: (column) => column,
  );
}

class $$RecommendationValidationTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$RecommendationValidationTable,
          i1.RecommendationValidationEntry,
          i1.$$RecommendationValidationTableFilterComposer,
          i1.$$RecommendationValidationTableOrderingComposer,
          i1.$$RecommendationValidationTableAnnotationComposer,
          $$RecommendationValidationTableCreateCompanionBuilder,
          $$RecommendationValidationTableUpdateCompanionBuilder,
          (
            i1.RecommendationValidationEntry,
            i0.BaseReferences<
              i0.GeneratedDatabase,
              i1.$RecommendationValidationTable,
              i1.RecommendationValidationEntry
            >,
          ),
          i1.RecommendationValidationEntry,
          i0.PrefetchHooks Function()
        > {
  $$RecommendationValidationTableTableManager(
    i0.GeneratedDatabase db,
    i1.$RecommendationValidationTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$RecommendationValidationTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              i1.$$RecommendationValidationTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              i1.$$RecommendationValidationTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<DateTime> recommendationDate = const i0.Value.absent(),
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<String> primaryRuleId = const i0.Value.absent(),
                i0.Value<double> entryPrice = const i0.Value.absent(),
                i0.Value<double?> exitPrice = const i0.Value.absent(),
                i0.Value<double?> returnRate = const i0.Value.absent(),
                i0.Value<bool?> isSuccess = const i0.Value.absent(),
                i0.Value<DateTime?> validationDate = const i0.Value.absent(),
                i0.Value<int> holdingDays = const i0.Value.absent(),
              }) => i1.RecommendationValidationCompanion(
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
                i0.Value<int> id = const i0.Value.absent(),
                required DateTime recommendationDate,
                required String symbol,
                required String primaryRuleId,
                required double entryPrice,
                i0.Value<double?> exitPrice = const i0.Value.absent(),
                i0.Value<double?> returnRate = const i0.Value.absent(),
                i0.Value<bool?> isSuccess = const i0.Value.absent(),
                i0.Value<DateTime?> validationDate = const i0.Value.absent(),
                i0.Value<int> holdingDays = const i0.Value.absent(),
              }) => i1.RecommendationValidationCompanion.insert(
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
              .map((e) => (e.readTable(table), i0.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecommendationValidationTableProcessedTableManager =
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$RecommendationValidationTable,
      i1.RecommendationValidationEntry,
      i1.$$RecommendationValidationTableFilterComposer,
      i1.$$RecommendationValidationTableOrderingComposer,
      i1.$$RecommendationValidationTableAnnotationComposer,
      $$RecommendationValidationTableCreateCompanionBuilder,
      $$RecommendationValidationTableUpdateCompanionBuilder,
      (
        i1.RecommendationValidationEntry,
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$RecommendationValidationTable,
          i1.RecommendationValidationEntry
        >,
      ),
      i1.RecommendationValidationEntry,
      i0.PrefetchHooks Function()
    >;
i0.Index get idxDailyAnalysisDate => i0.Index(
  'idx_daily_analysis_date',
  'CREATE INDEX idx_daily_analysis_date ON daily_analysis (date)',
);

class $DailyAnalysisTable extends i2.DailyAnalysis
    with i0.TableInfo<$DailyAnalysisTable, i1.DailyAnalysisEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyAnalysisTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: i0.GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
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
  static const i0.VerificationMeta _trendStateMeta = const i0.VerificationMeta(
    'trendState',
  );
  @override
  late final i0.GeneratedColumn<String> trendState = i0.GeneratedColumn<String>(
    'trend_state',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _reversalStateMeta =
      const i0.VerificationMeta('reversalState');
  @override
  late final i0.GeneratedColumn<String> reversalState =
      i0.GeneratedColumn<String>(
        'reversal_state',
        aliasedName,
        false,
        type: i0.DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const i3.Constant('NONE'),
      );
  static const i0.VerificationMeta _supportLevelMeta =
      const i0.VerificationMeta('supportLevel');
  @override
  late final i0.GeneratedColumn<double> supportLevel =
      i0.GeneratedColumn<double>(
        'support_level',
        aliasedName,
        true,
        type: i0.DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const i0.VerificationMeta _resistanceLevelMeta =
      const i0.VerificationMeta('resistanceLevel');
  @override
  late final i0.GeneratedColumn<double> resistanceLevel =
      i0.GeneratedColumn<double>(
        'resistance_level',
        aliasedName,
        true,
        type: i0.DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const i0.VerificationMeta _scoreMeta = const i0.VerificationMeta(
    'score',
  );
  @override
  late final i0.GeneratedColumn<double> score = i0.GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
  );
  static const i0.VerificationMeta _computedAtMeta = const i0.VerificationMeta(
    'computedAt',
  );
  @override
  late final i0.GeneratedColumn<DateTime> computedAt =
      i0.GeneratedColumn<DateTime>(
        'computed_at',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: i3.currentDateAndTime,
      );
  @override
  List<i0.GeneratedColumn> get $columns => [
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.DailyAnalysisEntry> instance, {
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
  Set<i0.GeneratedColumn> get $primaryKey => {symbol, date};
  @override
  i1.DailyAnalysisEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.DailyAnalysisEntry(
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      trendState: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}trend_state'],
      )!,
      reversalState: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}reversal_state'],
      )!,
      supportLevel: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}support_level'],
      ),
      resistanceLevel: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}resistance_level'],
      ),
      score: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      computedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}computed_at'],
      )!,
    );
  }

  @override
  $DailyAnalysisTable createAlias(String alias) {
    return $DailyAnalysisTable(attachedDatabase, alias);
  }
}

class DailyAnalysisEntry extends i0.DataClass
    implements i0.Insertable<i1.DailyAnalysisEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['symbol'] = i0.Variable<String>(symbol);
    map['date'] = i0.Variable<DateTime>(date);
    map['trend_state'] = i0.Variable<String>(trendState);
    map['reversal_state'] = i0.Variable<String>(reversalState);
    if (!nullToAbsent || supportLevel != null) {
      map['support_level'] = i0.Variable<double>(supportLevel);
    }
    if (!nullToAbsent || resistanceLevel != null) {
      map['resistance_level'] = i0.Variable<double>(resistanceLevel);
    }
    map['score'] = i0.Variable<double>(score);
    map['computed_at'] = i0.Variable<DateTime>(computedAt);
    return map;
  }

  i1.DailyAnalysisCompanion toCompanion(bool nullToAbsent) {
    return i1.DailyAnalysisCompanion(
      symbol: i0.Value(symbol),
      date: i0.Value(date),
      trendState: i0.Value(trendState),
      reversalState: i0.Value(reversalState),
      supportLevel: supportLevel == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(supportLevel),
      resistanceLevel: resistanceLevel == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(resistanceLevel),
      score: i0.Value(score),
      computedAt: i0.Value(computedAt),
    );
  }

  factory DailyAnalysisEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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

  i1.DailyAnalysisEntry copyWith({
    String? symbol,
    DateTime? date,
    String? trendState,
    String? reversalState,
    i0.Value<double?> supportLevel = const i0.Value.absent(),
    i0.Value<double?> resistanceLevel = const i0.Value.absent(),
    double? score,
    DateTime? computedAt,
  }) => i1.DailyAnalysisEntry(
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
  DailyAnalysisEntry copyWithCompanion(i1.DailyAnalysisCompanion data) {
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
      (other is i1.DailyAnalysisEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.trendState == this.trendState &&
          other.reversalState == this.reversalState &&
          other.supportLevel == this.supportLevel &&
          other.resistanceLevel == this.resistanceLevel &&
          other.score == this.score &&
          other.computedAt == this.computedAt);
}

class DailyAnalysisCompanion extends i0.UpdateCompanion<i1.DailyAnalysisEntry> {
  final i0.Value<String> symbol;
  final i0.Value<DateTime> date;
  final i0.Value<String> trendState;
  final i0.Value<String> reversalState;
  final i0.Value<double?> supportLevel;
  final i0.Value<double?> resistanceLevel;
  final i0.Value<double> score;
  final i0.Value<DateTime> computedAt;
  final i0.Value<int> rowid;
  const DailyAnalysisCompanion({
    this.symbol = const i0.Value.absent(),
    this.date = const i0.Value.absent(),
    this.trendState = const i0.Value.absent(),
    this.reversalState = const i0.Value.absent(),
    this.supportLevel = const i0.Value.absent(),
    this.resistanceLevel = const i0.Value.absent(),
    this.score = const i0.Value.absent(),
    this.computedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  DailyAnalysisCompanion.insert({
    required String symbol,
    required DateTime date,
    required String trendState,
    this.reversalState = const i0.Value.absent(),
    this.supportLevel = const i0.Value.absent(),
    this.resistanceLevel = const i0.Value.absent(),
    this.score = const i0.Value.absent(),
    this.computedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol),
       date = i0.Value(date),
       trendState = i0.Value(trendState);
  static i0.Insertable<i1.DailyAnalysisEntry> custom({
    i0.Expression<String>? symbol,
    i0.Expression<DateTime>? date,
    i0.Expression<String>? trendState,
    i0.Expression<String>? reversalState,
    i0.Expression<double>? supportLevel,
    i0.Expression<double>? resistanceLevel,
    i0.Expression<double>? score,
    i0.Expression<DateTime>? computedAt,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
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

  i1.DailyAnalysisCompanion copyWith({
    i0.Value<String>? symbol,
    i0.Value<DateTime>? date,
    i0.Value<String>? trendState,
    i0.Value<String>? reversalState,
    i0.Value<double?>? supportLevel,
    i0.Value<double?>? resistanceLevel,
    i0.Value<double>? score,
    i0.Value<DateTime>? computedAt,
    i0.Value<int>? rowid,
  }) {
    return i1.DailyAnalysisCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = i0.Variable<DateTime>(date.value);
    }
    if (trendState.present) {
      map['trend_state'] = i0.Variable<String>(trendState.value);
    }
    if (reversalState.present) {
      map['reversal_state'] = i0.Variable<String>(reversalState.value);
    }
    if (supportLevel.present) {
      map['support_level'] = i0.Variable<double>(supportLevel.value);
    }
    if (resistanceLevel.present) {
      map['resistance_level'] = i0.Variable<double>(resistanceLevel.value);
    }
    if (score.present) {
      map['score'] = i0.Variable<double>(score.value);
    }
    if (computedAt.present) {
      map['computed_at'] = i0.Variable<DateTime>(computedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = i0.Variable<int>(rowid.value);
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

i0.Index get idxDailyAnalysisScore => i0.Index(
  'idx_daily_analysis_score',
  'CREATE INDEX idx_daily_analysis_score ON daily_analysis (score)',
);
i0.Index get idxDailyAnalysisSymbolDate => i0.Index(
  'idx_daily_analysis_symbol_date',
  'CREATE INDEX idx_daily_analysis_symbol_date ON daily_analysis (symbol, date)',
);
i0.Index get idxDailyAnalysisDateScore => i0.Index(
  'idx_daily_analysis_date_score',
  'CREATE INDEX idx_daily_analysis_date_score ON daily_analysis (date, score)',
);
i0.Index get idxDailyReasonSymbolDate => i0.Index(
  'idx_daily_reason_symbol_date',
  'CREATE INDEX idx_daily_reason_symbol_date ON daily_reason (symbol, date)',
);

class $DailyReasonTable extends i2.DailyReason
    with i0.TableInfo<$DailyReasonTable, i1.DailyReasonEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyReasonTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: i0.GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
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
  static const i0.VerificationMeta _rankMeta = const i0.VerificationMeta(
    'rank',
  );
  @override
  late final i0.GeneratedColumn<int> rank = i0.GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: i0.DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _reasonTypeMeta = const i0.VerificationMeta(
    'reasonType',
  );
  @override
  late final i0.GeneratedColumn<String> reasonType = i0.GeneratedColumn<String>(
    'reason_type',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _evidenceJsonMeta =
      const i0.VerificationMeta('evidenceJson');
  @override
  late final i0.GeneratedColumn<String> evidenceJson =
      i0.GeneratedColumn<String>(
        'evidence_json',
        aliasedName,
        false,
        type: i0.DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const i0.VerificationMeta _ruleScoreMeta = const i0.VerificationMeta(
    'ruleScore',
  );
  @override
  late final i0.GeneratedColumn<double> ruleScore = i0.GeneratedColumn<double>(
    'rule_score',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
  );
  @override
  List<i0.GeneratedColumn> get $columns => [
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.DailyReasonEntry> instance, {
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
  Set<i0.GeneratedColumn> get $primaryKey => {symbol, date, rank};
  @override
  i1.DailyReasonEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.DailyReasonEntry(
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      rank: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}rank'],
      )!,
      reasonType: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}reason_type'],
      )!,
      evidenceJson: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}evidence_json'],
      )!,
      ruleScore: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}rule_score'],
      )!,
    );
  }

  @override
  $DailyReasonTable createAlias(String alias) {
    return $DailyReasonTable(attachedDatabase, alias);
  }
}

class DailyReasonEntry extends i0.DataClass
    implements i0.Insertable<i1.DailyReasonEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['symbol'] = i0.Variable<String>(symbol);
    map['date'] = i0.Variable<DateTime>(date);
    map['rank'] = i0.Variable<int>(rank);
    map['reason_type'] = i0.Variable<String>(reasonType);
    map['evidence_json'] = i0.Variable<String>(evidenceJson);
    map['rule_score'] = i0.Variable<double>(ruleScore);
    return map;
  }

  i1.DailyReasonCompanion toCompanion(bool nullToAbsent) {
    return i1.DailyReasonCompanion(
      symbol: i0.Value(symbol),
      date: i0.Value(date),
      rank: i0.Value(rank),
      reasonType: i0.Value(reasonType),
      evidenceJson: i0.Value(evidenceJson),
      ruleScore: i0.Value(ruleScore),
    );
  }

  factory DailyReasonEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime>(date),
      'rank': serializer.toJson<int>(rank),
      'reasonType': serializer.toJson<String>(reasonType),
      'evidenceJson': serializer.toJson<String>(evidenceJson),
      'ruleScore': serializer.toJson<double>(ruleScore),
    };
  }

  i1.DailyReasonEntry copyWith({
    String? symbol,
    DateTime? date,
    int? rank,
    String? reasonType,
    String? evidenceJson,
    double? ruleScore,
  }) => i1.DailyReasonEntry(
    symbol: symbol ?? this.symbol,
    date: date ?? this.date,
    rank: rank ?? this.rank,
    reasonType: reasonType ?? this.reasonType,
    evidenceJson: evidenceJson ?? this.evidenceJson,
    ruleScore: ruleScore ?? this.ruleScore,
  );
  DailyReasonEntry copyWithCompanion(i1.DailyReasonCompanion data) {
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
      (other is i1.DailyReasonEntry &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.rank == this.rank &&
          other.reasonType == this.reasonType &&
          other.evidenceJson == this.evidenceJson &&
          other.ruleScore == this.ruleScore);
}

class DailyReasonCompanion extends i0.UpdateCompanion<i1.DailyReasonEntry> {
  final i0.Value<String> symbol;
  final i0.Value<DateTime> date;
  final i0.Value<int> rank;
  final i0.Value<String> reasonType;
  final i0.Value<String> evidenceJson;
  final i0.Value<double> ruleScore;
  final i0.Value<int> rowid;
  const DailyReasonCompanion({
    this.symbol = const i0.Value.absent(),
    this.date = const i0.Value.absent(),
    this.rank = const i0.Value.absent(),
    this.reasonType = const i0.Value.absent(),
    this.evidenceJson = const i0.Value.absent(),
    this.ruleScore = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  DailyReasonCompanion.insert({
    required String symbol,
    required DateTime date,
    required int rank,
    required String reasonType,
    required String evidenceJson,
    this.ruleScore = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol),
       date = i0.Value(date),
       rank = i0.Value(rank),
       reasonType = i0.Value(reasonType),
       evidenceJson = i0.Value(evidenceJson);
  static i0.Insertable<i1.DailyReasonEntry> custom({
    i0.Expression<String>? symbol,
    i0.Expression<DateTime>? date,
    i0.Expression<int>? rank,
    i0.Expression<String>? reasonType,
    i0.Expression<String>? evidenceJson,
    i0.Expression<double>? ruleScore,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (rank != null) 'rank': rank,
      if (reasonType != null) 'reason_type': reasonType,
      if (evidenceJson != null) 'evidence_json': evidenceJson,
      if (ruleScore != null) 'rule_score': ruleScore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  i1.DailyReasonCompanion copyWith({
    i0.Value<String>? symbol,
    i0.Value<DateTime>? date,
    i0.Value<int>? rank,
    i0.Value<String>? reasonType,
    i0.Value<String>? evidenceJson,
    i0.Value<double>? ruleScore,
    i0.Value<int>? rowid,
  }) {
    return i1.DailyReasonCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (date.present) {
      map['date'] = i0.Variable<DateTime>(date.value);
    }
    if (rank.present) {
      map['rank'] = i0.Variable<int>(rank.value);
    }
    if (reasonType.present) {
      map['reason_type'] = i0.Variable<String>(reasonType.value);
    }
    if (evidenceJson.present) {
      map['evidence_json'] = i0.Variable<String>(evidenceJson.value);
    }
    if (ruleScore.present) {
      map['rule_score'] = i0.Variable<double>(ruleScore.value);
    }
    if (rowid.present) {
      map['rowid'] = i0.Variable<int>(rowid.value);
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

i0.Index get idxDailyRecommendationDate => i0.Index(
  'idx_daily_recommendation_date',
  'CREATE INDEX idx_daily_recommendation_date ON daily_recommendation (date)',
);

class $DailyRecommendationTable extends i2.DailyRecommendation
    with i0.TableInfo<$DailyRecommendationTable, i1.DailyRecommendationEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyRecommendationTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _rankMeta = const i0.VerificationMeta(
    'rank',
  );
  @override
  late final i0.GeneratedColumn<int> rank = i0.GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: i0.DriftSqlType.int,
    requiredDuringInsert: true,
  );
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
    defaultConstraints: i0.GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_master (symbol) ON DELETE CASCADE',
    ),
  );
  static const i0.VerificationMeta _scoreMeta = const i0.VerificationMeta(
    'score',
  );
  @override
  late final i0.GeneratedColumn<double> score = i0.GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<i0.GeneratedColumn> get $columns => [date, rank, symbol, score];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_recommendation';
  @override
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.DailyRecommendationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {date, rank};
  @override
  List<Set<i0.GeneratedColumn>> get uniqueKeys => [
    {date, symbol},
  ];
  @override
  i1.DailyRecommendationEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.DailyRecommendationEntry(
      date: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      rank: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}rank'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      score: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
    );
  }

  @override
  $DailyRecommendationTable createAlias(String alias) {
    return $DailyRecommendationTable(attachedDatabase, alias);
  }
}

class DailyRecommendationEntry extends i0.DataClass
    implements i0.Insertable<i1.DailyRecommendationEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['date'] = i0.Variable<DateTime>(date);
    map['rank'] = i0.Variable<int>(rank);
    map['symbol'] = i0.Variable<String>(symbol);
    map['score'] = i0.Variable<double>(score);
    return map;
  }

  i1.DailyRecommendationCompanion toCompanion(bool nullToAbsent) {
    return i1.DailyRecommendationCompanion(
      date: i0.Value(date),
      rank: i0.Value(rank),
      symbol: i0.Value(symbol),
      score: i0.Value(score),
    );
  }

  factory DailyRecommendationEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return DailyRecommendationEntry(
      date: serializer.fromJson<DateTime>(json['date']),
      rank: serializer.fromJson<int>(json['rank']),
      symbol: serializer.fromJson<String>(json['symbol']),
      score: serializer.fromJson<double>(json['score']),
    );
  }
  @override
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'rank': serializer.toJson<int>(rank),
      'symbol': serializer.toJson<String>(symbol),
      'score': serializer.toJson<double>(score),
    };
  }

  i1.DailyRecommendationEntry copyWith({
    DateTime? date,
    int? rank,
    String? symbol,
    double? score,
  }) => i1.DailyRecommendationEntry(
    date: date ?? this.date,
    rank: rank ?? this.rank,
    symbol: symbol ?? this.symbol,
    score: score ?? this.score,
  );
  DailyRecommendationEntry copyWithCompanion(
    i1.DailyRecommendationCompanion data,
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
      (other is i1.DailyRecommendationEntry &&
          other.date == this.date &&
          other.rank == this.rank &&
          other.symbol == this.symbol &&
          other.score == this.score);
}

class DailyRecommendationCompanion
    extends i0.UpdateCompanion<i1.DailyRecommendationEntry> {
  final i0.Value<DateTime> date;
  final i0.Value<int> rank;
  final i0.Value<String> symbol;
  final i0.Value<double> score;
  final i0.Value<int> rowid;
  const DailyRecommendationCompanion({
    this.date = const i0.Value.absent(),
    this.rank = const i0.Value.absent(),
    this.symbol = const i0.Value.absent(),
    this.score = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  DailyRecommendationCompanion.insert({
    required DateTime date,
    required int rank,
    required String symbol,
    required double score,
    this.rowid = const i0.Value.absent(),
  }) : date = i0.Value(date),
       rank = i0.Value(rank),
       symbol = i0.Value(symbol),
       score = i0.Value(score);
  static i0.Insertable<i1.DailyRecommendationEntry> custom({
    i0.Expression<DateTime>? date,
    i0.Expression<int>? rank,
    i0.Expression<String>? symbol,
    i0.Expression<double>? score,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
      if (date != null) 'date': date,
      if (rank != null) 'rank': rank,
      if (symbol != null) 'symbol': symbol,
      if (score != null) 'score': score,
      if (rowid != null) 'rowid': rowid,
    });
  }

  i1.DailyRecommendationCompanion copyWith({
    i0.Value<DateTime>? date,
    i0.Value<int>? rank,
    i0.Value<String>? symbol,
    i0.Value<double>? score,
    i0.Value<int>? rowid,
  }) {
    return i1.DailyRecommendationCompanion(
      date: date ?? this.date,
      rank: rank ?? this.rank,
      symbol: symbol ?? this.symbol,
      score: score ?? this.score,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (date.present) {
      map['date'] = i0.Variable<DateTime>(date.value);
    }
    if (rank.present) {
      map['rank'] = i0.Variable<int>(rank.value);
    }
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (score.present) {
      map['score'] = i0.Variable<double>(score.value);
    }
    if (rowid.present) {
      map['rowid'] = i0.Variable<int>(rowid.value);
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

i0.Index get idxDailyRecommendationSymbol => i0.Index(
  'idx_daily_recommendation_symbol',
  'CREATE INDEX idx_daily_recommendation_symbol ON daily_recommendation (symbol)',
);
i0.Index get idxDailyRecommendationDateSymbol => i0.Index(
  'idx_daily_recommendation_date_symbol',
  'CREATE INDEX idx_daily_recommendation_date_symbol ON daily_recommendation (date, symbol)',
);
i0.Index get idxRuleAccuracyRule => i0.Index(
  'idx_rule_accuracy_rule',
  'CREATE INDEX idx_rule_accuracy_rule ON rule_accuracy (rule_id)',
);

class $RuleAccuracyTable extends i2.RuleAccuracy
    with i0.TableInfo<$RuleAccuracyTable, i1.RuleAccuracyEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleAccuracyTable(this.attachedDatabase, [this._alias]);
  static const i0.VerificationMeta _ruleIdMeta = const i0.VerificationMeta(
    'ruleId',
  );
  @override
  late final i0.GeneratedColumn<String> ruleId = i0.GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _periodMeta = const i0.VerificationMeta(
    'period',
  );
  @override
  late final i0.GeneratedColumn<String> period = i0.GeneratedColumn<String>(
    'period',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _triggerCountMeta =
      const i0.VerificationMeta('triggerCount');
  @override
  late final i0.GeneratedColumn<int> triggerCount = i0.GeneratedColumn<int>(
    'trigger_count',
    aliasedName,
    false,
    type: i0.DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
  );
  static const i0.VerificationMeta _successCountMeta =
      const i0.VerificationMeta('successCount');
  @override
  late final i0.GeneratedColumn<int> successCount = i0.GeneratedColumn<int>(
    'success_count',
    aliasedName,
    false,
    type: i0.DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
  );
  static const i0.VerificationMeta _avgReturnMeta = const i0.VerificationMeta(
    'avgReturn',
  );
  @override
  late final i0.GeneratedColumn<double> avgReturn = i0.GeneratedColumn<double>(
    'avg_return',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.RuleAccuracyEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {ruleId, period};
  @override
  i1.RuleAccuracyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.RuleAccuracyEntry(
      ruleId: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      )!,
      period: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}period'],
      )!,
      triggerCount: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}trigger_count'],
      )!,
      successCount: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}success_count'],
      )!,
      avgReturn: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}avg_return'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RuleAccuracyTable createAlias(String alias) {
    return $RuleAccuracyTable(attachedDatabase, alias);
  }
}

class RuleAccuracyEntry extends i0.DataClass
    implements i0.Insertable<i1.RuleAccuracyEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['rule_id'] = i0.Variable<String>(ruleId);
    map['period'] = i0.Variable<String>(period);
    map['trigger_count'] = i0.Variable<int>(triggerCount);
    map['success_count'] = i0.Variable<int>(successCount);
    map['avg_return'] = i0.Variable<double>(avgReturn);
    map['updated_at'] = i0.Variable<DateTime>(updatedAt);
    return map;
  }

  i1.RuleAccuracyCompanion toCompanion(bool nullToAbsent) {
    return i1.RuleAccuracyCompanion(
      ruleId: i0.Value(ruleId),
      period: i0.Value(period),
      triggerCount: i0.Value(triggerCount),
      successCount: i0.Value(successCount),
      avgReturn: i0.Value(avgReturn),
      updatedAt: i0.Value(updatedAt),
    );
  }

  factory RuleAccuracyEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ruleId': serializer.toJson<String>(ruleId),
      'period': serializer.toJson<String>(period),
      'triggerCount': serializer.toJson<int>(triggerCount),
      'successCount': serializer.toJson<int>(successCount),
      'avgReturn': serializer.toJson<double>(avgReturn),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  i1.RuleAccuracyEntry copyWith({
    String? ruleId,
    String? period,
    int? triggerCount,
    int? successCount,
    double? avgReturn,
    DateTime? updatedAt,
  }) => i1.RuleAccuracyEntry(
    ruleId: ruleId ?? this.ruleId,
    period: period ?? this.period,
    triggerCount: triggerCount ?? this.triggerCount,
    successCount: successCount ?? this.successCount,
    avgReturn: avgReturn ?? this.avgReturn,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RuleAccuracyEntry copyWithCompanion(i1.RuleAccuracyCompanion data) {
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
      (other is i1.RuleAccuracyEntry &&
          other.ruleId == this.ruleId &&
          other.period == this.period &&
          other.triggerCount == this.triggerCount &&
          other.successCount == this.successCount &&
          other.avgReturn == this.avgReturn &&
          other.updatedAt == this.updatedAt);
}

class RuleAccuracyCompanion extends i0.UpdateCompanion<i1.RuleAccuracyEntry> {
  final i0.Value<String> ruleId;
  final i0.Value<String> period;
  final i0.Value<int> triggerCount;
  final i0.Value<int> successCount;
  final i0.Value<double> avgReturn;
  final i0.Value<DateTime> updatedAt;
  final i0.Value<int> rowid;
  const RuleAccuracyCompanion({
    this.ruleId = const i0.Value.absent(),
    this.period = const i0.Value.absent(),
    this.triggerCount = const i0.Value.absent(),
    this.successCount = const i0.Value.absent(),
    this.avgReturn = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  RuleAccuracyCompanion.insert({
    required String ruleId,
    required String period,
    this.triggerCount = const i0.Value.absent(),
    this.successCount = const i0.Value.absent(),
    this.avgReturn = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  }) : ruleId = i0.Value(ruleId),
       period = i0.Value(period);
  static i0.Insertable<i1.RuleAccuracyEntry> custom({
    i0.Expression<String>? ruleId,
    i0.Expression<String>? period,
    i0.Expression<int>? triggerCount,
    i0.Expression<int>? successCount,
    i0.Expression<double>? avgReturn,
    i0.Expression<DateTime>? updatedAt,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
      if (ruleId != null) 'rule_id': ruleId,
      if (period != null) 'period': period,
      if (triggerCount != null) 'trigger_count': triggerCount,
      if (successCount != null) 'success_count': successCount,
      if (avgReturn != null) 'avg_return': avgReturn,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  i1.RuleAccuracyCompanion copyWith({
    i0.Value<String>? ruleId,
    i0.Value<String>? period,
    i0.Value<int>? triggerCount,
    i0.Value<int>? successCount,
    i0.Value<double>? avgReturn,
    i0.Value<DateTime>? updatedAt,
    i0.Value<int>? rowid,
  }) {
    return i1.RuleAccuracyCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (ruleId.present) {
      map['rule_id'] = i0.Variable<String>(ruleId.value);
    }
    if (period.present) {
      map['period'] = i0.Variable<String>(period.value);
    }
    if (triggerCount.present) {
      map['trigger_count'] = i0.Variable<int>(triggerCount.value);
    }
    if (successCount.present) {
      map['success_count'] = i0.Variable<int>(successCount.value);
    }
    if (avgReturn.present) {
      map['avg_return'] = i0.Variable<double>(avgReturn.value);
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

i0.Index get idxRecValidationDate => i0.Index(
  'idx_rec_validation_date',
  'CREATE INDEX idx_rec_validation_date ON recommendation_validation (recommendation_date)',
);

class $RecommendationValidationTable extends i2.RecommendationValidation
    with
        i0.TableInfo<
          $RecommendationValidationTable,
          i1.RecommendationValidationEntry
        > {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecommendationValidationTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _recommendationDateMeta =
      const i0.VerificationMeta('recommendationDate');
  @override
  late final i0.GeneratedColumn<DateTime> recommendationDate =
      i0.GeneratedColumn<DateTime>(
        'recommendation_date',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
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
  static const i0.VerificationMeta _primaryRuleIdMeta =
      const i0.VerificationMeta('primaryRuleId');
  @override
  late final i0.GeneratedColumn<String> primaryRuleId =
      i0.GeneratedColumn<String>(
        'primary_rule_id',
        aliasedName,
        false,
        type: i0.DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const i0.VerificationMeta _entryPriceMeta = const i0.VerificationMeta(
    'entryPrice',
  );
  @override
  late final i0.GeneratedColumn<double> entryPrice = i0.GeneratedColumn<double>(
    'entry_price',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _exitPriceMeta = const i0.VerificationMeta(
    'exitPrice',
  );
  @override
  late final i0.GeneratedColumn<double> exitPrice = i0.GeneratedColumn<double>(
    'exit_price',
    aliasedName,
    true,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _returnRateMeta = const i0.VerificationMeta(
    'returnRate',
  );
  @override
  late final i0.GeneratedColumn<double> returnRate = i0.GeneratedColumn<double>(
    'return_rate',
    aliasedName,
    true,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _isSuccessMeta = const i0.VerificationMeta(
    'isSuccess',
  );
  @override
  late final i0.GeneratedColumn<bool> isSuccess = i0.GeneratedColumn<bool>(
    'is_success',
    aliasedName,
    true,
    type: i0.DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: i0.GeneratedColumn.constraintIsAlways(
      'CHECK ("is_success" IN (0, 1))',
    ),
  );
  static const i0.VerificationMeta _validationDateMeta =
      const i0.VerificationMeta('validationDate');
  @override
  late final i0.GeneratedColumn<DateTime> validationDate =
      i0.GeneratedColumn<DateTime>(
        'validation_date',
        aliasedName,
        true,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const i0.VerificationMeta _holdingDaysMeta = const i0.VerificationMeta(
    'holdingDays',
  );
  @override
  late final i0.GeneratedColumn<int> holdingDays = i0.GeneratedColumn<int>(
    'holding_days',
    aliasedName,
    false,
    type: i0.DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(5),
  );
  @override
  List<i0.GeneratedColumn> get $columns => [
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.RecommendationValidationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<i0.GeneratedColumn>> get uniqueKeys => [
    {recommendationDate, symbol, holdingDays},
  ];
  @override
  i1.RecommendationValidationEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.RecommendationValidationEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recommendationDate: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}recommendation_date'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      primaryRuleId: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}primary_rule_id'],
      )!,
      entryPrice: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}entry_price'],
      )!,
      exitPrice: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}exit_price'],
      ),
      returnRate: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}return_rate'],
      ),
      isSuccess: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.bool,
        data['${effectivePrefix}is_success'],
      ),
      validationDate: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}validation_date'],
      ),
      holdingDays: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}holding_days'],
      )!,
    );
  }

  @override
  $RecommendationValidationTable createAlias(String alias) {
    return $RecommendationValidationTable(attachedDatabase, alias);
  }
}

class RecommendationValidationEntry extends i0.DataClass
    implements i0.Insertable<i1.RecommendationValidationEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['recommendation_date'] = i0.Variable<DateTime>(recommendationDate);
    map['symbol'] = i0.Variable<String>(symbol);
    map['primary_rule_id'] = i0.Variable<String>(primaryRuleId);
    map['entry_price'] = i0.Variable<double>(entryPrice);
    if (!nullToAbsent || exitPrice != null) {
      map['exit_price'] = i0.Variable<double>(exitPrice);
    }
    if (!nullToAbsent || returnRate != null) {
      map['return_rate'] = i0.Variable<double>(returnRate);
    }
    if (!nullToAbsent || isSuccess != null) {
      map['is_success'] = i0.Variable<bool>(isSuccess);
    }
    if (!nullToAbsent || validationDate != null) {
      map['validation_date'] = i0.Variable<DateTime>(validationDate);
    }
    map['holding_days'] = i0.Variable<int>(holdingDays);
    return map;
  }

  i1.RecommendationValidationCompanion toCompanion(bool nullToAbsent) {
    return i1.RecommendationValidationCompanion(
      id: i0.Value(id),
      recommendationDate: i0.Value(recommendationDate),
      symbol: i0.Value(symbol),
      primaryRuleId: i0.Value(primaryRuleId),
      entryPrice: i0.Value(entryPrice),
      exitPrice: exitPrice == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(exitPrice),
      returnRate: returnRate == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(returnRate),
      isSuccess: isSuccess == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(isSuccess),
      validationDate: validationDate == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(validationDate),
      holdingDays: i0.Value(holdingDays),
    );
  }

  factory RecommendationValidationEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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

  i1.RecommendationValidationEntry copyWith({
    int? id,
    DateTime? recommendationDate,
    String? symbol,
    String? primaryRuleId,
    double? entryPrice,
    i0.Value<double?> exitPrice = const i0.Value.absent(),
    i0.Value<double?> returnRate = const i0.Value.absent(),
    i0.Value<bool?> isSuccess = const i0.Value.absent(),
    i0.Value<DateTime?> validationDate = const i0.Value.absent(),
    int? holdingDays,
  }) => i1.RecommendationValidationEntry(
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
    i1.RecommendationValidationCompanion data,
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
      (other is i1.RecommendationValidationEntry &&
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
    extends i0.UpdateCompanion<i1.RecommendationValidationEntry> {
  final i0.Value<int> id;
  final i0.Value<DateTime> recommendationDate;
  final i0.Value<String> symbol;
  final i0.Value<String> primaryRuleId;
  final i0.Value<double> entryPrice;
  final i0.Value<double?> exitPrice;
  final i0.Value<double?> returnRate;
  final i0.Value<bool?> isSuccess;
  final i0.Value<DateTime?> validationDate;
  final i0.Value<int> holdingDays;
  const RecommendationValidationCompanion({
    this.id = const i0.Value.absent(),
    this.recommendationDate = const i0.Value.absent(),
    this.symbol = const i0.Value.absent(),
    this.primaryRuleId = const i0.Value.absent(),
    this.entryPrice = const i0.Value.absent(),
    this.exitPrice = const i0.Value.absent(),
    this.returnRate = const i0.Value.absent(),
    this.isSuccess = const i0.Value.absent(),
    this.validationDate = const i0.Value.absent(),
    this.holdingDays = const i0.Value.absent(),
  });
  RecommendationValidationCompanion.insert({
    this.id = const i0.Value.absent(),
    required DateTime recommendationDate,
    required String symbol,
    required String primaryRuleId,
    required double entryPrice,
    this.exitPrice = const i0.Value.absent(),
    this.returnRate = const i0.Value.absent(),
    this.isSuccess = const i0.Value.absent(),
    this.validationDate = const i0.Value.absent(),
    this.holdingDays = const i0.Value.absent(),
  }) : recommendationDate = i0.Value(recommendationDate),
       symbol = i0.Value(symbol),
       primaryRuleId = i0.Value(primaryRuleId),
       entryPrice = i0.Value(entryPrice);
  static i0.Insertable<i1.RecommendationValidationEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<DateTime>? recommendationDate,
    i0.Expression<String>? symbol,
    i0.Expression<String>? primaryRuleId,
    i0.Expression<double>? entryPrice,
    i0.Expression<double>? exitPrice,
    i0.Expression<double>? returnRate,
    i0.Expression<bool>? isSuccess,
    i0.Expression<DateTime>? validationDate,
    i0.Expression<int>? holdingDays,
  }) {
    return i0.RawValuesInsertable({
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

  i1.RecommendationValidationCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<DateTime>? recommendationDate,
    i0.Value<String>? symbol,
    i0.Value<String>? primaryRuleId,
    i0.Value<double>? entryPrice,
    i0.Value<double?>? exitPrice,
    i0.Value<double?>? returnRate,
    i0.Value<bool?>? isSuccess,
    i0.Value<DateTime?>? validationDate,
    i0.Value<int>? holdingDays,
  }) {
    return i1.RecommendationValidationCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (id.present) {
      map['id'] = i0.Variable<int>(id.value);
    }
    if (recommendationDate.present) {
      map['recommendation_date'] = i0.Variable<DateTime>(
        recommendationDate.value,
      );
    }
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (primaryRuleId.present) {
      map['primary_rule_id'] = i0.Variable<String>(primaryRuleId.value);
    }
    if (entryPrice.present) {
      map['entry_price'] = i0.Variable<double>(entryPrice.value);
    }
    if (exitPrice.present) {
      map['exit_price'] = i0.Variable<double>(exitPrice.value);
    }
    if (returnRate.present) {
      map['return_rate'] = i0.Variable<double>(returnRate.value);
    }
    if (isSuccess.present) {
      map['is_success'] = i0.Variable<bool>(isSuccess.value);
    }
    if (validationDate.present) {
      map['validation_date'] = i0.Variable<DateTime>(validationDate.value);
    }
    if (holdingDays.present) {
      map['holding_days'] = i0.Variable<int>(holdingDays.value);
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

i0.Index get idxRecValidationSymbol => i0.Index(
  'idx_rec_validation_symbol',
  'CREATE INDEX idx_rec_validation_symbol ON recommendation_validation (symbol)',
);
