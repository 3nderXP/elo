#!/usr/bin/env python3
"""Inject the byte-exact ASCII wordmark into every data-ascii-logo slot.

Idempotent: replaces the whole slot content, so running it twice is a no-op.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ASC = ROOT / "assets" / "branding" / "elo.asc"
HTML = ROOT / "site" / "index.html"

SLOT = re.compile(r"(<pre[^>]*\bdata-ascii-logo\b[^>]*>)(.*?)(</pre>)", re.S)

wordmark = ASC.read_text().rstrip("\n")
doc = HTML.read_text()

expected = doc.count("data-ascii-logo")
if expected == 0:
    sys.exit("no data-ascii-logo slots found")

injected = 0


def replace(match: re.Match) -> str:
    global injected
    injected += 1
    return match.group(1) + wordmark + match.group(3)


out = SLOT.sub(replace, doc)

if injected != expected:
    sys.exit(f"matched {injected} of {expected} data-ascii-logo slots")

HTML.write_text(out)
print(f"injected {injected}/{expected} slots from {ASC.relative_to(ROOT)}")
