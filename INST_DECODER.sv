//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : INST_DECODER
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

`timescale 1ns/1ps
import riscv_pkg::*;

module INST_DECODER (
    input  logic [31:0] instr_in,  // 32-bit instruction
    input  logic        en,        // Enable, when 0 all outputs are forced to 0

    output logic [4:0]  rs1,       // Source register 1 index
    output logic [4:0]  rs2,       // Source register 2 index
    output logic [4:0]  rd,        // Destination register index
    output opcode_t     opcode,    // Instruction opcode (enum)
    output logic [2:0]  funct3,    // Function-3 field
    output logic [6:0]  funct7     // Function-7 field
);

    instr_t instr;
    assign instr = instr_t'(instr_in);

    // -------------------------------------------------------------------------
    // Pure combinational decode
    // When en = 0, drive all outputs to zero (NOP condition)
    // -------------------------------------------------------------------------
    always_comb begin
        if (en) begin
            rs1    = instr.rs1;
            rs2    = instr.rs2;
            rd     = instr.rd;
            opcode = opcode_t'(instr.opcode);
            funct3 = instr.funct3;
            funct7 = instr.funct7;
        end else begin
            rs1    = 5'd0;
            rs2    = 5'd0;
            rd     = 5'd0;
            opcode = opcode_t'(7'd0);
            funct3 = 3'd0;
            funct7 = 7'd0;
        end
    end

endmodule
