import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/models/twse/quarterly_report_entry.dart';

/// 季報 t187ap06 解析(2026-08-06 最新一季財報總覽)。
///
/// 兩市場的**財務欄名完全一致**(皆中文:本期淨利（淨損）/基本每股盈餘
/// （元）/營業收入),只有 metadata 欄不同——TWSE=公司代號/年度/季別/
/// 公司名稱、TPEx=SecuritiesCompanyCode/Year/Season/CompanyName——
/// 單一 parser 以雙 key fallback 吃兩邊。fixture 為 2026-08-05 live 快照
/// (115Q2 公布期進行中:上市 ci 82 筆、上櫃 ci 67 筆)。
void main() {
  List<Map<String, dynamic>> loadFixture(String name) =>
      (jsonDecode(File('test/fixtures/$name').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  group('QuarterlyReportEntry.tryFromJson', () {
    test('🚨 TWSE ci fixture 全量解析(82 筆,中文 metadata 欄)', () {
      final rows = loadFixture('twse_t187ap06_ci_q2.json')
          .map(QuarterlyReportEntry.tryFromJson)
          .whereType<QuarterlyReportEntry>()
          .toList();
      expect(rows.length, 82, reason: 'live 快照全列皆應可解析');

      final dtn = rows.firstWhere((r) => r.symbol == '1232');
      expect(dtn.companyName, '大統益');
      expect(dtn.year, 2026, reason: 'ROC 115 → 西元');
      expect(dtn.quarter, 2);
      expect(dtn.eps, 4.71, reason: 'EPS 單位=元(累計)');
      expect(dtn.netIncome, 790350.0, reason: '淨利單位=千元(=7.9 億)');
      expect(dtn.revenue, 11481997.0);
    });

    test('🚨 TPEx ci fixture 全量解析(67 筆,英文 metadata 欄)', () {
      final rows = loadFixture('tpex_t187ap06_ci_q2.json')
          .map(QuarterlyReportEntry.tryFromJson)
          .whereType<QuarterlyReportEntry>()
          .toList();
      expect(rows.length, 67, reason: 'live 快照全列皆應可解析');

      final sample = rows.firstWhere((r) => r.symbol == '1570');
      expect(sample.companyName, '力肯');
      expect(sample.year, 2026);
      expect(sample.quarter, 2);
      expect(sample.eps, 0.54);
      expect(sample.netIncome, 27849.0);
      expect(sample.revenue, 288259.0);
    });

    test('金融業別無營業收入欄 → revenue null、EPS/淨利照收', () {
      final entry = QuarterlyReportEntry.tryFromJson({
        '公司代號': '2881',
        '公司名稱': '富邦金',
        '年度': '115',
        '季別': '2',
        '基本每股盈餘（元）': '3.52',
        '本期淨利（淨損）': '45000000.00',
      });
      expect(entry, isNotNull);
      expect(entry!.revenue, isNull);
      expect(entry.eps, 3.52);
      expect(entry.netIncome, 45000000.0);
    });

    test('虧損公司負值保留負號', () {
      final entry = QuarterlyReportEntry.tryFromJson({
        'SecuritiesCompanyCode': '9999',
        'CompanyName': 'X',
        'Year': '115',
        'Season': '1',
        '基本每股盈餘（元）': '-1.25',
        '本期淨利（淨損）': '-500.00',
      });
      expect(entry, isNotNull);
      expect(entry!.eps, -1.25);
      expect(entry.netIncome, -500.0);
    });

    test('髒列拒收:代號無效/季別越界/年度離譜/EPS+淨利皆空', () {
      Map<String, dynamic> base({
        String symbol = '2330',
        String year = '115',
        String season = '2',
        String eps = '1.00',
        String netIncome = '100.00',
      }) => {
        '公司代號': symbol,
        '年度': year,
        '季別': season,
        '基本每股盈餘（元）': eps,
        '本期淨利（淨損）': netIncome,
      };

      expect(QuarterlyReportEntry.tryFromJson(base(symbol: '1')), isNull);
      expect(QuarterlyReportEntry.tryFromJson(base(season: '5')), isNull);
      expect(QuarterlyReportEntry.tryFromJson(base(season: '0')), isNull);
      // 年度防線沿月營收 dirty-data filter 同款(2026-08-05 複審)
      expect(QuarterlyReportEntry.tryFromJson(base(year: '15')), isNull);
      expect(QuarterlyReportEntry.tryFromJson(base(year: '2026')), isNull);
      // 兩個核心數字皆空=空殼列
      expect(
        QuarterlyReportEntry.tryFromJson(base(eps: '', netIncome: '')),
        isNull,
      );
      // 單一數字仍在 → 收(EPS 空但有淨利)
      expect(QuarterlyReportEntry.tryFromJson(base(eps: ''))?.netIncome, 100.0);
    });
  });
}
