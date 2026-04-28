`timescale 1ns / 1ps

(* use_dsp = "yes" *)
module optimal_mul_32 (
    input clk,
    input rst,                      
    input [31:0] a,          // rs1 (Multiplicand)
    input [31:0] b,          // rs2 (Multiplier)
    input [2:0] funct3,      // RISC-V M-Extension 3-bit code
    output [31:0] low,       // Lower 32 bits (Result of MUL)
    output [31:0] high       // Upper 32 bits (Result of MULH variants)
);

    // Pipeline Registers
    reg signed [32:0] a_reg, b_reg; // Stage 1 (Input)
    reg signed [65:0] prod_reg;     // Stage 2 (Multiplier)
    reg [63:0] final_out;           // Stage 3 (Output)
    // DSP slices on the Artix-7 have internal registers (IREG, MREG, PREG)
  //By declaring three sets of registers, Vivado maps our code directly into these hardware slots.

    // Sign selection based on RISC-V Spec

    wire a_is_signed = (funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010);
    //a_is_signed: True for MUL, MULH, and MULHSU.

    wire b_is_signed = (funct3 == 3'b000) || (funct3 == 3'b001);  
    // b_is_signed: True for MUL and MULH         

    always @(posedge clk) begin
        if (!rst) begin
            a_reg     <= 33'd0;
            b_reg     <= 33'd0;
            prod_reg  <= 66'd0;
            final_out <= 64'd0;
           
        end else begin
            // Stage 1: Capture and Sign Extend
            a_reg <= a_is_signed ? {a[31], a} : {1'b0, a};
            b_reg <= b_is_signed ? {b[31], b} : {1'b0, b};
            //By expanding to 33 bits, we can use one single math operation to handle all RISC-V signed/unsigned variations.

            // Stage 2: Multiply (Maps to DSP MREG)
            prod_reg <= a_reg * b_reg;

            // Stage 3: Output Latch (Maps to DSP PREG)
            //The 66-bit internal result is trimmed to the standard 64-bit output
            final_out <= prod_reg[63:0];
        end
    end

    assign low  = final_out[31:0];
    assign high = final_out[63:32];

endmodule