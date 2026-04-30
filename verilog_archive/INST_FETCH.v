//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : Block 5 - INST_FETCH - Instruction fetch stage PC and cache address
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

module INST_FETCH (
    input  wire        clk,           // System clock
    input  wire        rst_n,         // Active-low asynchronous reset
    input  wire        en_i,          // Boot-done signal from bootloader
    input  wire [31:0] pc_in,         // Next PC from top-level PC update mux

    output reg  [31:0] pc_out,        // Current registered PC
    output reg  [8:0]  cache_addr_o   // Word-aligned cache read address = pc_in[10:2]
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    reg  en_r1, en_r2;
    wire en_rise;
    wire gclk;

    assign en_rise = en_r1 & ~en_r2;  // Detect rising edge of en_i

    // -------------------------------------------------------------------------
    // Clock-gate instance
    // gclk runs only when en_i is high
    // -------------------------------------------------------------------------
    CLOCK_GATE u_clock_gate (
        .clk  (clk),
        .en   (en_i),
        .gclk (gclk)
    );

    // -------------------------------------------------------------------------
    // Rising-edge detector for en_i
    // This logic remains on the main clock so the first enable transition is seen
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_r1 <= 1'b0;
            en_r2 <= 1'b0;
        end else begin
            en_r1 <= en_i;
            en_r2 <= en_r1;
        end
    end

    // -------------------------------------------------------------------------
    // PC register and cache address register
    // On first enabled cycle after en_i rises, force both outputs to zero
    // On later enabled cycles, capture normal values
    // -------------------------------------------------------------------------
    always @(posedge gclk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out       <= 32'd0;
            cache_addr_o <= 9'd0;
        end else begin
            if (en_rise) begin
                pc_out       <= 32'd0;
                cache_addr_o <= 9'd0;
            end else begin
                pc_out       <= pc_in;
                cache_addr_o <= pc_in[10:2];
            end
        end
    end

endmodule