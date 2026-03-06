import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:afterclose/presentation/providers/portfolio_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

/// 匯出服務 — CSV 與 PDF 格式化
class ExportService {
  const ExportService();

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// 快取 CJK 字體，避免每次匯出都重新載入
  static pw.Font? _cjkFont;

  static Future<pw.Font> _loadCjkFont() async {
    if (_cjkFont != null) return _cjkFont!;
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansTC-Regular.ttf',
    );
    _cjkFont = pw.Font.ttf(fontData);
    return _cjkFont!;
  }

  /// 自選股清單 → CSV
  String watchlistToCsv(List<WatchlistItemData> items) {
    final headers = [
      'export.csvSymbol'.tr(),
      'export.csvName'.tr(),
      'export.csvMarket'.tr(),
      'export.csvClose'.tr(),
      'export.csvChange'.tr(),
      'export.csvTrend'.tr(),
      'export.csvScore'.tr(),
    ];

    final rows = items.map((item) {
      return [
        item.symbol,
        item.stockName ?? '',
        item.market ?? '',
        item.latestClose?.toStringAsFixed(2) ?? '',
        item.priceChange != null
            ? '${item.priceChange! >= 0 ? "+" : ""}${item.priceChange!.toStringAsFixed(2)}%'
            : '',
        item.trendState ?? '',
        item.score?.toStringAsFixed(0) ?? '',
      ];
    }).toList();

    return const CsvEncoder().convert([headers, ...rows]);
  }

  /// 投資組合 → CSV
  String portfolioToCsv(List<PortfolioPositionData> positions) {
    final headers = [
      'export.csvSymbol'.tr(),
      'export.csvName'.tr(),
      'export.csvQuantity'.tr(),
      'export.csvAvgCost'.tr(),
      'export.csvCurrentPrice'.tr(),
      'export.csvMarketValue'.tr(),
      'export.csvUnrealizedPnl'.tr(),
      'export.csvRealizedPnl'.tr(),
      'export.csvDividend'.tr(),
    ];

    final rows = positions.map((pos) {
      return [
        pos.symbol,
        pos.stockName ?? '',
        pos.quantity.toStringAsFixed(0),
        pos.avgCost.toStringAsFixed(2),
        pos.currentPrice?.toStringAsFixed(2) ?? '',
        pos.marketValue.toStringAsFixed(0),
        pos.unrealizedPnl.toStringAsFixed(0),
        pos.realizedPnl.toStringAsFixed(0),
        pos.totalDividendReceived.toStringAsFixed(0),
      ];
    }).toList();

    return const CsvEncoder().convert([headers, ...rows]);
  }

  /// 個股分析 → CSV
  String analysisDataToCsv(String symbol, StockDetailState state) {
    final rows = <List<String>>[];

    // 基本資訊
    rows.add([
      'export.csvSection'.tr(),
      'export.csvItem'.tr(),
      'export.csvValue'.tr(),
    ]);

    final stock = state.price.stock;
    final price = state.price.latestPrice;
    final analysis = state.price.analysis;

    rows.add(['export.csvBasicInfo'.tr(), 'export.csvSymbol'.tr(), symbol]);
    if (stock != null) {
      rows.add(['', 'export.csvName'.tr(), stock.name]);
    }
    if (price != null) {
      rows.add([
        '',
        'export.csvClose'.tr(),
        price.close?.toStringAsFixed(2) ?? '',
      ]);
      rows.add(['', 'export.csvDate'.tr(), _dateFormat.format(price.date)]);
    }

    // 分析
    if (analysis != null) {
      rows.add([
        'export.csvAnalysis'.tr(),
        'export.csvTrend'.tr(),
        analysis.trendState,
      ]);
      if (analysis.reversalState != 'NONE') {
        rows.add(['', 'export.csvReversal'.tr(), analysis.reversalState]);
      }
      rows.add(['', 'export.csvScore'.tr(), analysis.score.toStringAsFixed(0)]);
    }

    // AI 摘要
    if (state.aiSummary != null) {
      final summary = state.aiSummary!;
      rows.add([
        'export.csvAiSummary'.tr(),
        'export.csvOverall'.tr(),
        summary.overallAssessment,
      ]);
      for (final signal in summary.keySignals) {
        rows.add(['', 'export.csvSignal'.tr(), signal]);
      }
      for (final risk in summary.riskFactors) {
        rows.add(['', 'export.csvRisk'.tr(), risk]);
      }
    }

    // 訊號
    for (final reason in state.reasons) {
      rows.add([
        'export.csvSignals'.tr(),
        reason.reasonType,
        reason.ruleScore.toStringAsFixed(0),
      ]);
    }

    return const CsvEncoder().convert(rows);
  }

  /// 比較結果 → CSV
  String comparisonToCsv(ComparisonState state) {
    if (state.symbols.isEmpty) return '';

    // Header: 指標, symbol1, symbol2, ...
    final headers = ['export.csvItem'.tr()];
    for (final symbol in state.symbols) {
      final stock = state.stocksMap[symbol];
      headers.add('$symbol ${stock?.name ?? ""}');
    }

    final rows = <List<String>>[headers];

    // 收盤價
    _addComparisonRow(rows, 'export.csvClose'.tr(), state.symbols, (s) {
      return state.latestPricesMap[s]?.close?.toStringAsFixed(2) ?? '';
    });

    // 漲跌幅（前收基準）
    _addComparisonRow(rows, 'export.csvChange'.tr(), state.symbols, (s) {
      final price = state.latestPricesMap[s];
      if (price == null) return '';
      final close = price.close;
      final change = price.priceChange;
      if (close == null || change == null) return '';
      final prevClose = close - change;
      if (prevClose <= 0) return '';
      final changePercent = (change / prevClose) * 100;
      return '${changePercent >= 0 ? "+" : ""}${changePercent.toStringAsFixed(2)}%';
    });

    // 趨勢
    _addComparisonRow(rows, 'export.csvTrend'.tr(), state.symbols, (s) {
      return state.analysesMap[s]?.trendState ?? '';
    });

    // 分數
    _addComparisonRow(rows, 'export.csvScore'.tr(), state.symbols, (s) {
      return state.analysesMap[s]?.score.toStringAsFixed(0) ?? '';
    });

    // 本益比
    _addComparisonRow(rows, 'comparison.metricPE'.tr(), state.symbols, (s) {
      return state.valuationsMap[s]?.per?.toStringAsFixed(2) ?? '';
    });

    // 殖利率
    _addComparisonRow(
      rows,
      'comparison.metricDividendYield'.tr(),
      state.symbols,
      (s) {
        return state.valuationsMap[s]?.dividendYield?.toStringAsFixed(2) ?? '';
      },
    );

    // AI 情緒
    _addComparisonRow(rows, 'comparison.metricSentiment'.tr(), state.symbols, (
      s,
    ) {
      final summary = state.summariesMap[s];
      if (summary == null) return '';
      return summary.sentiment.name;
    });

    return const CsvEncoder().convert(rows);
  }

  void _addComparisonRow(
    List<List<String>> rows,
    String label,
    List<String> symbols,
    String Function(String symbol) getValue,
  ) {
    final row = [label];
    for (final s in symbols) {
      row.add(getValue(s));
    }
    rows.add(row);
  }

  // ==================================================
  // PDF Export
  // ==================================================

  /// 個股分析 → PDF 報告
  Future<Uint8List> analysisDataToPdf(
    String symbol,
    StockDetailState state,
  ) async {
    final cjkFont = await _loadCjkFont();
    final pdf = pw.Document();
    final stock = state.price.stock;
    final price = state.price.latestPrice;
    final analysis = state.price.analysis;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: cjkFont, bold: cjkFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'AfterClose',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _dateFormat.format(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 12),

              // Stock Info
              pw.Text(
                '$symbol ${stock?.name ?? ""}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),

              // Price
              if (price != null) ...[
                pw.Row(
                  children: [
                    pw.Text(
                      'export.csvClose'.tr(),
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      price.close?.toStringAsFixed(2) ?? '-',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (price.priceChange != null) ...[
                      pw.SizedBox(width: 12),
                      pw.Text(
                        '${price.priceChange! >= 0 ? "+" : ""}${price.priceChange!.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: price.priceChange! >= 0
                              ? PdfColors.red
                              : PdfColors.green,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _dateFormat.format(price.date),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],

              pw.SizedBox(height: 16),

              // Analysis section
              if (analysis != null) ...[
                _pdfSectionTitle('export.csvAnalysis'.tr()),
                pw.SizedBox(height: 6),
                _pdfKeyValue('export.csvTrend'.tr(), analysis.trendState),
                if (analysis.reversalState != 'NONE')
                  _pdfKeyValue(
                    'export.csvReversal'.tr(),
                    analysis.reversalState,
                  ),
                _pdfKeyValue(
                  'export.csvScore'.tr(),
                  analysis.score.toStringAsFixed(0),
                ),
                pw.SizedBox(height: 12),
              ],

              // AI Summary
              if (state.aiSummary != null) ...[
                _pdfSectionTitle('export.csvAiSummary'.tr()),
                pw.SizedBox(height: 6),
                pw.Text(
                  state.aiSummary!.overallAssessment,
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 8),
                if (state.aiSummary!.keySignals.isNotEmpty) ...[
                  pw.Text(
                    'export.csvSignal'.tr(),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  ...state.aiSummary!.keySignals.map(
                    (s) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                      child: pw.Text(
                        '• $s',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
                if (state.aiSummary!.riskFactors.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'export.csvRisk'.tr(),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  ...state.aiSummary!.riskFactors.map(
                    (r) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                      child: pw.Text(
                        '• $r',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
                pw.SizedBox(height: 12),
              ],

              // Signals
              if (state.reasons.isNotEmpty) ...[
                _pdfSectionTitle('export.csvSignals'.tr()),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'export.csvSignal'.tr(),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'export.csvScore'.tr(),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...state.reasons.map(
                      (r) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              r.reasonType,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              r.ruleScore.toStringAsFixed(0),
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              // Spacer + Disclaimer
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Text(
                'export.disclaimer'.tr(),
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _pdfKeyValue(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              key,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
