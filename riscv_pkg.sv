//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : riscv_pkg
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

`timescale 1ns/1ps

package riscv_pkg;

    typedef enum logic [6:0] {
        OP_LUI    = 7'b0110111,
        OP_AUIPC  = 7'b0010111,
        OP_JAL    = 7'b1101111,
        OP_JALR   = 7'b1100111,
        OP_BRANCH = 7'b1100011,
        OP_LOAD   = 7'b0000011,
        OP_STORE  = 7'b0100011,
        OP_IMM    = 7'b0010011,
        OP_ALU    = 7'b0110011,
        OP_SYSTEM = 7'b1110011
    } opcode_t;

    typedef struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } instr_t;

endpackage
