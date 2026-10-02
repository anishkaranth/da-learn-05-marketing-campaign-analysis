#!/usr/bin/env python3
"""Download the complete UCI Bank Marketing file (bank-additional-full.csv) into data/raw_full/ (git-ignored).

Source: UCI Machine Learning Repository dataset 222 "Bank Marketing" (Moro, Cortez & Rita 2014), CC BY 4.0.
Kaggle copy: henriqueyamahata/bank-marketing. No Kaggle key needed: the official UCI zip is tried first
(nested zip -> bank-additional/bank-additional-full.csv), then a byte-identical GitHub mirror.
"""
import hashlib, io, pathlib, sys, urllib.request, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "data/raw_full"
NAME = "bank-additional-full.csv"
UCI_ZIP = "https://archive.ics.uci.edu/static/public/222/bank+marketing.zip"
MIRROR = "https://raw.githubusercontent.com/selva86/datasets/master/bank-additional-full.csv"
SHA256 = "74adfc578bf77a7ff4bb1ba4a9f8709d9e3c6907342959c2c8416847e0afb4d8"  # 5,834,924 bytes, 41,188 rows x 21 cols


def from_uci():
    outer = zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(UCI_ZIP, timeout=120).read()))
    inner = zipfile.ZipFile(io.BytesIO(outer.read("bank-additional.zip")))
    return inner.read(f"bank-additional/{NAME}")


def from_mirror():
    return urllib.request.urlopen(MIRROR, timeout=120).read()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / NAME
    if dest.exists() and hashlib.sha256(dest.read_bytes()).hexdigest() == SHA256:
        print("already present:", dest); return
    for label, fetch in (("UCI zip", from_uci), ("GitHub mirror", from_mirror)):
        try:
            print("downloading from", label); data = fetch()
        except Exception as e:  # try the next source
            print("  failed:", e); continue
        if hashlib.sha256(data).hexdigest() != SHA256:
            print("  checksum mismatch"); continue
        dest.write_bytes(data)
        print(f"saved {dest} ({len(data):,} bytes, sha256 ok)"); return
    sys.exit("all sources failed")


if __name__ == "__main__":
    main()
