`timescale 1ns/1ps

module Bootloader #(
    parameter int TOTAL_INSTRUCTION_WORDS = 512,
    parameter int WAIT_CYCLES = 4
)(
    input  logic        clk,               // System clock.
    input  logic        rst_n,             // Active-low async reset.
    eeprom_if.master    e_if,              // EEPROM interface
    icache_if.master    i_if,              // ICache interface
    output logic        if_stage_enable,   // Asserts when DONE state is reached.
    output logic        boot_done          // Mirrors if_stage_enable for status visibility.
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE  = 3'd0,
        INIT  = 3'd1,
        REQ   = 3'd2,
        WAIT  = 3'd3,
        WRITE = 3'd4,
        DONE  = 3'd5
    } state_t;

    state_t state_q, state_d;
    
    logic [9:0]  word_cnt_q, word_cnt_d;
    logic [8:0]  word_cnt_r_q, word_cnt_r_d;
    logic [1:0]  byte_sel_q, byte_sel_d;
    logic [31:0] byte_buf_q, byte_buf_d;
    logic [2:0]  wait_cnt_q, wait_cnt_d;

    // Output Assignments
    assign e_if.we_n = 1'b1;
    
    // Address is combinationally driven by word_cnt and byte_sel
    // 10 bits of word_cnt + 2 bits of byte_sel + 1 padding bit = 13 bits
    assign e_if.a = {1'b0, word_cnt_q[9:0], byte_sel_q};
    
    // CE_n and OE_n are active low during WAIT and WRITE states
    assign e_if.ce_n = ~((state_q == WAIT) || (state_q == WRITE));
    assign e_if.oe_n = ~((state_q == WAIT) || (state_q == WRITE));
    
    // Instruction cache interface
    assign i_if.we    = (state_q == WRITE) && (byte_sel_q == 2'd3);
    assign i_if.waddr = word_cnt_r_q;
    assign i_if.wdata = byte_buf_q;
    
    // Control/Status interface
    assign if_stage_enable = (state_q == DONE);
    assign boot_done       = (state_q == DONE);

    // FSM Combinational Logic
    always_comb begin
        // Default assignments to prevent latches
        state_d      = state_q;
        word_cnt_d   = word_cnt_q;
        word_cnt_r_d = word_cnt_r_q;
        byte_sel_d   = byte_sel_q;
        byte_buf_d   = byte_buf_q;
        wait_cnt_d   = wait_cnt_q;

        unique case (state_q)
            IDLE: begin
                state_d = INIT;
            end
            
            INIT: begin
                word_cnt_d = 10'd0;
                byte_sel_d = 2'd0;
                wait_cnt_d = 3'd0;
                state_d    = REQ;
            end
            
            REQ: begin
                wait_cnt_d = 3'd0;
                state_d    = WAIT;
            end
            
            WAIT: begin
                if (wait_cnt_q == 3'(WAIT_CYCLES - 1)) begin
                    case (byte_sel_q)
                        2'd0: byte_buf_d[7:0]   = e_if.io;
                        2'd1: byte_buf_d[15:8]  = e_if.io;
                        2'd2: byte_buf_d[23:16] = e_if.io;
                        2'd3: byte_buf_d[31:24] = e_if.io;
                        default: ; // Handled by default assignments
                    endcase
                    word_cnt_r_d = word_cnt_q[8:0];
                    state_d      = WRITE;
                end else begin
                    wait_cnt_d = wait_cnt_q + 1'b1;
                end
            end
            
            WRITE: begin
                if (byte_sel_q == 2'd3) begin
                    byte_sel_d = 2'd0;
                    word_cnt_d = word_cnt_q + 1'b1;
                    if (word_cnt_q + 1'b1 == 10'(TOTAL_INSTRUCTION_WORDS)) begin
                        state_d = DONE;
                    end else begin
                        state_d = REQ;
                    end
                end else begin
                    byte_sel_d = byte_sel_q + 1'b1;
                    state_d    = REQ;
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
    always_ff @(posedge clk or negedge rst_n) begin
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
