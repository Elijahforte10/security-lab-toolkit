#!/usr/bin/env bash
#
# system_check.sh — Linux System Health & Security Check
#
# A quick read-only posture snapshot: who's logged in, uptime, disk, open
# ports, recent failed logins, and a few high-value security checks.
# Portable across Debian/Ubuntu, RHEL/CentOS/Fedora, and systemd-journal
# systems. Changes nothing — safe to run anywhere you have a shell.
#
# Usage:
#   ./system_check.sh
#   sudo ./system_check.sh        # fuller output (process names, auth logs)

# NOTE: intentionally NOT using `set -e` — several commands (grep with no
# matches) return non-zero normally and shouldn't abort the report.

hr() { printf '%s\n' "-----------------------------------"; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "🔐 System Health & Security Check"
echo "    $(hostname) — $(date '+%Y-%m-%d %H:%M:%S')"
hr

# --- Identity ---------------------------------------------------------------
echo ""
echo "👤 Current User:"
whoami
if [[ "$(id -u)" -ne 0 ]]; then
    echo "   (running unprivileged — re-run with sudo for full output)"
fi

# --- Uptime -----------------------------------------------------------------
echo ""
echo "⏳ System Uptime:"
uptime

# --- Disk -------------------------------------------------------------------
echo ""
echo "💾 Disk Usage:"
df -h | grep -E '^/dev' || df -h

# --- Open ports -------------------------------------------------------------
echo ""
echo "🌐 Listening Ports:"
if have ss; then
    # -p adds the owning process (needs root); falls back cleanly without it.
    if [[ "$(id -u)" -eq 0 ]]; then
        ss -tulnp
    else
        ss -tuln
    fi
elif have netstat; then
    netstat -tuln
else
    echo "   (neither ss nor netstat available)"
fi

# --- Failed logins (portable log source) ------------------------------------
echo ""
echo "🚨 Recent Failed Login Attempts:"
if   [[ -r /var/log/auth.log ]]; then            # Debian/Ubuntu
    grep -i "failed password" /var/log/auth.log 2>/dev/null | tail -5
elif [[ -r /var/log/secure ]]; then              # RHEL/CentOS/Fedora
    grep -i "failed password" /var/log/secure 2>/dev/null | tail -5
elif have journalctl; then                        # systemd journal fallback
    journalctl _COMM=sshd 2>/dev/null | grep -i "failed password" | tail -5
else
    echo "   (no readable auth log found — try sudo, or check journalctl)"
fi
[[ "$(id -u)" -ne 0 ]] && echo "   (auth logs usually need sudo to read)"

# --- Bonus security checks --------------------------------------------------
echo ""
echo "🧑‍💻 Recent Successful Logins:"
if have last; then last -n 5 -w 2>/dev/null | grep -v '^$' | head -5
else echo "   ('last' not available)"; fi

echo ""
echo "⚠️  Accounts with UID 0 (root-equivalent — should only be 'root'):"
awk -F: '($3 == 0) {print "   " $1}' /etc/passwd

echo ""
echo "🛡️  Members of sudo/wheel group:"
getent group sudo  2>/dev/null | awk -F: '{print "   sudo:  " $4}'
getent group wheel 2>/dev/null | awk -F: '{print "   wheel: " $4}'

echo ""
hr
echo "✅ Scan Complete."
