#!/usr/bin/env python3
"""
nmap_parse.py — extract open ports/services from nmap output

Feed it nmap greppable output (-oG) or XML (-oX) and it prints a clean,
sortable summary plus a comma-separated port list you can paste straight
into a follow-up targeted scan.

Usage:
    nmap -sS -p- 192.168.1.10 -oG scan.gnmap
    ./nmap_parse.py scan.gnmap

    nmap -sV 192.168.1.10 -oX scan.xml
    ./nmap_parse.py scan.xml
"""

import argparse
import re
import sys
import xml.etree.ElementTree as ET


def parse_greppable(path):
    """Parse -oG output. Lines look like: Host: 1.2.3.4 () Ports: 22/open/tcp//ssh..."""
    results = {}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "Ports:" not in line:
                continue
            host = re.search(r"Host:\s+(\S+)", line)
            host = host.group(1) if host else "unknown"
            ports_blob = line.split("Ports:", 1)[1]
            for entry in ports_blob.split(","):
                fields = entry.strip().split("/")
                if len(fields) >= 5 and fields[1] == "open":
                    port, proto, svc = fields[0], fields[2], fields[4] or "?"
                    results.setdefault(host, []).append((int(port), proto, svc))
    return results


def parse_xml(path):
    """Parse -oX output."""
    results = {}
    tree = ET.parse(path)
    for host in tree.getroot().findall("host"):
        addr_el = host.find("address")
        addr = addr_el.get("addr") if addr_el is not None else "unknown"
        for port in host.findall("./ports/port"):
            state = port.find("state")
            if state is None or state.get("state") != "open":
                continue
            svc_el = port.find("service")
            svc = svc_el.get("name") if svc_el is not None else "?"
            ver = ""
            if svc_el is not None:
                ver = " ".join(filter(None, [svc_el.get("product"),
                                             svc_el.get("version")]))
            label = f"{svc} {ver}".strip()
            results.setdefault(addr, []).append(
                (int(port.get("portid")), port.get("protocol"), label))
    return results


def main():
    ap = argparse.ArgumentParser(description="Parse nmap -oG or -oX output")
    ap.add_argument("file", help="path to .gnmap or .xml nmap output")
    args = ap.parse_args()

    if args.file.endswith(".xml"):
        data = parse_xml(args.file)
    else:
        data = parse_greppable(args.file)

    if not data:
        print("[!] No open ports parsed. Check the file format.")
        sys.exit(1)

    for host, ports in data.items():
        ports.sort()
        print(f"\n=== {host} ===")
        for port, proto, svc in ports:
            print(f"  {port:>5}/{proto:<3}  {svc}")
        portlist = ",".join(str(p) for p, _, _ in ports)
        print(f"  -> reuse: -p {portlist}")


if __name__ == "__main__":
    main()
