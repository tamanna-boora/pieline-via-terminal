`timescale 1ns / 1ps
`include "opcode.vh"

module tb_pipeline();

    // ---------------------------------------------------------
    // 1. Core Signals
    // ---------------------------------------------------------
    reg clk;
    reg reset;
    reg stall;
    
    wire exception;
    wire [31:0] pc_out;

    // Memory Interface Signals
    reg         inst_mem_is_valid;
    reg  [31:0] inst_mem_read_data;
    reg  [31:0] dmem_read_data_temp;
    reg         dmem_write_valid;
    reg         dmem_read_valid;

    wire        is_mul;
    wire        is_div;
    wire        mul_busy_o;
    wire        div_busy_o;
    wire [31:0] result_o;
    wire [31:0] inst_mem_address;
    wire        dmem_read_ready;
    wire [31:0] dmem_read_address;
    wire        dmem_write_ready;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [ 3:0] dmem_write_byte;

    // ---------------------------------------------------------
    // 2. Instantiate the Pipeline (Device Under Test)
    // ---------------------------------------------------------
    pipe DUT (
        .clk(clk),
        .reset(reset),
        .stall(stall),
        .exception(exception),
        .pc_out(pc_out),
        .inst_mem_is_valid(inst_mem_is_valid),
        .inst_mem_read_data(inst_mem_read_data),
        .dmem_read_data_temp(dmem_read_data_temp),
        .dmem_write_valid(dmem_write_valid),
        .dmem_read_valid(dmem_read_valid),
        .is_mul(is_mul),
        .is_div(is_div),
        .mul_busy_o(mul_busy_o),
        .div_busy_o(div_busy_o),
        .result_o(result_o),
        .inst_mem_address(inst_mem_address),
        .dmem_read_ready(dmem_read_ready),
        .dmem_read_address(dmem_read_address),
        .dmem_write_ready(dmem_write_ready),
        .dmem_write_address(dmem_write_address),
        .dmem_write_data(dmem_write_data),
        .dmem_write_byte(dmem_write_byte)
    );

    // ---------------------------------------------------------
    // 3. Mock Instruction Memory (The Custom AI Program)
    // ---------------------------------------------------------
    reg [31:0] instruction_rom [0:15];

    initial begin
        // 1. ADDI x1, x0, 0x05 -> Load dummy pixel data '5' into rs1
        instruction_rom[0] = 32'h0050_0093; 
        
        // 2. ADDI x2, x0, 0x12 -> Load dummy neuron ID (1) and weight addr (2) into rs2
        instruction_rom[1] = 32'h0120_0113; 
        
        // 3. NOP (Wait for registers to write back)
        instruction_rom[2] = 32'h0000_0013; 
        
        // 4. MAC_EN x0, x1, x2 -> Trigger custom neural network calculation
        // Custom Machine Code: rs1=1, rs2=2, funct3=000, opcode=0001011
        instruction_rom[3] = 32'h0020_800B; 
        
        // 5. NOPs (Simulate letting the MAC unit calculate for a few cycles)
        instruction_rom[4] = 32'h0000_0013;
        instruction_rom[5] = 32'h0000_0013;
        
        // 6. MAC_CLS x3, x0, x0 -> Trigger classification and write result to rs3
        // Custom Machine Code: rd=3, funct3=010, opcode=0001011
        instruction_rom[6] = 32'h0000_218B; 
        
        // 7. Halt/End (Infinite NOPs)
        instruction_rom[7] = 32'h0000_0013;
        instruction_rom[8] = 32'h0000_0013;
    end

    // Instruction Fetch Logic
    always @(posedge clk) begin
        if (!reset) begin
            inst_mem_read_data <= 32'h0000_0013; // Default to NOP
        end else begin
            inst_mem_read_data <= instruction_rom[inst_mem_address[5:2]];
        end
    end

    // ---------------------------------------------------------
    // 4. Clock Generation & Test Sequence
    // ---------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    initial begin
        reset = 0; // Active low reset
        stall = 0;
        inst_mem_is_valid = 1;
        dmem_read_data_temp = 32'd0;
        dmem_write_valid = 0;
        dmem_read_valid = 0;

        $display("========================================");
        $display("   TINYML MAC INTEGRATION TEST START    ");
        $display("========================================");

        #20;
        reset = 1; 

        #150;

        $display("========================================");
        $display("   TEST COMPLETE. CHECK WAVEFORMS.      ");
        $display("========================================");
        $finish;
    end

    // ---------------------------------------------------------
    // 5. System Monitors (For the TA Demo!)
    // ---------------------------------------------------------
    always @(posedge clk) begin
        // Monitor standard MUL/DIV 
        if (DUT.execute.mul_busy | DUT.execute.div_busy) begin
            $display("[Time: %0t] Standard M-EXT Active.", $time);
        end

        // Monitor the MAC Unit wake-up
        if (DUT.decode_inst.mac_enable) begin
            $display("[Time: %0t] AI MAC Awakened! Pixels: %x, Neuron: %x", 
                     $time, DUT.reg_rdata1, DUT.reg_rdata2);
        end
        
        // Monitor the Classification Result Write-Back
        if (DUT.decode_inst.classify) begin
            $display("[Time: %0t] AI Classification Complete! Predicted Digit: %d", 
                     $time, DUT.mac_unit_inst.digit_out);
        end
    end

endmodule
