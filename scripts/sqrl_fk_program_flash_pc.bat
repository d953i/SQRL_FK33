@echo off
rem Program the FK33/FK35 QSPI flashes and boot the FPGA while the board is installed in this PC (Windows).
rem 1. Disables the board's PCIe device, so the PCIe link going down does not crash Windows.
rem 2. Programs both flashes and boots the FPGA from them (sqrl_fk_program_flash.bat).
rem 3. Removes the old device and rescans, so Windows enumerates the new design without a restart.
rem Usage: sqrl_fk_program_flash_pc.bat path\to\SQRL_FK35.xpr
rem Needs administrator rights for the device changes and asks for them (UAC) when not elevated.
rem PCI IDs: vendor_id 1E24 / pf0_device_id 1533, as set in sqrl_fk_project.tcl.
setlocal EnableExtensions
if "%~1"=="" (
    echo Usage: %~nx0 path\to\project.xpr
    exit /b 1
)
set "XPR=%~f1"
if not exist "%XPR%" (
    echo Project not found: %XPR%
    exit /b 1
)

net session >nul 2>&1
if errorlevel 1 (
    if /i "%~2"=="/elevated" (
        echo Administrator rights are required.
        pause
        exit /b 1
    )
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList '\"%XPR%\"','/elevated'"
    exit /b 0
)

rem Vivado may create .Xil in the current folder; an elevated window starts in System32.
pushd "%TEMP%"

set "DEV="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object InstanceId -like 'PCI\VEN_1E24&DEV_1533*' | Select-Object -First 1 -ExpandProperty InstanceId"`) do set "DEV=%%I"

if defined DEV (
    echo Disabling the board's PCIe device "%DEV%"
    pnputil /disable-device "%DEV%"
    if errorlevel 1 (
        echo Could not disable the PCIe device, the FPGA is not reconfigured.
        goto fail
    )
) else (
    echo The board's PCIe device is not in Windows, nothing to disable.
)

call "%~dp0sqrl_fk_program_flash.bat" "%XPR%"
if errorlevel 1 (
    echo Flash programming or boot failed. The PCIe device stays disabled: fix the problem, then restart Windows.
    goto fail
)

if defined DEV pnputil /remove-device "%DEV%" >nul

echo Scanning for the new design...
set "NEWDEV="
for /l %%N in (1,1,5) do if not defined NEWDEV (
    pnputil /scan-devices >nul
    ping -n 3 127.0.0.1 >nul
    for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object InstanceId -like 'PCI\VEN_1E24&DEV_1533*' | Select-Object -First 1 -ExpandProperty InstanceId"`) do set "NEWDEV=%%I"
)
if not defined NEWDEV (
    echo The new design did not appear in Windows. Restart Windows to enumerate it.
    goto fail
)

rem It can come back disabled when it was not removed; enabling an enabled device is harmless.
pnputil /enable-device "%NEWDEV%" >nul
powershell -NoProfile -Command "$d = Get-PnpDevice -InstanceId '%NEWDEV%'; $s = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName DEVPKEY_PciDevice_CurrentLinkSpeed).Data; $w = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName DEVPKEY_PciDevice_CurrentLinkWidth).Data; $p = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName DEVPKEY_Device_ProblemCode).Data; $st = if ($p -eq 28) { 'no driver installed' } elseif ($p -eq 0) { 'OK' } else { 'problem code ' + $p }; 'PCIe device back: {0}, link Gen{1} x{2}, {3}' -f $d.InstanceId, $s, $w, $st"

popd
if /i "%~2"=="/elevated" pause
endlocal & exit /b 0

:fail
popd
if /i "%~2"=="/elevated" pause
endlocal & exit /b 1
