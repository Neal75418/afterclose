// Static drift guard：bundled `assets/calibration_manifest.json` 的
// `minimum_app_version` 必須 ≤ `pubspec.yaml` 的 `version`，否則 OTA gate
// 會在 production release 拒掉當前 build 自己（Milestone 1 review 抓到
// 的 blocker regression 2026-06-18）。
//
// 這是 static asset alignment 檢查，**不**透過 mock 跑 CalibrationUpdater
// — existing `calibration_updater_test.dart` 把 `appVersion` 直接塞進
// constructor 繞過 main.dart wiring，所以那層測試不會抓到 bundled manifest
// 跟 pubspec 失準的問題。
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calibration_manifest.json static alignment', () {
    test('minimum_app_version ≤ pubspec version (OTA self-lockout guard)', () {
      final manifest =
          jsonDecode(
                File('assets/calibration_manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final minVersion = manifest['minimum_app_version'] as String;

      final pubspec = File('pubspec.yaml').readAsLinesSync();
      final versionLine = pubspec.firstWhere(
        (l) => l.startsWith('version:'),
        orElse: () => throw StateError('pubspec.yaml missing version line'),
      );
      // `version: 0.5.1+1` → numeric segments only
      final pubspecVersion = versionLine
          .split(':')[1]
          .trim()
          .split(RegExp(r'[+\-]'))
          .first;

      expect(
        _compareVersionSegments(pubspecVersion, minVersion),
        greaterThanOrEqualTo(0),
        reason:
            'pubspec.yaml `version: $pubspecVersion` < manifest '
            '`minimum_app_version: $minVersion` — OTA gate 會把當前 release '
            '自己鎖在外面。降低 manifest minimum 或升 pubspec version。',
      );
    });

    test('tool/recalibrate.dart const aligns with bundled manifest', () {
      // 防止 manifest 被手動改但 recalibrate.dart 沒同步（下次 recalibrate
      // 跑出來的 candidate manifest 又會把 minimum 推回去）。
      final manifest =
          jsonDecode(
                File('assets/calibration_manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final bundledMin = manifest['minimum_app_version'] as String;

      final toolSrc = File('tool/recalibrate.dart').readAsStringSync();
      final match = RegExp(
        r"_manifestMinimumAppVersion\s*=\s*'([^']+)'",
      ).firstMatch(toolSrc);
      expect(
        match,
        isNotNull,
        reason: 'tool/recalibrate.dart 找不到 _manifestMinimumAppVersion const',
      );
      final toolMin = match!.group(1)!;

      expect(
        toolMin,
        equals(bundledMin),
        reason:
            'tool/recalibrate.dart `_manifestMinimumAppVersion = $toolMin` '
            '與 bundled manifest `$bundledMin` 不一致，下次跑 recalibrate '
            '產出的 candidate 會把 minimum 推回 $toolMin。',
      );
    });
    test('manifest sha256 與 bundled JSON 內容一致（手動改檔防漂移）', () {
      // OTA client 以 manifest.sha256 驗證下載的 JSON；bundled manifest 與
      // bundled JSON 不同步時，OTA 端會 integrity mismatch 靜默跳過更新。
      // 手動 patch production JSON（如 2026-07-11 TECH_BREAKDOWN 語意修正）
      // 必須同步重算 manifest hash —— 這個測試就是那條保險絲。
      final manifest =
          jsonDecode(
                File('assets/calibration_manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final horizon in ['short', 'long']) {
        final entry = manifest[horizon] as Map<String, dynamic>;
        final jsonStr = File('assets/${entry['filename']}').readAsStringSync();
        final actual = sha256.convert(utf8.encode(jsonStr)).toString();
        expect(
          actual,
          entry['sha256'],
          reason:
              '$horizon JSON 內容 hash 與 manifest 不符 — 改了 JSON 要同步 '
              'manifest（可用 tool/recalibrate.dart 重產或手動重算）',
        );
      }
    });
  });
}

/// 同 `CalibrationUpdater._parseVersionSegments` + 數字逐段比較。
/// 回傳 >0 / 0 / <0 對應 a>b / a=b / a<b。Malformed 任一側回傳 0（permissive
/// — 同 production 邏輯）。
int _compareVersionSegments(String a, String b) {
  final aSegs = _parse(a);
  final bSegs = _parse(b);
  if (aSegs == null || bSegs == null) return 0;
  final len = aSegs.length > bSegs.length ? aSegs.length : bSegs.length;
  for (var i = 0; i < len; i++) {
    final av = i < aSegs.length ? aSegs[i] : 0;
    final bv = i < bSegs.length ? bSegs[i] : 0;
    if (av != bv) return av - bv;
  }
  return 0;
}

List<int>? _parse(String v) {
  final cleaned = v.split(RegExp(r'[+\-]')).first;
  final parts = cleaned.split('.');
  final out = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null) return null;
    out.add(n);
  }
  return out;
}
