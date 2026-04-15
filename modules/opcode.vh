// opcode.vh
// Standard RISC-V Base Opcodes and Custom TinyML Edge AI Extensions

`ifndef OPCODE_VH
`define OPCODE_VH

// --- Standard RISC-V Base Opcodes (opcode[6:0]) ---
`define OPCODE_R_TYPE  7'b0110011  
`define OPCODE_I_TYPE  7'b0010011  
`define OPCODE_LOAD    7'b0000011  
`define OPCODE_STORE   7'b0100011  
`define OPCODE_BRANCH  7'b1100011  

// --- Custom Edge AI Accelerator Opcode ---
// Mapped to the RISC-V 'custom-0' instruction space
`define OPCODE_CUSTOM  7'b0001011  

// --- Custom MAC funct3 Commands ---
`define MAC_EN   3'b000     // Load weights and compute dot product
`define MAC_RST  3'b001     // Flush the MAC pipeline and accumulator
`define MAC_CLS  3'b010     // Trigger classification and valid flag

`endif
