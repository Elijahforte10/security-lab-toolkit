#!/usr/bin/env python3
"""
loot_helper.py — post-foothold loot processing

After you land on a host, you collect files: archives, configs, encoded
blobs. This bundles the boring-but-constant tasks into one tool:

    * base64 decode (strings or files)
    * find archives recursively
    * extract zip archives (with optional password)
    * pull values out of config files (sed-style regex extraction)

It does NOT exploit anything — it's a data-handling utility for material
you've already lawfully obtained during an authorized assessment.

Usage:
    ./loot_helper.py b64 aGVsbG8=                # decode a string
    ./loot_helper.py b64 --file blob.txt         # decode file contents
    ./loot_helper.py find /tmp/loot              # locate archives
    ./loot_helper.py unzip found.zip -d out/ [--password secret]
    ./loot_helper.py extract config.txt 'password=(.*)'
"""

import argparse
import base64
import os
import re
import sys
import zipfile


def cmd_b64(args):
    raw = open(args.value, "rb").read() if args.file else args.value.encode()
    try:
        decoded = base64.b64decode(raw, validate=False)
    except Exception as e:
        print(f"[!] decode failed: {e}")
        sys.exit(1)
    sys.stdout.buffer.write(decoded)
    sys.stdout.write("\n")


def cmd_find(args):
    exts = (".zip", ".tar", ".gz", ".tgz", ".7z", ".rar", ".bz2")
    hits = []
    for root, _, files in os.walk(args.path):
        for f in files:
            if f.lower().endswith(exts):
                hits.append(os.path.join(root, f))
    if hits:
        print(f"[+] {len(hits)} archive(s) found:")
        for h in hits:
            print(f"    {h}")
    else:
        print("[!] No archives found.")


def cmd_unzip(args):
    pwd = args.password.encode() if args.password else None
    try:
        with zipfile.ZipFile(args.zipfile) as zf:
            zf.extractall(path=args.dest, pwd=pwd)
            print(f"[+] Extracted {len(zf.namelist())} entries to {args.dest}")
            for name in zf.namelist():
                print(f"    {name}")
    except RuntimeError as e:
        # Usually "Bad password" or an encrypted entry.
        print(f"[!] {e} (try --password)")
        sys.exit(1)


def cmd_extract(args):
    pattern = re.compile(args.regex)
    with open(args.file, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = pattern.search(line)
            if m:
                # Print the first capture group if present, else whole match.
                print(m.group(1) if m.groups() else m.group(0))


def main():
    ap = argparse.ArgumentParser(description="Post-foothold loot processor")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("b64", help="base64 decode")
    p.add_argument("value", help="string to decode, or path if --file")
    p.add_argument("--file", action="store_true", help="treat value as a file path")
    p.set_defaults(func=cmd_b64)

    p = sub.add_parser("find", help="find archives recursively")
    p.add_argument("path")
    p.set_defaults(func=cmd_find)

    p = sub.add_parser("unzip", help="extract a zip archive")
    p.add_argument("zipfile")
    p.add_argument("-d", "--dest", default=".")
    p.add_argument("--password")
    p.set_defaults(func=cmd_unzip)

    p = sub.add_parser("extract", help="regex-extract a value from a file")
    p.add_argument("file")
    p.add_argument("regex", help="regex; first capture group is printed if present")
    p.set_defaults(func=cmd_extract)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
