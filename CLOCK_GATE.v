//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : CLOCK_GATE - Glitch-free generic clock gating block
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================


module CLOCK_GATE (
    input  wire clk,   // Source clock
    input  wire en,    // Clock enable
    output wire gclk   // Gated clock
);


    reg en_latched;


    // -------------------------------------------------------------------------
    // Latch enable only while clock is low
    // This avoids glitches on the gated clock
    // -------------------------------------------------------------------------
    always @(clk or en) begin
        if (!clk)
            en_latched = en;
    end


    // -------------------------------------------------------------------------
    // Gated clock output
    // -------------------------------------------------------------------------
    assign gclk = clk & en_latched;


endmodule