//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : INST_FETCH
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

`timescale 1ns/1ps

module INST_FETCH (
    input  logic        clk,           // System clock
    input  logic        rst_n,         // Active-low asynchronous reset
    input  logic        en_i,          // Boot-done signal from bootloader
    input  logic [31:0] pc_in,         // Next PC from top-level PC update mux

    output logic [31:0] pc_out,        // Current registered PC
    fetch_if.master     f_if           // Fetch interface to icache
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic en_r1, en_r2;
    logic en_rise;
    logic gclk;

    assign en_rise = en_r1 & ~en_r2;  // Detect rising edge of en_i
    assign f_if.enable = en_i;        // Drive icache output gate

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
    always_ff @(posedge clk or negedge rst_n) begin
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
    // -------------------------------------------------------------------------
    always_ff @(posedge gclk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out      <= 32'd0;
            f_if.raddr  <= 9'd0;
        end else begin
            if (en_rise) begin
                pc_out      <= 32'd0;
                f_if.raddr  <= 9'd0;
            end else begin
                pc_out      <= pc_in;
                f_if.raddr  <= pc_in[10:2];
            end
        end
    end

endmodule
