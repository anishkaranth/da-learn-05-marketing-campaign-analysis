#!/usr/bin/env python3
"""Build the reproducible repo sample data/raw/bank-additional-full.csv from the full file (run download_full_data.py first).

Rule (deterministic): keep every 600th record in file order (file rows 600, 1200, ... -> 68 of 41,188 contacts).
The file is chronological (May 2008 - Nov 2010), so the sample spans the whole campaign. All 21 columns are kept
verbatim (same ";" delimiter and quoting; CRLF line endings normalised to LF) so sql/01_staging.sql reads sample and full alike.
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
FULL = ROOT / "data/raw_full/bank-additional-full.csv"
OUT = ROOT / "data/raw/bank-additional-full.csv"
lines = FULL.read_bytes().replace(b"\r\n", b"\n").split(b"\n")
header, body = lines[0], [l for l in lines[1:] if l]
keep = [l for i, l in enumerate(body, start=1) if i % 600 == 0]
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_bytes(b"\n".join([header] + keep) + b"\n")
print(f"{OUT.name}: {len(keep)} of {len(body)} rows")
