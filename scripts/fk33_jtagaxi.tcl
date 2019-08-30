#Assuming I2C controller base address is 0x0000_9000 and FK33 LED's connected to its GPO port.

proc fk33_setup_sens {} {
	run_hw_axi [create_hw_axi_txn -force c0 [get_hw_axis hw_axi_1] -address 0x00009040 -data 0x0000000A -type write]
        run_hw_axi [create_hw_axi_txn -force c1 [get_hw_axis hw_axi_1] -address 0x00009120 -data 0x00000002 -type write]
        run_hw_axi [create_hw_axi_txn -force c2 [get_hw_axis hw_axi_1] -address 0x00009100 -data 0x00000002 -type write]
        #run_hw_axi [create_hw_axi_txn -force c3 [get_hw_axis hw_axi_1] -address 0x00009100 -data 0x00000001 -type write]

	create_hw_axi_txn -force c4 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000130 -type write
	create_hw_axi_txn -force c5 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000005 -type write
	create_hw_axi_txn -force c6 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000131 -type write
        create_hw_axi_txn -force c7 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000200 -type write
        create_hw_axi_txn -force e0 [get_hw_axis hw_axi_1] -address 0x00009100 -data 0x00000001 -type write
	#create_hw_axi_txn -force c7 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000202 -type write

        create_hw_axi_txn -force c8 [get_hw_axis hw_axi_1] -address 0x0000910C -type read
        create_hw_axi_txn -force c9 [get_hw_axis hw_axi_1] -address 0x0000910C -type read
        #create_hw_axi_txn -force s [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000200 -type write
        #create_hw_axi_txn -force c10 [get_hw_axis hw_axi_1] -address 0x0000910C -type read
        #create_hw_axi_txn -force c11 [get_hw_axis hw_axi_1] -address 0x0000910C -type read

        #run_hw_axi c0 c1 c2 c3 c4 c5 c6 c7 c8 c9 
        run_hw_axi c4 c5 c6 c7 e0 c8 c9 
#s
	#  c8 c9
        puts [get_property DATA [get_hw_axi_txn c8]]
        puts [get_property DATA [get_hw_axi_txn c9]]

        #create_hw_axi_txn -quiet -force c5 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000119 -type write
	#create_hw_axi_txn -quiet -force c6 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000202 -type write

        #create_hw_axi_txn -quiet -force c7 [get_hw_axis hw_axi_1] -address 0x0000910C -data 0x00000202 -type read
        #create_hw_axi_txn -quiet -force c8 [get_hw_axis hw_axi_1] -address 0x0000910C -data 0x00000202 -type read
	
	#run_hw_axi -quiet c0 c1 c2 c3 c4 c5 c6 c7 c8
        #run_hw_axi c0 c1 c2 c3 c4 c5 c6 c7 c8

#	run_hw_axi [create_hw_axi_txn -force c [get_hw_axis hw_axi_1] -address 0x0000910C -type read]
#       run_hw_axi [create_hw_axi_txn -force c [get_hw_axis hw_axi_1] -address 0x00009104 -type read]
#	puts [get_property DATA [get_hw_axi_txn c]]
}

proc fk33_check_rx_fifo {} {

run_hw_axi [create_hw_axi_txn -force c [get_hw_axis hw_axi_1] -address 0x00009104 -type read]
puts [get_property DATA [get_hw_axi_txn c]]
#puts [expr 0x1 & [expr 0x[get_property DATA [get_hw_axi_txn c]] >> 6]]

run_hw_axi [create_hw_axi_txn -force o [get_hw_axis hw_axi_1] -address 0x00009118 -type read]
puts [get_property DATA [get_hw_axi_txn o]]

}

proc fk33_read_rx_fifo {} {

run_hw_axi [create_hw_axi_txn -force r0 [get_hw_axis hw_axi_1] -address 0x0000910C -type read]
puts [get_property DATA [get_hw_axi_txn r0]]

#run_hw_axi [create_hw_axi_txn -force r1 [get_hw_axis hw_axi_1] -address 0x0000910C -type read]
#puts [get_property DATA [get_hw_axi_txn r1]]

#run_hw_axi [create_hw_axi_txn -force s [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000200 -type write]

}


proc fk33_read_temp {} {
	#create_hw_axi_txn -quiet -force c0 [get_hw_axis hw_axi_1] -address 0x00009040 -data 0x0000000A -type write
        #create_hw_axi_txn -quiet -force c1 [get_hw_axis hw_axi_1] -address 0x00009120 -data 0x0000000F -type write
        #create_hw_axi_txn -quiet -force c2 [get_hw_axis hw_axi_1] -address 0x00009100 -data 0x00000001 -type write
	#create_hw_axi_txn -quiet -force c3 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000118 -type write
	#create_hw_axi_txn -quiet -force c4 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000205 -type write

        create_hw_axi_txn -force s0 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000119 -type write
	create_hw_axi_txn -force s1 [get_hw_axis hw_axi_1] -address 0x00009108 -data 0x00000204 -type write
        create_hw_axi_txn -force s2 [get_hw_axis hw_axi_1] -address 0x0000910C -type read
        create_hw_axi_txn -force s3 [get_hw_axis hw_axi_1] -address 0x0000910C -type read
        run_hw_axi s0 s1 s2 s3
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

proc fk33_set_vccint_64 {} {
	create_hw_axi_txn -quiet -force wr_tx0_64 [get_hw_axis hw_axi_1] -address 0x200000040 -data 0x000000000000000A -type write
	create_hw_axi_txn -quiet -force wr_tx1_64 [get_hw_axis hw_axi_1] -address 0x200000108 -data 0x0000000000000158 -type write
	create_hw_axi_txn -quiet -force wr_tx2_64 [get_hw_axis hw_axi_1] -address 0x200000108 -data 0x0000000000000000 -type write
	create_hw_axi_txn -quiet -force wr_tx3_64 [get_hw_axis hw_axi_1] -address 0x200000108 -data 0x0000000000000244 -type write
	create_hw_axi_txn -quiet -force wr_tx4_64 [get_hw_axis hw_axi_1] -address 0x200000100 -data 0x0000000000000001 -type write
	run_hw_axi -quiet wr_tx0_64 wr_tx1_64 wr_tx2_64 wr_tx3_64 wr_tx4_64
}

proc fk33_set_led_64 {value} {
	create_hw_axi_txn wr_tx_led_64 [get_hw_axis hw_axi_1] -address 0x200000124 -data [format 0x%08x00000000 [expr $value]] -type write -force
	run_hw_axi -quiet wr_tx_led_64
}

#JTAG to AXI tcl procedure to write 256bit data to 64bit address.
proc write_mem256 {addr value} {
    create_hw_axi_txn -force w0 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr +  0]] -data [format 0x%016lx [expr ($value >>   0) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    create_hw_axi_txn -force w1 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr +  8]] -data [format 0x%016lx [expr ($value >>  64) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    create_hw_axi_txn -force w2 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr + 16]] -data [format 0x%016lx [expr ($value >> 128) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    create_hw_axi_txn -force w3 [get_hw_axis hw_axi_1] -address [format 0x%016lx [expr $addr + 24]] -data [format 0x%016lx [expr ($value >> 160) & 0xFFFFFFFFFFFFFFFFFFFFFFFF]] -type write
    run_hw_axi w0 w1 w2 w3
}

#JTAG to AXI tcl procedure to read 256bit data from 64bit address.
proc read_mem256 {addr} {
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
