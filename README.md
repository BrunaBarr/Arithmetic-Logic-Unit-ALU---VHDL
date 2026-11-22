# 4-bit Arithmetic Logic Unit with 8 Operations in VHDL

FPGA implementation of a 4-bit ALU with addition and subtraction in two's complement, logic operations, shifts and status flags (zero, negative, carry and overflow).

**Equipment:** Xilinx Spartan-3A/3AN Starter Kit (FPGA XC3S700AN-FGG484).

---

## 1. Overview

This repository contains the VHDL description and pin constraints of a 4-bit Arithmetic Logic Unit (ALU) implemented on an FPGA. These files are intended to be synthesized and implemented in Xilinx ISE 14.7 and programmed on the Xilinx Spartan-3A/3AN Starter Kit (FPGA XC3S700AN-FGG484). The operation code and both operands are entered through the board's slide switches, each value being confirmed with a push button. The 4-bit result and four status flags are displayed on the board's LEDs.

## 2. Specification

### 2.1 Operations

| Code (SW2..SW0) | Operation | Result | Carry (C) | Overflow (V) |
|:---:|---|---|---|---|
| `000` | Addition | A + B | carry out of bit 3 | two's complement overflow |
| `001` | Subtraction | A − B = A + not B + 1 | 1 = no borrow (A ≥ B, unsigned) | two's complement overflow |
| `010` | AND | A and B | 0 | 0 |
| `011` | OR | A or B | 0 | 0 |
| `100` | XOR | A xor B | 0 | 0 |
| `101` | NOT | not A | 0 | 0 |
| `110` | Shift left | A << 1 | shifted-out bit (A3) | 0 |
| `111` | Shift right (logical) | A >> 1 | shifted-out bit (A0) | 0 |

For every operation, Z = 1 when the result is `0000`, and N is the most significant bit of the result.

### 2.2 Inputs and outputs

| Signal | Board component | Pin | Function |
|---|---|---|---|
| `CLK` | 50 MHz oscillator | E12 | system clock |
| `SW(3:0)` | slide switches SW3..SW0 | T9, U8, U10, V8 | operation code and operands |
| `BTN_OK` | BTN_SOUTH | T15 | confirms each input |
| `BTN_RST` | BTN_WEST | U15 | resets the circuit |
| `LED(7:0)` | LED7..LED0 | W21, Y22, V20, V19, U19, U20, T19, R20 | current step, result and flags |

### 2.3 LED map

| State | LED7..LED4 | LED3..LED0 |
|---|---|---|
| Waiting for the operation code | `0001` | copy of the switches |
| Waiting for operand A | `0010` | copy of the switches |
| Waiting for operand B | `0100` | copy of the switches |
| Result | Z, N, C, V | result |

## 3. Architecture

The design is described in a single VHDL file, organized in the following blocks:

| Block | Type | Description |
|---|---|---|
| Synchronizer | sequential | two flip-flops per button, preventing metastability |
| Debouncer and edge detector | sequential | accepts a new button level only after 20 ms of stability and generates a one-clock pulse per press |
| State machine | sequential (Moore) | four states (`WAIT_OP`, `WAIT_A`, `WAIT_B`, `SHOW_RESULT`); stores the operation code and operands in registers |
| ALU | combinational | computes the result and the flags; addition and subtraction use a 5-bit sum whose most significant bit is the carry |
| LED multiplexer | combinational | selects the LED contents according to the current state |

### 3.1 Contact bounce

Mechanical buttons oscillate for a few milliseconds when pressed or released. At 50 MHz, each oscillation would be interpreted as a separate press, causing the state machine to skip steps. The synchronizer, the 20 ms debounce filter and the edge detector together guarantee that each press advances exactly one state.



## 4. Implementation (Xilinx ISE 14.7)

1. Create a project with the following settings: Family = Spartan3A and Spartan3AN, Device = XC3S700AN, Package = FGG484, Speed = -4, Preferred Language = VHDL.
2. Add `ula.vhd` with association **All** and set it as the top module.
3. Add `ula_spartan3an.ucf` with association **Implementation**.
4. Run **Generate Programming File** and program the FPGA through iMPACT (Boundary Scan).

## 6. Operation on the board

1. BTN_WEST resets the circuit; only LED4 remains lit.
2. The operation code is set on SW2..SW0 and confirmed with BTN_SOUTH.
3. Operand A is set on SW3..SW0 and confirmed with BTN_SOUTH.
4. Operand B is set on SW3..SW0 and confirmed with BTN_SOUTH; the result and flags are then displayed.
5. A further press of BTN_SOUTH starts a new operation.

### 6.1 Test cases

| Code | A | B | LEDs (LED7..LED0) | Remark |
|:---:|:---:|:---:|:---:|---|
| `000` | `0011` (3) | `0010` (2) | `0000 0101` | 3 + 2 = 5 |
| `000` | `0111` (7) | `0001` (1) | `0101 1000` | overflow: 8 exceeds the 4-bit signed range |
| `001` | `0101` (5) | `0101` (5) | `1010 0000` | zero result, no borrow |
| `001` | `0011` (3) | `0101` (5) | `0100 1110` | 3 − 5 = −2 (negative) |

## 7. Authors

| Name | GitHub |
|---|---|
| Bruna Barrientos | [@BrunaBarr](https://github.com/BrunaBarr) |
| Júlia Teles | [@juliateleseng](https://github.com/juliateleseng) |
