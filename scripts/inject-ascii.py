#!/usr/bin/env python3
"""Inject the byte-exact ASCII wordmark into every data-ascii-logo slot."""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ASC = ROOT / "assets" / "branding" / "elo.asc"
HTML = ROOT / "site" / "index.html"

wordmark = ASC.read_text().rstrip("\n")
doc = HTML.read_text()

slots = doc.count("data-ascii-logo")
if slots == 0:
    sys.exit("no data-ascii-logo slots found")

injected = 0
out = []
for line in doc.split("\n"):
    if "data-ascii-logo" in line:
        head, sep, _tail = line.partition(">")
        if not sep:
            sys.exit(f"cannot parse slot: {line}")
        out.append(head + ">" + wordmark + "</pre>")
        injected += 1
    else:
        out.append(line)

HTML.write_text("\n".join(out))
print(f"injected {injected}/{slots} slots from {ASC.relative_to(ROOT)}")
