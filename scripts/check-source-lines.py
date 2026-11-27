#!/usr/bin/env python3
"""检查 Git 管理及未忽略的新代码文件，避免单文件超过 400 行。"""

import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
extensions = {
    ".swift", ".py", ".sh", ".js", ".ts", ".tsx", ".jsx",
    ".m", ".mm", ".h", ".c", ".cpp", ".metal",
}
paths = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
    cwd=root,
).decode().split("\0")
violations = []
checked = 0
for name in sorted(set(paths)):
    if not name or pathlib.PurePosixPath(name).parts[0].startswith("."):
        continue
    path = root / name
    if path.suffix not in extensions or not path.is_file():
        continue
    checked += 1
    count = len(path.read_bytes().splitlines())
    if count > 400:
        violations.append((name, count))

for name, count in violations:
    print(f"{name}: {count} 行，超过 400 行限制")
print(f"已检查 {checked} 个代码文件，超限 {len(violations)} 个")
sys.exit(1 if violations else 0)
