#!/bin/zsh
# 安裝/更新 launchd 排程(2026-08-08)。
#
# 為什麼要有這支:plist 原本只存在於 ~/Library/LaunchAgents,未版控、
# 無文件——repo 搬家、路徑改變或換機都會讓排程靜默失效,而這個專案
# already 有過「自動更新靜默斷 13 天」的前科。
#
# 用法:ops/launchd/install.sh   (從 repo root 執行)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DART="$(command -v dart || echo /opt/homebrew/bin/dart)"
UID_NUM="$(id -u)"

for job in daily intraday; do
  src="$REPO/ops/launchd/com.neo.daredevil.$job.plist"
  dst="$HOME/Library/LaunchAgents/com.neo.daredevil.$job.plist"
  # 把版控的樣板中的路徑換成本機實際值
  sed -e "s|/Users/nealchen/IdeaProjects/daredevil|$REPO|g" \
      -e "s|/opt/homebrew/bin/dart|$DART|g" "$src" > "$dst"
  plutil -lint "$dst" > /dev/null
  launchctl bootout "gui/$UID_NUM/com.neo.daredevil.$job" 2>/dev/null || true
  launchctl bootstrap "gui/$UID_NUM" "$dst"
  echo "✅ com.neo.daredevil.$job 已安裝 ($dst)"
done

echo
echo "驗證:launchctl print gui/$UID_NUM/com.neo.daredevil.intraday | grep -E 'runs|exit'"
echo "日誌:~/Library/Logs/daredevil-*.log"
