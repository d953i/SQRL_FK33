# Installs the test-signed sqrlfk.sys driver package from this folder (build.bat makes it) for the board
# (PCI 1E24:1533), or removes it:  install.ps1  /  install.ps1 /uninstall
# Windows loads the test-signed driver only with test signing on (an administrator runs
# "bcdedit /set testsigning on" and restarts). The test certificate is not added to any trusted store, so Windows
# asks once whether to install a driver from an unverified publisher.
param([string] $Option, [switch] $Elevated)
$ErrorActionPreference = 'Stop'
$uninstall = $Option -eq '/uninstall'
$hwid = 'PCI\VEN_1E24&DEV_1533'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($uninstall) { $argList += '/uninstall' }
    $argList += '-Elevated'
    Write-Host 'Requesting administrator rights...'
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    return
}

function Done([int] $code) {
    if ($Elevated) { Read-Host 'Press Enter to close' | Out-Null }
    exit $code
}

try {
    if ($uninstall) {
        $published = Get-WindowsDriver -Online | Where-Object { $_.OriginalFileName -like '*\sqrlfk.inf' }
        foreach ($d in $published) {
            pnputil /delete-driver $d.Driver /uninstall /force
        }
        if (-not $published) { Write-Host 'sqrlfk.inf is not in the driver store' }
        Done 0
    }

    $bcd = bcdedit /enum '{current}' | Out-String
    if ($bcd -notmatch '(?m)^testsigning\s+Yes') {
        Write-Host 'Test signing is off, so Windows would not load the test-signed driver. As administrator run'
        Write-Host '    bcdedit /set testsigning on'
        Write-Host 'restart Windows (Secure Boot must be off), then run this again.'
        Done 1
    }

    Add-Type -Namespace SqrlFk -Name NewDev -MemberDefinition @'
[DllImport("newdev.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool UpdateDriverForPlugAndPlayDevicesW(IntPtr hwnd, string hardwareId, string infPath,
    uint flags, out bool reboot);
'@
    $inf = Join-Path $PSScriptRoot 'sqrlfk.inf'
    $reboot = $false
    Write-Host "Installing $inf for $hwid (confirm the unverified publisher prompt)..."
    if ([SqrlFk.NewDev]::UpdateDriverForPlugAndPlayDevicesW([IntPtr]::Zero, $hwid, $inf, 1, [ref] $reboot)) {
        Write-Host "Driver installed$(if ($reboot) { ' (restart Windows to finish)' })"
        Done 0
    }
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($err -eq 0xE000020B) { throw 'The board (PCI 1E24:1533) is not in Windows now. Install again when it is.' }
    throw "Driver installation failed: error 0x$('{0:X8}' -f $err)"
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Done 1
}
