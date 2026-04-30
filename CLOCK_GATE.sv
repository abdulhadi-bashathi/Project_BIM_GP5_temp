//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : CLOCK_GATE
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

`timescale 1ns/1ps

module CLOCK_GATE (
    input  logic clk,   // Source clock
    input  logic en,    // Clock enable
    output logic gclk   // Gated clock
);

    logic en_latched;

    // -------------------------------------------------------------------------
    // Latch enable only while clock is low
    // This avoids glitches on the gated clock
    // -------------------------------------------------------------------------
    always_latch begin
        if (!clk)
            en_latched = en;
    end

    // -------------------------------------------------------------------------
    // Gated clock output
    // -------------------------------------------------------------------------
    assign gclk = clk & en_latched;

endmodule
