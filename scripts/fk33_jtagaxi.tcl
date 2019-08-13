#Assuming I2C controller base address is 0x4080_0000 and FK33 LED's connected to its GPO port.

#To set FK33 VCCINT to 0.85V write to I2C address 0x2C, to register 0x00, value 0x44.
proc fk33_set_vccint {} {
	create_hw_axi_txn -quiet -force wr_tx0 [get_hw_axis hw_axi_1] -address 0x40800040 -data 0x0000000A -type write
	create_hw_axi_txn -quiet -force wr_tx1 [get_hw_axis hw_axi_1] -address 0x40800108 -data 0x00000158 -type write
	create_hw_axi_txn -quiet -force wr_tx2 [get_hw_axis hw_axi_1] -address 0x40800108 -data 0x00000000 -type write
	create_hw_axi_txn -quiet -force wr_tx3 [get_hw_axis hw_axi_1] -address 0x40800108 -data 0x00000244 -type write
	create_hw_axi_txn -quiet -force wr_tx4 [get_hw_axis hw_axi_1] -address 0x40800100 -data 0x00000001 -type write
	run_hw_axi -quiet wr_tx0 wr_tx1 wr_tx2 wr_tx3 wr_tx4
}

#To set FK33 user LED's(4Green + 1RGB) write to I2C controller GPO register (0x124) 32bit value.
proc fk33_set_led {value} {
	create_hw_axi_txn wr_tx_led [get_hw_axis hw_axi_1] -address 0x40800124 -data [format 0x%08x [expr $value]] -type write -force
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