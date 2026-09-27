#!/usr/bin/env python3
"""Write one version string into every data-repo-version slot.

The version shown on the page is the release the page documents, not a number
typed by hand. It comes from the highest version tag in the repo, which is the
same release the runtime check asks GitHub for, so the two slots can never drift
apart and the update notice stays quiet. Pass a version to override the lookup:

    python3 scripts/inject-version.py
    python3 scripts/inject-version.py v1.2.3
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
HTML = ROOT / "site" / "index.html"
TAG = re.compile(r"^v?\d+\.\d+(\.\d+)?([-.][0-9A-Za-z.-]+)?$")


def resolve(argument):
    if argument:
        candidate = argument.strip()
    else:
        try:
            candidate = subprocess.run(
                ["git", "tag", "--list", "v*", "--sort=-v:refname"],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=True,
            ).stdout.split("\n")[0].strip()
        except (OSError, subprocess.CalledProcessError):
            sys.exit("cannot read the tags; pass the version explicitly")
    if not TAG.match(candidate):
        sys.exit(f"not a version tag: {candidate!r}")
    return candidate if candidate.startswith("v") else "v" + candidate


def main():
    if len(sys.argv) > 2:
        sys.exit("usage: inject-version.py [version]")
    version = resolve(sys.argv[1] if len(sys.argv) > 1 else "")

    doc = HTML.read_text()
    slots = doc.count("data-repo-version")
    if slots == 0:
        sys.exit("no data-repo-version slots found")

    injected = 0
    out = []
    for line in doc.split("\n"):
        if "data-repo-version" in line:
            head, sep, tail = line.partition(">")
            if not sep:
                sys.exit(f"cannot parse slot: {line}")
            if "data-repo-version" in head and not head.rstrip().endswith("data-repo-version"):
                sys.exit(f"slot has attributes after the marker: {line}")
            trailing = re.sub(r"^[^<]*", "", tail, count=1)
            out.append(head + ">" + version + trailing)
            injected += 1
        else:
            out.append(line)

    HTML.write_text("\n".join(out))
    print(f"injected {injected}/{slots} slots with {version}")


if __name__ == "__main__":
    main()
