@echo off
rem Program the FK33/FK35 QSPI flashes with the bitstream of a Vivado project, then boot the FPGA from them.
rem Usage: sqrl_fk_program_flash.bat path\to\SQRL_FK35.xpr
rem Uses XILINX_VIVADO if set, otherwise Vivado 2019.2 in its default location.
setlocal
if "%~1"=="" (
    echo Usage: %~nx0 path\to\project.xpr
    exit /b 1
)
if "%XILINX_VIVADO%"=="" set XILINX_VIVADO=C:\Xilinx\Vivado\2019.2
set SCRIPT=%~dp0sqrl_fk_program_flash.tcl
set SCRIPT=%SCRIPT:\=/%
set XPR=%~f1
set XPR=%XPR:\=/%
call "%XILINX_VIVADO%\bin\vivado.bat" -mode batch -nojournal -nolog -notrace -source "%SCRIPT%" -tclargs "%XPR%"
set RC=%ERRORLEVEL%
endlocal & exit /b %RC%
