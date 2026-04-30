`timescale 1ns/1ps

module Bootloader_tb();

    // Parameters
    localparam int TOTAL_INSTRUCTION_WORDS = 4; 
    localparam int WAIT_CYCLES = 4;
    localparam time CLK_PERIOD = 100ns;

    // Signals
    logic clk;
    logic rst_n;

    // Interfaces
    eeprom_if e_if();
    icache_if i_if();

    // Instantiate the Unit Under Test (UUT)
    // Note: I'll stick to port connections for now to avoid changing the design's port list immediately,
    // or I can update the design to use interfaces. Let's update the design to use interfaces for better SV practice.
    Bootloader #(
        .TOTAL_INSTRUCTION_WORDS(TOTAL_INSTRUCTION_WORDS),
        .WAIT_CYCLES(WAIT_CYCLES)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .e_if(e_if.master),
        .i_if(i_if.master),
        .if_stage_enable(), 
        .boot_done()
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Simulated EEPROM Memory
    logic [7:0] eeprom_mem [0:2047]; 
    
    initial begin
        foreach (eeprom_mem[i]) begin
            eeprom_mem[i] = 8'(i);
        end
    end

    // EEPROM Read Logic
    assign e_if.io = (!e_if.ce_n && !e_if.oe_n) ? eeprom_mem[e_if.a] : 8'hZZ;

    // Verification Logic
    int words_written = 0;
    logic [31:0] expected_wdata;
    
    always_comb begin
        expected_wdata = { 
            eeprom_mem[{i_if.waddr, 2'd3}],
            eeprom_mem[{i_if.waddr, 2'd2}],
            eeprom_mem[{i_if.waddr, 2'd1}],
            eeprom_mem[{i_if.waddr, 2'd0}]
        };
    end

    // Assertions
    // 1. Check that icache_we pulses correctly
    property p_icache_write;
        @(posedge clk) i_if.we |-> (i_if.wdata == expected_wdata);
    endproperty
    a_icache_write: assert property (p_icache_write) else $error("Data mismatch at address %0d!", i_if.waddr);

    // 2. Check EEPROM control signals
    property p_eeprom_ctrl;
        @(posedge clk) (uut.state_q == 3'd3 || uut.state_q == 3'd4) |-> (!e_if.ce_n && !e_if.oe_n);
    endproperty
    a_eeprom_ctrl: assert property (p_eeprom_ctrl);

    // Test Sequence
    initial begin
        $dumpfile("bootloader_tb.vcd");
        $dumpvars(0, Bootloader_tb);

        rst_n = 0;
        #(CLK_PERIOD * 5);
        rst_n = 1;
        
        $display("--- Starting SV Bootloader Test ---");
        
        // Wait for boot_done (using hierarchical reference for now)
        wait(uut.boot_done == 1'b1);
        
        $display("Time: %0t | boot_done asserted.", $time);
        
        #(CLK_PERIOD * 10);
        $display("--- All Tests Passed Successfully ---");
        $finish;
    end

    // Monitor words written
    always @(posedge clk) begin
        if (i_if.we) words_written++;
    end

endmodule
