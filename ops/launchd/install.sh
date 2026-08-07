#!/bin/zsh
# 安裝/更新 launchd 排程(2026-08-08)。
#
# 為什麼要有這支:plist 原本只存在於 ~/Library/LaunchAgents,未版控、
# 無文件——repo 搬家、路徑改變或換機都會讓排程靜默失效,而這個專案
# 已經有過「自動更新靜默斷 13 天」的前科。
#
# 用法:ops/launchd/install.sh   (從任何位置皆可)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DART="$(command -v dart || echo /opt/homebrew/bin/dart)"
UID_NUM="$(id -u)"

# 路徑含空白或 shell 特殊字元會產生「plutil 過但 job 永遠死」的假成功
# (2026-08-08 二次審查 F7):寧可拒裝也不要裝一個假的
case "$REPO$DART$HOME" in
  *[\ \'\"\&\<\>\$\`]*)
    echo "❌ 路徑含空白或特殊字元,plist 產生器不支援:" >&2
    echo "   REPO=$REPO" >&2
    echo "   DART=$DART" >&2
    echo "   HOME=$HOME" >&2
    exit 1
    ;;
esac

mkdir -p "$HOME/Library/Logs" "$HOME/Library/LaunchAgents"

for job in daily intraday; do
  src="$REPO/ops/launchd/com.neo.daredevil.$job.plist"
  dst="$HOME/Library/LaunchAgents/com.neo.daredevil.$job.plist"
  tmp="$(mktemp)"
  # 三類硬編碼路徑都要換:repo、dart、以及 $HOME 底下的日誌路徑
  # (只換前兩者的話,換機/換使用者時日誌會寫到別人的家目錄)
  sed -e "s|/Users/nealchen/IdeaProjects/daredevil|$REPO|g" \
      -e "s|/opt/homebrew/bin/dart|$DART|g" \
      -e "s|/Users/nealchen/Library|$HOME/Library|g" "$src" > "$tmp"
  # 先驗證再落地:直接寫 dst 會在驗證失敗時留下半殘的 plist
  plutil -lint "$tmp" > /dev/null
  mv "$tmp" "$dst"
  launchctl bootout "gui/$UID_NUM/com.neo.daredevil.$job" 2>/dev/null || true
  launchctl bootstrap "gui/$UID_NUM" "$dst"
  echo "✅ com.neo.daredevil.$job 已安裝 ($dst)"
done

echo
echo "殘留檢查(應無輸出):"
grep -l "/Users/nealchen" "$HOME/Library/LaunchAgents/com.neo.daredevil."*.plist 2>/dev/null \
  | grep -v "^$HOME" || true
echo "驗證:launchctl print gui/$UID_NUM/com.neo.daredevil.intraday | grep -E 'runs|exit'"
echo "日誌:$HOME/Library/Logs/daredevil-*.log"
