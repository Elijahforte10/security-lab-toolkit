#!/usr/bin/env python3
"""
poc_doctor.py — diagnose why an old Python PoC won't run

Old proof-of-concept exploit code is usually Python 2 and breaks under
Python 3. This statically scans a script (it does NOT execute it) and
reports the common breakers, with the fix for each — so you can patch a
PoC by hand instead of guessing at a traceback.

It reads only; it never runs the target code.

Usage:
    ./poc_doctor.py suspicious_poc.py
"""

import argparse
import ast
import re
import sys

# (regex, label, fix) for line-by-line pattern checks.
PATTERNS = [
    (r"^\s*print\s+[^(]",            "Python 2 print statement",
     "wrap in parentheses: print(...)"),
    (r"except\s+\w+\s*,\s*\w+\s*:",  "Python 2 except syntax",
     "use 'except Exception as e:'"),
    (r"\bimport\s+urllib2\b",        "urllib2 (Py2 only)",
     "use urllib.request / urllib.error"),
    (r"\bimport\s+urlparse\b",       "urlparse module (Py2)",
     "use urllib.parse"),
    (r"\b(raw_input)\s*\(",          "raw_input()",
     "use input()"),
    (r"\bhas_key\b",                 "dict.has_key()",
     "use 'key in dict'"),
    (r"\bxrange\b",                  "xrange()",
     "use range()"),
    (r"\.iteritems\(\)",             "dict.iteritems()",
     "use .items()"),
    (r"<>",                          "Py2 '<>' operator",
     "use '!='"),
    (r"\bstring\.(join|split|upper|lower)\b", "string module methods (Py2)",
     "use str methods, e.g. ' '.join(...)"),
    (r"\.decode\(['\"]hex['\"]\)",   "str.decode('hex') (Py2)",
     "use bytes.fromhex(...)"),
    (r"socket\.send\(\s*['\"]",      "sending a str over a socket",
     "Py3 sockets need bytes: send(b'...') or .encode()"),
]


def check_syntax(path, source):
    """Try to parse as Py3. A SyntaxError points right at a breaker."""
    try:
        ast.parse(source, filename=path)
        return None
    except SyntaxError as e:
        return f"line {e.lineno}: {e.msg}  ->  {(e.text or '').strip()}"


def main():
    ap = argparse.ArgumentParser(description="Diagnose Py2->Py3 PoC issues")
    ap.add_argument("file", help="path to the .py PoC")
    args = ap.parse_args()

    try:
        with open(args.file, encoding="utf-8", errors="replace") as fh:
            source = fh.read()
    except OSError as e:
        print(f"[!] cannot read file: {e}")
        sys.exit(1)

    lines = source.splitlines()
    print(f"[*] Diagnosing {args.file} ({len(lines)} lines)\n")

    # 1) Hard syntax check under Python 3.
    syn = check_syntax(args.file, source)
    if syn:
        print(f"[!] Python 3 SYNTAX ERROR — {syn}")
        print("    (fix this first; it blocks everything else)\n")

    # 2) Shebang sanity.
    if lines and lines[0].startswith("#!") and "python3" not in lines[0] \
            and "python" in lines[0]:
        print("[~] Shebang doesn't pin python3 — may launch under Py2.")
        print(f"    line 1: {lines[0]}  ->  use '#!/usr/bin/env python3'\n")

    # 3) Pattern scan.
    findings = 0
    for n, line in enumerate(lines, 1):
        for rx, label, fix in PATTERNS:
            if re.search(rx, line):
                findings += 1
                print(f"[!] line {n}: {label}")
                print(f"      {line.strip()}")
                print(f"      fix: {fix}\n")

    if not findings and not syn:
        print("[+] No common Py2->Py3 breakers found. If it still fails, the")
        print("    issue is likely a missing module (pip install ...) or a")
        print("    runtime/logic bug — run it and read the traceback.")
    else:
        print(f"[*] {findings} pattern issue(s) flagged. Patch and re-run.")


if __name__ == "__main__":
    main()
