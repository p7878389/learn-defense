#!/bin/bash
# 编译 App 并在 iPad 模拟器里运行（纯命令行，不用打开 Xcode 界面）
# 用法：scripts/run-simulator.sh ["iPad Air 11-inch (M3)"]
set -euo pipefail

cd "$(dirname "$0")/.."

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "没有找到 Xcode。请先从 App Store 安装 Xcode，然后运行："
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# 按名字找模拟器（名字里可能带括号），没有指定时选第一个可用的 iPad
WANT="${1:-iPad}"
read -r UDID DEVICE < <(xcrun simctl list devices available -j | python3 -I -c '
import json, sys
want = sys.argv[1]
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in ds]
match = [d for d in devices if d["name"] == want] or [d for d in devices if d["name"].startswith(want)]
if match:
    print(match[0]["udid"], match[0]["name"])
' "$WANT") || true
if [ -z "${UDID:-}" ]; then
    echo "没有找到模拟器「$WANT」。请在 Xcode 设置 → Components 里下载 iOS 模拟器。"
    exit 1
fi
echo "▶ 使用模拟器：$DEVICE"

xcodebuild \
    -project LearnDefense.xcodeproj \
    -scheme LearnDefense \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath build \
    build | grep -E "error:|warning:|BUILD" || true

APP="build/Build/Products/Debug-iphonesimulator/LearnDefense.app"
[ -d "$APP" ] || { echo "编译失败"; exit 1; }

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.martin.learndefense
echo "✅ 已在「$DEVICE」上启动"
