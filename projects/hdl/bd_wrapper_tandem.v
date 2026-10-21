`timescale 1 ps / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: bd_wrapper (PCIe Tandem version)
// Description: Top level for PCIe Tandem builds, used instead of the generated bd_wrapper
//              (same module and instance names, so constraints and file names do not change).
//              With Tandem PROM, I/O in the configuration bank (bank 65) must be in stage 1.
//              I2C, LEDs and CLKREQ# use stage 1 tri-state buffers that stay off until XDMA's
//              mcap_design_switch goes high (stage 2 configured). The gate LUTs are explicit
//              primitives so sqrl_fk_project.tcl can put them in stage 1 as well.
//////////////////////////////////////////////////////////////////////////////////

module bd_wrapper #(
    parameter LANES = 8)  // PCIe lanes, set from PCIeLanes in sqrl_fk_project.tcl
(
    input Vaux0_v_n,
    input Vaux0_v_p,
    input Vaux12_v_n,
    input Vaux12_v_p,
    input Vaux13_v_n,
    input Vaux13_v_p,
    input Vaux4_v_n,
    input Vaux4_v_p,
    input Vaux5_v_n,
    input Vaux5_v_p,
    input Vaux8_v_n,
    input Vaux8_v_p,
    input Vp_Vn_v_n,
    input Vp_Vn_v_p,
    inout iic_scl_io,
    inout iic_sda_io,
    output [6:0] led,
    output [0:0] pcie_clkreq,
    input pcie_perstn,
    input [0:0] pcie_refclk_clk_n,
    input [0:0] pcie_refclk_clk_p,
    input [LANES-1:0] pcie_rxn,
    input [LANES-1:0] pcie_rxp,
    output [LANES-1:0] pcie_txn,
    output [LANES-1:0] pcie_txp);

    wire iic_scl_i;
    wire iic_scl_o;
    wire iic_scl_t;
    wire iic_sda_i;
    wire iic_sda_o;
    wire iic_sda_t;
    wire [6:0] led_o;
    wire [0:0] pcie_clkreq_o;
    wire mcap_design_switch;

    bd bd_i (
        .Vaux0_v_n(Vaux0_v_n),
        .Vaux0_v_p(Vaux0_v_p),
        .Vaux12_v_n(Vaux12_v_n),
        .Vaux12_v_p(Vaux12_v_p),
        .Vaux13_v_n(Vaux13_v_n),
        .Vaux13_v_p(Vaux13_v_p),
        .Vaux4_v_n(Vaux4_v_n),
        .Vaux4_v_p(Vaux4_v_p),
        .Vaux5_v_n(Vaux5_v_n),
        .Vaux5_v_p(Vaux5_v_p),
        .Vaux8_v_n(Vaux8_v_n),
        .Vaux8_v_p(Vaux8_v_p),
        .Vp_Vn_v_n(Vp_Vn_v_n),
        .Vp_Vn_v_p(Vp_Vn_v_p),
        .iic_scl_i(iic_scl_i),
        .iic_scl_o(iic_scl_o),
        .iic_scl_t(iic_scl_t),
        .iic_sda_i(iic_sda_i),
        .iic_sda_o(iic_sda_o),
        .iic_sda_t(iic_sda_t),
        .led(led_o),
        .mcap_design_switch(mcap_design_switch),
        .pcie_clkreq(pcie_clkreq_o),
        .pcie_perstn(pcie_perstn),
        .pcie_refclk_clk_n(pcie_refclk_clk_n),
        .pcie_refclk_clk_p(pcie_refclk_clk_p),
        .pcie_rxn(pcie_rxn),
        .pcie_rxp(pcie_rxp),
        .pcie_txn(pcie_txn),
        .pcie_txp(pcie_txp));

    // Stage 1 gates: io_off = 1 (outputs tri-stated) until stage 2 is configured.
    wire io_off;
    wire iic_scl_t_s1;
    wire iic_sda_t_s1;
    (* DONT_TOUCH = "TRUE" *) LUT1 #(.INIT(2'b01)) stage1_io_off (.O(io_off), .I0(mcap_design_switch));
    (* DONT_TOUCH = "TRUE" *) LUT2 #(.INIT(4'b1110)) stage1_iic_scl_t (.O(iic_scl_t_s1), .I0(iic_scl_t), .I1(io_off));
    (* DONT_TOUCH = "TRUE" *) LUT2 #(.INIT(4'b1110)) stage1_iic_sda_t (.O(iic_sda_t_s1), .I0(iic_sda_t), .I1(io_off));

    IOBUF iic_scl_iobuf (.I(iic_scl_o), .IO(iic_scl_io), .O(iic_scl_i), .T(iic_scl_t_s1));
    IOBUF iic_sda_iobuf (.I(iic_sda_o), .IO(iic_sda_io), .O(iic_sda_i), .T(iic_sda_t_s1));

    genvar i;
    generate
        for (i = 0; i < 7; i = i + 1) begin : led_obuft
            OBUFT led_obuft_i (.I(led_o[i]), .O(led[i]), .T(io_off));
        end
    endgenerate
    OBUFT pcie_clkreq_obuft (.I(pcie_clkreq_o[0]), .O(pcie_clkreq[0]), .T(io_off));
endmodule
