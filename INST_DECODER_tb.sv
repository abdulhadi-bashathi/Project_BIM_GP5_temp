//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : INST_DECODER_tb
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

`timescale 1ns/1ps
import riscv_pkg::*;

module TB_INST_DECODER;

    // DUT inputs
    logic [31:0] instr_in;
    logic        en;

    // DUT outputs
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;
    opcode_t     opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    // Bookkeeping
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // DUT instance
    INST_DECODER dut (.*);

    // Waveform dump
    initial begin
        $shm_open("waves.shm");
        $shm_probe("AS");
    end

    // Task: check expected decoded values
    task static check_decode(
        input logic [31:0] instr_in_val,
        input logic        en_in,
        input logic [4:0]  exp_rs1,
        input logic [4:0]  exp_rs2,
        input logic [4:0]  exp_rd,
        input logic [6:0]  exp_opcode,
        input logic [2:0]  exp_funct3,
        input logic [6:0]  exp_funct7
    );
        test_count++;
        instr_in = instr_in_val;
        en       = en_in;
        #1ns;

        if ((rs1    !== exp_rs1   ) ||
            (rs2    !== exp_rs2   ) ||
            (rd     !== exp_rd    ) ||
            (opcode !== opcode_t'(exp_opcode)) ||
            (funct3 !== exp_funct3) ||
            (funct7 !== exp_funct7)) begin

            fail_count++;
            $display("FAIL: test=%0d time=%0t", test_count, $time);
            $display("  instr   = 0x%08h  en = %b", instr_in, en);
            $display("  got     : rs1=%b rs2=%b rd=%b opcode=%s funct3=%b funct7=%b",
                     rs1, rs2, rd, opcode.name(), funct3, funct7);
            $display("  expected: rs1=%b rs2=%b rd=%b opcode=%b funct3=%b funct7=%b",
                     exp_rs1, exp_rs2, exp_rd, exp_opcode, exp_funct3, exp_funct7);
        end else begin
            pass_count++;
            $display("PASS: test=%0d instr=0x%08h en=%b", test_count, instr_in, en);
        end
    endtask

    // Task: check unknown propagation
    task static check_unknown_behavior(input logic [31:0] instr_in_val);
        test_count++;
        instr_in = instr_in_val;
        en    = 1'b1;
        #1ns;

        if ((^rs1    === 1'bx) || (^rs2    === 1'bx) || (^rd     === 1'bx) ||
            (^opcode === 1'bx) || (^funct3 === 1'bx) || (^funct7 === 1'bx)) begin
            pass_count++;
            $display("PASS: test=%0d unknown propagation observed for instr=%h", test_count, instr_in);
        end else begin
            fail_count++;
            $display("FAIL: test=%0d expected X/Z propagation for instr=%h", test_count, instr_in);
        end
    endtask

    // Stimulus
    initial begin
        $display("============================================================");
        $display("Starting TB_INST_DECODER (SystemVerilog)");
        $display("============================================================");

        // Default state
        instr_in = 32'd0;
        en       = 1'b0;

        // R-type: add x5, x6, x7
        check_decode(32'b0000000_00111_00110_000_00101_0110011, 1'b1, 5'd6, 5'd7, 5'd5, 7'b0110011, 3'b000, 7'b0000000);

        // R-type: sub x10, x11, x12
        check_decode(32'b0100000_01100_01011_000_01010_0110011, 1'b1, 5'd11, 5'd12, 5'd10, 7'b0110011, 3'b000, 7'b0100000);

        // I-type
        check_decode(32'b111111111111_00010_101_00001_0010011, 1'b1, 5'd2, 5'd31, 5'd1, 7'b0010011, 3'b101, 7'b1111111);

        // Unknown tests
        check_unknown_behavior(32'hXXXX_XXXX);
        check_unknown_behavior(32'hZZZZ_ZZZZ);

        // Summary
        $display("============================================================");
        $display("TB_INST_DECODER summary:");
        $display("  Total tests = %0d", test_count);
        $display("  Passed      = %0d", pass_count);
        $display("  Failed      = %0d", fail_count);
        $display("============================================================");

        if (fail_count == 0) $display("RESULT: TESTBENCH PASSED");
        else               $display("RESULT: TESTBENCH FAILED");

        $finish;
    end

endmodule
