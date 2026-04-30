# Project BIM - SystemVerilog Coding Style Guide

This document outlines the coding standards and naming conventions for the SystemVerilog transition of the BIM project. Following these rules ensures consistency and makes the codebase easier to maintain and verify.

## 1. File Naming Conventions
- **Source Files**: All SystemVerilog files must use the `.sv` extension.
- **Interfaces**: Name interfaces with an `_if` suffix (e.g., `eeprom_if.sv`).
- **Packages**: Name shared packages with a `_pkg` suffix (e.g., `riscv_pkg.sv`).
- **Testbenches**: Use either a `_tb` suffix (e.g., `icache_tb.sv`) or a `TB_` prefix (e.g., `TB_INST_DECODER.sv`). Be consistent within sub-modules.
- **Archiving**: Legacy Verilog-2001 code should be moved to the `verilog_archive/` directory.

## 2. Naming Conventions in Code
- **Modules**: Use `UPPER_CASE` for major architectural blocks (e.g., `INST_DECODER`) or `PascalCase` for sub-modules.
- **Types**: All `typedef` names must have a `_t` suffix (e.g., `opcode_t`, `instr_t`).
- **Enums**: Enum values should be `UPPER_CASE` (e.g., `OP_ALU`).
- **FSM States**:
    - Use `_q` for the current state register (e.g., `state_q`).
    - Use `_d` for the next state combinational logic (e.g., `state_d`).
- **Interfaces**: Use short, descriptive names for interface instances (e.g., `i_if` for icache interface).

## 3. Language Constructs
- **Logic Type**: Always use `logic` instead of `reg` or `wire` unless a net-type (like `tri`) is explicitly required for tri-state buses.
- **Always Blocks**: 
    - Use `always_ff @(posedge clk or negedge rst_n)` for sequential logic.
    - Use `always_comb` for combinational logic.
    - Use `always_latch` for latches (like clock gates).
- **Case Statements**: Use `unique case` or `priority case` to help the compiler optimize and catch bugs.
- **Port Connections**: Use the `.*` (dot-star) connection style for testbenches when port names and signal names match to reduce boilerplate.

## 4. Verification & Simulation
- **Assertions**: Include SystemVerilog Assertions (SVA) in testbenches to catch timing violations automatically.
- **Dumping**: Use native Cadence SHM dumping (`$shm_open`, `$shm_probe`) for high-performance waveforms in SimVision.
- **Clean Runs**: Always run with the `-clean` flag in `xrun` to avoid stale snapshot issues.

## 5. Metadata
- Every file must start with the following standard header:

```verilog
//
// ======================================================================================
// Copyright (c) Empty Quarter Semiconductor Co. - EQSemi
// All rights reserved.
// Project       : EQ-SSPC
// Module        : 
// Author(s)     : Group 5
// Last Modified : 29 April 2026
//
// ======================================================================================
```
