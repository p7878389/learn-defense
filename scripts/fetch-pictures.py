#!/usr/bin/env python3
"""从 microsoft/fluentui-emoji（MIT 许可）下载 3D 图片，放进 App 的图片目录。

每张图按 emoji 的码点命名，比如 🍎 → 1f34e.png，App 按 emoji 找图，找不到就显示系统 emoji。

用法：
  python3 -I scripts/fetch-pictures.py            # 补齐清单和所有题库里用到、但还没有的图
  python3 -I scripts/fetch-pictures.py 🦒 🍑      # 另外再下载这几个

清单在 Pictures/manifest.txt（界面和背景用到的 emoji），题库里的 "emoji" 字段会自动扫描。
"""

import json
import sys
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PICTURES = ROOT / "Packages/LearnKit/Sources/LearnGame/Resources/Pictures"
PACKS = ROOT / "Packages/LearnKit/Sources/LearnCore/Resources/Packs"
REPO = "microsoft/fluentui-emoji"
RAW = f"https://raw.githubusercontent.com/{REPO}/main/"

# Unicode 名字和 Fluent 目录名不一致的
ALIASES = {
    "black sun with rays": "sun",
    "white medium star": "star",
    "high voltage sign": "high voltage",
    "speaker with three sound waves": "speaker high volume",
    "lower left paintbrush": "paintbrush",
    "european castle": "castle",
    "ear of rice": "sheaf of rice",
    "wrapped present": "wrapped gift",
    "unicorn face": "unicorn",
    "fox face": "fox",
    "lion face": "lion",
    "panda face": "panda",
    "frog face": "frog",
    "bear face": "bear",
}


def key(emoji: str) -> str:
    """去掉变体选择符后的码点，和 App 里的 Pictures.key 一致"""
    return "-".join(f"{ord(c):x}" for c in emoji if c != "️")


def wanted() -> list[str]:
    found = []
    manifest = PICTURES / "manifest.txt"
    if manifest.exists():
        for line in manifest.read_text(encoding="utf-8").splitlines():
            line = line.split("#")[0].strip()
            found += line.split()
    for pack in sorted(PACKS.glob("*.json")):
        found += scan(json.loads(pack.read_text(encoding="utf-8")))
    found += sys.argv[1:]
    return list(dict.fromkeys(found))


def scan(node) -> list[str]:
    if isinstance(node, dict):
        out = [node["emoji"]] if isinstance(node.get("emoji"), str) else []
        for value in node.values():
            out += scan(value)
        return out
    if isinstance(node, list):
        return [e for item in node for e in scan(item)]
    return []


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "learn-defense"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def main() -> int:
    PICTURES.mkdir(parents=True, exist_ok=True)
    missing = [e for e in wanted() if not (PICTURES / f"{key(e)}.png").exists()]
    if not missing:
        print("图片已经齐了")
        return 0

    tree = json.loads(fetch(f"https://api.github.com/repos/{REPO}/git/trees/main?recursive=1"))
    files = [t["path"] for t in tree["tree"] if t["type"] == "blob"]
    folders = {p.split("/")[1].lower(): p.split("/")[1] for p in files if p.startswith("assets/")}

    failed = []
    for emoji in missing:
        chars = [c for c in emoji if c != "️"]
        name = unicodedata.name(chars[0], "").lower() if len(chars) == 1 else ""
        folder = folders.get(ALIASES.get(name, name))
        candidates = [
            p for p in files
            if folder and p.endswith(".png")
            and (p.startswith(f"assets/{folder}/3D/") or p.startswith(f"assets/{folder}/Default/3D/"))
        ]
        if not candidates:
            failed.append(emoji)
            continue
        data = fetch(RAW + urllib.parse.quote(candidates[0]))
        if not data.startswith(b"\x89PNG"):
            failed.append(emoji)
            continue
        (PICTURES / f"{key(emoji)}.png").write_bytes(data)
        print(f"{emoji}  {candidates[0]}  {len(data) // 1024}KB")

    license_file = PICTURES / "LICENSE-fluentui-emoji.txt"
    if not license_file.exists():
        license_file.write_bytes(fetch(RAW + "LICENSE"))

    if failed:
        print("没找到对应图片（App 会用系统 emoji 顶上）：", " ".join(failed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
