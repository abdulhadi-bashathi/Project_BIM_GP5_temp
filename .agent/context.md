# Technical Specification Report: Core Boot-up & Initialization Module (BIM)

## 1. Module Overview and Strategic Purpose

In the EQ-SSPC mixed-signal SoC architecture, the Core Boot-up & Initialization Module (BIM) serves as the mission-critical bridge between high-density, non-volatile off-chip storage and high-speed, on-chip execution. Developed by Group 5, the BIM is the first logic block to activate post-reset, ensuring that the RISC-V core transitions from a cold-boot state to a fully operational "Smart Protection" state with absolute integrity. Its primary strategic role is to manage the reliable transfer of firmware from an external 8-bit EEPROM into a dedicated internal instruction cache, providing the foundation for the system's "Smart Sense, Protect and Control" capabilities.

The primary objective of the BIM is to orchestrate the transition between two distinct operational modes: the "Safety/Demo" mode, where the core executes a basic LED-blink routine from an internal Boot ROM, and the "Smart Protection" mode, where the core executes the primary application firmware from the Instruction Cache (ICACHE). Because the EQ-SSPC utilizes a single-cycle execution model, every instruction completes in exactly one clock period. The BIM’s design allows the system to populate the ICACHE fully before execution begins, thereby enforcing deterministic latency. By eliminating the need for complex cache-miss stall logic, the BIM ensures that the processor can provide the Hard Real-Time (HRT) responsiveness required for high-speed protective switching and fault monitoring.

The following sections detail the hardware sub-modules and the finite state machine logic required to maintain this system integrity.

## 2. Primary Hardware Components

The BIM comprises several physical sub-modules tasked with maintaining system integrity during the Power-On Reset (POR) sequence. These modules are logically sequenced to ensure that the instruction memory is fully prepared before the RISC-V core is granted bus control.

* **Off-Chip EEPROM (AT28C64B):** A 64K (8K x 8) parallel EEPROM serving as the primary non-volatile storage. It provides a 150ns access time (tACC) and is selected for its high reliability, featuring Software Data Protection (SDP) and 10-year data retention, which are vital for industrial protection modules.
* **Instruction Cache (ICACHE):** A 2KB (512 words x 32-bit) SRAM model. It features a synchronous-write port for the bootloader and an asynchronous-read port for the execution core.
  * **Key Design Insight:** Because the read port is asynchronous, the instruction is available in the same cycle the address is presented. To satisfy this timing requirement, the BIM derives `cache_addr_o` from `pc_in` (the next PC) rather than `pc_out`. This "one-cycle ahead" addressing ensures the instruction settles before the next rising edge of the clock.
* **Boot ROM:** A hard-coded internal ROM used for the "Safety/Demo" mode while the system-enable signal (EN) is 0.
* **Bootloader FSM:** The central hardware controller that manages the flow of data from the EEPROM to the ICACHE without software intervention.

### AT28C64B Pinout Integration

The following table defines the interface between the BIM and the external storage device:

| Pin Name | Function | BIM Direction | Role in BIM Integration |
| :--- | :--- | :--- | :--- |
| A0 - A12 | Addresses | Out | Provides 13-bit byte address to EEPROM. |
| I/O0 - I/O7 | Data I/O | In | 8-bit data input from external storage. |
| CE# | Chip Enable | Out | Active-low signal to enable external device. |
| OE# | Output Enable | Out | Active-low signal to drive data onto the bus. |
| WE# | Write Enable | Out | Hardwired to HIGH (Read-only during boot). |

## 3. The Bootloader Finite State Machine (FSM) Logic

A hardware-based FSM is a strategic necessity for the EQ-SSPC architecture, allowing for "bare-metal" initialization of the RISC-V core. This ensures the processor state does not interfere with the population of the instruction memory. The FSM transitions through six chronological states:

1. **IDLE (3'd0):** The default state at POR. It initializes internal pointers and immediately transitions to INIT.
2. **INIT (3'd1):** Preparation cycle. It clears the word and byte counters to ensure the load begins at address 0x00.
3. **REQ (3'd2):** Address assertion. The FSM calculates the specific EEPROM byte address using the formula: `(word_cnt << 2) + byte_sel`. This address is asserted one cycle early to respect the AT28C64B’s address setup time.
4. **WAIT (3'd3):** The FSM holds CE# and OE# low to allow the EEPROM to drive the bus. The `WAIT_CYCLES` parameter is set to 4. While a minimum of 3 cycles is required to meet the 150ns tACC (providing a 300ns margin at 10 MHz), a value of 4 is utilized to provide a robust safety margin against board-level parasitic capacitance.
5. **WRITE (3'd4):** The FSM performs Byte Assembly. The 8-bit `eeprom_io` is latched into a `byte_buf` register. Once the 4th byte is received (`byte_sel == 3`), the FSM pulses `icache_we` to commit the assembled 32-bit word to the cache.
6. **DONE (3'd5):** A sticky final state. It asserts `if_stage_enable` and `boot_done`, signalling the handoff to the RISC-V core and the transition to Phase 2.

## 4. Operational Phases: Boot Flow and Signal Transitions

The EQ-SSPC architecture employs a dual-phase boot strategy to ensure the device remains responsive even in the event of external memory failure.

* **Phase 1 (EN = 0):** EEPROM Load. The `INST_FETCH` stage of the RISC-V core is inhibited. The core is prevented from accessing the ICACHE to avoid read-write collisions. During this time, a combinatorial multiplexer redirects the core to fetch instructions from the internal Boot ROM, which executes the "Safety/Demo" LED-blink program.
* **Phase 2 (EN = 1):** Normal Execution. The transition is triggered by the rising edge of EN. At this moment, the `INST_FETCH` unit detects the edge and forces a Program Counter (PC) reset to 0. The combinatorial multiplexer switches the instruction stream source from the Boot ROM to the ICACHE, allowing the core to begin executing the application firmware.

**Byte Assembly and Endianness:** The BIM utilizes little-endian format for instruction assembly. The first byte retrieved from address `(word_cnt << 2) + 0` is placed in bits [7:0] of the word, the second in [15:8], and so on. This ensures direct compatibility with GCC and LLVM toolchains, which generate RISC-V binaries in little-endian by default.

## 5. Signal Map and Interface Definitions

Precise signal mapping is critical for RTL developers and those working within the IDE environment to debug the boot sequence. All directions are relative to the Internal BIM Module Port.

| Signal Name | Width | Direction | Functional Description |
| :--- | :--- | :--- | :--- |
| eeprom_a | 13 | Out | EEPROM Byte Address Bus (A0-A12). |
| eeprom_io | 8 | In | 8-bit Data from external storage. |
| eeprom_ce_n | 1 | Out | Active-low Chip Enable for EEPROM. |
| eeprom_oe_n | 1 | Out | Active-low Output Enable for EEPROM. |
| icache_we | 1 | Out | Write Enable pulse for ICACHE word commit. |
| icache_wdata | 32 | Out | Assembled 32-bit little-endian instruction word. |
| en_i / EN | 1 | In/Out | System-wide flag; enables ICACHE and resets PC. |
| boot_done | 1 | Out | Status flag indicating FSM has reached DONE. |

**Known Limitations:** The BIM does not include hardware-based read-write collision protection within the ICACHE. Developers must ensure the Bootloader FSM is the exclusive master of the cache during EN=0 and that no software-level writes are attempted during EN=1.

## 6. Implementation Notes and Design Constraints

* **Deterministic Timing Margin:** The system clock is capped at 10 MHz. This is a hard physical constraint dictated by the AT28C64B’s 150ns tACC. The BIM's WAIT states are specifically tuned to this frequency to ensure reliable data latching from the off-chip interface. This predictability is what enables the EQ-SSPC’s Hard Real-Time performance.
* **Simulation Handling:** To optimize verification cycles, the RTL includes an `` `ifdef SIMULATION `` block. This allows the `$readmemh` task to pre-load `instructions.txt` directly into the ICACHE, bypassing the lengthy FSM-driven EEPROM load process during CPU logic verification.
* **Address Calculation & Alignment:** The BIM discards PC bits [1:0] to maintain 4-byte word alignment. This results in a 9-bit address bus `cache_addr_o[8:0]` which maps directly to the 512-word deep cache (covering addresses 0x000 to 0x7FC).

The BIM serves as the essential foundation of the EQ-SSPC architecture, guaranteeing that the processor initializes into a known, valid state before assuming control of the critical protective switching elements of the SoC.
