//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : Block 5 - INST_DECODER - Instruction field extraction decoder
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

module INST_DECODER (
    input  wire [31:0] instr,     // 32-bit instruction from instruction mux
    input  wire        en,        // Enable, when 0 all outputs are forced to 0

    output reg  [4:0]  rs1,       // Source register 1 index = instr[19:15]
    output reg  [4:0]  rs2,       // Source register 2 index = instr[24:20]
    output reg  [4:0]  rd,        // Destination register index = instr[11:7]
    output reg  [6:0]  opcode,    // Instruction opcode = instr[6:0]
    output reg  [2:0]  funct3,    // Function-3 field = instr[14:12]
    output reg  [6:0]  funct7     // Function-7 field = instr[31:25]
);

    // -------------------------------------------------------------------------
    // Pure combinational decode
    // When en = 0, drive all outputs to zero (NOP condition)
    // -------------------------------------------------------------------------
    always @(*) begin
        if (en) begin
            rs1    = instr[19:15];
            rs2    = instr[24:20];
            rd     = instr[11:7];
            opcode = instr[6:0];
            funct3 = instr[14:12];
            funct7 = instr[31:25];
        end else begin
            rs1    = 5'd0;
            rs2    = 5'd0;
            rd     = 5'd0;
            opcode = 7'd0;
            funct3 = 3'd0;
            funct7 = 7'd0;
        end
    end

endmodule