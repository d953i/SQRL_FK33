#Program the FK33/FK35 QSPI flashes (two MT25QU256, dual QSPI SPIx8) with the bitstream of a Vivado project,
#then boot the FPGA from them.
#In the Vivado Tcl console with the project open: source <repo>/scripts/sqrl_fk_program_flash.tcl
#From Windows: sqrl_fk_program_flash.bat <path to project .xpr>
#Uses the impl_1 bitstream. bd_wrapper_primary/_secondary .mcs/.prm are written if missing or older than the bitstream.

set FlashPart mt25qu256-spi-x1_x2_x4_x8
set FlashSizeMB 64

if {[llength $argv] > 0} {
    open_project [lindex $argv 0]
}
if {[current_project -quiet] eq ""} {
    return -code error "No project open. Open the project first, or pass its .xpr to sqrl_fk_program_flash.bat"
}

set ImplDir [get_property DIRECTORY [get_runs impl_1]]
set Top [get_property TOP [current_fileset]]
set Bit $ImplDir/$Top.bit
#Tandem PCIe builds write <top>_tandem1.bit (stage 1, goes to the flash) and <top>_tandem2.bit (stage 2, over PCIe).
set Stage1 $ImplDir/${Top}_tandem1.bit
if {[file exists $Stage1] && (![file exists $Bit] || [file mtime $Stage1] > [file mtime $Bit])} {
    set Bit $Stage1
}
if {![file exists $Bit]} {
    return -code error "No bitstream $Bit. Run implementation and write_bitstream first."
}
puts "Bitstream: $Bit"

set Mcs [list $ImplDir/${Top}_primary.mcs $ImplDir/${Top}_secondary.mcs]
set Prm [list $ImplDir/${Top}_primary.prm $ImplDir/${Top}_secondary.prm]
set stale 0
foreach f [concat $Mcs $Prm] {
    if {![file exists $f] || [file mtime $f] < [file mtime $Bit]} { set stale 1 }
}
if {$stale} {
    write_cfgmem -force -format mcs -size $FlashSizeMB -interface SPIx8 -loadbit [list up 0x00000000 $Bit] -file $ImplDir/$Top.mcs
}
puts "Flash images: [join $Mcs {, }]"

set Device [lindex [split [get_property PART [current_project]] -] 0]
#Errors here only mean the Hardware Manager is already open (e.g. in the GUI).
if {[catch {open_hw_manager}]} { catch {open_hw} }
if {[current_hw_server -quiet] eq ""} { connect_hw_server }
catch {open_hw_target}
set dev [lindex [get_hw_devices -quiet ${Device}_0] 0]
if {$dev eq ""} {
    return -code error "No $Device on the JTAG chain"
}
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev

create_hw_cfgmem -hw_device $dev [lindex [get_cfgmem_parts $FlashPart] 0]
set cfgmem [get_property PROGRAM.HW_CFGMEM $dev]
set_property PROGRAM.ADDRESS_RANGE use_file $cfgmem
set_property PROGRAM.FILES $Mcs $cfgmem
set_property PROGRAM.PRM_FILES $Prm $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION pull-none $cfgmem
set_property PROGRAM.BLANK_CHECK 0 $cfgmem
set_property PROGRAM.ERASE 1 $cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $cfgmem
set_property PROGRAM.VERIFY 1 $cfgmem
set_property PROGRAM.CHECKSUM 0 $cfgmem

#The FPGA is loaded with a flash programming helper design first.
create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]
program_hw_devices $dev
refresh_hw_device $dev
program_hw_cfgmem -hw_cfgmem $cfgmem

#Reconfigure the FPGA from the flashes and check that it came up.
boot_hw_device $dev
after 5000
refresh_hw_device -quiet $dev
set done [get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]
puts "$dev booted from flash: DONE=$done"
if {$done != 1} {
    return -code error "FPGA did not configure from flash (DONE=0)"
}
