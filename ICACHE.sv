//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : ICACHE
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

`timescale 1ns/1ps

module icache (
    input  logic    clk,           // System clock
    icache_if.slave i_if,          // Write interface from bootloader
    fetch_if.slave  f_if           // Read interface for instruction fetch
);

    logic [31:0] cache [0:511];    // 512 words of 32 bits each

    // Synchronous write logic for bootloader
    always_ff @(posedge clk) begin
        if (i_if.we) begin
            cache[i_if.waddr] <= i_if.wdata;
        end
    end

    // Combinational read logic for instruction fetch
    // Output gating: if enable is 1, output cache data; else output 0
    assign f_if.rdata = f_if.enable ? cache[f_if.raddr] : 32'h00000000;

endmodule
