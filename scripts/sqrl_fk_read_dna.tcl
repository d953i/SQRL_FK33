#Read and print the FPGA device DNA (96-bit unique ID) of a FK33/FK35 over JTAG.
#Run with sqrl_fk_read_dna.bat, "vivado -mode batch -source sqrl_fk_read_dna.tcl", or source it in the Vivado Tcl console.
#The eFUSE DNA is read by JTAG and needs no design loaded. If the loaded design has the dna_reader block
#(sqrl_fk_project.tcl), the DNA read by the design is printed too, from jtag_axil at 0x1000/0x1008/0x7000.

proc hex_to_bits {hex} {
    return [string map {0 0000 1 0001 2 0010 3 0011 4 0100 5 0101 6 0110 7 0111 8 1000 9 1001 A 1010 B 1011 C 1100 D 1101 E 1110 F 1111} [string toupper $hex]]
}

proc bits_to_hex {bits} {
    set out ""
    for {set i 0} {$i < [string length $bits]} {incr i 4} {
        append out [string map {0000 0 0001 1 0010 2 0011 3 0100 4 0101 5 0110 6 0111 7 1000 8 1001 9 1010 A 1011 B 1100 C 1101 D 1110 E 1111 F} [string range $bits $i [expr {$i + 3}]]]
    }
    return $out
}

proc same_hex {a b} {
    return [expr {[string trimleft [string toupper $a] 0] eq [string trimleft [string toupper $b] 0]}]
}

#Errors here only mean the Hardware Manager is already open (e.g. in the GUI).
if {[catch {open_hw_manager}]} { catch {open_hw} }
if {[current_hw_server -quiet] eq ""} { connect_hw_server }
catch {open_hw_target}

set devices [lsearch -all -inline -glob [get_hw_devices] xcvu*]
if {[llength $devices] == 0} {
    return -code error "No Virtex UltraScale+ device found on the JTAG chain"
}

foreach dev $devices {
    refresh_hw_device -quiet $dev
    set fuse [string toupper [get_property REGISTER.EFUSE.FUSE_DNA $dev]]
    puts "DNA $dev (JTAG eFUSE):        $fuse"

    #jtag_axil is the 32-bit JTAG-to-AXI master on the AXI-Lite bus (jtag_hbm is the 64-bit one).
    #CELL_NAME is empty without a probes file, so pick it by data width.
    set axi [lindex [get_hw_axis -quiet -of_objects $dev -filter {AXI_DATA_WIDTH == 32}] 0]
    if {$axi eq ""} {
        puts "DNA $dev (design dna_reader): no jtag_axil core in the loaded design"
        continue
    }
    create_hw_axi_txn -quiet -force dna_ls  $axi -address 0x00001000 -type read
    create_hw_axi_txn -quiet -force dna_us  $axi -address 0x00001008 -type read
    create_hw_axi_txn -quiet -force dna_ms  $axi -address 0x00007000 -type read
    create_hw_axi_txn -quiet -force dna_rdy $axi -address 0x00007008 -type read
    #Reads from unmapped addresses do not fail, the AXI response (DECERR) is in STATUS.RRESP.
    if {[catch {run_hw_axi -quiet dna_ls dna_us dna_ms dna_rdy}] || [get_property STATUS.RRESP $axi] ne "OKAY"} {
        puts "DNA $dev (design dna_reader): no dna_reader registers in the loaded design"
        continue
    }
    set design [string toupper "[get_property DATA [get_hw_axi_txn dna_ms]][get_property DATA [get_hw_axi_txn dna_us]][get_property DATA [get_hw_axi_txn dna_ls]]"]
    set ready [expr {[scan [get_property DATA [get_hw_axi_txn dna_rdy]] %x] & 1}]
    if {[same_hex $design $fuse]} {
        set match "matches eFUSE"
    } elseif {[same_hex [bits_to_hex [string reverse [hex_to_bits $design]]] $fuse]} {
        set match "matches eFUSE bit-reversed"
    } else {
        set match "differs from eFUSE"
    }
    puts "DNA $dev (design dna_reader): $design ready=$ready ($match)"
}
