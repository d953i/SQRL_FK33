@echo off
rem Test the FK33/FK35 PCIe Tandem design through the Windows driver (driver\windows, sqrlfk.sys):
rem 1. Boot time and the board's PCIe device (present, driver, link speed and width).
rem 2. sqrl_fk_mcap info: BARs, XDMA engines, MCAP registers.
rem 3. sqrl_fk_mcap load: stage 2 over MCAP (Tandem PCIe builds; it does nothing if stage 2 is already loaded).
rem 4. sqrl_fk_mcap dna: the design's DNA over PCIe (BAR0), to compare with the eFUSE DNA.
rem 5. sqrl_fk_mcap loop: XDMA loop test on the DMA BRAM and both HBM stacks.
rem Usage: sqrl_fk_pcie_test.bat [stage2.bit]   (default: STAGE2 below)
rem Run it after every power-on of a Tandem PCIe board. Needs the driver (install.bat in the driver package) and
rem administrator rights, which it asks for (UAC). The output also goes to LOG.
setlocal EnableExtensions

rem ---- Paths: edit for your build ----------------------------------------------------------------------------------
rem Stage 2 of the Tandem PCIe build that is in the flash (stage 1 and stage 2 must come from the same build).
set "STAGE2=C:\Users\Dima\AppData\Local\Temp\rr\fk19x\SQRL_FK35\SQRL_FK35.runs\impl_1\bd_wrapper_tandem2.bit"
rem Driver package made by driver\windows\build.bat (sqrl_fk_mcap.exe, install.bat).
set "PACKAGE=%~dp0..\driver\windows\package"
rem XDMA loop test iterations per target, and the log file.
set "ITERATIONS=10"
set "LOG=%TEMP%\sqrl_fk_pcie_test.log"
rem ------------------------------------------------------------------------------------------------------------------

if not "%~1"=="" if /i not "%~1"=="/elevated" set "STAGE2=%~f1"
for %%I in ("%PACKAGE%") do set "PACKAGE=%%~fI"
set "TOOL=%PACKAGE%\sqrl_fk_mcap.exe"
set "OUT=%TEMP%\sqrl_fk_pcie_test.out"
set "ELEVATED="
if /i "%~2"=="/elevated" set "ELEVATED=1"

if not exist "%TOOL%" (
    echo sqrl_fk_mcap.exe not found in "%PACKAGE%". Build the driver package with driver\windows\build.bat.
    goto fail
)
if not exist "%STAGE2%" (
    echo Stage 2 bitstream not found: "%STAGE2%". Pass it as the argument or edit STAGE2 in this file.
    goto fail
)

net session >nul 2>&1
if errorlevel 1 (
    if defined ELEVATED (
        echo Administrator rights are required.
        goto fail
    )
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList '\"%STAGE2%\"','/elevated'"
    exit /b 0
)

rem Windows PowerShell with its own module path (PowerShell 7 passes its path to child processes).
set "PSModulePath="
> "%LOG%" echo SQRL FK PCIe Tandem test, %DATE% %TIME%
set "LOGGING=1"
call :say "Driver package: %PACKAGE%"
call :say "Stage 2:        %STAGE2%"

call :say ""
call :say "== Windows and the board"
powershell -NoProfile -Command "'Windows started ' + (Get-CimInstance Win32_OperatingSystem).LastBootUpTime; $d = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object InstanceId -like 'PCI\VEN_1E24&DEV_1533*' | Select-Object -First 1; if (-not $d) { 'Board: not in Windows'; exit 1 }; $p = { param($k) (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName $k).Data }; 'Board: {0}, {1} (problem {2}), link Gen{3} x{4}, arrived {5}' -f $d.FriendlyName, $d.Status, [int]$d.Problem, (& $p DEVPKEY_PciDevice_CurrentLinkSpeed), (& $p DEVPKEY_PciDevice_CurrentLinkWidth), (& $p DEVPKEY_Device_LastArrivalDate)" > "%OUT%" 2>&1
set "RC=%ERRORLEVEL%"
type "%OUT%"
type "%OUT%" >> "%LOG%"
if not "%RC%"=="0" (
    call :say "The board is not in Windows: nothing to test. After a power-on this means stage 1 was not up when the BIOS scanned the slot."
    goto fail
)

call :say ""
call :say "== sqrl_fk_mcap info"
call :run info
if errorlevel 1 (
    call :say "The driver does not answer: install it with %PACKAGE%\install.bat (test signing must be on)."
    goto fail
)

call :say ""
call :say "== sqrl_fk_mcap load (about 11 s for the FK35)"
call :run load "%STAGE2%"
if errorlevel 1 (
    call :say "Stage 2 did not load. Do not load it again: power-cycle the board first (one stage 2 per stage 1)."
    goto fail
)

call :say ""
call :say "== sqrl_fk_mcap dna"
call :run dna
if errorlevel 1 goto fail

call :say ""
call :say "== sqrl_fk_mcap loop"
call :run -n %ITERATIONS% loop
if errorlevel 1 goto fail

call :say ""
call :say "All steps passed. Log: %LOG%"
if defined ELEVATED pause
endlocal & exit /b 0

:fail
if defined LOGGING (
    >> "%LOG%" echo FAILED
    echo Log: "%LOG%"
)
if defined ELEVATED pause
endlocal & exit /b 1

rem Runs sqrl_fk_mcap with the given arguments; prints and logs its output, returns its exit code.
:run
"%TOOL%" %* > "%OUT%" 2>&1
set "RC=%ERRORLEVEL%"
type "%OUT%"
type "%OUT%" >> "%LOG%"
exit /b %RC%

rem Prints a line and adds it to the log.
:say
echo(%~1
>> "%LOG%" echo(%~1
exit /b 0
