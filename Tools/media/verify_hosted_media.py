#!/usr/bin/env python3
"""Check a published immutable lesson release and optional Android preview."""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--apk-url")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    base = args.base.rstrip("/") + "/"
    raw = args.manifest.read_bytes()
    manifest = json.loads(raw)

    def request(url, method="GET", headers=None):
        response = urllib.request.urlopen(urllib.request.Request(
            url, method=method, headers={"Accept-Encoding": "identity", "User-Agent": "SwedishCards/0.1 (hosting verification)", **(headers or {})}), timeout=45)
        assert response.url == url, f"Unexpected redirect: {url}"
        return response

    def digest(data):
        return hashlib.sha256(data).hexdigest()

    with request(base + "manifest.json") as response:
        assert response.read() == raw, "Hosted manifest differs"

    def check_pack(pack):
        with request(base + pack["file"], "HEAD") as response:
            assert response.status == 200
            assert int(response.headers["Content-Length"]) == pack["bytes"], pack["file"]
        return pack["file"]

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        checked = list(pool.map(check_pack, manifest["packs"]))
    packs = {p["file"]: p for p in manifest["packs"]}
    ranges = []
    for kind in ("image/", "audio/sv-SE/", "audio/en-US/"):
        item = next(a for a in manifest["assets"] if a["key"].startswith(kind) and not packs[a["pack"]]["starter"])
        start, end = item["offset"], item["offset"] + item["bytes"] - 1
        with request(base + item["pack"], headers={"Range": f"bytes={start}-{end}"}) as response:
            assert response.status == 206
            assert response.headers["Content-Range"] == f"bytes {start}-{end}/{packs[item['pack']]['bytes']}"
            assert digest(response.read()) == item["sha256"]
        ranges.append(item["key"])
    pack = next(p for p in manifest["packs"] if not p["starter"])
    with request(base + pack["file"]) as response:
        assert digest(response.read()) == pack["sha256"]
    result = dict(base=base, version=manifest["version"], packHeadersVerified=len(checked),
                  rangesVerified=ranges, fullPackVerified=pack["file"])
    if args.apk:
        assert args.apk_url
        with request(args.apk_url) as response:
            assert response.headers["Content-Type"].split(";")[0] == "application/vnd.android.package-archive"
            assert digest(response.read()) == digest(args.apk.read_bytes())
        result.update(apkUrl=args.apk_url, apkBytes=args.apk.stat().st_size,
                      apkSha256=digest(args.apk.read_bytes()))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
