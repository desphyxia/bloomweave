#!/usr/bin/env python3
"""Fetch only Godot's web export templates from the official archive.

The full export-templates archive is over 1 GB. This reads just the web
templates out of it with HTTP range requests and installs them where Godot
looks for them.

Usage: scripts/fetch_web_templates.py 4.7.2
"""
import io
import os
import ssl
import sys
import urllib.request
import zipfile

WANTED = ("version.txt", "web_nothreads_release.zip", "web_nothreads_debug.zip")
UA = {"User-Agent": "bloomweave-ci"}


def main() -> None:
    version = sys.argv[1]
    url = f"https://downloads.godotengine.org/?version={version}&flavor=stable&slug=export_templates.tpz"
    cafile = os.environ.get("SSL_CERT_FILE")
    ctx = ssl.create_default_context(cafile=cafile) if cafile else ssl.create_default_context()
    opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))

    first = opener.open(urllib.request.Request(url, headers={**UA, "Range": "bytes=0-0"}))
    final_url = first.geturl()
    size = int(first.headers["Content-Range"].split("/")[1])

    class RangeFile(io.RawIOBase):
        def __init__(self) -> None:
            self.pos = 0

        def seekable(self) -> bool:
            return True

        def readable(self) -> bool:
            return True

        def tell(self) -> int:
            return self.pos

        def seek(self, offset: int, whence: int = 0) -> int:
            base = {0: 0, 1: self.pos, 2: size}[whence]
            self.pos = base + offset
            return self.pos

        def readinto(self, buf) -> int:
            n = min(len(buf), size - self.pos)
            if n <= 0:
                return 0
            req = urllib.request.Request(
                final_url, headers={**UA, "Range": f"bytes={self.pos}-{self.pos + n - 1}"})
            data = opener.open(req).read()
            buf[:len(data)] = data
            self.pos += len(data)
            return len(data)

    archive = zipfile.ZipFile(io.BufferedReader(RangeFile(), buffer_size=1 << 20))
    dest = os.path.expanduser(f"~/.local/share/godot/export_templates/{version}.stable")
    os.makedirs(dest, exist_ok=True)
    for name in archive.namelist():
        base = name.rsplit("/", 1)[-1]
        if base in WANTED:
            with archive.open(name) as src, open(os.path.join(dest, base), "wb") as out:
                out.write(src.read())
            print("installed", base)


if __name__ == "__main__":
    main()
