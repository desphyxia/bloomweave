#!/usr/bin/env python3
"""Give the exported game pack a per-build name so browsers can't reuse an
old cached copy.

GitHub Pages lets browsers cache files for 10 minutes, and phones often keep
them even after a reload. Renaming index.pck to index-<build>.pck and pointing
index.html at it means every deploy fetches the new game data.

Usage: scripts/stamp_web_build.py build/web <build-id>
"""
import json
import os
import re
import sys


def main() -> None:
    web_dir, build = sys.argv[1], sys.argv[2]
    html_path = os.path.join(web_dir, "index.html")
    new_pack = f"index-{build}.pck"
    os.replace(os.path.join(web_dir, "index.pck"), os.path.join(web_dir, new_pack))

    html = open(html_path, encoding="utf-8").read()
    match = re.search(r"const GODOT_CONFIG = (\{.*?\});", html, re.S)
    if not match:
        sys.exit("GODOT_CONFIG not found in index.html")
    config = json.loads(match.group(1))
    config["mainPack"] = new_pack
    sizes = config.get("fileSizes", {})
    if "index.pck" in sizes:
        sizes[new_pack] = sizes.pop("index.pck")
    html = html[:match.start(1)] + json.dumps(config, separators=(",", ":")) + html[match.end(1):]
    open(html_path, "w", encoding="utf-8").write(html)
    print("main pack:", new_pack)


if __name__ == "__main__":
    main()
