# Security Lab Toolkit

A collection of reconnaissance, enumeration, and assessment helper scripts
built while working through hands-on penetration testing and cloud/Windows
security labs. Each tool wraps a repeatable step of the methodology so the
boring parts are automated and the thinking parts stay manual.

> ⚠️ **Authorized use only.** Everything here is for use on systems you own
> or have **explicit written permission** to test (your own lab, a CTF range,
> a client engagement with a signed scope). Running these tools against
> systems you don't have permission to assess is illegal. These are
> assessment and learning tools — there are no weaponized exploits in this
> repository.

## Layout

```
security-lab-toolkit/
├── recon/                     # Discovery & enumeration
│   ├── network_discovery.sh   # ARP (L2) host discovery for ICMP-filtered nets
│   ├── banner_grab.py         # Socket banner grabber — find service versions
│   └── nmap_parse.py          # Parse nmap -oG / -oX into clean port summaries
├── pivot/                     # Post-foothold navigation (authorized labs)
│   ├── loot_helper.py         # base64 decode / find+unzip / regex value extract
│   ├── dns_enum.sh            # Resolve internal names via a discovered DNS server
│   └── pivot_setup.rc         # Metasploit resource TEMPLATE for routing/scanning
├── iac/                       # Infrastructure as Code security
│   ├── iac_security_scan.sh   # Run tfsec/checkov/terrascan/trivy over a dir
│   └── example_secure_s3.tf   # A "known good" secure Terraform reference
├── windows/
│   └── Windows-Security-Audit.ps1  # Read-only local security posture report
└── python-debugging/
    └── poc_doctor.py          # Diagnose why an old Py2 PoC won't run on Py3
```

## Quick start

```bash
# Make the shell/python scripts executable
chmod +x recon/*.sh recon/*.py pivot/*.py pivot/*.sh iac/*.sh python-debugging/*.py

# Layer 2 host discovery (where ping fails)
sudo ./recon/network_discovery.sh eth0 192.168.1.0/24

# Grab banners off the host that stood out
./recon/banner_grab.py 192.168.1.10 -p 1-1000

# Parse a full nmap scan into a reusable port list
nmap -sS -p- 192.168.1.10 -oG scan.gnmap && ./recon/nmap_parse.py scan.gnmap

# Scan your Terraform before it ships
./iac/iac_security_scan.sh ./terraform

# Audit a Windows box (PowerShell, as Administrator)
.\windows\Windows-Security-Audit.ps1 | Out-File audit_report.txt

# Triage a broken PoC
./python-debugging/poc_doctor.py old_exploit_poc.py
```

## Requirements

| Tool | Needs |
|---|---|
| recon / pivot scripts | Python 3.10+, `nmap`; optional `netdiscover`/`arp-scan` |
| iac_security_scan.sh | any of `tfsec`, `checkov`, `terrascan`, `trivy` |
| Windows-Security-Audit.ps1 | PowerShell 5.1+, run as Administrator |
| pivot_setup.rc | Metasploit Framework |

## Notes

- The Python tools have **no third-party dependencies** — standard library only.
- `pivot_setup.rc` is intentionally a template with placeholders; it configures
  routing and scanning through an existing foothold and does not include an
  exploit.
- `poc_doctor.py` and `Windows-Security-Audit.ps1` are strictly read-only.

## License

MIT — see `LICENSE`. Provided as-is, with no warranty, for educational and
authorized professional use.
