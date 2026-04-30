`timescale 1ns/1ps

module icache (
    input  wire        clk,                       // System clock for synchronous write port
    input  wire        o_enable_from_boot_loader,  // Gate for read output. 0 forces output to 0x00000000
    input  wire        icache_we,                 // Write enable from bootloader (active high)
    input  wire [8:0]  icache_waddr,              // Write address (word index 0–511) from bootloader
    input  wire [31:0] icache_wdata,              // Instruction word to write from bootloader
    input  wire [8:0]  icache_raddr,              // Read address from INST_FETCH
    output wire [31:0] risc_instruction           // Instruction word to INST_DECODER. 0x00000000 if disabled
);

reg [31:0] cache [0:511]; // 512 words of 32 bits each

// Synchronous write logic for bootloader
always @(posedge clk) begin
    if (icache_we) begin
        cache[icache_waddr] <= icache_wdata; // Write instruction to cache
    end
end
// Combinational read logic for instruction fetch
wire [31:0] cache_read_data;
assign cache_read_data = cache[icache_raddr];

// Output gating: if o_enable_from_boot_loader is 1, output cache data; else output 0
assign risc_instruction = o_enable_from_boot_loader ? cache_read_data : 32'h00000000;

endmodule