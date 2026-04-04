// riscv_opcodes.vh
// Standard RISC-V and Custom Accelerator Opcode Definitions

`ifndef RISCV_OPCODES_VH
`define RISCV_OPCODES_VH

// --- Standard RISC-V Base Opcodes (opcode[6:0]) ---
`define OPCODE_R_TYPE  7'b0110011  // Standard Register-Register ALU ops
`define OPCODE_I_TYPE  7'b0010011  // Immediate ALU ops
`define OPCODE_LOAD    7'b0000011  // Load from memory
`define OPCODE_STORE   7'b0100011  // Store to memory
`define OPCODE_BRANCH  7'b1100011  // Conditional branches

// --- Custom Edge AI Accelerator Opcode ---
// Mapped to the RISC-V 'custom-0' instruction space
`define OPCODE_CUSTOM  7'b0001011  

// --- funct3 Definitions (instr[14:12]) ---
`define FUNCT3_ADD_SUB 3'b000
`define FUNCT3_AND     3'b111
`define FUNCT3_OR      3'b110
`define FUNCT3_MUL     3'b000  // Used when funct7 is RV32M

// --- funct7 Definitions (instr[31:25]) ---
`define FUNCT7_STANDARD 7'b0000000 // Standard ALU (e.g., ADD)
`define FUNCT7_SUB      7'b0100000 // Subtraction
`define FUNCT7_RV32M    7'b0000001 // Triggers the MUL/DIV module

// --- Custom MAC funct3 Commands ---
`define MAC_LOAD_WGHT   3'b000     // Load weights into MAC buffer
`define MAC_DOT_PROD    3'b001     // Execute pipelined dot product
`define MAC_READ_ACC    3'b010     // Read 32-bit accumulator result

`endif
