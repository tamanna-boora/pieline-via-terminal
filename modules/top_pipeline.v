`timescale 1ns / 1ps

module top (
    input  wire clk,        // 100 MHz onboard clock
    input  wire btnc,       // Physical reset button (Pin D9, active high)
    output wire [15:0] led  // LD0-LD15
);

    // ================================================================
    // Reset Logic (Active-High Physical to Active-Low Internal)
    // ================================================================
    wire reset_n = ~btnc; 

    // ================================================================
    // Internal Wires
    // ================================================================
    wire [31:0] inst_mem_read_data, inst_mem_address;
    wire [31:0] dmem_read_data, dmem_write_address, dmem_read_address, dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire        inst_mem_is_valid, dmem_write_valid, dmem_read_valid;
    wire        dmem_read_ready, dmem_write_ready, exception;
    wire [31:0] pc_out;

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
        else if (clk_enable_counter == 32'd8_333_333) begin  
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
    // Pipeline CPU Instantiation
    // ================================================================
    pipe pipe_u (
        .clk(clk),              
        .reset(reset_n),        
        .stall(~clock_enable),  
        .exception(exception),
        .pc_out(pc_out),

        .inst_mem_is_valid(inst_mem_is_valid),
        .inst_mem_read_data(inst_mem_read_data),
        .inst_mem_address(inst_mem_address),

        .dmem_read_data_temp(dmem_read_data),
        .dmem_write_valid(dmem_write_valid),
        .dmem_read_valid(dmem_read_valid),
        .dmem_write_ready(dmem_write_ready),
        .dmem_read_ready(dmem_read_ready),
        .dmem_write_address(dmem_write_address),
        .dmem_read_address(dmem_read_address),
        .dmem_write_data(dmem_write_data),
        .dmem_write_byte(dmem_write_byte),
        
        .is_mul(is_mul),
        .is_div(is_div),
        .mul_busy_o(mul_busy_o),
        .div_busy_o(div_busy_o),
        .result_o(result_o)
    );

    // ================================================================
    // LED Monitors
    // ================================================================
    reg div_happened;
    reg mul_happened;
    reg mac_happened; // New register to catch the AI spark

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            div_happened <= 1'b0;
            mul_happened <= 1'b0;
            mac_happened <= 1'b0;
        end
        else begin
            if (is_div) div_happened <= 1'b1;
            if (is_mul) mul_happened <= 1'b1;
            // Sniff the instruction wire to see if the custom opcode fired
            if (inst_mem_read_data[6:0] == 7'b0001011) mac_happened <= 1'b1;
        end
    end

    assign led[15]    = exception;    // Error light
    assign led[14]    = mul_happened; // Standard MUL fired
    assign led[13]    = div_happened; // Standard DIV fired
    assign led[12]    = clock_enable; // Heartbeat
    assign led[11]    = 1'b0;
    assign led[10]    = mac_happened; // LD10: AI ACCELERATOR FIRED!
    assign led[9:0]   = pc_out[11:2]; // Show the current PC

    // ================================================================
    // Instruction & Data Memory Instantiations
    // ================================================================
    instr_mem IMEM (
        .clk(clk),
        .pc(inst_mem_address[31:2]),      
        .instr(inst_mem_read_data)  
    );

    data_mem DMEM (
        .clk(clk),
        .re(dmem_read_ready),       
        .raddr(dmem_read_address),  
        .rdata(dmem_read_data),     
        .we(dmem_write_ready),      
        .waddr(dmem_write_address), 
        .wdata(dmem_write_data),    
        .wstrb(dmem_write_byte)     
    );

endmodule
