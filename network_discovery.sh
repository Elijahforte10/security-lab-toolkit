#!/usr/bin/env bash
#
# network_discovery.sh — Layer 2 (ARP) host discovery
#
# Why this exists:
#   Many environments drop ICMP (ping), so a standard Layer 3 ping sweep
#   reports every host as "down" and you find nothing. ARP operates at
#   Layer 2 and cannot be meaningfully firewalled on the local segment —
#   every live host must answer ARP to function — so it surfaces hosts that
#   a ping sweep hides.
#
# Authorized use only. Run this only against networks you own or have
# explicit written permission to assess.
#
# Usage:
#   sudo ./network_discovery.sh <interface> <cidr>
#   sudo ./network_discovery.sh eth0 192.168.1.0/24

set -euo pipefail

IFACE="${1:-}"
RANGE="${2:-}"

if [[ -z "$IFACE" || -z "$RANGE" ]]; then
    echo "Usage: sudo $0 <interface> <cidr>"
    echo "Example: sudo $0 eth0 192.168.1.0/24"
    exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
    echo "[!] ARP discovery needs root. Re-run with sudo."
    exit 1
fi

OUTFILE="discovery_$(date +%Y%m%d_%H%M%S).txt"

echo "[*] Interface : $IFACE"
echo "[*] Range     : $RANGE"
echo "[*] Output    : $OUTFILE"
echo

# Prefer nmap's ARP discovery (-PR). -sn = no port scan, discovery only.
if command -v nmap >/dev/null 2>&1; then
    echo "[*] Running ARP discovery with nmap (-PR -sn)..."
    nmap -sn -PR -e "$IFACE" "$RANGE" | tee "$OUTFILE"
elif command -v netdiscover >/dev/null 2>&1; then
    echo "[*] nmap not found, falling back to netdiscover..."
    netdiscover -i "$IFACE" -r "$RANGE" -P | tee "$OUTFILE"
elif command -v arp-scan >/dev/null 2>&1; then
    echo "[*] Using arp-scan..."
    arp-scan --interface="$IFACE" "$RANGE" | tee "$OUTFILE"
else
    echo "[!] None of nmap / netdiscover / arp-scan found. Install one."
    exit 1
fi

echo
echo "[*] Live hosts saved to $OUTFILE"
