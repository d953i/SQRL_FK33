@echo off
rem Program the FK33/FK35 QSPI flashes with the bitstream of a Vivado project, then boot the FPGA from them.
rem Usage: sqrl_fk_program_flash.bat [path\to\SQRL_FK35.xpr or its folder]
rem Without a path it uses the project in the current folder (or in one of its subfolders).
rem Uses XILINX_VIVADO if set, otherwise Vivado 2019.2 in its default location.
setlocal
call :find_xpr "%~1"
if errorlevel 1 exit /b 1
if "%XILINX_VIVADO%"=="" set XILINX_VIVADO=C:\Xilinx\Vivado\2019.2
set SCRIPT=%~dp0sqrl_fk_program_flash.tcl
set SCRIPT=%SCRIPT:\=/%
set XPR=%XPR:\=/%
call "%XILINX_VIVADO%\bin\vivado.bat" -mode batch -nojournal -nolog -notrace -source "%SCRIPT%" -tclargs "%XPR%"
set RC=%ERRORLEVEL%
endlocal & exit /b %RC%

rem Sets XPR to the full path of the project: the .xpr given, or the only .xpr in the folder given
rem (the current folder by default) or in its subfolders (the folder sqrl_fk_project.tcl ran in).
:find_xpr
set "XPR="
set "DIR=%CD%"
if "%~1"=="" goto find_xpr_dir
set "DIR=%~f1"
if exist "%~1\" goto find_xpr_dir
set "XPR=%~f1"
if exist "%XPR%" exit /b 0
echo Project not found: "%XPR%"
exit /b 1
:find_xpr_dir
set NXPR=0
for %%F in ("%DIR%\*.xpr") do (set /a NXPR+=1 & set "XPR=%%~fF")
if %NXPR%==0 for /d %%D in ("%DIR%\*") do for %%F in ("%%~fD\*.xpr") do (set /a NXPR+=1 & set "XPR=%%~fF")
if %NXPR%==1 echo Project: "%XPR%"& exit /b 0
set "XPR="
if %NXPR%==0 echo No Vivado project (.xpr) in "%DIR%" or its subfolders.& exit /b 1
echo More than one Vivado project in "%DIR%", pass the one to use:
for %%F in ("%DIR%\*.xpr") do echo   %%~fF
if not exist "%DIR%\*.xpr" for /d %%D in ("%DIR%\*") do for %%F in ("%%~fD\*.xpr") do echo   %%~fF
exit /b 1
