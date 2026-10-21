`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: dna_reader
// Description: Reads the 96-bit device DNA from DNA_PORTE2 (UltraScale+) once after
//              configuration. dna_ms/dna_us/dna_ls = DNA[95:64]/[63:32]/[31:0], the same
//              value Vivado Hardware Manager shows as REGISTER.EFUSE.FUSE_DNA.
//              ready goes high when all 96 bits are in.
//////////////////////////////////////////////////////////////////////////////////


module dna_reader #(
    parameter [95:0] SIM_DNA_VALUE = 96'h000000000000000000000000) // DNA returned in simulation
(
    input clk,
    output ready,
    output [31:0] dna_ls,
    output [31:0] dna_us,
    output [31:0] dna_ms);

    // Storage
    reg ready_w = 0;
    reg [95:0] dna_read = 0;

    // Map output ports
    assign ready = ready_w;
    assign dna_ls = dna_read[31:0];
    assign dna_us = dna_read[63:32];
    assign dna_ms = dna_read[95:64];

    // DNA port wires
    wire DNAP_DOUT;
    reg DNAP_READ = 1;
    reg DNAP_SHIFT = 0;

    // DNA_PORTE2: Device DNA Access Port (UltraScale+)
    DNA_PORTE2 #(
       .SIM_DNA_VALUE(SIM_DNA_VALUE)  // 96-bit DNA value used in simulation
    )
    DNA_PORT_inst (
       .DOUT(DNAP_DOUT),   // 1-bit output: DNA output data.
       .CLK(clk),          // 1-bit input: Clock input.
       .DIN(1'b0),         // 1-bit input: User data input pin.
       .READ(DNAP_READ),   // 1-bit input: Active high load DNA, active low read input.
       .SHIFT(DNAP_SHIFT)  // 1-bit input: Active high shift enable input.
    );

    reg [31:0] count = 0;

    // DNA_PORTE2 loads on rising edges while READ is high, then shifts the DNA out LSB first:
    // bit 0 is on DOUT right after the load and each SHIFT clock brings the next bit.
    // Sample on the falling edge, between the DNA port's rising edges.
    always @(negedge clk)
    if (0 == ready_w)
    begin
        count <= count+1;
        if (count == 1)
            begin
                DNAP_READ <= 0;
                DNAP_SHIFT <= 1;
            end
        if (count >= 1 && count <= 96)
            begin
                // Bit 0 is sampled first (before the first shift) and ends up in dna_read[0].
                dna_read <= {DNAP_DOUT, dna_read[95:1]};
            end
        else if (count > 96)
            begin
            // Done- all bits shifted out
            ready_w <= 1;
            end
    end
endmodule
