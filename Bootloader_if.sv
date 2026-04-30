`timescale 1ns/1ps

interface eeprom_if;
    logic [12:0] a;
    logic        ce_n;
    logic        oe_n;
    logic        we_n;
    logic [7:0]  io;

    modport master (
        output a, ce_n, oe_n, we_n,
        input  io
    );

    modport slave (
        input  a, ce_n, oe_n, we_n,
        output io
    );

    modport monitor (
        input a, ce_n, oe_n, we_n, io
    );
endinterface

interface icache_if;
    logic        we;
    logic [8:0]  waddr;
    logic [31:0] wdata;

    modport master (
        output we, waddr, wdata
    );

    modport slave (
        input  we, waddr, wdata
    );

    modport monitor (
        input we, waddr, wdata
    );
endinterface
