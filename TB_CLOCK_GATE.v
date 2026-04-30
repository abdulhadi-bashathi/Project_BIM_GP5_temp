`timescale 1ns/1ps
`include "CLOCK_GATE.v"

module TB_CLOCK_GATE;

    reg  clk;
    reg  en;
    wire gclk;

    integer in_clk_edges;
    integer gclk_edges;
    integer errors;

    CLOCK_GATE dut (
        .clk  (clk),
        .en   (en),
        .gclk (gclk)
    );

    // Waveform dump
    initial begin
        $dumpfile("TB_CLOCK_GATE.vcd");
        $dumpvars(0, TB_CLOCK_GATE);
    end

    // 10 ns clock period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Hard timeout so simulation never runs forever
    initial begin
        #500;
        $display("[%0t] TIMEOUT reached", $time);
        $display("FINAL: in_clk_edges=%0d gclk_edges=%0d errors=%0d", in_clk_edges, gclk_edges, errors);
        $finish;
    end

    // Counters
    always @(posedge clk)
        in_clk_edges = in_clk_edges + 1;

    always @(posedge gclk) begin
        gclk_edges = gclk_edges + 1;
        $display("[%0t] posedge gclk | en=%b clk=%b", $time, en, clk);
    end

    task check_gclk_low;
        input [255:0] tag;
        begin
            #1;
            if (gclk !== 1'b0) begin
                $display("[%0t] ERROR %0s : gclk is not low when expected, gclk=%b", $time, tag, gclk);
                errors = errors + 1;
            end else begin
                $display("[%0t] PASS  %0s : gclk low", $time, tag);
            end
        end
    endtask

    task check_counts;
        input integer exp;
        input [255:0] tag;
        begin
            if (gclk_edges !== exp) begin
                $display("[%0t] ERROR %0s : expected gclk_edges=%0d got=%0d", $time, tag, exp, gclk_edges);
                errors = errors + 1;
            end else begin
                $display("[%0t] PASS  %0s : gclk_edges=%0d", $time, tag, gclk_edges);
            end
        end
    endtask

    initial begin
        in_clk_edges = 0;
        gclk_edges   = 0;
        errors       = 0;
        en           = 0;

        $display("========== TB_CLOCK_GATE START ==========");

        // --------------------------------------------------
        // Test 1: Disabled => gclk must stay low
        // --------------------------------------------------
        #22;
        check_gclk_low("disabled_idle");
        check_counts(0, "disabled_idle_count");

        // --------------------------------------------------
        // Test 2: Enable while clk is low => next pulses should pass
        // --------------------------------------------------
        @(negedge clk);
        en = 1'b1;
        $display("[%0t] Enable asserted during clk low", $time);

        repeat (3) @(posedge clk);
        #1;
        check_counts(3, "enable_during_low_three_pulses");

        // --------------------------------------------------
        // Test 3: Disable while clk is low => gclk stops cleanly
        // --------------------------------------------------
        @(negedge clk);
        en = 1'b0;
        $display("[%0t] Enable deasserted during clk low", $time);

        repeat (2) @(posedge clk);
        #1;
        check_gclk_low("disabled_after_low_deassert");
        check_counts(3, "no_extra_pulses_after_disable");

        // --------------------------------------------------
        // Test 4: Assert enable near clk high phase
        // Should not create mid-cycle glitch; effect appears on a later valid pulse
        // --------------------------------------------------
        @(posedge clk);
        #1;
        en = 1'b1;
        $display("[%0t] Enable asserted during clk high", $time);

        repeat (3) @(posedge clk);
        #1;
        if (gclk_edges < 5 || gclk_edges > 6) begin
            $display("[%0t] ERROR high_phase_enable_window : unexpected edge count=%0d", $time, gclk_edges);
            errors = errors + 1;
        end else begin
            $display("[%0t] PASS  high_phase_enable_window : edge count=%0d", $time, gclk_edges);
        end

        // --------------------------------------------------
        // Test 5: Deassert enable near clk high phase
        // --------------------------------------------------
        @(posedge clk);
        #1;
        en = 1'b0;
        $display("[%0t] Enable deasserted during clk high", $time);

        repeat (3) @(posedge clk);
        #1;
        check_gclk_low("disabled_after_high_deassert");

        // --------------------------------------------------
        // Test 6: Fast chatter while clk low/high
        // Stress only; monitor output
        // --------------------------------------------------
        @(negedge clk);
        en = 1'b1; #1;
        en = 1'b0; #1;
        en = 1'b1; #1;
        en = 1'b0; #1;
        en = 1'b1;
        $display("[%0t] Chatter sequence applied", $time);

        repeat (4) @(posedge clk);
        #1;
        $display("[%0t] INFO after chatter: gclk=%b gclk_edges=%0d", $time, gclk, gclk_edges);

        // --------------------------------------------------
        // Test 7: Random stress
        // --------------------------------------------------
        repeat (20) begin
            @(negedge clk);
            en = $random;
            #1;
            $display("[%0t] Random stress en=%b gclk=%b", $time, en, gclk);
        end

        // Final settle
        #20;
        $display("========== TB_CLOCK_GATE END ==========");
        $display("FINAL: in_clk_edges=%0d gclk_edges=%0d errors=%0d", in_clk_edges, gclk_edges, errors);
        $finish;
    end

endmodule