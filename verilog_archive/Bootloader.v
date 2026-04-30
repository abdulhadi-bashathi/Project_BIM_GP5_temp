//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : Bootloader
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================

`timescale 1ns/1ps

module Bootloader #(
    parameter TOTAL_INSTRUCTION_WORDS = 512,
    parameter WAIT_CYCLES = 4
)(
    input  wire        clk,               // System clock.
    input  wire        rst_n,             // Active-low async reset.
    output wire [12:0] eeprom_a,          // EEPROM byte address bus.
    output wire        eeprom_ce_n,       // EEPROM chip-enable, active low.
    output wire        eeprom_oe_n,       // EEPROM output-enable, active low.
    output wire        eeprom_we_n,       // Hardwired to 1 (read-only access).
    input  wire [7:0]  eeprom_io,         // EEPROM data bus — one byte read at a time.
    output wire        icache_we,         // Write enable to ICACHE. Pulses for one cycle per word.
    output wire [8:0]  icache_waddr,      // Word address to ICACHE.
    output wire [31:0] icache_wdata,      // Assembled 32-bit instruction word to ICACHE.
    output wire        if_stage_enable,   // Asserts when DONE state is reached.
    output wire        boot_done          // Mirrors if_stage_enable for status visibility.
);

    // FSM States
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] INIT  = 3'd1;
    localparam [2:0] REQ   = 3'd2;
    localparam [2:0] WAIT  = 3'd3;
    localparam [2:0] WRITE = 3'd4;
    localparam [2:0] DONE  = 3'd5;

    reg [2:0]  state_q, state_d;
    reg [9:0]  word_cnt_q, word_cnt_d;
    reg [8:0]  word_cnt_r_q, word_cnt_r_d;
    reg [1:0]  byte_sel_q, byte_sel_d;
    reg [31:0] byte_buf_q, byte_buf_d;
    reg [2:0]  wait_cnt_q, wait_cnt_d;

    // Output Assignments
    assign eeprom_we_n = 1'b1;
    
    // Address is combinationally driven by word_cnt and byte_sel
    // 10 bits of word_cnt + 2 bits of byte_sel + 1 padding bit = 13 bits
    assign eeprom_a = {1'b0, word_cnt_q[9:0], byte_sel_q};
    
    // CE_n and OE_n are active low during WAIT and WRITE states
    assign eeprom_ce_n = ~((state_q == WAIT) || (state_q == WRITE));
    assign eeprom_oe_n = ~((state_q == WAIT) || (state_q == WRITE));
    
    // Instruction cache interface
    assign icache_we = (state_q == WRITE) && (byte_sel_q == 2'd3);
    assign icache_waddr = word_cnt_r_q;
    assign icache_wdata = byte_buf_q;
    
    // Control/Status interface
    assign if_stage_enable = (state_q == DONE);
    assign boot_done = (state_q == DONE);

    // FSM Combinational Logic
    always @(*) begin
        // Default assignments to prevent latches
        state_d      = state_q;
        word_cnt_d   = word_cnt_q;
        word_cnt_r_d = word_cnt_r_q;
        byte_sel_d   = byte_sel_q;
        byte_buf_d   = byte_buf_q;
        wait_cnt_d   = wait_cnt_q;

        case (state_q)
            IDLE: begin
                state_d = INIT;
            end
            
            INIT: begin
                word_cnt_d = 10'd0;
                byte_sel_d = 2'd0;
                wait_cnt_d = 3'd0;
                state_d = REQ;
            end
            
            REQ: begin
                wait_cnt_d = 3'd0;
                state_d = WAIT;
            end
            
            WAIT: begin
                if (wait_cnt_q == WAIT_CYCLES - 1) begin
                    case (byte_sel_q)
                        2'd0: byte_buf_d[7:0]   = eeprom_io;
                        2'd1: byte_buf_d[15:8]  = eeprom_io;
                        2'd2: byte_buf_d[23:16] = eeprom_io;
                        2'd3: byte_buf_d[31:24] = eeprom_io;
                    endcase
                    word_cnt_r_d = word_cnt_q[8:0];
                    state_d = WRITE;
                end else begin
                    wait_cnt_d = wait_cnt_q + 1'b1;
                end
            end
            
            WRITE: begin
                if (byte_sel_q == 2'd3) begin
                    byte_sel_d = 2'd0;
                    word_cnt_d = word_cnt_q + 1'b1;
                    if (word_cnt_q + 1'b1 == TOTAL_INSTRUCTION_WORDS) begin
                        state_d = DONE;
                    end else begin
                        state_d = REQ;
                    end
                end else begin
                    byte_sel_d = byte_sel_q + 1'b1;
                    state_d = REQ;
                end
            end
            
            DONE: begin
                state_d = DONE;
            end
            
            default: begin
                state_d = IDLE;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q      <= IDLE;
            word_cnt_q   <= 10'd0;
            word_cnt_r_q <= 9'd0;
            byte_sel_q   <= 2'd0;
            byte_buf_q   <= 32'd0;
            wait_cnt_q   <= 3'd0;
        end else begin
            state_q      <= state_d;
            word_cnt_q   <= word_cnt_d;
            word_cnt_r_q <= word_cnt_r_d;
            byte_sel_q   <= byte_sel_d;
            byte_buf_q   <= byte_buf_d;
            wait_cnt_q   <= wait_cnt_d;
        end
    end

endmodule