#!/usr/bin/env bash
#
# iac_security_scan.sh — run IaC misconfiguration scanners over a directory
#
# Wraps the common "shift-left" scanners so you can catch insecure
# infrastructure definitions (open security groups, unencrypted storage,
# hardcoded secrets) before they ever deploy. Runs whichever scanners are
# installed and skips the rest.
#
# Scanners supported: tfsec, checkov, terrascan, trivy
#
# Usage:
#   ./iac_security_scan.sh <path-to-iac-dir>
#   ./iac_security_scan.sh ./terraform

set -uo pipefail

TARGET="${1:-.}"

if [[ ! -d "$TARGET" ]]; then
    echo "[!] '$TARGET' is not a directory."
    echo "Usage: $0 <path-to-iac-dir>"
    exit 1
fi

REPORT_DIR="iac_scan_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"
echo "[*] Scanning: $TARGET"
echo "[*] Reports : $REPORT_DIR/"
echo

run_if_present() {
    local tool="$1"; shift
    if command -v "$tool" >/dev/null 2>&1; then
        echo "=== Running $tool ==="
        "$@" | tee "$REPORT_DIR/${tool}.txt" || true
        echo
    else
        echo "[-] $tool not installed, skipping."
    fi
}

run_if_present tfsec      tfsec "$TARGET"
run_if_present checkov    checkov -d "$TARGET" --compact
run_if_present terrascan  terrascan scan -d "$TARGET"
run_if_present trivy      trivy config "$TARGET"

echo "[*] Done. Review findings in $REPORT_DIR/"
