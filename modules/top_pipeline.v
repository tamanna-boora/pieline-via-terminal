`timescale 1ns / 1ps
`include "opcode.vh"

module top (
    input  wire clk,        // 100 MHz onboard clock
    input  wire btnc,       // Physical reset button (active low)
    output wire [15:0] led  // LD0-LD15
);

    // ================================================================
    // Reset Logic
    // ================================================================
    wire reset_n = ~btnc;  // Direct connection (active low)

    // ================================================================
    // Internal Wires
    // ================================================================
    wire [31:0] inst_mem_read_data, inst_mem_address;
    wire [31:0] dmem_read_data, dmem_write_address, dmem_read_address, dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire        inst_mem_is_valid, dmem_write_valid, dmem_read_valid;
    wire        dmem_read_ready, dmem_write_ready, exception;
    wire [31:0] pc_out;
    
    // M-Extension signals (optional - if your pipe module has them)
    wire is_mul, is_div, mul_busy_o, div_busy_o;
    wire [31:0] result_o;

    // ================================================================
    // Clock Divider (100 MHz to ~6 Hz for visualization)
    // ================================================================
    reg [31:0] clk_enable_counter;
    wire clock_enable;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            clk_enable_counter <= 32'h0;
        end
        else if (clk_enable_counter == 32'd8_333_333) begin  // 100M / (2 * 6Hz)
            clk_enable_counter <= 32'h0;
        end
        else begin
            clk_enable_counter <= clk_enable_counter + 1;
        end
    end
    
    assign clock_enable = (clk_enable_counter == 32'h0);

    // ================================================================
    // Interface Constants
    // ================================================================
    assign inst_mem_is_valid = 1'b1;
    assign dmem_write_valid  = 1'b1;
    assign dmem_read_valid   = 1'b1;

    // ================================================================
    // LED Output
    // ================================================================
   
    // ================================================================
    // Pipeline CPU Instantiation
    // ================================================================
    pipe pipe_u (
        .clk(clk),              // 100MHz clock
        .reset(reset_n),        // Active low
        .stall(~clock_enable),  // Stall when clock_enable is LOW (6Hz visualization)
        .exception(exception),
        .pc_out(pc_out),

        // Instruction Memory Interface
        .inst_mem_is_valid(inst_mem_is_valid),
        .inst_mem_read_data(inst_mem_read_data),
        .inst_mem_address(inst_mem_address),

        // Data Memory Interface
        .dmem_read_data_temp(dmem_read_data),
        .dmem_write_valid(dmem_write_valid),
        .dmem_read_valid(dmem_read_valid),
        .dmem_write_ready(dmem_write_ready),
        .dmem_read_ready(dmem_read_ready),
        .dmem_write_address(dmem_write_address),
        .dmem_read_address(dmem_read_address),
        .dmem_write_data(dmem_write_data),
        .dmem_write_byte(dmem_write_byte),
        
        // M-Extension outputs (comment out if not in your pipe module)
        .is_mul(is_mul),
        .is_div(is_div),
        .mul_busy_o(mul_busy_o),
        .div_busy_o(div_busy_o),
        .result_o(result_o)
    );
    reg div_happened;
    reg mul_happened;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            div_happened <= 1'b0;
            mul_happened <= 1'b0;
        end
        else begin
            if (is_div) div_happened <= 1'b1; // Catch the DIV spark
            if (is_mul) mul_happened <= 1'b1; // Catch the MUL spark
        end
    end
 assign led[15]    = exception;    // LD15: Error light
    assign led[14]    = mul_happened; // LD14: Stays on if a MUL ever happened
    assign led[13]    = div_happened; // LD13: Stays on if a DIV ever happened
    assign led[12]    = clock_enable; // LD12: Heartbeat (will blink fast)
    assign led[11:0]  = pc_out[13:2]; // LD11-0: Show the current PC (word address)
    // ================================================================
    // Instruction Memory (IMEM) - CORRECTED INSTANTIATION
    // ================================================================
    instr_mem IMEM (
        .clk(clk),
        .pc(inst_mem_address[31:2]),      // ← Byte address from pipeline
        .instr(inst_mem_read_data)  // ← 32-bit instruction output
    );

    // ================================================================
    // Data Memory (DMEM) - CORRECTED INSTANTIATION
    // ================================================================
    data_mem DMEM (
        .clk(clk),
        
        // Read port
        .re(dmem_read_ready),       // ← Read enable
        .raddr(dmem_read_address),  // ← Byte address
        .rdata(dmem_read_data),     // ← 32-bit read data output
        
        // Write port
        .we(dmem_write_ready),      // ← Write enable
        .waddr(dmem_write_address), // ← Byte address
        .wdata(dmem_write_data),    // ← 32-bit write data
        .wstrb(dmem_write_byte)     // ← Byte write strobe [3:0]
    );

endmodule
