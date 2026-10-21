@echo off
rem Read and print the FK33/FK35 FPGA device DNA over JTAG (Vivado batch mode).
rem Uses XILINX_VIVADO if set, otherwise Vivado 2019.2 in its default location.
setlocal
if "%XILINX_VIVADO%"=="" set XILINX_VIVADO=C:\Xilinx\Vivado\2019.2
set SCRIPT=%~dp0sqrl_fk_read_dna.tcl
set SCRIPT=%SCRIPT:\=/%
call "%XILINX_VIVADO%\bin\vivado.bat" -mode batch -nojournal -nolog -notrace -source "%SCRIPT%"
endlocal
