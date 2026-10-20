# Squirrels Research Labs - Forrest Kitten FPGA HBM2 boards
SQRL FK33/FK35 board files, contraints, example designs and scripts.<br>
<b>Boards for sale at SQRL store at</b> <a href='https://store.squirrelsresearch.com/sqrl/forest-kitten-a/'>https://store.squirrelsresearch.com/sqrl/forest-kitten-a/<a>

Scripts target Vivado 2025.2. Virtex UltraScale+ devices are not supported by the free Vivado Standard edition; an Enterprise (or evaluation) license is required.<br>

Add board_files folder of this repo to Vivado board repository paths, for example in Vivado TCL console (or in Vivado_init.tcl):<br>
```set_param board.repoPaths [list ../path_to_this_repo/SQRL_FK33/board_files]```<br>
Board files: sqrl_fk33 (Forest Kitten 33, XCVU33P) and sqrl_fk35 (Forest Kitten 35, XCVU35P). Both boards use the same PCB and pinout, only the FPGA differs.<br>

To build example project use sqrl_fk_project.tcl script. Options at the top of the script:<br>
- Board: FK33 (XCVU33P) or FK35 (XCVU35P), project is created in SQRL_FK33 or SQRL_FK35 folder<br>
- EnablePCIe: 1 to include XDMA PCIe, 0 for JTAG-only design<br>
- PCIeLanes: 1, 4, 8 or 16 and PCIeGen: 1, 2, 3 or 4 (up to Gen3 x16 or Gen4 x8, default Gen4 x8)<br>

For example, in Vivado TCL console:
<br>
```source ../path_to_this_repo/SQRL_FK33/projects/sqrl_fk_project.tcl```
<br><br>
![Vivado_Block_Diagram](images/Vivado_example1.PNG?raw=true "Vivado TCL Console")

<br>Example project block diagram<br>
![Vivado_Block_Diagram](images/Vivado_example2.PNG?raw=true "SQRL FK33 Example Vivado BlockDiagram")
