import 'package:afterclose/domain/services/analysis/sector_strength_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SectorStrengthService service;

  setUp(() => service = SectorStrengthService());

  group('SectorStrengthService.rankByPercentile', () {
    test('empty input returns empty map', () {
      expect(service.rankByPercentile({}), isEmpty);
    });

    test('single industry returns 0.5 (neutral)', () {
      expect(service.rankByPercentile({'半導體業': 0.12}), equals({'半導體業': 0.5}));
    });

    test('ranks weakest=0, strongest=1, evenly spaced', () {
      final result = service.rankByPercentile({
        '弱': -0.05,
        '中': 0.00,
        '強': 0.10,
      });
      expect(result['弱'], 0.0);
      expect(result['中'], 0.5);
      expect(result['強'], 1.0);
    });

    test('higher 20D return → higher percentile', () {
      final result = service.rankByPercentile({
        '航運業': 0.30,
        '金融業': 0.05,
        '鋼鐵業': -0.10,
        '生技業': 0.15,
      });
      // 排序：鋼鐵(-0.10) < 金融(0.05) < 生技(0.15) < 航運(0.30)
      expect(result['鋼鐵業'], 0.0);
      expect(result['金融業'], closeTo(1 / 3, 1e-9));
      expect(result['生技業'], closeTo(2 / 3, 1e-9));
      expect(result['航運業'], 1.0);
    });

    test('ties share the same average-position percentile', () {
      // [10, 20, 20, 30] → 10→0, 兩個20→avg(1,2)/3=0.5, 30→1.0
      final result = service.rankByPercentile({
        'a': 0.10,
        'b': 0.20,
        'c': 0.20,
        'd': 0.30,
      });
      expect(result['a'], 0.0);
      expect(result['b'], 0.5);
      expect(result['c'], 0.5);
      expect(result['d'], 1.0);
    });

    test('all-equal momentum → all 0.5 (no spurious ordering)', () {
      final result = service.rankByPercentile({'x': 0.1, 'y': 0.1, 'z': 0.1});
      expect(result.values, everyElement(0.5));
    });
  });

  group('SectorStrengthService.sectorTiltedScores', () {
    test('weight=0 → finalScore equals baseRank (零產業影響)', () {
      final base = {'A': 30.0, 'B': 10.0, 'C': 20.0};
      final result = service.sectorTiltedScores(
        baseKeyBySymbol: base,
        industryBySymbol: {'A': '弱產業', 'B': '強產業', 'C': '弱產業'},
        industryStrength: {'強產業': 1.0, '弱產業': 0.0},
        weight: 0.0,
      );
      // baseRank：B(10)=0、C(20)=0.5、A(30)=1.0
      expect(result['B'], 0.0);
      expect(result['C'], 0.5);
      expect(result['A'], 1.0);
    });

    test('weight>0 → 強產業股被加分上移、弱產業股被壓低', () {
      // A 與 C base 相同名次差距，但 A 在弱產業、B 在強產業
      final base = {'A': 30.0, 'B': 10.0}; // baseRank: B=0, A=1
      final tilt = service.sectorTiltedScores(
        baseKeyBySymbol: base,
        industryBySymbol: {'A': '弱產業', 'B': '強產業'},
        industryStrength: {'強產業': 1.0, '弱產業': 0.0},
        weight: 0.5,
      );
      // A = 0.5*1 + 0.5*0 = 0.5；B = 0.5*0 + 0.5*1 = 0.5 → 強產業把 B 拉到與 A 平
      expect(tilt['A'], closeTo(0.5, 1e-9));
      expect(tilt['B'], closeTo(0.5, 1e-9));
      // 權重再大一點 → 強產業 B 反超原本 base 較強的 A
      final tilt2 = service.sectorTiltedScores(
        baseKeyBySymbol: base,
        industryBySymbol: {'A': '弱產業', 'B': '強產業'},
        industryStrength: {'強產業': 1.0, '弱產業': 0.0},
        weight: 0.7,
      );
      expect(tilt2['B']! > tilt2['A']!, isTrue);
    });

    test('未知產業 / 缺強弱資料 → 視為 0.5 中性', () {
      final result = service.sectorTiltedScores(
        baseKeyBySymbol: {'A': 10.0, 'B': 20.0},
        industryBySymbol: {'A': null, 'B': '某產業'},
        industryStrength: const {}, // B 的產業沒強弱資料
        weight: 0.5,
      );
      // 兩者 sectorRank 都 0.5 → tilt 後仍按 baseRank 相對：A(0) < B(1)
      // A = 0.5*0 + 0.5*0.5 = 0.25；B = 0.5*1 + 0.5*0.5 = 0.75
      expect(result['A'], closeTo(0.25, 1e-9));
      expect(result['B'], closeTo(0.75, 1e-9));
    });
  });
}
