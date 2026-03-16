// dart format width=80
// ignore_for_file: type=lint
import 'package:drift/drift.dart' as i0;
import 'package:afterclose/data/database/tables/user_tables.drift.dart' as i1;
import 'package:afterclose/data/database/tables/user_tables.dart' as i2;
import 'package:drift/src/runtime/query_builder/query_builder.dart' as i3;
import 'package:afterclose/data/database/tables/stock_master.drift.dart' as i4;
import 'package:drift/internal/modular.dart' as i5;

typedef $$WatchlistTableCreateCompanionBuilder =
    i1.WatchlistCompanion Function({
      required String symbol,
      i0.Value<DateTime> createdAt,
      i0.Value<int> rowid,
    });
typedef $$WatchlistTableUpdateCompanionBuilder =
    i1.WatchlistCompanion Function({
      i0.Value<String> symbol,
      i0.Value<DateTime> createdAt,
      i0.Value<int> rowid,
    });

final class $$WatchlistTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$WatchlistTable,
          i1.WatchlistEntry
        > {
  $$WatchlistTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static i4.$StockMasterTable _symbolTable(i0.GeneratedDatabase db) =>
      i5.ReadDatabaseContainer(db)
          .resultSet<i4.$StockMasterTable>('stock_master')
          .createAlias(
            i0.$_aliasNameGenerator(
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$WatchlistTable>('watchlist').symbol,
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

class $$WatchlistTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$WatchlistTable> {
  $$WatchlistTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

class $$WatchlistTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$WatchlistTable> {
  $$WatchlistTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

class $$WatchlistTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$WatchlistTable> {
  $$WatchlistTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

class $$WatchlistTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$WatchlistTable,
          i1.WatchlistEntry,
          i1.$$WatchlistTableFilterComposer,
          i1.$$WatchlistTableOrderingComposer,
          i1.$$WatchlistTableAnnotationComposer,
          $$WatchlistTableCreateCompanionBuilder,
          $$WatchlistTableUpdateCompanionBuilder,
          (i1.WatchlistEntry, i1.$$WatchlistTableReferences),
          i1.WatchlistEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$WatchlistTableTableManager(
    i0.GeneratedDatabase db,
    i1.$WatchlistTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$WatchlistTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$WatchlistTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$WatchlistTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.WatchlistCompanion(
                symbol: symbol,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.WatchlistCompanion.insert(
                symbol: symbol,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  i1.$$WatchlistTableReferences(db, table, e),
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
                                referencedTable: i1.$$WatchlistTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1.$$WatchlistTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$WatchlistTable,
      i1.WatchlistEntry,
      i1.$$WatchlistTableFilterComposer,
      i1.$$WatchlistTableOrderingComposer,
      i1.$$WatchlistTableAnnotationComposer,
      $$WatchlistTableCreateCompanionBuilder,
      $$WatchlistTableUpdateCompanionBuilder,
      (i1.WatchlistEntry, i1.$$WatchlistTableReferences),
      i1.WatchlistEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
typedef $$UserNoteTableCreateCompanionBuilder =
    i1.UserNoteCompanion Function({
      i0.Value<int> id,
      required String symbol,
      i0.Value<DateTime?> date,
      required String content,
      i0.Value<DateTime> createdAt,
      i0.Value<DateTime> updatedAt,
    });
typedef $$UserNoteTableUpdateCompanionBuilder =
    i1.UserNoteCompanion Function({
      i0.Value<int> id,
      i0.Value<String> symbol,
      i0.Value<DateTime?> date,
      i0.Value<String> content,
      i0.Value<DateTime> createdAt,
      i0.Value<DateTime> updatedAt,
    });

final class $$UserNoteTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$UserNoteTable,
          i1.UserNoteEntry
        > {
  $$UserNoteTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static i4.$StockMasterTable _symbolTable(i0.GeneratedDatabase db) =>
      i5.ReadDatabaseContainer(db)
          .resultSet<i4.$StockMasterTable>('stock_master')
          .createAlias(
            i0.$_aliasNameGenerator(
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$UserNoteTable>('user_note').symbol,
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

class $$UserNoteTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$UserNoteTable> {
  $$UserNoteTableFilterComposer({
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

  i0.ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
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

class $$UserNoteTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$UserNoteTable> {
  $$UserNoteTableOrderingComposer({
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

  i0.ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
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

class $$UserNoteTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$UserNoteTable> {
  $$UserNoteTableAnnotationComposer({
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

  i0.GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

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

class $$UserNoteTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$UserNoteTable,
          i1.UserNoteEntry,
          i1.$$UserNoteTableFilterComposer,
          i1.$$UserNoteTableOrderingComposer,
          i1.$$UserNoteTableAnnotationComposer,
          $$UserNoteTableCreateCompanionBuilder,
          $$UserNoteTableUpdateCompanionBuilder,
          (i1.UserNoteEntry, i1.$$UserNoteTableReferences),
          i1.UserNoteEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$UserNoteTableTableManager(i0.GeneratedDatabase db, i1.$UserNoteTable table)
    : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$UserNoteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$UserNoteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$UserNoteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<DateTime?> date = const i0.Value.absent(),
                i0.Value<String> content = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
              }) => i1.UserNoteCompanion(
                id: id,
                symbol: symbol,
                date: date,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                required String symbol,
                i0.Value<DateTime?> date = const i0.Value.absent(),
                required String content,
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
              }) => i1.UserNoteCompanion.insert(
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
                  i1.$$UserNoteTableReferences(db, table, e),
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
                                referencedTable: i1.$$UserNoteTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1.$$UserNoteTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$UserNoteTable,
      i1.UserNoteEntry,
      i1.$$UserNoteTableFilterComposer,
      i1.$$UserNoteTableOrderingComposer,
      i1.$$UserNoteTableAnnotationComposer,
      $$UserNoteTableCreateCompanionBuilder,
      $$UserNoteTableUpdateCompanionBuilder,
      (i1.UserNoteEntry, i1.$$UserNoteTableReferences),
      i1.UserNoteEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
typedef $$StrategyCardTableCreateCompanionBuilder =
    i1.StrategyCardCompanion Function({
      i0.Value<int> id,
      required String symbol,
      i0.Value<DateTime?> forDate,
      i0.Value<String?> ifA,
      i0.Value<String?> thenA,
      i0.Value<String?> ifB,
      i0.Value<String?> thenB,
      i0.Value<String?> elsePlan,
      i0.Value<DateTime> createdAt,
      i0.Value<DateTime> updatedAt,
    });
typedef $$StrategyCardTableUpdateCompanionBuilder =
    i1.StrategyCardCompanion Function({
      i0.Value<int> id,
      i0.Value<String> symbol,
      i0.Value<DateTime?> forDate,
      i0.Value<String?> ifA,
      i0.Value<String?> thenA,
      i0.Value<String?> ifB,
      i0.Value<String?> thenB,
      i0.Value<String?> elsePlan,
      i0.Value<DateTime> createdAt,
      i0.Value<DateTime> updatedAt,
    });

final class $$StrategyCardTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$StrategyCardTable,
          i1.StrategyCardEntry
        > {
  $$StrategyCardTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static i4.$StockMasterTable _symbolTable(i0.GeneratedDatabase db) =>
      i5.ReadDatabaseContainer(db)
          .resultSet<i4.$StockMasterTable>('stock_master')
          .createAlias(
            i0.$_aliasNameGenerator(
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$StrategyCardTable>('strategy_card').symbol,
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

class $$StrategyCardTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$StrategyCardTable> {
  $$StrategyCardTableFilterComposer({
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

  i0.ColumnFilters<DateTime> get forDate => $composableBuilder(
    column: $table.forDate,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get ifA => $composableBuilder(
    column: $table.ifA,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get thenA => $composableBuilder(
    column: $table.thenA,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get ifB => $composableBuilder(
    column: $table.ifB,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get thenB => $composableBuilder(
    column: $table.thenB,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get elsePlan => $composableBuilder(
    column: $table.elsePlan,
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

class $$StrategyCardTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$StrategyCardTable> {
  $$StrategyCardTableOrderingComposer({
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

  i0.ColumnOrderings<DateTime> get forDate => $composableBuilder(
    column: $table.forDate,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get ifA => $composableBuilder(
    column: $table.ifA,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get thenA => $composableBuilder(
    column: $table.thenA,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get ifB => $composableBuilder(
    column: $table.ifB,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get thenB => $composableBuilder(
    column: $table.thenB,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get elsePlan => $composableBuilder(
    column: $table.elsePlan,
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

class $$StrategyCardTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$StrategyCardTable> {
  $$StrategyCardTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get forDate =>
      $composableBuilder(column: $table.forDate, builder: (column) => column);

  i0.GeneratedColumn<String> get ifA =>
      $composableBuilder(column: $table.ifA, builder: (column) => column);

  i0.GeneratedColumn<String> get thenA =>
      $composableBuilder(column: $table.thenA, builder: (column) => column);

  i0.GeneratedColumn<String> get ifB =>
      $composableBuilder(column: $table.ifB, builder: (column) => column);

  i0.GeneratedColumn<String> get thenB =>
      $composableBuilder(column: $table.thenB, builder: (column) => column);

  i0.GeneratedColumn<String> get elsePlan =>
      $composableBuilder(column: $table.elsePlan, builder: (column) => column);

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

class $$StrategyCardTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$StrategyCardTable,
          i1.StrategyCardEntry,
          i1.$$StrategyCardTableFilterComposer,
          i1.$$StrategyCardTableOrderingComposer,
          i1.$$StrategyCardTableAnnotationComposer,
          $$StrategyCardTableCreateCompanionBuilder,
          $$StrategyCardTableUpdateCompanionBuilder,
          (i1.StrategyCardEntry, i1.$$StrategyCardTableReferences),
          i1.StrategyCardEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$StrategyCardTableTableManager(
    i0.GeneratedDatabase db,
    i1.$StrategyCardTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$StrategyCardTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$StrategyCardTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$StrategyCardTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<DateTime?> forDate = const i0.Value.absent(),
                i0.Value<String?> ifA = const i0.Value.absent(),
                i0.Value<String?> thenA = const i0.Value.absent(),
                i0.Value<String?> ifB = const i0.Value.absent(),
                i0.Value<String?> thenB = const i0.Value.absent(),
                i0.Value<String?> elsePlan = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
              }) => i1.StrategyCardCompanion(
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
                i0.Value<int> id = const i0.Value.absent(),
                required String symbol,
                i0.Value<DateTime?> forDate = const i0.Value.absent(),
                i0.Value<String?> ifA = const i0.Value.absent(),
                i0.Value<String?> thenA = const i0.Value.absent(),
                i0.Value<String?> ifB = const i0.Value.absent(),
                i0.Value<String?> thenB = const i0.Value.absent(),
                i0.Value<String?> elsePlan = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
              }) => i1.StrategyCardCompanion.insert(
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
                  i1.$$StrategyCardTableReferences(db, table, e),
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
                                    .$$StrategyCardTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1
                                    .$$StrategyCardTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$StrategyCardTable,
      i1.StrategyCardEntry,
      i1.$$StrategyCardTableFilterComposer,
      i1.$$StrategyCardTableOrderingComposer,
      i1.$$StrategyCardTableAnnotationComposer,
      $$StrategyCardTableCreateCompanionBuilder,
      $$StrategyCardTableUpdateCompanionBuilder,
      (i1.StrategyCardEntry, i1.$$StrategyCardTableReferences),
      i1.StrategyCardEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
typedef $$UpdateRunTableCreateCompanionBuilder =
    i1.UpdateRunCompanion Function({
      i0.Value<int> id,
      required DateTime runDate,
      i0.Value<DateTime> startedAt,
      i0.Value<DateTime?> finishedAt,
      required String status,
      i0.Value<String?> message,
    });
typedef $$UpdateRunTableUpdateCompanionBuilder =
    i1.UpdateRunCompanion Function({
      i0.Value<int> id,
      i0.Value<DateTime> runDate,
      i0.Value<DateTime> startedAt,
      i0.Value<DateTime?> finishedAt,
      i0.Value<String> status,
      i0.Value<String?> message,
    });

class $$UpdateRunTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$UpdateRunTable> {
  $$UpdateRunTableFilterComposer({
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

  i0.ColumnFilters<DateTime> get runDate => $composableBuilder(
    column: $table.runDate,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => i0.ColumnFilters(column),
  );
}

class $$UpdateRunTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$UpdateRunTable> {
  $$UpdateRunTableOrderingComposer({
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

  i0.ColumnOrderings<DateTime> get runDate => $composableBuilder(
    column: $table.runDate,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => i0.ColumnOrderings(column),
  );
}

class $$UpdateRunTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$UpdateRunTable> {
  $$UpdateRunTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get runDate =>
      $composableBuilder(column: $table.runDate, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  i0.GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  i0.GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);
}

class $$UpdateRunTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$UpdateRunTable,
          i1.UpdateRunEntry,
          i1.$$UpdateRunTableFilterComposer,
          i1.$$UpdateRunTableOrderingComposer,
          i1.$$UpdateRunTableAnnotationComposer,
          $$UpdateRunTableCreateCompanionBuilder,
          $$UpdateRunTableUpdateCompanionBuilder,
          (
            i1.UpdateRunEntry,
            i0.BaseReferences<
              i0.GeneratedDatabase,
              i1.$UpdateRunTable,
              i1.UpdateRunEntry
            >,
          ),
          i1.UpdateRunEntry,
          i0.PrefetchHooks Function()
        > {
  $$UpdateRunTableTableManager(
    i0.GeneratedDatabase db,
    i1.$UpdateRunTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$UpdateRunTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$UpdateRunTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$UpdateRunTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<DateTime> runDate = const i0.Value.absent(),
                i0.Value<DateTime> startedAt = const i0.Value.absent(),
                i0.Value<DateTime?> finishedAt = const i0.Value.absent(),
                i0.Value<String> status = const i0.Value.absent(),
                i0.Value<String?> message = const i0.Value.absent(),
              }) => i1.UpdateRunCompanion(
                id: id,
                runDate: runDate,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
                message: message,
              ),
          createCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                required DateTime runDate,
                i0.Value<DateTime> startedAt = const i0.Value.absent(),
                i0.Value<DateTime?> finishedAt = const i0.Value.absent(),
                required String status,
                i0.Value<String?> message = const i0.Value.absent(),
              }) => i1.UpdateRunCompanion.insert(
                id: id,
                runDate: runDate,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
                message: message,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), i0.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UpdateRunTableProcessedTableManager =
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$UpdateRunTable,
      i1.UpdateRunEntry,
      i1.$$UpdateRunTableFilterComposer,
      i1.$$UpdateRunTableOrderingComposer,
      i1.$$UpdateRunTableAnnotationComposer,
      $$UpdateRunTableCreateCompanionBuilder,
      $$UpdateRunTableUpdateCompanionBuilder,
      (
        i1.UpdateRunEntry,
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$UpdateRunTable,
          i1.UpdateRunEntry
        >,
      ),
      i1.UpdateRunEntry,
      i0.PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    i1.AppSettingsCompanion Function({
      required String key,
      required String value,
      i0.Value<DateTime> updatedAt,
      i0.Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    i1.AppSettingsCompanion Function({
      i0.Value<String> key,
      i0.Value<String> value,
      i0.Value<DateTime> updatedAt,
      i0.Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => i0.ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  i0.GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$AppSettingsTable,
          i1.AppSettingEntry,
          i1.$$AppSettingsTableFilterComposer,
          i1.$$AppSettingsTableOrderingComposer,
          i1.$$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            i1.AppSettingEntry,
            i0.BaseReferences<
              i0.GeneratedDatabase,
              i1.$AppSettingsTable,
              i1.AppSettingEntry
            >,
          ),
          i1.AppSettingEntry,
          i0.PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(
    i0.GeneratedDatabase db,
    i1.$AppSettingsTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<String> key = const i0.Value.absent(),
                i0.Value<String> value = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.AppSettingsCompanion.insert(
                key: key,
                value: value,
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

typedef $$AppSettingsTableProcessedTableManager =
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$AppSettingsTable,
      i1.AppSettingEntry,
      i1.$$AppSettingsTableFilterComposer,
      i1.$$AppSettingsTableOrderingComposer,
      i1.$$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        i1.AppSettingEntry,
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$AppSettingsTable,
          i1.AppSettingEntry
        >,
      ),
      i1.AppSettingEntry,
      i0.PrefetchHooks Function()
    >;
typedef $$PriceAlertTableCreateCompanionBuilder =
    i1.PriceAlertCompanion Function({
      i0.Value<int> id,
      required String symbol,
      required String alertType,
      required double targetValue,
      i0.Value<bool> isActive,
      i0.Value<DateTime?> triggeredAt,
      i0.Value<String?> note,
      i0.Value<DateTime> createdAt,
    });
typedef $$PriceAlertTableUpdateCompanionBuilder =
    i1.PriceAlertCompanion Function({
      i0.Value<int> id,
      i0.Value<String> symbol,
      i0.Value<String> alertType,
      i0.Value<double> targetValue,
      i0.Value<bool> isActive,
      i0.Value<DateTime?> triggeredAt,
      i0.Value<String?> note,
      i0.Value<DateTime> createdAt,
    });

final class $$PriceAlertTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$PriceAlertTable,
          i1.PriceAlertEntry
        > {
  $$PriceAlertTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static i4.$StockMasterTable _symbolTable(i0.GeneratedDatabase db) =>
      i5.ReadDatabaseContainer(db)
          .resultSet<i4.$StockMasterTable>('stock_master')
          .createAlias(
            i0.$_aliasNameGenerator(
              i5.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$PriceAlertTable>('price_alert').symbol,
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

class $$PriceAlertTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PriceAlertTable> {
  $$PriceAlertTableFilterComposer({
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

  i0.ColumnFilters<String> get alertType => $composableBuilder(
    column: $table.alertType,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
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

class $$PriceAlertTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PriceAlertTable> {
  $$PriceAlertTableOrderingComposer({
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

  i0.ColumnOrderings<String> get alertType => $composableBuilder(
    column: $table.alertType,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
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

class $$PriceAlertTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$PriceAlertTable> {
  $$PriceAlertTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<String> get alertType =>
      $composableBuilder(column: $table.alertType, builder: (column) => column);

  i0.GeneratedColumn<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => column,
  );

  i0.GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
    builder: (column) => column,
  );

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

class $$PriceAlertTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$PriceAlertTable,
          i1.PriceAlertEntry,
          i1.$$PriceAlertTableFilterComposer,
          i1.$$PriceAlertTableOrderingComposer,
          i1.$$PriceAlertTableAnnotationComposer,
          $$PriceAlertTableCreateCompanionBuilder,
          $$PriceAlertTableUpdateCompanionBuilder,
          (i1.PriceAlertEntry, i1.$$PriceAlertTableReferences),
          i1.PriceAlertEntry,
          i0.PrefetchHooks Function({bool symbol})
        > {
  $$PriceAlertTableTableManager(
    i0.GeneratedDatabase db,
    i1.$PriceAlertTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$PriceAlertTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$PriceAlertTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$PriceAlertTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<String> alertType = const i0.Value.absent(),
                i0.Value<double> targetValue = const i0.Value.absent(),
                i0.Value<bool> isActive = const i0.Value.absent(),
                i0.Value<DateTime?> triggeredAt = const i0.Value.absent(),
                i0.Value<String?> note = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
              }) => i1.PriceAlertCompanion(
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
                i0.Value<int> id = const i0.Value.absent(),
                required String symbol,
                required String alertType,
                required double targetValue,
                i0.Value<bool> isActive = const i0.Value.absent(),
                i0.Value<DateTime?> triggeredAt = const i0.Value.absent(),
                i0.Value<String?> note = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
              }) => i1.PriceAlertCompanion.insert(
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
                  i1.$$PriceAlertTableReferences(db, table, e),
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
                                referencedTable: i1.$$PriceAlertTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1.$$PriceAlertTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$PriceAlertTable,
      i1.PriceAlertEntry,
      i1.$$PriceAlertTableFilterComposer,
      i1.$$PriceAlertTableOrderingComposer,
      i1.$$PriceAlertTableAnnotationComposer,
      $$PriceAlertTableCreateCompanionBuilder,
      $$PriceAlertTableUpdateCompanionBuilder,
      (i1.PriceAlertEntry, i1.$$PriceAlertTableReferences),
      i1.PriceAlertEntry,
      i0.PrefetchHooks Function({bool symbol})
    >;
typedef $$ScreeningStrategyTableTableCreateCompanionBuilder =
    i1.ScreeningStrategyTableCompanion Function({
      i0.Value<int> id,
      required String name,
      required String conditionsJson,
      i0.Value<DateTime> createdAt,
      i0.Value<DateTime> updatedAt,
    });
typedef $$ScreeningStrategyTableTableUpdateCompanionBuilder =
    i1.ScreeningStrategyTableCompanion Function({
      i0.Value<int> id,
      i0.Value<String> name,
      i0.Value<String> conditionsJson,
      i0.Value<DateTime> createdAt,
      i0.Value<DateTime> updatedAt,
    });

class $$ScreeningStrategyTableTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$ScreeningStrategyTableTable> {
  $$ScreeningStrategyTableTableFilterComposer({
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

  i0.ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
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
}

class $$ScreeningStrategyTableTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$ScreeningStrategyTableTable> {
  $$ScreeningStrategyTableTableOrderingComposer({
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

  i0.ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
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
}

class $$ScreeningStrategyTableTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$ScreeningStrategyTableTable> {
  $$ScreeningStrategyTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  i0.GeneratedColumn<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => column,
  );

  i0.GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ScreeningStrategyTableTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$ScreeningStrategyTableTable,
          i1.ScreeningStrategyEntry,
          i1.$$ScreeningStrategyTableTableFilterComposer,
          i1.$$ScreeningStrategyTableTableOrderingComposer,
          i1.$$ScreeningStrategyTableTableAnnotationComposer,
          $$ScreeningStrategyTableTableCreateCompanionBuilder,
          $$ScreeningStrategyTableTableUpdateCompanionBuilder,
          (
            i1.ScreeningStrategyEntry,
            i0.BaseReferences<
              i0.GeneratedDatabase,
              i1.$ScreeningStrategyTableTable,
              i1.ScreeningStrategyEntry
            >,
          ),
          i1.ScreeningStrategyEntry,
          i0.PrefetchHooks Function()
        > {
  $$ScreeningStrategyTableTableTableManager(
    i0.GeneratedDatabase db,
    i1.$ScreeningStrategyTableTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$ScreeningStrategyTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              i1.$$ScreeningStrategyTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              i1.$$ScreeningStrategyTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                i0.Value<String> name = const i0.Value.absent(),
                i0.Value<String> conditionsJson = const i0.Value.absent(),
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
              }) => i1.ScreeningStrategyTableCompanion(
                id: id,
                name: name,
                conditionsJson: conditionsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                i0.Value<int> id = const i0.Value.absent(),
                required String name,
                required String conditionsJson,
                i0.Value<DateTime> createdAt = const i0.Value.absent(),
                i0.Value<DateTime> updatedAt = const i0.Value.absent(),
              }) => i1.ScreeningStrategyTableCompanion.insert(
                id: id,
                name: name,
                conditionsJson: conditionsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), i0.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScreeningStrategyTableTableProcessedTableManager =
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$ScreeningStrategyTableTable,
      i1.ScreeningStrategyEntry,
      i1.$$ScreeningStrategyTableTableFilterComposer,
      i1.$$ScreeningStrategyTableTableOrderingComposer,
      i1.$$ScreeningStrategyTableTableAnnotationComposer,
      $$ScreeningStrategyTableTableCreateCompanionBuilder,
      $$ScreeningStrategyTableTableUpdateCompanionBuilder,
      (
        i1.ScreeningStrategyEntry,
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$ScreeningStrategyTableTable,
          i1.ScreeningStrategyEntry
        >,
      ),
      i1.ScreeningStrategyEntry,
      i0.PrefetchHooks Function()
    >;

class $WatchlistTable extends i2.Watchlist
    with i0.TableInfo<$WatchlistTable, i1.WatchlistEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistTable(this.attachedDatabase, [this._alias]);
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
  List<i0.GeneratedColumn> get $columns => [symbol, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist';
  @override
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.WatchlistEntry> instance, {
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<i0.GeneratedColumn> get $primaryKey => {symbol};
  @override
  i1.WatchlistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.WatchlistEntry(
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WatchlistTable createAlias(String alias) {
    return $WatchlistTable(attachedDatabase, alias);
  }
}

class WatchlistEntry extends i0.DataClass
    implements i0.Insertable<i1.WatchlistEntry> {
  /// 股票代碼
  final String symbol;

  /// 加入自選股的時間
  final DateTime createdAt;
  const WatchlistEntry({required this.symbol, required this.createdAt});
  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['symbol'] = i0.Variable<String>(symbol);
    map['created_at'] = i0.Variable<DateTime>(createdAt);
    return map;
  }

  i1.WatchlistCompanion toCompanion(bool nullToAbsent) {
    return i1.WatchlistCompanion(
      symbol: i0.Value(symbol),
      createdAt: i0.Value(createdAt),
    );
  }

  factory WatchlistEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return WatchlistEntry(
      symbol: serializer.fromJson<String>(json['symbol']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  i1.WatchlistEntry copyWith({String? symbol, DateTime? createdAt}) =>
      i1.WatchlistEntry(
        symbol: symbol ?? this.symbol,
        createdAt: createdAt ?? this.createdAt,
      );
  WatchlistEntry copyWithCompanion(i1.WatchlistCompanion data) {
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
      (other is i1.WatchlistEntry &&
          other.symbol == this.symbol &&
          other.createdAt == this.createdAt);
}

class WatchlistCompanion extends i0.UpdateCompanion<i1.WatchlistEntry> {
  final i0.Value<String> symbol;
  final i0.Value<DateTime> createdAt;
  final i0.Value<int> rowid;
  const WatchlistCompanion({
    this.symbol = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  WatchlistCompanion.insert({
    required String symbol,
    this.createdAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol);
  static i0.Insertable<i1.WatchlistEntry> custom({
    i0.Expression<String>? symbol,
    i0.Expression<DateTime>? createdAt,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  i1.WatchlistCompanion copyWith({
    i0.Value<String>? symbol,
    i0.Value<DateTime>? createdAt,
    i0.Value<int>? rowid,
  }) {
    return i1.WatchlistCompanion(
      symbol: symbol ?? this.symbol,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (createdAt.present) {
      map['created_at'] = i0.Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = i0.Variable<int>(rowid.value);
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

class $UserNoteTable extends i2.UserNote
    with i0.TableInfo<$UserNoteTable, i1.UserNoteEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserNoteTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _dateMeta = const i0.VerificationMeta(
    'date',
  );
  @override
  late final i0.GeneratedColumn<DateTime> date = i0.GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    true,
    type: i0.DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _contentMeta = const i0.VerificationMeta(
    'content',
  );
  @override
  late final i0.GeneratedColumn<String> content = i0.GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.UserNoteEntry> instance, {
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  i1.UserNoteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.UserNoteEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      date: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      ),
      content: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
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
  $UserNoteTable createAlias(String alias) {
    return $UserNoteTable(attachedDatabase, alias);
  }
}

class UserNoteEntry extends i0.DataClass
    implements i0.Insertable<i1.UserNoteEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['symbol'] = i0.Variable<String>(symbol);
    if (!nullToAbsent || date != null) {
      map['date'] = i0.Variable<DateTime>(date);
    }
    map['content'] = i0.Variable<String>(content);
    map['created_at'] = i0.Variable<DateTime>(createdAt);
    map['updated_at'] = i0.Variable<DateTime>(updatedAt);
    return map;
  }

  i1.UserNoteCompanion toCompanion(bool nullToAbsent) {
    return i1.UserNoteCompanion(
      id: i0.Value(id),
      symbol: i0.Value(symbol),
      date: date == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(date),
      content: i0.Value(content),
      createdAt: i0.Value(createdAt),
      updatedAt: i0.Value(updatedAt),
    );
  }

  factory UserNoteEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'date': serializer.toJson<DateTime?>(date),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  i1.UserNoteEntry copyWith({
    int? id,
    String? symbol,
    i0.Value<DateTime?> date = const i0.Value.absent(),
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => i1.UserNoteEntry(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    date: date.present ? date.value : this.date,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserNoteEntry copyWithCompanion(i1.UserNoteCompanion data) {
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
      (other is i1.UserNoteEntry &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.date == this.date &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserNoteCompanion extends i0.UpdateCompanion<i1.UserNoteEntry> {
  final i0.Value<int> id;
  final i0.Value<String> symbol;
  final i0.Value<DateTime?> date;
  final i0.Value<String> content;
  final i0.Value<DateTime> createdAt;
  final i0.Value<DateTime> updatedAt;
  const UserNoteCompanion({
    this.id = const i0.Value.absent(),
    this.symbol = const i0.Value.absent(),
    this.date = const i0.Value.absent(),
    this.content = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
  });
  UserNoteCompanion.insert({
    this.id = const i0.Value.absent(),
    required String symbol,
    this.date = const i0.Value.absent(),
    required String content,
    this.createdAt = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol),
       content = i0.Value(content);
  static i0.Insertable<i1.UserNoteEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<String>? symbol,
    i0.Expression<DateTime>? date,
    i0.Expression<String>? content,
    i0.Expression<DateTime>? createdAt,
    i0.Expression<DateTime>? updatedAt,
  }) {
    return i0.RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (date != null) 'date': date,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  i1.UserNoteCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<String>? symbol,
    i0.Value<DateTime?>? date,
    i0.Value<String>? content,
    i0.Value<DateTime>? createdAt,
    i0.Value<DateTime>? updatedAt,
  }) {
    return i1.UserNoteCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      content: content ?? this.content,
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
    if (date.present) {
      map['date'] = i0.Variable<DateTime>(date.value);
    }
    if (content.present) {
      map['content'] = i0.Variable<String>(content.value);
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

class $StrategyCardTable extends i2.StrategyCard
    with i0.TableInfo<$StrategyCardTable, i1.StrategyCardEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StrategyCardTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _forDateMeta = const i0.VerificationMeta(
    'forDate',
  );
  @override
  late final i0.GeneratedColumn<DateTime> forDate =
      i0.GeneratedColumn<DateTime>(
        'for_date',
        aliasedName,
        true,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const i0.VerificationMeta _ifAMeta = const i0.VerificationMeta('ifA');
  @override
  late final i0.GeneratedColumn<String> ifA = i0.GeneratedColumn<String>(
    'if_a',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _thenAMeta = const i0.VerificationMeta(
    'thenA',
  );
  @override
  late final i0.GeneratedColumn<String> thenA = i0.GeneratedColumn<String>(
    'then_a',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _ifBMeta = const i0.VerificationMeta('ifB');
  @override
  late final i0.GeneratedColumn<String> ifB = i0.GeneratedColumn<String>(
    'if_b',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _thenBMeta = const i0.VerificationMeta(
    'thenB',
  );
  @override
  late final i0.GeneratedColumn<String> thenB = i0.GeneratedColumn<String>(
    'then_b',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _elsePlanMeta = const i0.VerificationMeta(
    'elsePlan',
  );
  @override
  late final i0.GeneratedColumn<String> elsePlan = i0.GeneratedColumn<String>(
    'else_plan',
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.StrategyCardEntry> instance, {
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  i1.StrategyCardEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.StrategyCardEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      forDate: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}for_date'],
      ),
      ifA: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}if_a'],
      ),
      thenA: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}then_a'],
      ),
      ifB: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}if_b'],
      ),
      thenB: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}then_b'],
      ),
      elsePlan: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}else_plan'],
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
  $StrategyCardTable createAlias(String alias) {
    return $StrategyCardTable(attachedDatabase, alias);
  }
}

class StrategyCardEntry extends i0.DataClass
    implements i0.Insertable<i1.StrategyCardEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['symbol'] = i0.Variable<String>(symbol);
    if (!nullToAbsent || forDate != null) {
      map['for_date'] = i0.Variable<DateTime>(forDate);
    }
    if (!nullToAbsent || ifA != null) {
      map['if_a'] = i0.Variable<String>(ifA);
    }
    if (!nullToAbsent || thenA != null) {
      map['then_a'] = i0.Variable<String>(thenA);
    }
    if (!nullToAbsent || ifB != null) {
      map['if_b'] = i0.Variable<String>(ifB);
    }
    if (!nullToAbsent || thenB != null) {
      map['then_b'] = i0.Variable<String>(thenB);
    }
    if (!nullToAbsent || elsePlan != null) {
      map['else_plan'] = i0.Variable<String>(elsePlan);
    }
    map['created_at'] = i0.Variable<DateTime>(createdAt);
    map['updated_at'] = i0.Variable<DateTime>(updatedAt);
    return map;
  }

  i1.StrategyCardCompanion toCompanion(bool nullToAbsent) {
    return i1.StrategyCardCompanion(
      id: i0.Value(id),
      symbol: i0.Value(symbol),
      forDate: forDate == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(forDate),
      ifA: ifA == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(ifA),
      thenA: thenA == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(thenA),
      ifB: ifB == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(ifB),
      thenB: thenB == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(thenB),
      elsePlan: elsePlan == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(elsePlan),
      createdAt: i0.Value(createdAt),
      updatedAt: i0.Value(updatedAt),
    );
  }

  factory StrategyCardEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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

  i1.StrategyCardEntry copyWith({
    int? id,
    String? symbol,
    i0.Value<DateTime?> forDate = const i0.Value.absent(),
    i0.Value<String?> ifA = const i0.Value.absent(),
    i0.Value<String?> thenA = const i0.Value.absent(),
    i0.Value<String?> ifB = const i0.Value.absent(),
    i0.Value<String?> thenB = const i0.Value.absent(),
    i0.Value<String?> elsePlan = const i0.Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => i1.StrategyCardEntry(
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
  StrategyCardEntry copyWithCompanion(i1.StrategyCardCompanion data) {
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
      (other is i1.StrategyCardEntry &&
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

class StrategyCardCompanion extends i0.UpdateCompanion<i1.StrategyCardEntry> {
  final i0.Value<int> id;
  final i0.Value<String> symbol;
  final i0.Value<DateTime?> forDate;
  final i0.Value<String?> ifA;
  final i0.Value<String?> thenA;
  final i0.Value<String?> ifB;
  final i0.Value<String?> thenB;
  final i0.Value<String?> elsePlan;
  final i0.Value<DateTime> createdAt;
  final i0.Value<DateTime> updatedAt;
  const StrategyCardCompanion({
    this.id = const i0.Value.absent(),
    this.symbol = const i0.Value.absent(),
    this.forDate = const i0.Value.absent(),
    this.ifA = const i0.Value.absent(),
    this.thenA = const i0.Value.absent(),
    this.ifB = const i0.Value.absent(),
    this.thenB = const i0.Value.absent(),
    this.elsePlan = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
  });
  StrategyCardCompanion.insert({
    this.id = const i0.Value.absent(),
    required String symbol,
    this.forDate = const i0.Value.absent(),
    this.ifA = const i0.Value.absent(),
    this.thenA = const i0.Value.absent(),
    this.ifB = const i0.Value.absent(),
    this.thenB = const i0.Value.absent(),
    this.elsePlan = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol);
  static i0.Insertable<i1.StrategyCardEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<String>? symbol,
    i0.Expression<DateTime>? forDate,
    i0.Expression<String>? ifA,
    i0.Expression<String>? thenA,
    i0.Expression<String>? ifB,
    i0.Expression<String>? thenB,
    i0.Expression<String>? elsePlan,
    i0.Expression<DateTime>? createdAt,
    i0.Expression<DateTime>? updatedAt,
  }) {
    return i0.RawValuesInsertable({
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

  i1.StrategyCardCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<String>? symbol,
    i0.Value<DateTime?>? forDate,
    i0.Value<String?>? ifA,
    i0.Value<String?>? thenA,
    i0.Value<String?>? ifB,
    i0.Value<String?>? thenB,
    i0.Value<String?>? elsePlan,
    i0.Value<DateTime>? createdAt,
    i0.Value<DateTime>? updatedAt,
  }) {
    return i1.StrategyCardCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (id.present) {
      map['id'] = i0.Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (forDate.present) {
      map['for_date'] = i0.Variable<DateTime>(forDate.value);
    }
    if (ifA.present) {
      map['if_a'] = i0.Variable<String>(ifA.value);
    }
    if (thenA.present) {
      map['then_a'] = i0.Variable<String>(thenA.value);
    }
    if (ifB.present) {
      map['if_b'] = i0.Variable<String>(ifB.value);
    }
    if (thenB.present) {
      map['then_b'] = i0.Variable<String>(thenB.value);
    }
    if (elsePlan.present) {
      map['else_plan'] = i0.Variable<String>(elsePlan.value);
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

class $UpdateRunTable extends i2.UpdateRun
    with i0.TableInfo<$UpdateRunTable, i1.UpdateRunEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UpdateRunTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _runDateMeta = const i0.VerificationMeta(
    'runDate',
  );
  @override
  late final i0.GeneratedColumn<DateTime> runDate =
      i0.GeneratedColumn<DateTime>(
        'run_date',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const i0.VerificationMeta _startedAtMeta = const i0.VerificationMeta(
    'startedAt',
  );
  @override
  late final i0.GeneratedColumn<DateTime> startedAt =
      i0.GeneratedColumn<DateTime>(
        'started_at',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: i3.currentDateAndTime,
      );
  static const i0.VerificationMeta _finishedAtMeta = const i0.VerificationMeta(
    'finishedAt',
  );
  @override
  late final i0.GeneratedColumn<DateTime> finishedAt =
      i0.GeneratedColumn<DateTime>(
        'finished_at',
        aliasedName,
        true,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const i0.VerificationMeta _statusMeta = const i0.VerificationMeta(
    'status',
  );
  @override
  late final i0.GeneratedColumn<String> status = i0.GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _messageMeta = const i0.VerificationMeta(
    'message',
  );
  @override
  late final i0.GeneratedColumn<String> message = i0.GeneratedColumn<String>(
    'message',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<i0.GeneratedColumn> get $columns => [
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.UpdateRunEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  i1.UpdateRunEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.UpdateRunEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      runDate: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}run_date'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      message: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}message'],
      ),
    );
  }

  @override
  $UpdateRunTable createAlias(String alias) {
    return $UpdateRunTable(attachedDatabase, alias);
  }
}

class UpdateRunEntry extends i0.DataClass
    implements i0.Insertable<i1.UpdateRunEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['run_date'] = i0.Variable<DateTime>(runDate);
    map['started_at'] = i0.Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = i0.Variable<DateTime>(finishedAt);
    }
    map['status'] = i0.Variable<String>(status);
    if (!nullToAbsent || message != null) {
      map['message'] = i0.Variable<String>(message);
    }
    return map;
  }

  i1.UpdateRunCompanion toCompanion(bool nullToAbsent) {
    return i1.UpdateRunCompanion(
      id: i0.Value(id),
      runDate: i0.Value(runDate),
      startedAt: i0.Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(finishedAt),
      status: i0.Value(status),
      message: message == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(message),
    );
  }

  factory UpdateRunEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runDate': serializer.toJson<DateTime>(runDate),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'status': serializer.toJson<String>(status),
      'message': serializer.toJson<String?>(message),
    };
  }

  i1.UpdateRunEntry copyWith({
    int? id,
    DateTime? runDate,
    DateTime? startedAt,
    i0.Value<DateTime?> finishedAt = const i0.Value.absent(),
    String? status,
    i0.Value<String?> message = const i0.Value.absent(),
  }) => i1.UpdateRunEntry(
    id: id ?? this.id,
    runDate: runDate ?? this.runDate,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    status: status ?? this.status,
    message: message.present ? message.value : this.message,
  );
  UpdateRunEntry copyWithCompanion(i1.UpdateRunCompanion data) {
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
      (other is i1.UpdateRunEntry &&
          other.id == this.id &&
          other.runDate == this.runDate &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.status == this.status &&
          other.message == this.message);
}

class UpdateRunCompanion extends i0.UpdateCompanion<i1.UpdateRunEntry> {
  final i0.Value<int> id;
  final i0.Value<DateTime> runDate;
  final i0.Value<DateTime> startedAt;
  final i0.Value<DateTime?> finishedAt;
  final i0.Value<String> status;
  final i0.Value<String?> message;
  const UpdateRunCompanion({
    this.id = const i0.Value.absent(),
    this.runDate = const i0.Value.absent(),
    this.startedAt = const i0.Value.absent(),
    this.finishedAt = const i0.Value.absent(),
    this.status = const i0.Value.absent(),
    this.message = const i0.Value.absent(),
  });
  UpdateRunCompanion.insert({
    this.id = const i0.Value.absent(),
    required DateTime runDate,
    this.startedAt = const i0.Value.absent(),
    this.finishedAt = const i0.Value.absent(),
    required String status,
    this.message = const i0.Value.absent(),
  }) : runDate = i0.Value(runDate),
       status = i0.Value(status);
  static i0.Insertable<i1.UpdateRunEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<DateTime>? runDate,
    i0.Expression<DateTime>? startedAt,
    i0.Expression<DateTime>? finishedAt,
    i0.Expression<String>? status,
    i0.Expression<String>? message,
  }) {
    return i0.RawValuesInsertable({
      if (id != null) 'id': id,
      if (runDate != null) 'run_date': runDate,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (status != null) 'status': status,
      if (message != null) 'message': message,
    });
  }

  i1.UpdateRunCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<DateTime>? runDate,
    i0.Value<DateTime>? startedAt,
    i0.Value<DateTime?>? finishedAt,
    i0.Value<String>? status,
    i0.Value<String?>? message,
  }) {
    return i1.UpdateRunCompanion(
      id: id ?? this.id,
      runDate: runDate ?? this.runDate,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (id.present) {
      map['id'] = i0.Variable<int>(id.value);
    }
    if (runDate.present) {
      map['run_date'] = i0.Variable<DateTime>(runDate.value);
    }
    if (startedAt.present) {
      map['started_at'] = i0.Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = i0.Variable<DateTime>(finishedAt.value);
    }
    if (status.present) {
      map['status'] = i0.Variable<String>(status.value);
    }
    if (message.present) {
      map['message'] = i0.Variable<String>(message.value);
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

class $AppSettingsTable extends i2.AppSettings
    with i0.TableInfo<$AppSettingsTable, i1.AppSettingEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const i0.VerificationMeta _keyMeta = const i0.VerificationMeta('key');
  @override
  late final i0.GeneratedColumn<String> key = i0.GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _valueMeta = const i0.VerificationMeta(
    'value',
  );
  @override
  late final i0.GeneratedColumn<String> value = i0.GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<i0.GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.AppSettingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {key};
  @override
  i1.AppSettingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.AppSettingEntry(
      key: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingEntry extends i0.DataClass
    implements i0.Insertable<i1.AppSettingEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['key'] = i0.Variable<String>(key);
    map['value'] = i0.Variable<String>(value);
    map['updated_at'] = i0.Variable<DateTime>(updatedAt);
    return map;
  }

  i1.AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return i1.AppSettingsCompanion(
      key: i0.Value(key),
      value: i0.Value(value),
      updatedAt: i0.Value(updatedAt),
    );
  }

  factory AppSettingEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return AppSettingEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  i1.AppSettingEntry copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => i1.AppSettingEntry(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSettingEntry copyWithCompanion(i1.AppSettingsCompanion data) {
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
      (other is i1.AppSettingEntry &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends i0.UpdateCompanion<i1.AppSettingEntry> {
  final i0.Value<String> key;
  final i0.Value<String> value;
  final i0.Value<DateTime> updatedAt;
  final i0.Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const i0.Value.absent(),
    this.value = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  }) : key = i0.Value(key),
       value = i0.Value(value);
  static i0.Insertable<i1.AppSettingEntry> custom({
    i0.Expression<String>? key,
    i0.Expression<String>? value,
    i0.Expression<DateTime>? updatedAt,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  i1.AppSettingsCompanion copyWith({
    i0.Value<String>? key,
    i0.Value<String>? value,
    i0.Value<DateTime>? updatedAt,
    i0.Value<int>? rowid,
  }) {
    return i1.AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (key.present) {
      map['key'] = i0.Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = i0.Variable<String>(value.value);
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
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PriceAlertTable extends i2.PriceAlert
    with i0.TableInfo<$PriceAlertTable, i1.PriceAlertEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceAlertTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _alertTypeMeta = const i0.VerificationMeta(
    'alertType',
  );
  @override
  late final i0.GeneratedColumn<String> alertType = i0.GeneratedColumn<String>(
    'alert_type',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _targetValueMeta = const i0.VerificationMeta(
    'targetValue',
  );
  @override
  late final i0.GeneratedColumn<double> targetValue =
      i0.GeneratedColumn<double>(
        'target_value',
        aliasedName,
        false,
        type: i0.DriftSqlType.double,
        requiredDuringInsert: true,
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
  static const i0.VerificationMeta _triggeredAtMeta = const i0.VerificationMeta(
    'triggeredAt',
  );
  @override
  late final i0.GeneratedColumn<DateTime> triggeredAt =
      i0.GeneratedColumn<DateTime>(
        'triggered_at',
        aliasedName,
        true,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.PriceAlertEntry> instance, {
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  i1.PriceAlertEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.PriceAlertEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      alertType: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}alert_type'],
      )!,
      targetValue: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.double,
        data['${effectivePrefix}target_value'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      triggeredAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}triggered_at'],
      ),
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
  $PriceAlertTable createAlias(String alias) {
    return $PriceAlertTable(attachedDatabase, alias);
  }
}

class PriceAlertEntry extends i0.DataClass
    implements i0.Insertable<i1.PriceAlertEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['symbol'] = i0.Variable<String>(symbol);
    map['alert_type'] = i0.Variable<String>(alertType);
    map['target_value'] = i0.Variable<double>(targetValue);
    map['is_active'] = i0.Variable<bool>(isActive);
    if (!nullToAbsent || triggeredAt != null) {
      map['triggered_at'] = i0.Variable<DateTime>(triggeredAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = i0.Variable<String>(note);
    }
    map['created_at'] = i0.Variable<DateTime>(createdAt);
    return map;
  }

  i1.PriceAlertCompanion toCompanion(bool nullToAbsent) {
    return i1.PriceAlertCompanion(
      id: i0.Value(id),
      symbol: i0.Value(symbol),
      alertType: i0.Value(alertType),
      targetValue: i0.Value(targetValue),
      isActive: i0.Value(isActive),
      triggeredAt: triggeredAt == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(triggeredAt),
      note: note == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(note),
      createdAt: i0.Value(createdAt),
    );
  }

  factory PriceAlertEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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

  i1.PriceAlertEntry copyWith({
    int? id,
    String? symbol,
    String? alertType,
    double? targetValue,
    bool? isActive,
    i0.Value<DateTime?> triggeredAt = const i0.Value.absent(),
    i0.Value<String?> note = const i0.Value.absent(),
    DateTime? createdAt,
  }) => i1.PriceAlertEntry(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    alertType: alertType ?? this.alertType,
    targetValue: targetValue ?? this.targetValue,
    isActive: isActive ?? this.isActive,
    triggeredAt: triggeredAt.present ? triggeredAt.value : this.triggeredAt,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  PriceAlertEntry copyWithCompanion(i1.PriceAlertCompanion data) {
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
      (other is i1.PriceAlertEntry &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.alertType == this.alertType &&
          other.targetValue == this.targetValue &&
          other.isActive == this.isActive &&
          other.triggeredAt == this.triggeredAt &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class PriceAlertCompanion extends i0.UpdateCompanion<i1.PriceAlertEntry> {
  final i0.Value<int> id;
  final i0.Value<String> symbol;
  final i0.Value<String> alertType;
  final i0.Value<double> targetValue;
  final i0.Value<bool> isActive;
  final i0.Value<DateTime?> triggeredAt;
  final i0.Value<String?> note;
  final i0.Value<DateTime> createdAt;
  const PriceAlertCompanion({
    this.id = const i0.Value.absent(),
    this.symbol = const i0.Value.absent(),
    this.alertType = const i0.Value.absent(),
    this.targetValue = const i0.Value.absent(),
    this.isActive = const i0.Value.absent(),
    this.triggeredAt = const i0.Value.absent(),
    this.note = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
  });
  PriceAlertCompanion.insert({
    this.id = const i0.Value.absent(),
    required String symbol,
    required String alertType,
    required double targetValue,
    this.isActive = const i0.Value.absent(),
    this.triggeredAt = const i0.Value.absent(),
    this.note = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
  }) : symbol = i0.Value(symbol),
       alertType = i0.Value(alertType),
       targetValue = i0.Value(targetValue);
  static i0.Insertable<i1.PriceAlertEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<String>? symbol,
    i0.Expression<String>? alertType,
    i0.Expression<double>? targetValue,
    i0.Expression<bool>? isActive,
    i0.Expression<DateTime>? triggeredAt,
    i0.Expression<String>? note,
    i0.Expression<DateTime>? createdAt,
  }) {
    return i0.RawValuesInsertable({
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

  i1.PriceAlertCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<String>? symbol,
    i0.Value<String>? alertType,
    i0.Value<double>? targetValue,
    i0.Value<bool>? isActive,
    i0.Value<DateTime?>? triggeredAt,
    i0.Value<String?>? note,
    i0.Value<DateTime>? createdAt,
  }) {
    return i1.PriceAlertCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (id.present) {
      map['id'] = i0.Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (alertType.present) {
      map['alert_type'] = i0.Variable<String>(alertType.value);
    }
    if (targetValue.present) {
      map['target_value'] = i0.Variable<double>(targetValue.value);
    }
    if (isActive.present) {
      map['is_active'] = i0.Variable<bool>(isActive.value);
    }
    if (triggeredAt.present) {
      map['triggered_at'] = i0.Variable<DateTime>(triggeredAt.value);
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

class $ScreeningStrategyTableTable extends i2.ScreeningStrategyTable
    with i0.TableInfo<$ScreeningStrategyTableTable, i1.ScreeningStrategyEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScreeningStrategyTableTable(this.attachedDatabase, [this._alias]);
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
  static const i0.VerificationMeta _nameMeta = const i0.VerificationMeta(
    'name',
  );
  @override
  late final i0.GeneratedColumn<String> name = i0.GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: i0.GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _conditionsJsonMeta =
      const i0.VerificationMeta('conditionsJson');
  @override
  late final i0.GeneratedColumn<String> conditionsJson =
      i0.GeneratedColumn<String>(
        'conditions_json',
        aliasedName,
        false,
        type: i0.DriftSqlType.string,
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.ScreeningStrategyEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  i1.ScreeningStrategyEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.ScreeningStrategyEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      conditionsJson: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}conditions_json'],
      )!,
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
  $ScreeningStrategyTableTable createAlias(String alias) {
    return $ScreeningStrategyTableTable(attachedDatabase, alias);
  }
}

class ScreeningStrategyEntry extends i0.DataClass
    implements i0.Insertable<i1.ScreeningStrategyEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<int>(id);
    map['name'] = i0.Variable<String>(name);
    map['conditions_json'] = i0.Variable<String>(conditionsJson);
    map['created_at'] = i0.Variable<DateTime>(createdAt);
    map['updated_at'] = i0.Variable<DateTime>(updatedAt);
    return map;
  }

  i1.ScreeningStrategyTableCompanion toCompanion(bool nullToAbsent) {
    return i1.ScreeningStrategyTableCompanion(
      id: i0.Value(id),
      name: i0.Value(name),
      conditionsJson: i0.Value(conditionsJson),
      createdAt: i0.Value(createdAt),
      updatedAt: i0.Value(updatedAt),
    );
  }

  factory ScreeningStrategyEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return ScreeningStrategyEntry(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      conditionsJson: serializer.fromJson<String>(json['conditionsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'conditionsJson': serializer.toJson<String>(conditionsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  i1.ScreeningStrategyEntry copyWith({
    int? id,
    String? name,
    String? conditionsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => i1.ScreeningStrategyEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    conditionsJson: conditionsJson ?? this.conditionsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScreeningStrategyEntry copyWithCompanion(
    i1.ScreeningStrategyTableCompanion data,
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
      (other is i1.ScreeningStrategyEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.conditionsJson == this.conditionsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScreeningStrategyTableCompanion
    extends i0.UpdateCompanion<i1.ScreeningStrategyEntry> {
  final i0.Value<int> id;
  final i0.Value<String> name;
  final i0.Value<String> conditionsJson;
  final i0.Value<DateTime> createdAt;
  final i0.Value<DateTime> updatedAt;
  const ScreeningStrategyTableCompanion({
    this.id = const i0.Value.absent(),
    this.name = const i0.Value.absent(),
    this.conditionsJson = const i0.Value.absent(),
    this.createdAt = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
  });
  ScreeningStrategyTableCompanion.insert({
    this.id = const i0.Value.absent(),
    required String name,
    required String conditionsJson,
    this.createdAt = const i0.Value.absent(),
    this.updatedAt = const i0.Value.absent(),
  }) : name = i0.Value(name),
       conditionsJson = i0.Value(conditionsJson);
  static i0.Insertable<i1.ScreeningStrategyEntry> custom({
    i0.Expression<int>? id,
    i0.Expression<String>? name,
    i0.Expression<String>? conditionsJson,
    i0.Expression<DateTime>? createdAt,
    i0.Expression<DateTime>? updatedAt,
  }) {
    return i0.RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (conditionsJson != null) 'conditions_json': conditionsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  i1.ScreeningStrategyTableCompanion copyWith({
    i0.Value<int>? id,
    i0.Value<String>? name,
    i0.Value<String>? conditionsJson,
    i0.Value<DateTime>? createdAt,
    i0.Value<DateTime>? updatedAt,
  }) {
    return i1.ScreeningStrategyTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      conditionsJson: conditionsJson ?? this.conditionsJson,
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
    if (name.present) {
      map['name'] = i0.Variable<String>(name.value);
    }
    if (conditionsJson.present) {
      map['conditions_json'] = i0.Variable<String>(conditionsJson.value);
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
