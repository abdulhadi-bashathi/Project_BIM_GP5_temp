//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : TB_INST_DECODER - Self-checking testbench for INST_DECODER
// Author(s)     : Group 5
// Last Modified : 30 April 2026
//
// ======================================================================================

`include "INST_DECODER.v"
`timescale 1ns/1ps

module TB_INST_DECODER;

    // -------------------------------------------------------------------------
    // DUT inputs
    // -------------------------------------------------------------------------
    reg  [31:0] instr;
    reg         en;

    // -------------------------------------------------------------------------
    // DUT outputs
    // -------------------------------------------------------------------------
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    // -------------------------------------------------------------------------
    // Bookkeeping
    // -------------------------------------------------------------------------
    integer test_count;
    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------------
    // DUT instance
    // -------------------------------------------------------------------------
    INST_DECODER dut (
        .instr  (instr),
        .en     (en),
        .rs1    (rs1),
        .rs2    (rs2),
        .rd     (rd),
        .opcode (opcode),
        .funct3 (funct3),
        .funct7 (funct7)
    );

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("TB_INST_DECODER.vcd");
        $dumpvars(0, TB_INST_DECODER);
    end

    // -------------------------------------------------------------------------
    // Task: check expected decoded values
    // Uses case inequality (!==) so X/Z mismatches are caught in simulation
    // -------------------------------------------------------------------------
    task check_decode;
        input [31:0] instr_in;
        input        en_in;
        input [4:0]  exp_rs1;
        input [4:0]  exp_rs2;
        input [4:0]  exp_rd;
        input [6:0]  exp_opcode;
        input [2:0]  exp_funct3;
        input [6:0]  exp_funct7;
        begin
            test_count = test_count + 1;

            instr = instr_in;
            en    = en_in;
            #1;

            if ((rs1    !== exp_rs1   ) ||
                (rs2    !== exp_rs2   ) ||
                (rd     !== exp_rd    ) ||
                (opcode !== exp_opcode) ||
                (funct3 !== exp_funct3) ||
                (funct7 !== exp_funct7)) begin

                fail_count = fail_count + 1;
                $display("FAIL: test=%0d time=%0t", test_count, $time);
                $display("  instr   = 0x%08h  en = %b", instr, en);
                $display("  got     : rs1=%b rs2=%b rd=%b opcode=%b funct3=%b funct7=%b",
                         rs1, rs2, rd, opcode, funct3, funct7);
                $display("  expected: rs1=%b rs2=%b rd=%b opcode=%b funct3=%b funct7=%b",
                         exp_rs1, exp_rs2, exp_rd, exp_opcode, exp_funct3, exp_funct7);
            end else begin
                pass_count = pass_count + 1;
                $display("PASS: test=%0d instr=0x%08h en=%b", test_count, instr, en);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: expect unknown propagation when en = 1 and instr contains X/Z
    // -------------------------------------------------------------------------
    task check_unknown_behavior;
        input [31:0] instr_in;
        begin
            test_count = test_count + 1;

            instr = instr_in;
            en    = 1'b1;
            #1;

            if ((^rs1    === 1'bx) ||
                (^rs2    === 1'bx) ||
                (^rd     === 1'bx) ||
                (^opcode === 1'bx) ||
                (^funct3 === 1'bx) ||
                (^funct7 === 1'bx)) begin

                pass_count = pass_count + 1;
                $display("PASS: test=%0d unknown propagation observed as expected for instr=%h",
                         test_count, instr);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: test=%0d expected X/Z propagation for invalid instr=%h", test_count, instr);
                $display("  got rs1=%b rs2=%b rd=%b opcode=%b funct3=%b funct7=%b",
                         rs1, rs2, rd, opcode, funct3, funct7);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: check behavior when enable itself is X or Z
    // Because the DUT uses if (en), invalid en should be stress-tested too
    // -------------------------------------------------------------------------
    task check_bad_enable_behavior;
        input [31:0] instr_in;
        input        en_in;
        begin
            test_count = test_count + 1;

            instr = instr_in;
            en    = en_in;
            #1;

            if ((^rs1    === 1'bx) || (^rs2    === 1'bx) ||
                (^rd     === 1'bx) || (^opcode === 1'bx) ||
                (^funct3 === 1'bx) || (^funct7 === 1'bx)) begin

                pass_count = pass_count + 1;
                $display("PASS: test=%0d invalid enable caused unknown behavior as stress expected, instr=%h en=%b",
                         test_count, instr, en);
            end else if ((rs1    === 5'd0) &&
                         (rs2    === 5'd0) &&
                         (rd     === 5'd0) &&
                         (opcode === 7'd0) &&
                         (funct3 === 3'd0) &&
                         (funct7 === 7'd0)) begin

                pass_count = pass_count + 1;
                $display("PASS: test=%0d invalid enable collapsed into disabled behavior, instr=%h en=%b",
                         test_count, instr, en);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: test=%0d invalid enable produced unexpected clean decode, instr=%h en=%b",
                         test_count, instr, en);
                $display("  got rs1=%b rs2=%b rd=%b opcode=%b funct3=%b funct7=%b",
                         rs1, rs2, rd, opcode, funct3, funct7);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        instr = 32'd0;
        en    = 1'b0;

        $display("============================================================");
        $display("Starting TB_INST_DECODER");
        $display("============================================================");

        // ---------------------------------------------------------------------
        // 1) Basic disabled test: all outputs must be zero
        // ---------------------------------------------------------------------
        check_decode(32'hFFFFFFFF, 1'b0, 5'd0, 5'd0, 5'd0, 7'd0, 3'd0, 7'd0);

        // ---------------------------------------------------------------------
        // 2) All-zero instruction with enable
        // ---------------------------------------------------------------------
        check_decode(32'h00000000, 1'b1, 5'd0, 5'd0, 5'd0, 7'd0, 3'd0, 7'd0);

        // ---------------------------------------------------------------------
        // 3) R-type example: add x5, x6, x7
        // ---------------------------------------------------------------------
        check_decode(32'b0000000_00111_00110_000_00101_0110011,
                     1'b1,
                     5'd6, 5'd7, 5'd5, 7'b0110011, 3'b000, 7'b0000000);

        // ---------------------------------------------------------------------
        // 4) R-type example: sub x10, x11, x12
        // ---------------------------------------------------------------------
        check_decode(32'b0100000_01100_01011_000_01010_0110011,
                     1'b1,
                     5'd11, 5'd12, 5'd10, 7'b0110011, 3'b000, 7'b0100000);

        // ---------------------------------------------------------------------
        // 5) I-type style field extraction
        // ---------------------------------------------------------------------
        check_decode(32'b111111111111_00010_101_00001_0010011,
                     1'b1,
                     5'd2, 5'd31, 5'd1, 7'b0010011, 3'b101, 7'b1111111);

        // ---------------------------------------------------------------------
        // 6) Maximum field values
        // ---------------------------------------------------------------------
        check_decode(32'b1111111_11111_11111_111_11111_1111111,
                     1'b1,
                     5'd31, 5'd31, 5'd31, 7'd127, 3'd7, 7'd127);

        // ---------------------------------------------------------------------
        // 7) Random-looking pattern
        // Correct bit slices for 32'hA5C3F09B:
        // funct7 = instr[31:25] = 7'h52
        // rs2    = instr[24:20] = 5'h1C
        // rs1    = instr[19:15] = 5'h07
        // funct3 = instr[14:12] = 3'h7
        // rd     = instr[11:7]  = 5'h01
        // opcode = instr[6:0]   = 7'h1B
        // ---------------------------------------------------------------------
        check_decode(32'hA5C3F09B,
                     1'b1,
                     5'h07,
                     5'h1C,
                     5'h01,
                     7'h1B,
                     3'h7,
                     7'h52);

        // ---------------------------------------------------------------------
        // 8) Toggle enable low again, outputs must return to zero immediately
        // ---------------------------------------------------------------------
        check_decode(32'hA5C3F09B, 1'b0, 5'd0, 5'd0, 5'd0, 7'd0, 3'd0, 7'd0);

        // ---------------------------------------------------------------------
        // 9) More legal decode patterns
        // ---------------------------------------------------------------------
        check_decode(32'b0000001_00010_00001_001_00011_0110011,
                     1'b1,
                     5'd1, 5'd2, 5'd3, 7'b0110011, 3'b001, 7'b0000001);

        check_decode(32'b1010101_01010_10101_010_11100_0010011,
                     1'b1,
                     5'd21, 5'd10, 5'd28, 7'b0010011, 3'b010, 7'b1010101);

        check_decode(32'b0011001_11111_00000_111_11111_1100011,
                     1'b1,
                     5'd0, 5'd31, 5'd31, 7'b1100011, 3'b111, 7'b0011001);

        // ---------------------------------------------------------------------
        // 10) Unknown/X/Z stress tests on instruction input
        // ---------------------------------------------------------------------
        check_unknown_behavior(32'hXXXX_XXXX);
        check_unknown_behavior(32'hZZZZ_ZZZZ);
        check_unknown_behavior(32'b0100000_01100_xxxxx_000_01010_0110011);
        check_unknown_behavior(32'b0100000_zzzzz_01011_000_01010_0110011);
        check_unknown_behavior(32'bxxxxxxx_01100_01011_000_01010_0110011);
        check_unknown_behavior(32'b0100000_01100_01011_xxx_01010_0110011);
        check_unknown_behavior(32'b0100000_01100_01011_000_zzzzz_0110011);
        check_unknown_behavior(32'b0100000_01100_01011_000_01010_zzzzzzz);
        check_unknown_behavior(32'b1010x01_01z10_0x011_1z0_z1010_01x0011);

        // ---------------------------------------------------------------------
        // 11) Ensure en=0 masks invalid instruction values to zero
        // ---------------------------------------------------------------------
        check_decode(32'hXXXX_XXXX, 1'b0, 5'd0, 5'd0, 5'd0, 7'd0, 3'd0, 7'd0);
        check_decode(32'hZZZZ_ZZZZ, 1'b0, 5'd0, 5'd0, 5'd0, 7'd0, 3'd0, 7'd0);
        check_decode(32'b1010x01_01z10_0x011_1z0_z1010_01x0011,
                     1'b0, 5'd0, 5'd0, 5'd0, 7'd0, 3'd0, 7'd0);

        // ---------------------------------------------------------------------
        // 12) Stress enable itself with X and Z
        // ---------------------------------------------------------------------
        check_bad_enable_behavior(32'h00000033, 1'bx);
        check_bad_enable_behavior(32'h00000033, 1'bz);
        check_bad_enable_behavior(32'hFFFFFFFF, 1'bx);
        check_bad_enable_behavior(32'hFFFFFFFF, 1'bz);
        check_bad_enable_behavior(32'hA5C3F09B, 1'bx);
        check_bad_enable_behavior(32'hA5C3F09B, 1'bz);
        check_bad_enable_behavior(32'hXXXX_XXXX, 1'bx);
        check_bad_enable_behavior(32'hZZZZ_ZZZZ, 1'bz);
        check_bad_enable_behavior(32'b0100000_01100_0010x_000_01010_0110011, 1'bx);
        check_bad_enable_behavior(32'b0100000_01100_0010z_000_01010_0110011, 1'bx);
        check_bad_enable_behavior(32'b0100000_01100_0010x_000_01010_0110011, 1'bz);
        check_bad_enable_behavior(32'b0100000_01100_0010z_000_01010_0110011, 1'bz);

        // ---------------------------------------------------------------------
        // 13) Rapid toggling between valid and invalid cases
        // ---------------------------------------------------------------------
        check_decode(32'h12345678, 1'b1,
                     5'd8, 5'd3, 5'd12, 7'h78, 3'h5, 7'h09);
        check_decode(32'h12345678, 1'b0,
                     5'd0, 5'd0, 5'd0, 7'd0, 3'd0, 7'd0);
        check_bad_enable_behavior(32'h12345678, 1'bx);
        check_decode(32'h12345678, 1'b1,
                     5'd8, 5'd3, 5'd12, 7'h78, 3'h5, 7'h09);
        check_decode(32'h12345678, 1'b0,
                     5'd0, 5'd0, 5'd0, 7'h0, 3'h0, 7'h0);
        check_decode(32'h12345678, 1'b1,
                     5'd8, 5'd3, 5'd12, 7'h78, 3'h5, 7'h09);
        check_decode(32'h12345678, 1'bz,
                     5'd0, 5'd0, 5'd0, 7'h0, 3'h0, 7'h0);
        check_decode(32'h12345678, 1'b1,
                     5'd8, 5'd3, 5'd12, 7'h78, 3'h5, 7'h09);
        check_decode(32'h12345678, 1'bx,
                     5'd0, 5'd0, 5'd0, 7'h0, 3'h0, 7'h0);
        check_decode(32'h12345678, 1'b1,
                     5'd8, 5'd3, 5'd12, 7'h78, 3'h5, 7'h09);
        check_decode(32'h12345678, 1'b0,
                     5'd0, 5'd0, 5'd0, 7'h0, 3'h0, 7'h0);
        check_decode(32'h12345678, 1'b1,
                     5'd8, 5'd3, 5'd12, 7'h78, 3'h5, 7'h09);
        check_decode(32'h12345678, 1'bz,
                     5'd0, 5'd0, 5'd0, 7'h0, 3'h0, 7'h0);
        check_decode(32'h12345678, 1'b1,
                     5'd8, 5'd3, 5'd12, 7'h78, 3'h5, 7'h09);
        check_decode(32'h12345678, 1'bx,
                     5'd0, 5'd0, 5'd0, 7'h0, 3'h0, 7'h0);

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        $display("============================================================");
        $display("TB_INST_DECODER summary:");
        $display("  Total tests = %0d", test_count);
        $display("  Passed      = %0d", pass_count);
        $display("  Failed      = %0d", fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("RESULT: TESTBENCH PASSED");
        else
            $display("RESULT: TESTBENCH FAILED");

        #5;
        $finish;
    end

endmodule