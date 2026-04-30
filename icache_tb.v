`timescale 1ns/1ps

// ============================================================
// icache_tb.v — Testbench for icache.v
// Tests all 4 combinations of {o_enable_from_boot_loader, icache_we}
// across representative addresses and data patterns.
// ============================================================
module icache_tb;

// ---- DUT ports ----
reg         clk;
reg         o_enable_from_boot_loader;
reg         icache_we;
reg  [8:0]  icache_waddr;
reg  [31:0] icache_wdata;
reg  [8:0]  icache_raddr;
wire [31:0] risc_instruction;

// ---- scoreboard ----
integer pass_cnt;
integer fail_cnt;

// ---- DUT ----
icache dut (
    .clk                      (clk),
    .o_enable_from_boot_loader(o_enable_from_boot_loader),
    .icache_we                (icache_we),
    .icache_waddr             (icache_waddr),
    .icache_wdata             (icache_wdata),
    .icache_raddr             (icache_raddr),
    .risc_instruction         (risc_instruction)
);

// ---- clock  (10 ns period) ----
initial clk = 0;
always #5 clk = ~clk;

// ============================================================
// TASK: synchronous write one word into the cache
// ============================================================
task write_word;
    input [8:0]  addr;
    input [31:0] data;
    begin
        icache_we    = 1'b1;
        icache_waddr = addr;
        icache_wdata = data;
        @(posedge clk);   // latch on rising edge
        #1;               // propagation margin
        icache_we = 1'b0;
    end
endtask

// ============================================================
// TASK: apply read address, compare output, print PASS/FAIL
// label is up to 20 ASCII characters packed in a 160-bit reg
// ============================================================
task check_read;
    input [8:0]   addr;
    input [31:0]  expected;
    input [159:0] label;   // 20-char string, %s skips leading zeros
    begin
        icache_raddr = addr;
        #1;   // combinational settling
        if (risc_instruction === expected) begin
            $display("PASS | %-20s | addr=0x%03X | out=0x%08X",
                     label, addr, risc_instruction);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL | %-20s | addr=0x%03X | expected=0x%08X | got=0x%08X",
                     label, addr, expected, risc_instruction);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

// ---- address/data tables ----
reg [8:0]  ADDR [0:5];   // 6 representative addresses
reg [31:0] DATA [0:5];   // 6 data patterns
integer i, j;

initial begin
    // representative addresses: min, near-min, mid, near-max, max-1, max
    ADDR[0] = 9'd0;
    ADDR[1] = 9'd1;
    ADDR[2] = 9'd127;
    ADDR[3] = 9'd255;
    ADDR[4] = 9'd510;
    ADDR[5] = 9'd511;

    // representative data patterns
    DATA[0] = 32'hFFFFFFFF;   // all ones
    DATA[1] = 32'hAAAAAAAA;   // alternating 10
    DATA[2] = 32'h55555555;   // alternating 01
    DATA[3] = 32'h12345678;   // ascending nibbles
    DATA[4] = 32'hDEADBEEF;   // well-known canary
    DATA[5] = 32'h00000001;   // single LSB

    pass_cnt = 0;
    fail_cnt = 0;

    // default safe state
    o_enable_from_boot_loader = 1'b0;
    icache_we    = 1'b0;
    icache_waddr = 9'd0;
    icache_wdata = 32'd0;
    icache_raddr = 9'd0;

    repeat(2) @(posedge clk);   // allow DUT to settle

    // ================================================================
    // COMBO 1:  o_enable=0, icache_we=0
    // Read from uninitialised / previously-written addresses while
    // output gate is off → output must always be 0x00000000.
    // No write occurs (we=0).
    // ================================================================
    $display("\n[COMBO 1]  o_enable=0  we=0  (output gated off, no write)");
    o_enable_from_boot_loader = 1'b0;
    icache_we = 1'b0;
    for (i = 0; i < 6; i = i + 1) begin
        check_read(ADDR[i], 32'h00000000, "en0_we0_read");
    end

    // ================================================================
    // COMBO 2:  o_enable=0, icache_we=1
    // Write data while output gate is off.
    // Reads taken immediately after each write must still return 0
    // (gate forces output to zero) even though data is now stored.
    // ================================================================
    $display("\n[COMBO 2]  o_enable=0  we=1  (write active, output gated off)");
    o_enable_from_boot_loader = 1'b0;
    for (i = 0; i < 6; i = i + 1) begin
        write_word(ADDR[i], DATA[i]);
        check_read(ADDR[i], 32'h00000000, "en0_we1_write");
    end

    // ================================================================
    // COMBO 3:  o_enable=1, icache_we=0
    // Output gate is on, no new writes.
    // Data written in COMBO 2 must be readable (cache retained values).
    // ================================================================
    $display("\n[COMBO 3]  o_enable=1  we=0  (output enabled, cache retains data)");
    o_enable_from_boot_loader = 1'b1;
    icache_we = 1'b0;
    for (i = 0; i < 6; i = i + 1) begin
        // Attempt a dummy write with we=0 (should not overwrite)
        icache_waddr = ADDR[i];
        icache_wdata = 32'hBADC0DE0;
        @(posedge clk); #1;
        // Data from COMBO 2 must still be present
        check_read(ADDR[i], DATA[i], "en1_we0_retain");
    end

    // ================================================================
    // COMBO 4:  o_enable=1, icache_we=1
    // Write new data and read it back — the full write→read path.
    // Overwrite each address with a different pattern (DATA shifted).
    // ================================================================
    $display("\n[COMBO 4]  o_enable=1  we=1  (write and read, full path)");
    o_enable_from_boot_loader = 1'b1;
    for (i = 0; i < 6; i = i + 1) begin
        // Write a fresh value (rotate DATA index to avoid old data)
        j = (i + 3) % 6;
        write_word(ADDR[i], DATA[j]);
        check_read(ADDR[i], DATA[j], "en1_we1_write_read");
    end

    // ================================================================
    // BONUS: Enable-toggle test on a single address
    // Verifies that toggling o_enable_from_boot_loader mid-stream
    // gates and un-gates the output correctly without a new write.
    // ================================================================
    $display("\n[BONUS]    Enable toggle (same address, alternating enable)");
    o_enable_from_boot_loader = 1'b1;
    write_word(9'd42, 32'hCAFEBABE);
    icache_raddr = 9'd42;

    o_enable_from_boot_loader = 1'b1; #1;
    check_read(9'd42, 32'hCAFEBABE, "toggle_enable_on");

    o_enable_from_boot_loader = 1'b0; #1;
    check_read(9'd42, 32'h00000000, "toggle_enable_off");

    o_enable_from_boot_loader = 1'b1; #1;
    check_read(9'd42, 32'hCAFEBABE, "toggle_enable_on2");

    // ================================================================
    // Summary
    // ================================================================
    $display("\n====================================================");
    $display("  TOTAL  PASS: %0d   FAIL: %0d", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
        $display("  *** ALL TESTS PASSED ***");
    else
        $display("  *** %0d TEST(S) FAILED ***", fail_cnt);
    $display("====================================================\n");

    $finish;
end

endmodule
