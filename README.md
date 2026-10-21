# Squirrels Research Labs - Forrest Kitten FPGA HBM2 boards
SQRL FK33/FK35 board files, contraints, example designs and scripts.<br>
<b>Boards for sale at SQRL store at</b> <a href='https://store.squirrelsresearch.com/sqrl/forest-kitten-a/'>https://store.squirrelsresearch.com/sqrl/forest-kitten-a/<a>

Scripts target Vivado 2019.2. Virtex UltraScale+ devices are not supported by the free Vivado Standard edition; an Enterprise (or evaluation) license is required.<br>

Add board_files folder of this repo to Vivado board repository paths, for example in Vivado TCL console (or in Vivado_init.tcl):<br>
```set_param board.repoPaths [list ../path_to_this_repo/SQRL_FK33/board_files]```<br>
Board files: sqrl_fk33 (Forest Kitten 33, XCVU33P) and sqrl_fk35 (Forest Kitten 35, XCVU35P). Both boards use the same PCB and pinout, only the FPGA differs.<br>

To build example project use sqrl_fk_project.tcl script. Options at the top of the script:<br>
- Board: FK33 (XCVU33P) or FK35 (XCVU35P), project is created in SQRL_FK33 or SQRL_FK35 folder<br>
- EnablePCIe: 1 to include XDMA PCIe, 0 for JTAG-only design<br>
- PCIeLanes: 1, 4, 8 or 16 and PCIeGen: 1, 2, 3 or 4 (up to Gen3 x16 or Gen4 x8, default Gen4 x8)<br>
- FlashPart / FlashSizeMB: configuration flash, two MT25QU256 in dual QSPI (SPIx8, 64 MB) on both boards. The build also writes bd_wrapper_primary/_secondary .mcs/.prm next to the bitstream. If the board is on JTAG during project creation, the flash is also added to the project's Hardware Manager as its configuration memory device<br>

To program both flashes with the project's bitstream and boot the FPGA from them: in the Vivado Tcl console with the project open, source scripts/sqrl_fk_program_flash.tcl, or run scripts/sqrl_fk_program_flash.bat path\to\SQRL_FK35.xpr<br>

Board in a PC (Windows): the PC finds the PCIe device only if the FPGA is already configured from flash when the PC boots, otherwise the BIOS hides the slot. Before reconfiguring the FPGA of a board the PC has already enumerated (JTAG bitstream, flash programming or boot from flash), disable its "PCI Device" in Device Manager so the PCIe link going down does not crash Windows, then restart Windows to enumerate the new design.<br>
scripts/sqrl_fk_program_flash_pc.bat path\to\SQRL_FK35.xpr does all of this: disables the device, programs the flashes and boots the FPGA, then removes the old device and rescans so Windows finds the new design without a restart. It needs administrator rights and asks for them (UAC).<br>

The example design includes the FPGA device DNA (96-bit unique ID), readable on the AXI-Lite bus (PCIe BAR or JTAG-to-AXI): 0x1000 DNA[31:0], 0x1008 DNA[63:32], 0x7000 DNA[95:64], 0x7008 bit 0 = ready.<br>
scripts/sqrl_fk_read_dna.bat (or sqrl_fk_read_dna.tcl) prints the DNA over JTAG, and compares it with the design's copy when the design is loaded.<br>

For example, in Vivado TCL console:
<br>
```source ../path_to_this_repo/SQRL_FK33/projects/sqrl_fk_project.tcl```
<br><br>
![Vivado_Block_Diagram](images/Vivado_example1.PNG?raw=true "Vivado TCL Console")

<br>Example project block diagram<br>
![Vivado_Block_Diagram](images/Vivado_example2.PNG?raw=true "SQRL FK33 Example Vivado BlockDiagram")
