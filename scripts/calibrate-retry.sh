#!/usr/bin/env bash
#
# scripts/calibrate-retry.sh — calibrate.sh 的 rate-limit retry wrapper
#
# 自動偵測 TWSE rate limit 並 sleep 15 分鐘重跑，最多 MAX_RETRIES 輪。
# 每輪 calibrate.sh 跑 ~7-15 分鐘可以推進 60-120 trading days，
# 一次完整 2 年 backfill 預計 3-6 輪、總時間 3-5 小時。
#
# ## 使用
#
#     export FINMIND_TOKEN=eyJ...
#     ./scripts/calibrate-retry.sh                # 預設 30 retry × 15min
#
#     # 可選 env vars（會傳給 calibrate.sh）
#     export BACKFILL_YEARS=2                     # 預設 2
#     export BACKFILL_SYMBOLS=2330,2317           # 預設全市場
#     export BACKFILL_INTER_DAY_DELAY_MS=5000     # 預設 5000ms
#     ./scripts/calibrate-retry.sh
#
#     # 調 retry / sleep
#     MAX_RETRIES=10 SLEEP_BETWEEN_RETRIES=600 ./scripts/calibrate-retry.sh
#
# ## 背景跑 + 監看
#
#     nohup ./scripts/calibrate-retry.sh >> calibrate.log 2>&1 &
#     tail -f calibrate.log
#
#     # 確認 process 還活著
#     ps aux | grep -E "calibrate" | grep -v grep
#
#     # 看 retry 歷史
#     grep "attempt" calibrate.log
#
#     # 中止
#     pkill -f "scripts/calibrate"
#
# ## 為什麼不直接 `while ! ./scripts/calibrate.sh; do`
#
# 踩過的兩個 bash 陷阱：
#
# 1. **`!` 反轉 exit code**：`while ! cmd; do code=$?` 抓到的是 `!` 反轉
#    後的值（0），不是 cmd 真實 exit code（4）。改用 `cmd && exit 0` +
#    後續處理。
#
# 2. **Test runner 包覆 exit code**：calibrate.sh 內部跑 `flutter test`，
#    test runner 把 backfill 工具的 exit 4（rate limit）統一包成 exit 1
#    （test failed）。即使 calibrate.sh 內 docstring 寫「exit 4 = rate
#    limit」，wrapper 之外看到的是 1，無法靠 exit code 區分 rate limit
#    vs 其他失敗。改用 log content grep "API rate limit exceeded" 判斷。
#
# 同時記錄 calibrate 跑之前的 log 行數，retry 判斷只看新增的行，避免
# 上一輪殘留的 "rate limit" 字串誤觸發。

set -uo pipefail
# 不用 `set -e` — 我們需要自己判斷 calibrate.sh 失敗原因

# ============================================================================
# Config
# ============================================================================

: "${MAX_RETRIES:=30}"
: "${SLEEP_BETWEEN_RETRIES:=900}"  # 15 分鐘
: "${CALIBRATE_LOG:=$(cd "$(dirname "$0")/.." && pwd)/calibrate.log}"

# 自動切到 repo root（script 可能從任何目錄呼叫）
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ============================================================================
# Prerequisites
# ============================================================================

if [ -z "${FINMIND_TOKEN:-}" ]; then
  echo "❌ FINMIND_TOKEN 環境變數未設定" >&2
  echo "" >&2
  echo "請先設定：" >&2
  echo "  export FINMIND_TOKEN=<你的 token>" >&2
  exit 1
fi

if [ ! -x "scripts/calibrate.sh" ]; then
  echo "❌ scripts/calibrate.sh 不存在或不可執行" >&2
  exit 1
fi

# ============================================================================
# Retry loop
# ============================================================================

echo "=========================================================="
echo "🔁 Calibrate Retry Wrapper"
echo "=========================================================="
echo "  Max retries:           $MAX_RETRIES"
echo "  Sleep between retries: ${SLEEP_BETWEEN_RETRIES}s"
echo "  Log:                   $CALIBRATE_LOG"
echo "  Start:                 $(date)"
echo "=========================================================="
echo ""

for i in $(seq 1 "$MAX_RETRIES"); do
  echo "[$(date)] attempt $i/$MAX_RETRIES: starting calibrate.sh"

  # 記錄當前 log 行數（用來只 grep 這輪新增的部分）
  start_lines=$(wc -l < "$CALIBRATE_LOG" 2>/dev/null || echo 0)

  if ./scripts/calibrate.sh; then
    echo ""
    echo "[$(date)] attempt $i: ✅ PIPELINE COMPLETE"
    exit 0
  fi

  exit_code=$?

  # 只 grep 這輪新增的 log 行
  new_lines=$(tail -n +$((start_lines + 1)) "$CALIBRATE_LOG" 2>/dev/null || echo "")

  # Transient failures：rate limit + network error 都 retry
  # - rate limit: TWSE 短期 IP cooldown (~15min)
  # - network error: TPEx server 偶爾主動斷線（HttpException: Connection closed）
  #                  → 短 sleep 60s 即可（不是 rate limit）
  if echo "$new_lines" | grep -q "API rate limit exceeded"; then
    echo "[$(date)] attempt $i: rate limit，sleep ${SLEEP_BETWEEN_RETRIES}s"
    sleep "$SLEEP_BETWEEN_RETRIES"
  elif echo "$new_lines" | grep -q "Network error"; then
    echo "[$(date)] attempt $i: network error，sleep 60s"
    sleep 60
  else
    echo "[$(date)] attempt $i: non-transient failure (exit $exit_code)，aborting" >&2
    echo "Last 50 lines of log:" >&2
    tail -50 "$CALIBRATE_LOG" >&2
    exit "$exit_code"
  fi
done

echo "[$(date)] ❌ Exceeded $MAX_RETRIES retries，giving up" >&2
exit 1
