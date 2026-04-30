`timescale 1ns/1ps
`include "CLOCK_GATE.v"
`include "INST_FETCH.v"

module TB_INST_FETCH;

    reg         clk;
    reg         rst_n;
    reg         en_i;
    reg [31:0]  pc_in;

    wire [31:0] pc_out;
    wire [8:0]  cache_addr_o;

    integer errors;

    INST_FETCH dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .en_i         (en_i),
        .pc_in        (pc_in),
        .pc_out       (pc_out),
        .cache_addr_o (cache_addr_o)
    );

    // ------------------------------------------------------------
    // Waveform dump
    // ------------------------------------------------------------
    initial begin
        $dumpfile("TB_INST_FETCH.vcd");
        $dumpvars(0, TB_INST_FETCH);
    end

    // ------------------------------------------------------------
    // Base clock: 10ns period
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Hard timeout
    // ------------------------------------------------------------
    initial begin
        #1000;
        $display("[%0t] TIMEOUT reached", $time);
        $display("FINAL ERRORS = %0d", errors);
        $finish;
    end

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------
    task check_outputs;
        input [31:0] exp_pc;
        input [8:0]  exp_cache;
        input [255:0] tag;
        begin
            #1;
            if ((pc_out !== exp_pc) || (cache_addr_o !== exp_cache)) begin
                $display("[%0t] ERROR %0s | exp pc_out=%h cache=%h | got pc_out=%h cache=%h",
                         $time, tag, exp_pc, exp_cache, pc_out, cache_addr_o);
                errors = errors + 1;
            end
            else begin
                $display("[%0t] PASS  %0s | pc_out=%h cache=%h",
                         $time, tag, pc_out, cache_addr_o);
            end
        end
    endtask

    task wait_clk_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------
    initial begin
        errors = 0;

        rst_n = 1'b0;
        en_i  = 1'b0;
        pc_in = 32'h0000_0000;

        $display("========== TB_INST_FETCH START ==========");

        // --------------------------------------------------------
        // Test 1: Reset active
        // --------------------------------------------------------
        #2;
        check_outputs(32'h0000_0000, 9'h000, "reset_active_1");

        pc_in = 32'h0000_0020;
        #5;
        check_outputs(32'h0000_0000, 9'h000, "reset_active_2");

        // Release reset while disabled
        rst_n = 1'b1;
        wait_clk_cycles(2);
        check_outputs(32'h0000_0000, 9'h000, "after_reset_disabled");

        // --------------------------------------------------------
        // Test 2: Disabled mode, outputs must hold at zero
        // --------------------------------------------------------
        pc_in = 32'h0000_0100;
        wait_clk_cycles(1);
        check_outputs(32'h0000_0000, 9'h000, "disabled_hold_1");

        pc_in = 32'h1234_5678;
        wait_clk_cycles(1);
        check_outputs(32'h0000_0000, 9'h000, "disabled_hold_2");

        // --------------------------------------------------------
        // Test 3: First enable should force outputs to zero
        // --------------------------------------------------------
        @(negedge clk);
        en_i  = 1'b1;
        pc_in = 32'h0000_0020;

        wait_clk_cycles(1);
        check_outputs(32'h0000_0000, 9'h000, "first_enable_zero");

        // --------------------------------------------------------
        // Test 4: Following enabled cycles capture pc_in
        // --------------------------------------------------------
        pc_in = 32'h0000_0024;
        wait_clk_cycles(1);
        check_outputs(32'h0000_0024, 9'h009, "capture_0024");

        pc_in = 32'h0000_0038;
        wait_clk_cycles(1);
        check_outputs(32'h0000_0038, 9'h00E, "capture_0038");

        pc_in = 32'h0000_0400;
        wait_clk_cycles(1);
        check_outputs(32'h0000_0400, 9'h100, "capture_0400");

        // --------------------------------------------------------
        // Test 5: Disable and verify outputs freeze
        // --------------------------------------------------------
        @(negedge clk);
        en_i  = 1'b0;
        pc_in = 32'hDEAD_BEEF;

        wait_clk_cycles(2);
        check_outputs(32'h0000_0400, 9'h100, "disable_freeze_1");

        // --------------------------------------------------------
        // Test 6: Re-enable, first active cycle should zero again
        // --------------------------------------------------------
        @(negedge clk);
        en_i  = 1'b1;
        pc_in = 32'h0000_0080;

        wait_clk_cycles(1);
        check_outputs(32'h0000_0000, 9'h000, "re_enable_zero");

        pc_in = 32'h0000_0084;
        wait_clk_cycles(1);
        check_outputs(32'h0000_0084, 9'h021, "re_enable_capture");

        // --------------------------------------------------------
        // Test 7: Async reset during operation
        // --------------------------------------------------------
        #2;
        rst_n = 1'b0;
        #1;
        check_outputs(32'h0000_0000, 9'h000, "async_reset_during_run");

        #7;
        rst_n = 1'b1;
        en_i  = 1'b1;
        pc_in = 32'h0000_0200;

        wait_clk_cycles(1);
        check_outputs(32'h0000_0000, 9'h000, "post_reset_first_zero");

        pc_in = 32'h0000_0204;
        wait_clk_cycles(1);
        check_outputs(32'h0000_0204, 9'h081, "post_reset_capture");

        // --------------------------------------------------------
        // Test 8: Fast pc changes while enabled
        // --------------------------------------------------------
        @(negedge clk);
        pc_in = 32'h0000_0300; #1;
        pc_in = 32'h0000_0304; #1;
        pc_in = 32'h0000_0308; #1;
        pc_in = 32'h0000_030C; #1;
        pc_in = 32'h0000_0310;

        wait_clk_cycles(1);
        check_outputs(32'h0000_0310, 9'h0C4, "fast_pc_change_capture");

        // --------------------------------------------------------
        // Test 9: Stress enable around edge
        // --------------------------------------------------------
        en_i = 1'b0;
        pc_in = 32'h0000_0500;
        #4.5 en_i = 1'b1;   // near edge
        wait_clk_cycles(1);
        $display("[%0t] INFO edge stress 1 | pc_out=%h cache=%h en_rise=%b gclk=%b",
                 $time, pc_out, cache_addr_o, dut.en_rise, dut.gclk);

        pc_in = 32'h0000_0504;
        wait_clk_cycles(1);
        $display("[%0t] INFO edge stress 2 | pc_out=%h cache=%h en_rise=%b gclk=%b",
                 $time, pc_out, cache_addr_o, dut.en_rise, dut.gclk);

        // --------------------------------------------------------
        // Test 10: Random stress
        // --------------------------------------------------------
        repeat (15) begin
            @(negedge clk);
            pc_in = {$random, $random};
            en_i  = $random;
            #1;
            $display("[%0t] RANDOM | en_i=%b pc_in=%h pc_out=%h cache=%h",
                     $time, en_i, pc_in, pc_out, cache_addr_o);
        end

        #20;
        $display("========== TB_INST_FETCH END ==========");
        $display("FINAL ERRORS = %0d", errors);
        $finish;
    end

endmodule