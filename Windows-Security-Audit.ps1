#requires -Version 5.1
<#
.SYNOPSIS
    Windows-Security-Audit.ps1 — read-only local security posture report.

.DESCRIPTION
    Reports on the Windows security settings covered in the A+/Security+
    objectives: local accounts and groups, BitLocker/EFS status, shares and
    their permissions, UAC configuration, and Windows Firewall profiles.

    This script ONLY READS state. It changes nothing. Run as Administrator
    for complete results (some queries need elevation).

.EXAMPLE
    PS> .\Windows-Security-Audit.ps1
    PS> .\Windows-Security-Audit.ps1 | Out-File audit_report.txt
#>

function Write-Section($Title) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

# --- Local users & groups ----------------------------------------------------
Write-Section "Local Users"
Get-LocalUser | Select-Object Name, Enabled, LastLogon, PasswordRequired,
    PasswordExpires | Format-Table -AutoSize

Write-Section "Administrators Group Membership"
try {
    Get-LocalGroupMember -Group "Administrators" |
        Select-Object Name, PrincipalSource | Format-Table -AutoSize
} catch { Write-Host "  (could not enumerate — run as Administrator)" }

Write-Section "Guest Account Status"
$guest = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
if ($guest) {
    $state = if ($guest.Enabled) { "ENABLED (review!)" } else { "Disabled (good)" }
    Write-Host "  Guest account: $state"
}

# --- UAC ---------------------------------------------------------------------
Write-Section "User Account Control (UAC)"
$uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$uac = Get-ItemProperty -Path $uacKey -ErrorAction SilentlyContinue
Write-Host "  EnableLUA (UAC on)         : $($uac.EnableLUA)"
Write-Host "  ConsentPromptBehaviorAdmin : $($uac.ConsentPromptBehaviorAdmin)"

# --- BitLocker ---------------------------------------------------------------
Write-Section "BitLocker Volume Encryption"
if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
    Get-BitLockerVolume | Select-Object MountPoint, VolumeType,
        ProtectionStatus, EncryptionPercentage, EncryptionMethod |
        Format-Table -AutoSize
} else {
    Write-Host "  BitLocker cmdlets not available on this SKU."
}

# --- EFS ---------------------------------------------------------------------
Write-Section "EFS (Encrypting File System) Certificates"
$efs = certutil -user -store My 2>$null | Select-String "Encrypting File System"
if ($efs) { Write-Host "  EFS certificate(s) present for current user." }
else { Write-Host "  No EFS certificate found for current user." }

# --- Shares & permissions ----------------------------------------------------
Write-Section "SMB Shares"
Get-SmbShare | Select-Object Name, Path, Description | Format-Table -AutoSize

Write-Section "Share Permissions (non-admin shares)"
Get-SmbShare | Where-Object { $_.Name -notmatch '\$$' } | ForEach-Object {
    Write-Host "`n  Share: $($_.Name)" -ForegroundColor Yellow
    Get-SmbShareAccess -Name $_.Name |
        Select-Object AccountName, AccessControlType, AccessRight |
        Format-Table -AutoSize
}

Write-Section "Administrative Shares (hidden, end in '$')"
Get-SmbShare | Where-Object { $_.Name -match '\$$' } |
    Select-Object Name, Path | Format-Table -AutoSize

# --- Firewall ----------------------------------------------------------------
Write-Section "Windows Firewall Profiles"
Get-NetFirewallProfile | Select-Object Name, Enabled,
    DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize

Write-Host "`n[*] Audit complete (read-only — nothing was changed).`n" -ForegroundColor Green
