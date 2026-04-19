`ifndef OPCODE_VH
`define OPCODE_VH

// ================================================================
// 1. Instruction Bit-Field Slicing
// ================================================================
`define OPCODE  6:0
`define RD      11:7
`define FUNC3   14:12
`define RS1     19:15
`define RS2     24:20
`define SUBTYPE 30

// ================================================================
// 2. Standard RISC-V Base Opcodes
// ================================================================
`define ARITHR  7'b0110011
`define ARITHI  7'b0010011
`define LOAD    7'b0000011
`define STORE   7'b0100011
`define BRANCH  7'b1100011
`define JAL     7'b1101111
`define JALR    7'b1100111
`define LUI     7'b0110111

// ================================================================
// 3. Standard Funct3 Codes (Branches, ALU, Load/Store)
// ================================================================
// Branches
`define BEQ     3'b000
`define BNE     3'b001
`define BLT     3'b100
`define BGE     3'b101
`define BLTU    3'b110
`define BGEU    3'b111

// ALU Operations
`define ADD     3'b000
`define SLL     3'b001
`define SLT     3'b010
`define SLTU    3'b011
`define XOR     3'b100
`define SR      3'b101
`define OR      3'b110
`define AND     3'b111

// Load / Store Operations
`define LB      3'b000
`define LH      3'b001
`define LW      3'b010
`define LBU     3'b100
`define LHU     3'b101
`define SB      3'b000
`define SH      3'b001
`define SW      3'b010

// M-Extension Identifier & NOP
`define MEXT_FUNCT7 7'b0000001
`define NOP         32'h0000_0013

// ================================================================
// 4. Custom TinyML Edge AI Accelerator Opcodes
// ================================================================
`define OPCODE_CUSTOM  7'b0001011

`define MAC_EN   7'd0
`define MAC_RST  7'd2
`define MAC_CLS  7'd1

`endif
