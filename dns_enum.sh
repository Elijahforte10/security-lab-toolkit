#!/usr/bin/env bash
#
# dns_enum.sh — resolve internal hostnames against a discovered DNS server
#
# A port scan through a pivot hands you IPs; the internal DNS server hands
# you names (and sometimes hosts you hadn't found). This forward-resolves a
# wordlist of likely internal names and reverse-resolves a subnet.
#
# Authorized use only.
#
# Usage:
#   ./dns_enum.sh <dns-server-ip> <domain> [wordlist]
#   ./dns_enum.sh 192.168.50.2 dev.local hostnames.txt
#
#   Reverse a /24:
#   ./dns_enum.sh <dns-server-ip> --reverse 192.168.50

set -uo pipefail

DNS_SERVER="${1:-}"
SECOND="${2:-}"
THIRD="${3:-}"

if [[ -z "$DNS_SERVER" || -z "$SECOND" ]]; then
    echo "Usage:"
    echo "  $0 <dns-server-ip> <domain> [wordlist]"
    echo "  $0 <dns-server-ip> --reverse <a.b.c>   # reverse a /24"
    exit 1
fi

if [[ "$SECOND" == "--reverse" ]]; then
    BASE="$THIRD"
    [[ -z "$BASE" ]] && { echo "[!] provide the /24 base, e.g. 192.168.50"; exit 1; }
    echo "[*] Reverse-resolving ${BASE}.0/24 via $DNS_SERVER"
    for i in $(seq 1 254); do
        name=$(nslookup "${BASE}.${i}" "$DNS_SERVER" 2>/dev/null \
               | awk -F'= ' '/name =/{print $2}')
        [[ -n "$name" ]] && echo "[+] ${BASE}.${i} -> ${name}"
    done
    exit 0
fi

DOMAIN="$SECOND"
WORDLIST="${THIRD:-}"

# Sensible default names if no wordlist supplied.
DEFAULT_NAMES=(dev test staging git jenkins web app db sql mail dns ns1 ns2 \
               intranet vpn fileserver backup admin api ftp)

resolve() {
    local host="$1"
    local fqdn="${host}.${DOMAIN}"
    local ip
    ip=$(nslookup "$fqdn" "$DNS_SERVER" 2>/dev/null \
         | awk '/^Address: /{print $2}' | tail -n1)
    [[ -n "$ip" ]] && echo "[+] ${fqdn} -> ${ip}"
}

echo "[*] Forward-resolving names in ${DOMAIN} via $DNS_SERVER"
if [[ -n "$WORDLIST" && -f "$WORDLIST" ]]; then
    while read -r name; do
        [[ -n "$name" ]] && resolve "$name"
    done < "$WORDLIST"
else
    for name in "${DEFAULT_NAMES[@]}"; do
        resolve "$name"
    done
fi
