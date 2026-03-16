// dart format width=80
// ignore_for_file: type=lint
import 'package:drift/drift.dart' as i0;
import 'package:afterclose/data/database/tables/news_tables.drift.dart' as i1;
import 'package:afterclose/data/database/tables/news_tables.dart' as i2;
import 'package:drift/src/runtime/query_builder/query_builder.dart' as i3;
import 'package:drift/internal/modular.dart' as i4;
import 'package:afterclose/data/database/tables/stock_master.drift.dart' as i5;

typedef $$NewsItemTableCreateCompanionBuilder =
    i1.NewsItemCompanion Function({
      required String id,
      required String source,
      required String title,
      i0.Value<String?> content,
      required String url,
      required String category,
      required DateTime publishedAt,
      i0.Value<DateTime> fetchedAt,
      i0.Value<int> rowid,
    });
typedef $$NewsItemTableUpdateCompanionBuilder =
    i1.NewsItemCompanion Function({
      i0.Value<String> id,
      i0.Value<String> source,
      i0.Value<String> title,
      i0.Value<String?> content,
      i0.Value<String> url,
      i0.Value<String> category,
      i0.Value<DateTime> publishedAt,
      i0.Value<DateTime> fetchedAt,
      i0.Value<int> rowid,
    });

final class $$NewsItemTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$NewsItemTable,
          i1.NewsItemEntry
        > {
  $$NewsItemTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static i0.MultiTypedResultKey<
    i1.$NewsStockMapTable,
    List<i1.NewsStockMapEntry>
  >
  _newsStockMapRefsTable(i0.GeneratedDatabase db) =>
      i0.MultiTypedResultKey.fromTable(
        i4.ReadDatabaseContainer(
          db,
        ).resultSet<i1.$NewsStockMapTable>('news_stock_map'),
        aliasName: i0.$_aliasNameGenerator(
          i4.ReadDatabaseContainer(
            db,
          ).resultSet<i1.$NewsItemTable>('news_item').id,
          i4.ReadDatabaseContainer(
            db,
          ).resultSet<i1.$NewsStockMapTable>('news_stock_map').newsId,
        ),
      );

  i1.$$NewsStockMapTableProcessedTableManager get newsStockMapRefs {
    final manager = i1
        .$$NewsStockMapTableTableManager(
          $_db,
          i4.ReadDatabaseContainer(
            $_db,
          ).resultSet<i1.$NewsStockMapTable>('news_stock_map'),
        )
        .filter((f) => f.newsId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_newsStockMapRefsTable($_db));
    return i0.ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NewsItemTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$NewsItemTable> {
  $$NewsItemTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.Expression<bool> newsStockMapRefs(
    i0.Expression<bool> Function(i1.$$NewsStockMapTableFilterComposer f) f,
  ) {
    final i1.$$NewsStockMapTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i1.$NewsStockMapTable>('news_stock_map'),
      getReferencedColumn: (t) => t.newsId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i1.$$NewsStockMapTableFilterComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i1.$NewsStockMapTable>('news_stock_map'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$NewsItemTable> {
  $$NewsItemTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );
}

class $$NewsItemTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$NewsItemTable> {
  $$NewsItemTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  i0.GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  i0.GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  i0.GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  i0.GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  i0.GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  i0.GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  i0.Expression<T> newsStockMapRefs<T extends Object>(
    i0.Expression<T> Function(i1.$$NewsStockMapTableAnnotationComposer a) f,
  ) {
    final i1.$$NewsStockMapTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i1.$NewsStockMapTable>('news_stock_map'),
      getReferencedColumn: (t) => t.newsId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i1.$$NewsStockMapTableAnnotationComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i1.$NewsStockMapTable>('news_stock_map'),
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
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$NewsItemTable,
          i1.NewsItemEntry,
          i1.$$NewsItemTableFilterComposer,
          i1.$$NewsItemTableOrderingComposer,
          i1.$$NewsItemTableAnnotationComposer,
          $$NewsItemTableCreateCompanionBuilder,
          $$NewsItemTableUpdateCompanionBuilder,
          (i1.NewsItemEntry, i1.$$NewsItemTableReferences),
          i1.NewsItemEntry,
          i0.PrefetchHooks Function({bool newsStockMapRefs})
        > {
  $$NewsItemTableTableManager(i0.GeneratedDatabase db, i1.$NewsItemTable table)
    : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$NewsItemTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$NewsItemTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$NewsItemTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<String> id = const i0.Value.absent(),
                i0.Value<String> source = const i0.Value.absent(),
                i0.Value<String> title = const i0.Value.absent(),
                i0.Value<String?> content = const i0.Value.absent(),
                i0.Value<String> url = const i0.Value.absent(),
                i0.Value<String> category = const i0.Value.absent(),
                i0.Value<DateTime> publishedAt = const i0.Value.absent(),
                i0.Value<DateTime> fetchedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.NewsItemCompanion(
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
                i0.Value<String?> content = const i0.Value.absent(),
                required String url,
                required String category,
                required DateTime publishedAt,
                i0.Value<DateTime> fetchedAt = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.NewsItemCompanion.insert(
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
                  i1.$$NewsItemTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({newsStockMapRefs = false}) {
            return i0.PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (newsStockMapRefs)
                  i4.ReadDatabaseContainer(
                    db,
                  ).resultSet<i1.$NewsStockMapTable>('news_stock_map'),
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (newsStockMapRefs)
                    await i0.$_getPrefetchedData<
                      i1.NewsItemEntry,
                      i1.$NewsItemTable,
                      i1.NewsStockMapEntry
                    >(
                      currentTable: table,
                      referencedTable: i1.$$NewsItemTableReferences
                          ._newsStockMapRefsTable(db),
                      managerFromTypedResult: (p0) => i1
                          .$$NewsItemTableReferences(db, table, p0)
                          .newsStockMapRefs,
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$NewsItemTable,
      i1.NewsItemEntry,
      i1.$$NewsItemTableFilterComposer,
      i1.$$NewsItemTableOrderingComposer,
      i1.$$NewsItemTableAnnotationComposer,
      $$NewsItemTableCreateCompanionBuilder,
      $$NewsItemTableUpdateCompanionBuilder,
      (i1.NewsItemEntry, i1.$$NewsItemTableReferences),
      i1.NewsItemEntry,
      i0.PrefetchHooks Function({bool newsStockMapRefs})
    >;
typedef $$NewsStockMapTableCreateCompanionBuilder =
    i1.NewsStockMapCompanion Function({
      required String newsId,
      required String symbol,
      i0.Value<int> rowid,
    });
typedef $$NewsStockMapTableUpdateCompanionBuilder =
    i1.NewsStockMapCompanion Function({
      i0.Value<String> newsId,
      i0.Value<String> symbol,
      i0.Value<int> rowid,
    });

final class $$NewsStockMapTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$NewsStockMapTable,
          i1.NewsStockMapEntry
        > {
  $$NewsStockMapTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static i1.$NewsItemTable _newsIdTable(i0.GeneratedDatabase db) =>
      i4.ReadDatabaseContainer(db)
          .resultSet<i1.$NewsItemTable>('news_item')
          .createAlias(
            i0.$_aliasNameGenerator(
              i4.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$NewsStockMapTable>('news_stock_map').newsId,
              i4.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$NewsItemTable>('news_item').id,
            ),
          );

  i1.$$NewsItemTableProcessedTableManager get newsId {
    final $_column = $_itemColumn<String>('news_id')!;

    final manager = i1
        .$$NewsItemTableTableManager(
          $_db,
          i4.ReadDatabaseContainer(
            $_db,
          ).resultSet<i1.$NewsItemTable>('news_item'),
        )
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_newsIdTable($_db));
    if (item == null) return manager;
    return i0.ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static i5.$StockMasterTable _symbolTable(i0.GeneratedDatabase db) =>
      i4.ReadDatabaseContainer(db)
          .resultSet<i5.$StockMasterTable>('stock_master')
          .createAlias(
            i0.$_aliasNameGenerator(
              i4.ReadDatabaseContainer(
                db,
              ).resultSet<i1.$NewsStockMapTable>('news_stock_map').symbol,
              i4.ReadDatabaseContainer(
                db,
              ).resultSet<i5.$StockMasterTable>('stock_master').symbol,
            ),
          );

  i5.$$StockMasterTableProcessedTableManager get symbol {
    final $_column = $_itemColumn<String>('symbol')!;

    final manager = i5
        .$$StockMasterTableTableManager(
          $_db,
          i4.ReadDatabaseContainer(
            $_db,
          ).resultSet<i5.$StockMasterTable>('stock_master'),
        )
        .filter((f) => f.symbol.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_symbolTable($_db));
    if (item == null) return manager;
    return i0.ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NewsStockMapTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$NewsStockMapTable> {
  $$NewsStockMapTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i1.$$NewsItemTableFilterComposer get newsId {
    final i1.$$NewsItemTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.newsId,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i1.$NewsItemTable>('news_item'),
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i1.$$NewsItemTableFilterComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i1.$NewsItemTable>('news_item'),
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  i5.$$StockMasterTableFilterComposer get symbol {
    final i5.$$StockMasterTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i5.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i5.$$StockMasterTableFilterComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i5.$StockMasterTable>('stock_master'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$NewsStockMapTable> {
  $$NewsStockMapTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i1.$$NewsItemTableOrderingComposer get newsId {
    final i1.$$NewsItemTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.newsId,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i1.$NewsItemTable>('news_item'),
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i1.$$NewsItemTableOrderingComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i1.$NewsItemTable>('news_item'),
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  i5.$$StockMasterTableOrderingComposer get symbol {
    final i5.$$StockMasterTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i5.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i5.$$StockMasterTableOrderingComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i5.$StockMasterTable>('stock_master'),
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
    extends i0.Composer<i0.GeneratedDatabase, i1.$NewsStockMapTable> {
  $$NewsStockMapTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i1.$$NewsItemTableAnnotationComposer get newsId {
    final i1.$$NewsItemTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.newsId,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i1.$NewsItemTable>('news_item'),
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i1.$$NewsItemTableAnnotationComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i1.$NewsItemTable>('news_item'),
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  i5.$$StockMasterTableAnnotationComposer get symbol {
    final i5.$$StockMasterTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.symbol,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i5.$StockMasterTable>('stock_master'),
      getReferencedColumn: (t) => t.symbol,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i5.$$StockMasterTableAnnotationComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i5.$StockMasterTable>('stock_master'),
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
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$NewsStockMapTable,
          i1.NewsStockMapEntry,
          i1.$$NewsStockMapTableFilterComposer,
          i1.$$NewsStockMapTableOrderingComposer,
          i1.$$NewsStockMapTableAnnotationComposer,
          $$NewsStockMapTableCreateCompanionBuilder,
          $$NewsStockMapTableUpdateCompanionBuilder,
          (i1.NewsStockMapEntry, i1.$$NewsStockMapTableReferences),
          i1.NewsStockMapEntry,
          i0.PrefetchHooks Function({bool newsId, bool symbol})
        > {
  $$NewsStockMapTableTableManager(
    i0.GeneratedDatabase db,
    i1.$NewsStockMapTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              i1.$$NewsStockMapTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$NewsStockMapTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              i1.$$NewsStockMapTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                i0.Value<String> newsId = const i0.Value.absent(),
                i0.Value<String> symbol = const i0.Value.absent(),
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.NewsStockMapCompanion(
                newsId: newsId,
                symbol: symbol,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String newsId,
                required String symbol,
                i0.Value<int> rowid = const i0.Value.absent(),
              }) => i1.NewsStockMapCompanion.insert(
                newsId: newsId,
                symbol: symbol,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  i1.$$NewsStockMapTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({newsId = false, symbol = false}) {
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
                    if (newsId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.newsId,
                                referencedTable: i1
                                    .$$NewsStockMapTableReferences
                                    ._newsIdTable(db),
                                referencedColumn: i1
                                    .$$NewsStockMapTableReferences
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
                                referencedTable: i1
                                    .$$NewsStockMapTableReferences
                                    ._symbolTable(db),
                                referencedColumn: i1
                                    .$$NewsStockMapTableReferences
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
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$NewsStockMapTable,
      i1.NewsStockMapEntry,
      i1.$$NewsStockMapTableFilterComposer,
      i1.$$NewsStockMapTableOrderingComposer,
      i1.$$NewsStockMapTableAnnotationComposer,
      $$NewsStockMapTableCreateCompanionBuilder,
      $$NewsStockMapTableUpdateCompanionBuilder,
      (i1.NewsStockMapEntry, i1.$$NewsStockMapTableReferences),
      i1.NewsStockMapEntry,
      i0.PrefetchHooks Function({bool newsId, bool symbol})
    >;
i0.Index get idxNewsItemPublishedAt => i0.Index(
  'idx_news_item_published_at',
  'CREATE INDEX idx_news_item_published_at ON news_item (published_at)',
);

class $NewsItemTable extends i2.NewsItem
    with i0.TableInfo<$NewsItemTable, i1.NewsItemEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NewsItemTable(this.attachedDatabase, [this._alias]);
  static const i0.VerificationMeta _idMeta = const i0.VerificationMeta('id');
  @override
  late final i0.GeneratedColumn<String> id = i0.GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _sourceMeta = const i0.VerificationMeta(
    'source',
  );
  @override
  late final i0.GeneratedColumn<String> source = i0.GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _titleMeta = const i0.VerificationMeta(
    'title',
  );
  @override
  late final i0.GeneratedColumn<String> title = i0.GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _contentMeta = const i0.VerificationMeta(
    'content',
  );
  @override
  late final i0.GeneratedColumn<String> content = i0.GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _urlMeta = const i0.VerificationMeta('url');
  @override
  late final i0.GeneratedColumn<String> url = i0.GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _categoryMeta = const i0.VerificationMeta(
    'category',
  );
  @override
  late final i0.GeneratedColumn<String> category = i0.GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _publishedAtMeta = const i0.VerificationMeta(
    'publishedAt',
  );
  @override
  late final i0.GeneratedColumn<DateTime> publishedAt =
      i0.GeneratedColumn<DateTime>(
        'published_at',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const i0.VerificationMeta _fetchedAtMeta = const i0.VerificationMeta(
    'fetchedAt',
  );
  @override
  late final i0.GeneratedColumn<DateTime> fetchedAt =
      i0.GeneratedColumn<DateTime>(
        'fetched_at',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: i3.currentDateAndTime,
      );
  @override
  List<i0.GeneratedColumn> get $columns => [
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
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.NewsItemEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {id};
  @override
  i1.NewsItemEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.NewsItemEntry(
      id: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      title: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      url: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      category: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $NewsItemTable createAlias(String alias) {
    return $NewsItemTable(attachedDatabase, alias);
  }
}

class NewsItemEntry extends i0.DataClass
    implements i0.Insertable<i1.NewsItemEntry> {
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['id'] = i0.Variable<String>(id);
    map['source'] = i0.Variable<String>(source);
    map['title'] = i0.Variable<String>(title);
    if (!nullToAbsent || content != null) {
      map['content'] = i0.Variable<String>(content);
    }
    map['url'] = i0.Variable<String>(url);
    map['category'] = i0.Variable<String>(category);
    map['published_at'] = i0.Variable<DateTime>(publishedAt);
    map['fetched_at'] = i0.Variable<DateTime>(fetchedAt);
    return map;
  }

  i1.NewsItemCompanion toCompanion(bool nullToAbsent) {
    return i1.NewsItemCompanion(
      id: i0.Value(id),
      source: i0.Value(source),
      title: i0.Value(title),
      content: content == null && nullToAbsent
          ? const i0.Value.absent()
          : i0.Value(content),
      url: i0.Value(url),
      category: i0.Value(category),
      publishedAt: i0.Value(publishedAt),
      fetchedAt: i0.Value(fetchedAt),
    );
  }

  factory NewsItemEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
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

  i1.NewsItemEntry copyWith({
    String? id,
    String? source,
    String? title,
    i0.Value<String?> content = const i0.Value.absent(),
    String? url,
    String? category,
    DateTime? publishedAt,
    DateTime? fetchedAt,
  }) => i1.NewsItemEntry(
    id: id ?? this.id,
    source: source ?? this.source,
    title: title ?? this.title,
    content: content.present ? content.value : this.content,
    url: url ?? this.url,
    category: category ?? this.category,
    publishedAt: publishedAt ?? this.publishedAt,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  NewsItemEntry copyWithCompanion(i1.NewsItemCompanion data) {
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
      (other is i1.NewsItemEntry &&
          other.id == this.id &&
          other.source == this.source &&
          other.title == this.title &&
          other.content == this.content &&
          other.url == this.url &&
          other.category == this.category &&
          other.publishedAt == this.publishedAt &&
          other.fetchedAt == this.fetchedAt);
}

class NewsItemCompanion extends i0.UpdateCompanion<i1.NewsItemEntry> {
  final i0.Value<String> id;
  final i0.Value<String> source;
  final i0.Value<String> title;
  final i0.Value<String?> content;
  final i0.Value<String> url;
  final i0.Value<String> category;
  final i0.Value<DateTime> publishedAt;
  final i0.Value<DateTime> fetchedAt;
  final i0.Value<int> rowid;
  const NewsItemCompanion({
    this.id = const i0.Value.absent(),
    this.source = const i0.Value.absent(),
    this.title = const i0.Value.absent(),
    this.content = const i0.Value.absent(),
    this.url = const i0.Value.absent(),
    this.category = const i0.Value.absent(),
    this.publishedAt = const i0.Value.absent(),
    this.fetchedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  NewsItemCompanion.insert({
    required String id,
    required String source,
    required String title,
    this.content = const i0.Value.absent(),
    required String url,
    required String category,
    required DateTime publishedAt,
    this.fetchedAt = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  }) : id = i0.Value(id),
       source = i0.Value(source),
       title = i0.Value(title),
       url = i0.Value(url),
       category = i0.Value(category),
       publishedAt = i0.Value(publishedAt);
  static i0.Insertable<i1.NewsItemEntry> custom({
    i0.Expression<String>? id,
    i0.Expression<String>? source,
    i0.Expression<String>? title,
    i0.Expression<String>? content,
    i0.Expression<String>? url,
    i0.Expression<String>? category,
    i0.Expression<DateTime>? publishedAt,
    i0.Expression<DateTime>? fetchedAt,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
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

  i1.NewsItemCompanion copyWith({
    i0.Value<String>? id,
    i0.Value<String>? source,
    i0.Value<String>? title,
    i0.Value<String?>? content,
    i0.Value<String>? url,
    i0.Value<String>? category,
    i0.Value<DateTime>? publishedAt,
    i0.Value<DateTime>? fetchedAt,
    i0.Value<int>? rowid,
  }) {
    return i1.NewsItemCompanion(
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
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (id.present) {
      map['id'] = i0.Variable<String>(id.value);
    }
    if (source.present) {
      map['source'] = i0.Variable<String>(source.value);
    }
    if (title.present) {
      map['title'] = i0.Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = i0.Variable<String>(content.value);
    }
    if (url.present) {
      map['url'] = i0.Variable<String>(url.value);
    }
    if (category.present) {
      map['category'] = i0.Variable<String>(category.value);
    }
    if (publishedAt.present) {
      map['published_at'] = i0.Variable<DateTime>(publishedAt.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = i0.Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = i0.Variable<int>(rowid.value);
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

i0.Index get idxNewsItemSource => i0.Index(
  'idx_news_item_source',
  'CREATE INDEX idx_news_item_source ON news_item (source)',
);
i0.Index get idxNewsStockMapSymbol => i0.Index(
  'idx_news_stock_map_symbol',
  'CREATE INDEX idx_news_stock_map_symbol ON news_stock_map (symbol)',
);

class $NewsStockMapTable extends i2.NewsStockMap
    with i0.TableInfo<$NewsStockMapTable, i1.NewsStockMapEntry> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NewsStockMapTable(this.attachedDatabase, [this._alias]);
  static const i0.VerificationMeta _newsIdMeta = const i0.VerificationMeta(
    'newsId',
  );
  @override
  late final i0.GeneratedColumn<String> newsId = i0.GeneratedColumn<String>(
    'news_id',
    aliasedName,
    false,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: i0.GeneratedColumn.constraintIsAlways(
      'REFERENCES news_item (id) ON DELETE CASCADE',
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
  @override
  List<i0.GeneratedColumn> get $columns => [newsId, symbol];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'news_stock_map';
  @override
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.NewsStockMapEntry> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
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
  Set<i0.GeneratedColumn> get $primaryKey => {newsId, symbol};
  @override
  i1.NewsStockMapEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.NewsStockMapEntry(
      newsId: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}news_id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
    );
  }

  @override
  $NewsStockMapTable createAlias(String alias) {
    return $NewsStockMapTable(attachedDatabase, alias);
  }
}

class NewsStockMapEntry extends i0.DataClass
    implements i0.Insertable<i1.NewsStockMapEntry> {
  /// 新聞 ID
  final String newsId;

  /// 關聯股票代碼
  final String symbol;
  const NewsStockMapEntry({required this.newsId, required this.symbol});
  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['news_id'] = i0.Variable<String>(newsId);
    map['symbol'] = i0.Variable<String>(symbol);
    return map;
  }

  i1.NewsStockMapCompanion toCompanion(bool nullToAbsent) {
    return i1.NewsStockMapCompanion(
      newsId: i0.Value(newsId),
      symbol: i0.Value(symbol),
    );
  }

  factory NewsStockMapEntry.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return NewsStockMapEntry(
      newsId: serializer.fromJson<String>(json['newsId']),
      symbol: serializer.fromJson<String>(json['symbol']),
    );
  }
  @override
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'newsId': serializer.toJson<String>(newsId),
      'symbol': serializer.toJson<String>(symbol),
    };
  }

  i1.NewsStockMapEntry copyWith({String? newsId, String? symbol}) =>
      i1.NewsStockMapEntry(
        newsId: newsId ?? this.newsId,
        symbol: symbol ?? this.symbol,
      );
  NewsStockMapEntry copyWithCompanion(i1.NewsStockMapCompanion data) {
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
      (other is i1.NewsStockMapEntry &&
          other.newsId == this.newsId &&
          other.symbol == this.symbol);
}

class NewsStockMapCompanion extends i0.UpdateCompanion<i1.NewsStockMapEntry> {
  final i0.Value<String> newsId;
  final i0.Value<String> symbol;
  final i0.Value<int> rowid;
  const NewsStockMapCompanion({
    this.newsId = const i0.Value.absent(),
    this.symbol = const i0.Value.absent(),
    this.rowid = const i0.Value.absent(),
  });
  NewsStockMapCompanion.insert({
    required String newsId,
    required String symbol,
    this.rowid = const i0.Value.absent(),
  }) : newsId = i0.Value(newsId),
       symbol = i0.Value(symbol);
  static i0.Insertable<i1.NewsStockMapEntry> custom({
    i0.Expression<String>? newsId,
    i0.Expression<String>? symbol,
    i0.Expression<int>? rowid,
  }) {
    return i0.RawValuesInsertable({
      if (newsId != null) 'news_id': newsId,
      if (symbol != null) 'symbol': symbol,
      if (rowid != null) 'rowid': rowid,
    });
  }

  i1.NewsStockMapCompanion copyWith({
    i0.Value<String>? newsId,
    i0.Value<String>? symbol,
    i0.Value<int>? rowid,
  }) {
    return i1.NewsStockMapCompanion(
      newsId: newsId ?? this.newsId,
      symbol: symbol ?? this.symbol,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (newsId.present) {
      map['news_id'] = i0.Variable<String>(newsId.value);
    }
    if (symbol.present) {
      map['symbol'] = i0.Variable<String>(symbol.value);
    }
    if (rowid.present) {
      map['rowid'] = i0.Variable<int>(rowid.value);
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

i0.Index get idxNewsStockMapNewsId => i0.Index(
  'idx_news_stock_map_news_id',
  'CREATE INDEX idx_news_stock_map_news_id ON news_stock_map (news_id)',
);
