// dart format width=80
// ignore_for_file: type=lint
import 'package:drift/drift.dart' as i0;
import 'package:afterclose/data/database/tables/portfolio_tables.drift.dart'
    as i1;
import 'package:afterclose/data/database/tables/portfolio_tables.dart' as i2;
import 'package:drift/src/runtime/query_builder/query_builder.dart' as i3;
import 'package:afterclose/data/database/tables/stock_master.drift.dart' as i4;
import 'package:drift/internal/modular.dart' as i5;

typedef $$PortfolioPositionTableCreateCompanionBuilder =
    i1.PortfolioPositionCompanion Function({
      i0.Value<int> id,
      required String symbol,
      i0.Value<double> quantity,
      i0.Value<double> avgCost,
      i0.Value<double> realizedPnl,
      i0.Value<double> totalDividendReceived,
      i0.Value<String?> note,
      i0.Value<DateTime> createdAt,
      i0.Value<DateTime> updatedAt,
    });
typedef $$PortfolioPositionTableUpdateCompanionBuilder =
    i1.PortfolioPositionCompanion Function({
      i0.Value<int> id,
      i0.Value<String> symbol,
      i0.Value<double> quantity,
      i0.Value<double> avgCost,
      i0.Value<double> realizedPnl,
      i0.Value<double> totalDividendReceived,
      i0.Value<String?> note,
      i0.Value<DateTime> createdAt,
      i0.Value<DateTime> updatedAt,
    });

final class $$PortfolioPositionTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$PortfolioPositionTable,
          i1.PortfolioPositionEntry
        > {
  $$PortfolioPositionTableReferences(
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
                  .resultSet<i1.$PortfolioPositionTable>('portfolio_position')
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

class $$PortfolioPositionTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PortfolioPositionTable> {
  $$PortfolioPositionTableFilterComposer({
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

  i0.ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get avgCost => $composableBuilder(
    column: $table.avgCost,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get totalDividendReceived => $composableBuilder(
    column: $table.totalDividendReceived,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

class $$PortfolioPositionTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PortfolioPositionTable> {
  $$PortfolioPositionTableOrderingComposer({
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

  i0.ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get avgCost => $composableBuilder(
    column: $table.avgCost,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get totalDividendReceived => $composableBuilder(
    column: $table.totalDividendReceived,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

class $$PortfolioPositionTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PortfolioPositionTable> {
  $$PortfolioPositionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  i0.GeneratedColumn<double> get avgCost =>
      $composableBuilder(column: $table.avgCost, builder: (column) => column);

  i0.GeneratedColumn<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => column,
  );

  i0.GeneratedColumn<double> get totalDividendReceived => $composableBuilder(
    column: $table.totalDividendReceived,
    builder: (column) => column,
  );

  i0.GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

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

class $$PortfolioPositionTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$PortfolioPositionTable,
          i1.PortfolioPositionEntry,
          i1.$$PortfolioPositionTableFilterComposer,
          i1.$$PortfolioPositionTableOrderingComposer,
          i1.$$PortfolioPositionTableAnnotationComposer,
          $$PortfolioPositionTableCreateCompanionBuilder,
          $$PortfolioPositionTableUpdateCompanionBuilder,
          (i1.PortfolioPositionEntry, i1.$$PortfolioPositionTableReferences),
          i1.PortfolioPositionEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$PortfolioPositionTableTableManager(
    i0.GeneratedDatabase db,
    i1.$PortfolioPositionTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$PortfolioPositionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => i1
              .$$PortfolioPositionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$PortfolioPositionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<double> quantity = const i0.Value.absent(),
                i0.Value<double> avgCost = const i0.Value.absent(),
                i0.Value<double> realizedPnl = const i0.Value.absent(),
                i0.Value<double> totalDividendReceived =
                    const i0.Value.absent(),
                i0.Value<String?> note = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
              }) => i1.PortfolioPositionCompanion(
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
                i0.Value<int> id = const i0.Value.absent(),
                required String symbol,
                i0.Value<double> quantity = const i0.Value.absent(),
                i0.Value<double> avgCost = const i0.Value.absent(),
                i0.Value<double> realizedPnl = const i0.Value.absent(),
                i0.Value<double> totalDividendReceived =
                    const i0.Value.absent(),
                i0.Value<String?> note = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
              }) => i1.PortfolioPositionCompanion.insert(
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
                  i1.$$PortfolioPositionTableReferences(db, table, e),
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
                                    .$$PortfolioPositionTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1
                                    .$$PortfolioPositionTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$PortfolioPositionTable,
      i1.PortfolioPositionEntry,
      i1.$$PortfolioPositionTableFilterComposer,
      i1.$$PortfolioPositionTableOrderingComposer,
      i1.$$PortfolioPositionTableAnnotationComposer,
      $$PortfolioPositionTableCreateCompanionBuilder,
      $$PortfolioPositionTableUpdateCompanionBuilder,
      (i1.PortfolioPositionEntry, i1.$$PortfolioPositionTableReferences),
      i1.PortfolioPositionEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
typedef $$PortfolioTransactionTableCreateCompanionBuilder =
    i1.PortfolioTransactionCompanion Function({
      i0.Value<int> id,
      required String symbol,
      required String txType,
      required DateTime date,
      required double quantity,
      required double price,
      i0.Value<double> fee,
      i0.Value<double> tax,
      i0.Value<String?> note,
      i0.Value<DateTime> createdAt,
    });
typedef $$PortfolioTransactionTableUpdateCompanionBuilder =
    i1.PortfolioTransactionCompanion Function({
      i0.Value<int> id,
      i0.Value<String> symbol,
      i0.Value<String> txType,
      i0.Value<DateTime> date,
      i0.Value<double> quantity,
      i0.Value<double> price,
      i0.Value<double> fee,
      i0.Value<double> tax,
      i0.Value<String?> note,
      i0.Value<DateTime> createdAt,
    });

final class $$PortfolioTransactionTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$PortfolioTransactionTable,
          i1.PortfolioTransactionEntry
        > {
  $$PortfolioTransactionTableReferences(
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
                  .resultSet<i1.$PortfolioTransactionTable>(
                    'portfolio_transaction',
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

class $$PortfolioTransactionTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PortfolioTransactionTable> {
  $$PortfolioTransactionTableFilterComposer({
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

  i0.ColumnFilters<String> get txType => $composableBuilder(
    column: $table.txType,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get fee => $composableBuilder(
    column: $table.fee,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

class $$PortfolioTransactionTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PortfolioTransactionTable> {
  $$PortfolioTransactionTableOrderingComposer({
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

  i0.ColumnOrderings<String> get txType => $composableBuilder(
    column: $table.txType,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get fee => $composableBuilder(
    column: $table.fee,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

class $$PortfolioTransactionTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PortfolioTransactionTable> {
  $$PortfolioTransactionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<String> get txType =>
      $composableBuilder(column: $table.txType, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  i0.GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  i0.GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  i0.GeneratedColumn<double> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => column);

  i0.GeneratedColumn<double> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  i0.GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

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

class $$PortfolioTransactionTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$PortfolioTransactionTable,
          i1.PortfolioTransactionEntry,
          i1.$$PortfolioTransactionTableFilterComposer,
          i1.$$PortfolioTransactionTableOrderingComposer,
          i1.$$PortfolioTransactionTableAnnotationComposer,
          $$PortfolioTransactionTableCreateCompanionBuilder,
          $$PortfolioTransactionTableUpdateCompanionBuilder,
          (
            i1.PortfolioTransactionEntry,
            i1.$$PortfolioTransactionTableReferences,
          ),
          i1.PortfolioTransactionEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$PortfolioTransactionTableTableManager(
    i0.GeneratedDatabase db,
    i1.$PortfolioTransactionTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$PortfolioTransactionTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              i1.$$PortfolioTransactionTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              i1.$$PortfolioTransactionTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<String> txType = const i0.Value.absent(),
                i0.Value<DateTime> date = const i0.Value.absent(),
                i0.Value<double> quantity = const i0.Value.absent(),
                i0.Value<double> price = const i0.Value.absent(),
                i0.Value<double> fee = const i0.Value.absent(),
                i0.Value<double> tax = const i0.Value.absent(),
                i0.Value<String?> note = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
              }) => i1.PortfolioTransactionCompanion(
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
                i0.Value<int> id = const i0.Value.absent(),
                required String symbol,
                required String txType,
                required DateTime date,
                required double quantity,
                required double price,
                i0.Value<double> fee = const i0.Value.absent(),
                i0.Value<double> tax = const i0.Value.absent(),
                i0.Value<String?> note = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
              }) => i1.PortfolioTransactionCompanion.insert(
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
                  i1.$$PortfolioTransactionTableReferences(db, table, e),
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
                                    .$$PortfolioTransactionTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1
                                    .$$PortfolioTransactionTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$PortfolioTransactionTable,
      i1.PortfolioTransactionEntry,
      i1.$$PortfolioTransactionTableFilterComposer,
      i1.$$PortfolioTransactionTableOrderingComposer,
      i1.$$PortfolioTransactionTableAnnotationComposer,
      $$PortfolioTransactionTableCreateCompanionBuilder,
      $$PortfolioTransactionTableUpdateCompanionBuilder,
      (i1.PortfolioTransactionEntry, i1.$$PortfolioTransactionTableReferences),
      i1.PortfolioTransactionEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
i0.Index get idxPortfolioPositionSymbol => i0.Index(
  'idx_portfolio_position_symbol',
  'CREATE INDEX idx_portfolio_position_symbol ON portfolio_position (symbol)',
);

class $PortfolioPositionTable extends i2.PortfolioPosition
    with i0.TableInfo<$PortfolioPositionTable, i1.PortfolioPositionEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfolioPositionTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _quantityMeta = const i0.VerificationMeta(
    'quantity',
  );
  @override
  late final i0.GeneratedColumn<double> quantity = i0.GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
  );
  static const i0.VerificationMeta _avgCostMeta = const i0.VerificationMeta(
    'avgCost',
  );
  @override
  late final i0.GeneratedColumn<double> avgCost = i0.GeneratedColumn<double>(
    'avg_cost',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
  );
  static const i0.VerificationMeta _realizedPnlMeta = const i0.VerificationMeta(
    'realizedPnl',
  );
  @override
  late final i0.GeneratedColumn<double> realizedPnl =
      i0.GeneratedColumn<double>(
        'realized_pnl',
        aliasedName,
        false,
        type: i0.DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const i3.Constant(0),
      );
  static const i0.VerificationMeta _totalDividendReceivedMeta =
      const i0.VerificationMeta('totalDividendReceived');
  @override
  late final i0.GeneratedColumn<double> totalDividendReceived =
      i0.GeneratedColumn<double>(
        'total_dividend_received',
        aliasedName,
        false,
        type: i0.DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const i3.Constant(0),
      );
  static const i0.VerificationMeta _noteMeta = const i0.VerificationMeta(
    'note',
  );
  @override
  late final i0.GeneratedColumn<String> note = i0.GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.PortfolioPositionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  i1.PortfolioPositionEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.PortfolioPositionEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      avgCost: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}avg_cost'],
      )!,
      realizedPnl: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}realized_pnl'],
      )!,
      totalDividendReceived: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}total_dividend_received'],
      )!,
      note: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PortfolioPositionTable createAlias(String alias) {
    return $PortfolioPositionTable(attachedDatabase, alias);
  }
}

class PortfolioPositionEntry extends i0.DataClass
    implements i0.Insertable<i1.PortfolioPositionEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['symbol'] = i0.Variable<String>(symbol);
    map['quantity'] = i0.Variable<double>(quantity);
    map['avg_cost'] = i0.Variable<double>(avgCost);
    map['realized_pnl'] = i0.Variable<double>(realizedPnl);
    map['total_dividend_received'] = i0.Variable<double>(totalDividendReceived);
    if (!nullToAbsent || note != null) {
      map['note'] = i0.Variable<String>(note);
    }
    map['created_at'] = i0.Variable<DateTime>(createdAt);
    map['updated_at'] = i0.Variable<DateTime>(updatedAt);
    return map;
  }

  i1.PortfolioPositionCompanion toCompanion(bool nullToAbsent) {
    return i1.PortfolioPositionCompanion(
      id: i0.Value(id),
      symbol: i0.Value(symbol),
      quantity: i0.Value(quantity),
      avgCost: i0.Value(avgCost),
      realizedPnl: i0.Value(realizedPnl),
      totalDividendReceived: i0.Value(totalDividendReceived),
      note: note == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(note),
      createdAt: i0.Value(createdAt),
      updatedAt: i0.Value(updatedAt),
    );
  }

  factory PortfolioPositionEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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

  i1.PortfolioPositionEntry copyWith({
    int? id,
    String? symbol,
    double? quantity,
    double? avgCost,
    double? realizedPnl,
    double? totalDividendReceived,
    i0.Value<String?> note = const i0.Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => i1.PortfolioPositionEntry(
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
  PortfolioPositionEntry copyWithCompanion(i1.PortfolioPositionCompanion data) {
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
      (other is i1.PortfolioPositionEntry &&
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
    extends i0.UpdateCompanion<i1.PortfolioPositionEntry> {
  final i0.Value<int> id;
  final i0.Value<String> symbol;
  final i0.Value<double> quantity;
  final i0.Value<double> avgCost;
  final i0.Value<double> realizedPnl;
  final i0.Value<double> totalDividendReceived;
  final i0.Value<String?> note;
  final i0.Value<DateTime> createdAt;
  final i0.Value<DateTime> updatedAt;
  const PortfolioPositionCompanion({
    this.id = const i0.Value.absent(),
    this.symbol = const i0.Value.absent(),
    this.quantity = const i0.Value.absent(),
    this.avgCost = const i0.Value.absent(),
    this.realizedPnl = const i0.Value.absent(),
    this.totalDividendReceived = const i0.Value.absent(),
    this.note = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
  });
  PortfolioPositionCompanion.insert({
    this.id = const i0.Value.absent(),
    required String symbol,
    this.quantity = const i0.Value.absent(),
    this.avgCost = const i0.Value.absent(),
    this.realizedPnl = const i0.Value.absent(),
    this.totalDividendReceived = const i0.Value.absent(),
    this.note = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol);
  static i0.Insertable<i1.PortfolioPositionEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<String>? symbol,
    i0.Expression<double>? quantity,
    i0.Expression<double>? avgCost,
    i0.Expression<double>? realizedPnl,
    i0.Expression<double>? totalDividendReceived,
    i0.Expression<String>? note,
    i0.Expression<DateTime>? createdAt,
    i0.Expression<DateTime>? updatedAt,
  }) {
    return i0.RawValuesInsertable({
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

  i1.PortfolioPositionCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<String>? symbol,
    i0.Value<double>? quantity,
    i0.Value<double>? avgCost,
    i0.Value<double>? realizedPnl,
    i0.Value<double>? totalDividendReceived,
    i0.Value<String?>? note,
    i0.Value<DateTime>? createdAt,
    i0.Value<DateTime>? updatedAt,
  }) {
    return i1.PortfolioPositionCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (id.present) {
      map['id'] = i0.Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (quantity.present) {
      map['quantity'] = i0.Variable<double>(quantity.value);
    }
    if (avgCost.present) {
      map['avg_cost'] = i0.Variable<double>(avgCost.value);
    }
    if (realizedPnl.present) {
      map['realized_pnl'] = i0.Variable<double>(realizedPnl.value);
    }
    if (totalDividendReceived.present) {
      map['total_dividend_received'] = i0.Variable<double>(
        totalDividendReceived.value,
      );
    }
    if (note.present) {
      map['note'] = i0.Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = i0.Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = i0.Variable<DateTime>(updatedAt.value);
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

i0.Index get idxPortfolioTxSymbol => i0.Index(
  'idx_portfolio_tx_symbol',
  'CREATE INDEX idx_portfolio_tx_symbol ON portfolio_transaction (symbol)',
);

class $PortfolioTransactionTable extends i2.PortfolioTransaction
    with
        i0.TableInfo<$PortfolioTransactionTable, i1.PortfolioTransactionEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfolioTransactionTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _txTypeMeta = const i0.VerificationMeta(
    'txType',
  );
  @override
  late final i0.GeneratedColumn<String> txType = i0.GeneratedColumn<String>(
    'tx_type',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const i0.VerificationMeta _quantityMeta = const i0.VerificationMeta(
    'quantity',
  );
  @override
  late final i0.GeneratedColumn<double> quantity = i0.GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _priceMeta = const i0.VerificationMeta(
    'price',
  );
  @override
  late final i0.GeneratedColumn<double> price = i0.GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _feeMeta = const i0.VerificationMeta('fee');
  @override
  late final i0.GeneratedColumn<double> fee = i0.GeneratedColumn<double>(
    'fee',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
  );
  static const i0.VerificationMeta _taxMeta = const i0.VerificationMeta('tax');
  @override
  late final i0.GeneratedColumn<double> tax = i0.GeneratedColumn<double>(
    'tax',
    aliasedName,
    false,
    type: i0.DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const i3.Constant(0),
  );
  static const i0.VerificationMeta _noteMeta = const i0.VerificationMeta(
    'note',
  );
  @override
  late final i0.GeneratedColumn<String> note = i0.GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.PortfolioTransactionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  i1.PortfolioTransactionEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.PortfolioTransactionEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      txType: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}tx_type'],
      )!,
      date: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      price: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      fee: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}fee'],
      )!,
      tax: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}tax'],
      )!,
      note: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PortfolioTransactionTable createAlias(String alias) {
    return $PortfolioTransactionTable(attachedDatabase, alias);
  }
}

class PortfolioTransactionEntry extends i0.DataClass
    implements i0.Insertable<i1.PortfolioTransactionEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['symbol'] = i0.Variable<String>(symbol);
    map['tx_type'] = i0.Variable<String>(txType);
    map['date'] = i0.Variable<DateTime>(date);
    map['quantity'] = i0.Variable<double>(quantity);
    map['price'] = i0.Variable<double>(price);
    map['fee'] = i0.Variable<double>(fee);
    map['tax'] = i0.Variable<double>(tax);
    if (!nullToAbsent || note != null) {
      map['note'] = i0.Variable<String>(note);
    }
    map['created_at'] = i0.Variable<DateTime>(createdAt);
    return map;
  }

  i1.PortfolioTransactionCompanion toCompanion(bool nullToAbsent) {
    return i1.PortfolioTransactionCompanion(
      id: i0.Value(id),
      symbol: i0.Value(symbol),
      txType: i0.Value(txType),
      date: i0.Value(date),
      quantity: i0.Value(quantity),
      price: i0.Value(price),
      fee: i0.Value(fee),
      tax: i0.Value(tax),
      note: note == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(note),
      createdAt: i0.Value(createdAt),
    );
  }

  factory PortfolioTransactionEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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

  i1.PortfolioTransactionEntry copyWith({
    int? id,
    String? symbol,
    String? txType,
    DateTime? date,
    double? quantity,
    double? price,
    double? fee,
    double? tax,
    i0.Value<String?> note = const i0.Value.absent(),
    DateTime? createdAt,
  }) => i1.PortfolioTransactionEntry(
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
    i1.PortfolioTransactionCompanion data,
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
      (other is i1.PortfolioTransactionEntry &&
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
    extends i0.UpdateCompanion<i1.PortfolioTransactionEntry> {
  final i0.Value<int> id;
  final i0.Value<String> symbol;
  final i0.Value<String> txType;
  final i0.Value<DateTime> date;
  final i0.Value<double> quantity;
  final i0.Value<double> price;
  final i0.Value<double> fee;
  final i0.Value<double> tax;
  final i0.Value<String?> note;
  final i0.Value<DateTime> createdAt;
  const PortfolioTransactionCompanion({
    this.id = const i0.Value.absent(),
    this.symbol = const i0.Value.absent(),
    this.txType = const i0.Value.absent(),
    this.date = const i0.Value.absent(),
    this.quantity = const i0.Value.absent(),
    this.price = const i0.Value.absent(),
    this.fee = const i0.Value.absent(),
    this.tax = const i0.Value.absent(),
    this.note = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
  });
  PortfolioTransactionCompanion.insert({
    this.id = const i0.Value.absent(),
    required String symbol,
    required String txType,
    required DateTime date,
    required double quantity,
    required double price,
    this.fee = const i0.Value.absent(),
    this.tax = const i0.Value.absent(),
    this.note = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol),
       txType = i0.Value(txType),
       date = i0.Value(date),
       quantity = i0.Value(quantity),
       price = i0.Value(price);
  static i0.Insertable<i1.PortfolioTransactionEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<String>? symbol,
    i0.Expression<String>? txType,
    i0.Expression<DateTime>? date,
    i0.Expression<double>? quantity,
    i0.Expression<double>? price,
    i0.Expression<double>? fee,
    i0.Expression<double>? tax,
    i0.Expression<String>? note,
    i0.Expression<DateTime>? createdAt,
  }) {
    return i0.RawValuesInsertable({
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

  i1.PortfolioTransactionCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<String>? symbol,
    i0.Value<String>? txType,
    i0.Value<DateTime>? date,
    i0.Value<double>? quantity,
    i0.Value<double>? price,
    i0.Value<double>? fee,
    i0.Value<double>? tax,
    i0.Value<String?>? note,
    i0.Value<DateTime>? createdAt,
  }) {
    return i1.PortfolioTransactionCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (id.present) {
      map['id'] = i0.Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (txType.present) {
      map['tx_type'] = i0.Variable<String>(txType.value);
    }
    if (date.present) {
      map['date'] = i0.Variable<DateTime>(date.value);
    }
    if (quantity.present) {
      map['quantity'] = i0.Variable<double>(quantity.value);
    }
    if (price.present) {
      map['price'] = i0.Variable<double>(price.value);
    }
    if (fee.present) {
      map['fee'] = i0.Variable<double>(fee.value);
    }
    if (tax.present) {
      map['tax'] = i0.Variable<double>(tax.value);
    }
    if (note.present) {
      map['note'] = i0.Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = i0.Variable<DateTime>(createdAt.value);
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

i0.Index get idxPortfolioTxDate => i0.Index(
  'idx_portfolio_tx_date',
  'CREATE INDEX idx_portfolio_tx_date ON portfolio_transaction (date)',
);
