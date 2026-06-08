#!/usr/bin/env python3
"""
banner_grab.py — lightweight service banner grabber

Connects to one or more TCP ports on a target and reads whatever the
service announces. Banners frequently leak the product and version
string ("the truth is in the details"), which is the breadcrumb that
points at the vulnerable service.

Authorized use only. Scan only hosts you own or are permitted to test.

Usage:
    ./banner_grab.py <host> -p 21,22,80,443
    ./banner_grab.py 192.168.1.10 -p 1-1000 --timeout 2
"""

import argparse
import socket
import sys


def parse_ports(spec: str):
    """Turn '22,80,1-100' into a sorted list of ints."""
    ports = set()
    for chunk in spec.split(","):
        chunk = chunk.strip()
        if "-" in chunk:
            lo, hi = chunk.split("-", 1)
            ports.update(range(int(lo), int(hi) + 1))
        elif chunk:
            ports.add(int(chunk))
    return sorted(p for p in ports if 0 < p < 65536)


def grab(host: str, port: int, timeout: float) -> str | None:
    """Return the banner string for host:port, or None if nothing/closed."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(timeout)
            s.connect((host, port))
            # Some services (HTTP) only talk after we do. Nudge them.
            if port in (80, 8080, 8000):
                s.sendall(b"HEAD / HTTP/1.0\r\n\r\n")
            data = s.recv(1024)
            return data.decode(errors="replace").strip() or None
    except (socket.timeout, ConnectionRefusedError, OSError):
        return None


def main():
    ap = argparse.ArgumentParser(description="Simple TCP banner grabber")
    ap.add_argument("host", help="target IP or hostname")
    ap.add_argument("-p", "--ports", default="21,22,23,25,80,110,143,443,3306,8080",
                    help="comma list and/or ranges, e.g. 22,80,1-1000")
    ap.add_argument("--timeout", type=float, default=2.0, help="socket timeout (s)")
    args = ap.parse_args()

    ports = parse_ports(args.ports)
    print(f"[*] Banner grab against {args.host} ({len(ports)} ports)\n")

    found = 0
    for port in ports:
        banner = grab(args.host, port, args.timeout)
        if banner:
            found += 1
            # Show first line — that's usually where the version lives.
            first = banner.splitlines()[0]
            print(f"[+] {port:>5}/tcp  {first}")

    print(f"\n[*] Done. {found} port(s) returned a banner.")
    if not found:
        print("[!] No banners. Try -sV with nmap, or the service may be silent.")
        sys.exit(1)


if __name__ == "__main__":
    main()
