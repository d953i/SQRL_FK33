
#create_clock -period 10 [get_ports APB_0_PCLK]
#create_clock -period 10 [get_ports APB_1_PCLK]

#create_clock -period 5.000 [get_ports AXI_ACLK_IN_0]
#set_property LOC MMCM_X0Y0 [get_cells -hier -filter {NAME =~ u_mmcm_0}]

#create_clock -period 5.000 [get_ports AXI_ACLK_IN_1]
#set_property LOC MMCM_X0Y1 [get_cells -hier -filter {NAME =~ u_mmcm_1}]

#set_property IOSTANDARD LVCMOS12 [get_ports APB_0_PCLK]
#set_property IOSTANDARD LVCMOS12 [get_ports APB_0_PRESET_N]
#set_property IOSTANDARD LVCMOS12 [get_ports AXI_ACLK_IN_0]
#set_property IOSTANDARD LVCMOS12 [get_ports AXI_ARESET_N_0]
#set_property IOSTANDARD LVCMOS12 [get_ports axi_trans_err]
#set_property IOSTANDARD LVCMOS12 [get_ports APB_1_PCLK]
#set_property IOSTANDARD LVCMOS12 [get_ports APB_1_PRESET_N]
#set_property IOSTANDARD LVCMOS12 [get_ports AXI_ACLK_IN_1]
#set_property IOSTANDARD LVCMOS12 [get_ports AXI_ARESET_N_1]
 
create_pblock pblock_1
resize_pblock pblock_1 -add {SLICE_X0Y0:SLICE_X116Y121 DSP48E2_X0Y0:DSP48E2_X15Y41 RAMB18_X0Y0:RAMB18_X7Y47 RAMB36_X0Y0:RAMB36_X7Y23 URAM288_X0Y0:URAM288_X1Y31}
#add_cells_to_pblock pblock_1 [get_cells [list u_atg_axi_0 u_atg_axi_1 u_atg_axi_2 u_atg_axi_3 u_atg_axi_4 u_atg_axi_5 u_atg_axi_6 u_atg_axi_7 u_atg_axi_8 u_atg_axi_9 u_atg_axi_10 u_atg_axi_11 u_atg_axi_12 u_atg_axi_13 u_atg_axi_14 u_atg_axi_15]]

create_pblock pblock_2	
resize_pblock pblock_2 -add {SLICE_X117Y0:SLICE_X232Y119 DSP48E2_X16Y0:DSP48E2_X31Y41 RAMB18_X8Y0:RAMB18_X13Y47 RAMB36_X8Y0:RAMB36_X13Y23 URAM288_X2Y0:URAM288_X4Y31}
#add_cells_to_pblock pblock_2 [get_cells [list u_atg_axi_16 u_atg_axi_17 u_atg_axi_18 u_atg_axi_19 u_atg_axi_20 u_atg_axi_21 u_atg_axi_22 u_atg_axi_23 u_atg_axi_24 u_atg_axi_25 u_atg_axi_26 u_atg_axi_27 u_atg_axi_28 u_atg_axi_29 u_atg_axi_30 u_atg_axi_31]]
 
create_waiver -internal -type CDC -id CDC-12 -from [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.hbm_apb_mst_*/apb_switch_r_reg/C] -to [get_pins apb_seq_complete_*_st*_r0_reg/D] -description "This is a safe CDC in this design per review with team"
create_waiver -internal -type CDC -id CDC-10 -from [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.hbm_apb_mst_*/apb_switch_r_reg/C] -to [get_pins apb_seq_complete_*_st*_r0_reg/D] -description "This is a safe CDC in this design per review with team"
create_waiver -internal -type CDC -id CDC-1  -from [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.hbm_apb_arbiter_1/apb_mux_sel_r_reg[0]/C] -to [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.u_xsdb_top_1/xsdb2adb_u0/*/CE] -description "This is a safe CDC in this design per review with team"
create_waiver -internal -type CDC -id CDC-1  -from [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.hbm_apb_arbiter_1/apb_mux_sel_r_reg[0]/C] -to [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.u_xsdb_top_1/xsdb2adb_u0/*/D] -description "This is a safe CDC in this design per review with team"
create_waiver -internal -type CDC -id CDC-4  -from [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.u_hbm_temp_rd_1/temp_value_r_reg[*]/C] -to [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.u_xsdb_top_*/xsdb2adb_u0/hbm_temp_r_reg[*]/D] -description "This is a safe CDC in this design per review with team"
create_waiver -internal -type CDC -id CDC-13 -from [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.u_xsdb_top_0/xsdb2adb_u0/*/C] -to [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.hbm_two_stack_intf/HBM_ONE_STACK_INTF<1>_INST/HBM_SNGLBLI_INTF_APB_INST/*] -description "This is a safe CDC in this design per review with team"
create_waiver -internal -type CDC -id CDC-14 -from [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.u_xsdb_top_1/xsdb2adb_u0/*/C] -to [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.hbm_two_stack_intf/HBM_ONE_STACK_INTF<1>_INST/HBM_SNGLBLI_INTF_APB_INST/*] -description "This is a safe CDC in this design per review with team"
create_waiver -internal -type CDC -id CDC-1  -from [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.u_xsdb_top_1/xsdb2adb_u0/*/C] -to [get_pins */*/inst/TWO_STACK.u_hbm_top/TWO_STACK_HBM.hbm_apb_arbiter_1/apb_mux_sel_r_reg*/*] -description "This is a safe CDC in this design per review with team"

#create_waiver -internal -type CDC -id CDC-1 -description "This is a safe CDC in this design per review with team" -from [get_pins u_atg_vio_*/inst/DECODER_INST/Hold_probe_in_reg/C] -to [get_pins u_atg_vio_*/inst/PROBE_IN_INST/probe_in_reg_reg[*]/CE] -description "This is a safe CDC in this design per review with team"
#create_waiver -internal -type CDC -id CDC-4 -description "This is a safe CDC in this design per review with team" -from [get_pins u_atg_vio_*/inst/PROBE_IN_INST/probe_in_reg_reg[*]/C] -to [get_pins u_atg_vio_*/inst/PROBE_IN_INST/data_int_sync1_reg[*]/D] -description "This is a safe CDC in this design per review with team"

#set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
#connect_debug_port dbg_hub/clk [get_nets */APB_0_PCLK]
