//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : ICACHE_tb
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

`timescale 1ns/1ps

module icache_tb;

    // Parameters
    localparam time CLK_PERIOD = 10ns;

    // Signals
    logic clk;
    
    // Interfaces
    icache_if i_if();
    fetch_if  f_if();

    // DUT
    icache dut (
        .clk (clk),
        .i_if(i_if.slave),
        .f_if(f_if.slave)
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Scoreboard
    int pass_cnt = 0;
    int fail_cnt = 0;

    // Tasks
    task static write_word(input logic [8:0] addr, input logic [31:0] data);
        i_if.we    = 1'b1;
        i_if.waddr = addr;
        i_if.wdata = data;
        @(posedge clk);
        #1ns;
        i_if.we = 1'b0;
    endtask

    task static check_read(input logic [8:0] addr, input logic [31:0] expected, input string label);
        f_if.raddr = addr;
        #1ns;
        if (f_if.rdata === expected) begin
            $display("PASS | %-20s | addr=0x%03X | out=0x%08X", label, addr, f_if.rdata);
            pass_cnt++;
        end else begin
            $display("FAIL | %-20s | addr=0x%03X | expected=0x%08X | got=0x%08X", label, addr, expected, f_if.rdata);
            fail_cnt++;
        end
    endtask

    // Test Data
    logic [8:0]  ADDR [6] = '{9'd0, 9'd1, 9'd127, 9'd255, 9'd510, 9'd511};
    logic [31:0] DATA [6] = '{32'hFFFFFFFF, 32'hAAAAAAAA, 32'h55555555, 32'h12345678, 32'hDEADBEEF, 32'h00000001};

    initial begin
        // Waveform dumping
        $shm_open("waves.shm");
        $shm_probe("AS");

        // Default state
        f_if.enable = 1'b0;
        i_if.we     = 1'b0;
        i_if.waddr  = 9'd0;
        i_if.wdata  = 32'd0;
        f_if.raddr  = 9'd0;

        repeat(2) @(posedge clk);

        // COMBO 1: enable=0, we=0
        $display("\n[COMBO 1]  enable=0  we=0");
        f_if.enable = 1'b0;
        i_if.we = 1'b0;
        foreach (ADDR[i]) check_read(ADDR[i], 32'h0, "en0_we0_read");

        // COMBO 2: enable=0, we=1
        $display("\n[COMBO 2]  enable=0  we=1");
        f_if.enable = 1'b0;
        foreach (ADDR[i]) begin
            write_word(ADDR[i], DATA[i]);
            check_read(ADDR[i], 32'h0, "en0_we1_write");
        end

        // COMBO 3: enable=1, we=0
        $display("\n[COMBO 3]  enable=1  we=0");
        f_if.enable = 1'b1;
        i_if.we = 1'b0;
        foreach (ADDR[i]) begin
            i_if.waddr = ADDR[i];
            i_if.wdata = 32'hBADC0DE0;
            @(posedge clk); #1ns;
            check_read(ADDR[i], DATA[i], "en1_we0_retain");
        end

        // COMBO 4: enable=1, we=1
        $display("\n[COMBO 4]  enable=1  we=1");
        f_if.enable = 1'b1;
        foreach (ADDR[i]) begin
            int j;
            j = (i + 3) % 6;
            write_word(ADDR[i], DATA[j]);
            check_read(ADDR[i], DATA[j], "en1_we1_write_read");
        end

        // BONUS: Toggle test
        $display("\n[BONUS]    Enable toggle");
        f_if.enable = 1'b1;
        write_word(9'd42, 32'hCAFEBABE);
        f_if.raddr = 9'd42;
        
        f_if.enable = 1'b1; #1ns; check_read(9'd42, 32'hCAFEBABE, "toggle_on");
        f_if.enable = 1'b0; #1ns; check_read(9'd42, 32'h0, "toggle_off");
        f_if.enable = 1'b1; #1ns; check_read(9'd42, 32'hCAFEBABE, "toggle_on2");

        // Summary
        $display("\n====================================================");
        $display("  TOTAL  PASS: %0d   FAIL: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  *** ALL TESTS PASSED ***");
        else               $display("  *** %0d TEST(S) FAILED ***", fail_cnt);
        $display("====================================================\n");

        $finish;
    end

endmodule
