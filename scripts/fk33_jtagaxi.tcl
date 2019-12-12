#Assuming I2C controller base address is 0x0000_9000 and FK33 LED's connected to its GPO port.

proc axil_setup_axis2mm {} {
    set addr 0x00001000
    #create_hw_axi_txn -force w0 [get_hw_axis hw_axi_1] -address [format 0x%08lx [expr $addr +  0]] -data [format 0x%016lx [expr ($value >>   0) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    create_hw_axi_txn -force w0 [get_hw_axis hw_axi_1] -address [format 0x%08lx [expr $addr +  1]] -data 0x00000100 -type write
    create_hw_axi_txn -force w1 [get_hw_axis hw_axi_1] -address [format 0x%08lx [expr $addr +  2]] -data 0x00010000 -type write
    run_hw_axi w0 w1
}

proc axil_write {addr value} {
    create_hw_axi_txn -force w0 [get_hw_axis hw_axi_1] -address [format 0x%08x [expr 0x00001000 + $addr]] -data [format 0x%08x [expr $value]] -type write
    run_hw_axi w0
}

proc axil_write0 {} {
    create_hw_axi_txn -force w0 [get_hw_axis hw_axi_1] -address 0x00001000 -data 0x80000000 -type write
    run_hw_axi w0
}

proc axil_read0 {} {
    set addr 0x00001000
    create_hw_axi_txn -force r0 [get_hw_axis hw_axi_1] -address [format 0x%08x [expr $addr +  0]] -type read
    run_hw_axi -quiet r0
    set d0 [get_property DATA [get_hw_axi_txn r0]]
    return 0x[concat $d0]

}


proc fk33_regulator_temps {} {
    fk33_read_i2c_temp 0x18
    fk33_read_i2c_temp 0x19
    fk33_read_i2c_temp 0x1F
}

proc fk33_read_i2c_temp {i2c_addr} {
    set addr [format 0x%02x [expr ($i2c_addr << 1)]]
    create_hw_axi_txn -quiet -force c0 [get_hw_axis hw_axi_1] -address 0x00009040 -data 0x0000000A -type write
    create_hw_axi_txn -quiet -force c1 [get_hw_axis hw_axi_1] -address 0x00009120 -data 0x00000002 -type write
    create_hw_axi_txn -quiet -force c2 [get_hw_axis hw_axi_1] -address 0x00009100 -data 0x00000000 -type write
    create_hw_axi_txn -quiet -force c3 [get_hw_axis hw_axi_1] -address 0x00009108 -data [format 0x%08x [expr $addr | 0x100]] -type write
    create_hw_axi_txn -quiet -force c4 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000005 -type write
    create_hw_axi_txn -quiet -force c5 [get_hw_axis hw_axi_1] -address 0x00009108 -data [format 0x%08x [expr $addr | 0x101]] -type write
    create_hw_axi_txn -quiet -force c6 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000202 -type write
    create_hw_axi_txn -quiet -force e0 [get_hw_axis hw_axi_1] -address 0x00009100 -data 0x00000001 -type write
    create_hw_axi_txn -quiet -force r0 [get_hw_axis hw_axi_1] -address 0x0000910C -type read
    create_hw_axi_txn -quiet -force r1 [get_hw_axis hw_axi_1] -address 0x0000910C -type read
    run_hw_axi -quiet c0 c1 c2 c3 c4 c5 c6 e0 r0 r1 c0

    set UB [format 0x%02x [expr 0x[get_property DATA [get_hw_axi_txn r0]]]]
    set LB [format 0x%02x [expr 0x[get_property DATA [get_hw_axi_txn r1]]]]
    #puts [format "I2C addr 0x%02x read: 0x%02x 0x%02x" $i2c_addr $UB $LB]

    set UB [format %.2f [expr $UB & 0x1F]]
    set LB [format %.2f [expr $LB]]
    puts [format "I2C addr 0x%02x temp: %.2f degree" $i2c_addr [expr $UB * 16 + $LB / 16]]
}

#To set FK33 VCCINT to 0.85V write to I2C address 0x2C, to register 0x00, value 0x44.
proc fk33_set_vccint {} {
    create_hw_axi_txn -quiet -force wr_tx0 [get_hw_axis hw_axi_1] -address 0x00009040 -data 0x0000000A -type write
    create_hw_axi_txn -quiet -force wr_tx1 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000158 -type write
    create_hw_axi_txn -quiet -force wr_tx2 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000000 -type write
    create_hw_axi_txn -quiet -force wr_tx3 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000244 -type write
    create_hw_axi_txn -quiet -force wr_tx4 [get_hw_axis hw_axi_1] -address 0x00009100 -data 0x00000001 -type write
    run_hw_axi -quiet wr_tx0 wr_tx1 wr_tx2 wr_tx3 wr_tx4
}

#To set FK33 user LED's(4Green + 1RGB) write to I2C controller GPO register (0x124) 32bit value.
proc fk33_set_led {value} {
    create_hw_axi_txn wr_tx_led [get_hw_axis hw_axi_1] -address 0x00009124 -data [format 0x%08x [expr $value]] -type write -force
    run_hw_axi -quiet wr_tx_led
}

#JTAG to AXI tcl procedure to write 256bit data to 64bit address.
proc axi256_write {addr value} {
    create_hw_axi_txn -force w0 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr +  0]] -data [format 0x%016lx [expr ($value >>   0) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    create_hw_axi_txn -force w1 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr +  8]] -data [format 0x%016lx [expr ($value >>  64) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    create_hw_axi_txn -force w2 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr + 16]] -data [format 0x%016lx [expr ($value >> 128) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    create_hw_axi_txn -force w3 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr + 24]] -data [format 0x%016lx [expr ($value >> 160) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    run_hw_axi w0 w1 w2 w3
}

#JTAG to AXI tcl procedure to read 256bit data from 64bit address.
proc axi256_read {addr} {
    create_hw_axi_txn -force r0 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr +  0]] -type read
    create_hw_axi_txn -force r1 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr +  8]] -type read
    create_hw_axi_txn -force r2 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr + 16]] -type read
    create_hw_axi_txn -force r3 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr + 24]] -type read
    run_hw_axi -quiet r0 r1 r2 r3
    set d0 [get_property DATA [get_hw_axi_txn r0]]
    set d1 [get_property DATA [get_hw_axi_txn r1]]
    set d2 [get_property DATA [get_hw_axi_txn r2]]
    set d3 [get_property DATA [get_hw_axi_txn r3]]
    return 0x[concat $d3$d2$d1$d0]
}

proc conv_temp_sysmon {value} {
    return [expr ($value * 507.6 / 65536.0) - 279.43]
}

proc conv_volt_sysmon {value} {
    return [expr ($value * 3.0 / 65536.0)]
}

proc conv_temp_ltc3636 {value} {
    return [expr ($value * 400.0 / 65536.0) - 273.15]
}

#Inspired by @bri3gel
proc fk33_read_sysmon {} {

    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3400 -type read]
    set vu33p_temp [conv_temp_sysmon [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "Temp.:  %0.2fC" $vu33p_temp]

    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3440 -type read]
    set inp12v [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "INP12V:  %0.2fV" [expr  $vcc12v * 15.2 / 65536.0]]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3404 -type read]
    set vccint [conv_volt_sysmon [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "VCCINT:  %0.2fV" $vccint]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 360c -type read]
    set vcchbm [conv_volt_sysmon [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "VCCHBM:  %0.2fV" $vcchbm]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3408 -type read]
    set vccaux [conv_volt_sysmon [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "VCCAUX:  %0.2fV" $vccaux]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3418 -type read]
    set vccbram [conv_volt_sysmon [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "VCCBRAM: %0.2fV" $vccbram]

    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3600 -type read]
    set mgtavcc [conv_volt_sysmon [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "MGTAVCC: %0.2fV" $mgtavcc]

    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3604 -type read]
    set mgtaaux [conv_volt_sysmon [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "MGTAAUX: %0.2fV" $mgtaaux]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3608 -type read]
    set mgtavtt [conv_volt_sysmon [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "MGTAVTT: %0.2fV" $mgtavtt]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3460 -type read]
    set mgt_temp [conv_temp_ltc3636 [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "LTC3636 VCCMGT Temp: %0.2fC" $mgt_temp]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3450 -type read]
    set aux_temp [conv_temp_ltc3636 [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]]
    puts [format "LTC3636 VCCAUX Temp: %0.2fC" $aux_temp]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3454 -type read]
    set vccint_current [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3470 -type read]
    set vcchbm_current [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]
    
    run_hw_axi -quiet [create_hw_axi_txn -quiet -force r [get_hw_axis hw_axi_1] -address 3474 -type read]
    set vccbram_current [lindex [report_hw_axi_txn -t d4 [get_hw_axi_txns r]] 1]

    puts [format "VCCINT  I = %0.2fA (%0.2fW)" $vccint_current  [expr $vccint_current *  (12.0 / $vccint)]]
    puts [format "VCCHBM  I = %0.2fA (%0.2fW)" $vcchbm_current  [expr $vcchbm_current *  (12.0 / $vcchbm)]]
    puts [format "VCCBRAM I = %0.2fA (%0.2fW)" $vccbram_current [expr $vccbram_current * (12.0 / $vccbram)]]
}
