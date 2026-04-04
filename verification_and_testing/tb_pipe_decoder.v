`timescale 1ns / 1ps
`include "../modules/riscv_opcodes.vh" // Reference the header file in modules

module tb_pipe_decoder();

    reg clk;
    reg rst_n;
    reg [31:0] instr;

    wire [3:0] alu_ctrl;
    wire reg_write;
    wire mem_read;
    wire mem_write;
    wire branch;
    wire mac_en;
    wire mul_div_en;

    decode uut (
        .clk(clk),
        .rst_n(rst_n),
        .instr(instr),
        .alu_ctrl(alu_ctrl),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .mac_en(mac_en),
        .mul_div_en(mul_div_en)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0; 
        instr = 32'b0;

        #20;
        rst_n = 1; 
        #10;

        $display("--- Starting Pipeline Decoder Tests ---");

        // TEST 1: Standard ADD
        instr = {`FUNCT7_STANDARD, 5'd2, 5'd1, `FUNCT3_ADD_SUB, 5'd3, `OPCODE_R_TYPE};
        #10;
        if (mac_en || mul_div_en) $display("FAIL: Standard ADD incorrectly triggered an accelerator.");
        else $display("PASS: Standard ADD decoded correctly.");

        // TEST 2: Standard SUB
        instr = {`FUNCT7_SUB, 5'd2, 5'd1, `FUNCT3_ADD_SUB, 5'd3, `OPCODE_R_TYPE};
        #10;

        // TEST 3: RV32M Multiply
        instr = {`FUNCT7_RV32M, 5'd2, 5'd1, `FUNCT3_MUL, 5'd3, `OPCODE_R_TYPE};
        #10;
        if (mul_div_en && !mac_en) $display("PASS: RV32M Multiply routed correctly.");
        else $display("FAIL: RV32M routing failed.");

        // TEST 4: Custom MAC Instruction
        instr = {7'b0, 5'd2, 5'd1, `MAC_DOT_PROD, 5'd3, `OPCODE_CUSTOM};
        #10;
        if (mac_en && !mul_div_en) $display("PASS: Custom MAC Instruction routed successfully!");
        else $display("FAIL: Custom MAC routing failed.");

        // TEST 5: Active-Low Reset
        rst_n = 0; 
        #10;
        if (mac_en == 0 && reg_write == 0) $display("PASS: Active-low reset successful.");
        else $display("FAIL: Reset logic failed.");

        #20;
        $finish;
    end
endmodule
