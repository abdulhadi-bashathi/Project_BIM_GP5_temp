`timescale 1ns/1ps

module Bootloader_tb();

    // Parameters
    // Override TOTAL_INSTRUCTION_WORDS to 4 to make the simulation shorter and easier to debug
    // while still proving the full functionality of the FSM loops.
    localparam TOTAL_INSTRUCTION_WORDS = 4; 
    localparam WAIT_CYCLES = 4;
    localparam CLK_PERIOD = 100; // 10MHz clock (100ns)

    // Signals
    reg         clk;
    reg         rst_n;
    wire [12:0] eeprom_a;
    wire        eeprom_ce_n;
    wire        eeprom_oe_n;
    wire        eeprom_we_n;
    reg  [7:0]  eeprom_io;
    wire        icache_we;
    wire [8:0]  icache_waddr;
    wire [31:0] icache_wdata;
    wire        if_stage_enable;
    wire        boot_done;

    // Instantiate the Unit Under Test (UUT)
    Bootloader #(
        .TOTAL_INSTRUCTION_WORDS(TOTAL_INSTRUCTION_WORDS),
        .WAIT_CYCLES(WAIT_CYCLES)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .eeprom_a(eeprom_a),
        .eeprom_ce_n(eeprom_ce_n),
        .eeprom_oe_n(eeprom_oe_n),
        .eeprom_we_n(eeprom_we_n),
        .eeprom_io(eeprom_io),
        .icache_we(icache_we),
        .icache_waddr(icache_waddr),
        .icache_wdata(icache_wdata),
        .if_stage_enable(if_stage_enable),
        .boot_done(boot_done)
    );

    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // Simulated EEPROM Memory (2KB)
    reg [7:0] eeprom_mem [0:2047]; 
    integer i;

    // Initialize memory with dummy sequential data so we can track exactly which byte is which
    initial begin
        for (i = 0; i < 2048; i = i + 1) begin
            // eeprom_mem[0] = 0x00, eeprom_mem[1] = 0x01, etc.
            eeprom_mem[i] = i;
        end
    end

    // EEPROM Read Logic
    always @(*) begin
        // Typical EEPROM outputs data when CE and OE are both low
        if (!eeprom_ce_n && !eeprom_oe_n) begin
            eeprom_io = eeprom_mem[eeprom_a];
        end else begin
            eeprom_io = 8'hZZ;
        end
    end

    // Verify cache data against what we expect from memory
    reg [31:0] expected_wdata;
    always @(*) begin
        // Because of little-endian, byte 0 is LSB.
        // eeprom_mem[addr] is just the address itself because of how we initialized it.
        expected_wdata = { 
            eeprom_mem[{icache_waddr, 2'd3}],
            eeprom_mem[{icache_waddr, 2'd2}],
            eeprom_mem[{icache_waddr, 2'd1}],
            eeprom_mem[{icache_waddr, 2'd0}]
        };
    end

    // Cache Write Monitor and Verification
    integer words_written = 0;
    always @(posedge clk) begin
        if (icache_we) begin
            $display("Time: %0t | Cache Write [Word Addr: %0d] = Data: 0x%08X (Expected: 0x%08X)", 
                     $time, icache_waddr, icache_wdata, expected_wdata);
            
            if (icache_wdata !== expected_wdata) begin
                $display("ERROR: Data mismatch at address %0d!", icache_waddr);
                $stop;
            end
            
            if (icache_waddr !== words_written) begin
                $display("ERROR: Address out of sequence! Expected %0d, got %0d", words_written, icache_waddr);
                $stop;
            end
            
            words_written = words_written + 1;
        end
    end

    // Timeout watchdog just in case FSM hangs
    initial begin
        #(CLK_PERIOD * 100 * TOTAL_INSTRUCTION_WORDS);
        $display("ERROR: Simulation timed out before boot_done asserted.");
        $stop;
    end

    // Test Sequence
    initial begin
        // Waveform dumping
        $dumpfile("bootloader_tb.vcd");
        $dumpvars(0, Bootloader_tb);

        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        
        // Wait 5 clock cycles for global reset to finish
        #(CLK_PERIOD * 5);
        
        $display("--- Starting Bootloader Test ---");
        rst_n = 1;
        
        // Wait for boot_done to assert
        wait(boot_done == 1'b1);
        
        $display("Time: %0t | boot_done asserted. Finalizing verification...", $time);
        
        // Verify Total Written Words
        if (words_written == TOTAL_INSTRUCTION_WORDS) begin
            $display("SUCCESS: All %0d words were successfully written to cache.", words_written);
        end else begin
            $display("ERROR: boot_done asserted but only %0d words were written!", words_written);
            $stop;
        end
        
        // Verify Status Signals
        if (if_stage_enable !== 1'b1) begin
            $display("ERROR: if_stage_enable is not asserted!");
            $stop;
        end
        
        if (eeprom_we_n !== 1'b1) begin
            $display("ERROR: EEPROM write-enable was incorrectly asserted!");
            $stop;
        end
        
        if (eeprom_ce_n !== 1'b1 || eeprom_oe_n !== 1'b1) begin
            $display("ERROR: EEPROM control signals are not deasserted at DONE state!");
            $stop;
        end
        
        // Let simulation run a few more cycles to ensure it stays locked in DONE state
        #(CLK_PERIOD * 10);
        
        if (icache_we !== 1'b0) begin
            $display("ERROR: icache_we pulsed after DONE state!");
            $stop;
        end
        
        $display("--- All Tests Passed Successfully ---");
        $finish;
    end

endmodule
