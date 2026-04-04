`timescale 1ns / 1ps
`include "riscv_opcodes.vh" // Pulls in definitions from the header file

module decode (
    input wire clk,
    input wire rst_n,          
    input wire [31:0] instr,   
    
    // Standard Processor Control Signals
    output reg [3:0] alu_ctrl,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg branch,
    
    // Custom Accelerator Control Signals
    output reg mac_en,         
    output reg mul_div_en      
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @(*) begin
        // Default control signal states 
        alu_ctrl   = 4'b0000;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        mac_en     = 1'b0;    
        mul_div_en = 1'b0;    

        if (!rst_n) begin
            // Active-low reset logic
            alu_ctrl   = 4'b0000;
            reg_write  = 1'b0;
            mem_read   = 1'b0;
            mem_write  = 1'b0;
            branch     = 1'b0;
            mac_en     = 1'b0;
            mul_div_en = 1'b0;
        end else begin
            case(opcode)
                `OPCODE_R_TYPE: begin
                    reg_write = 1'b1;
                    if (funct7 == `FUNCT7_RV32M) begin
                        mul_div_en = 1'b1; 
                    end else begin
                        case(funct3)
                            `FUNCT3_ADD_SUB: alu_ctrl = (funct7 == `FUNCT7_SUB) ? 4'b0001 : 4'b0000; 
                            `FUNCT3_AND:     alu_ctrl = 4'b0010; 
                            `FUNCT3_OR:      alu_ctrl = 4'b0011; 
                            default:         alu_ctrl = 4'b0000;
                        endcase
                    end
                end

                `OPCODE_I_TYPE: begin
                    reg_write = 1'b1;
                    // I-Type logic here...
                end

                `OPCODE_LOAD: begin
                    mem_read = 1'b1;
                    reg_write = 1'b1;
                end

                `OPCODE_STORE: begin
                    mem_write = 1'b1;
                end

                `OPCODE_BRANCH: begin
                    branch = 1'b1;
                end

                // --- CUSTOM INSTRUCTION ROUTING ---
                `OPCODE_CUSTOM: begin
                    mac_en = 1'b1;     
                    reg_write = 1'b1;  
                end

                default: begin
                    // Handle undefined opcodes
                end
            endcase
        end
    end
endmodule
