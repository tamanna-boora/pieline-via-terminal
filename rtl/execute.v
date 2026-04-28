`timescale 1ns / 1ps

module execute
#(
    parameter [31:0] RESET = 32'h0000_0000
)
(
    input clk,
    input reset,

    input  [31:0] reg_rdata1,
    input  [31:0] reg_rdata2,
    input  [31:0] execute_imm,
    input  [31:0] pc,
    input  [31:0] fetch_pc,
    input         immediate_sel,
    input         mem_write,
    input         jal,
    input         jalr,
    input         lui,
    input         alu,
    input         branch,
    input         arithsubtype,
    input         mem_to_reg,
    input         stall_read,
    input  [4:0]  dest_reg_sel,
    input  [2:0]  alu_op,
    input  [1:0]  dmem_raddr,
    input         is_mul,              // NEW: MUL signal from if_id
    input         is_div,              // NEW: DIV signal from if_id

    input         wb_branch_i,
    input         wb_branch_nxt_i,
    
    output [31:0] alu_operand1,
    output [31:0] alu_operand2,
    output [31:0] write_address,
    output        branch_stall,
    output reg [31:0] next_pc,
    output reg        branch_taken,

    output [31:0] wb_result,
    output        wb_mem_write,
    output        wb_alu_to_reg,
    output [4:0]  wb_dest_reg_sel,
    output        wb_branch,
    output        wb_branch_nxt,
    output        wb_mem_to_reg,
    output [1:0]  wb_read_address,
    output [2:0]  mem_alu_operation,
    
    output wire [31:0] ex_result_forward,
    output wire   cpu_stall_out
);

`include "opcode.vh"

reg  [31:0] ex_result;
wire [32:0] ex_result_subs;
wire [32:0] ex_result_subu;
wire [31:0] div_quotient, div_remainder;
wire        div_busy;
wire        div_start;
wire        mul_busy;

// ================================================================
// OPERAND SELECTION
// ================================================================
assign alu_operand1 = reg_rdata1;
assign alu_operand2 = immediate_sel ? execute_imm : reg_rdata2;

assign ex_result_subs =
    {alu_operand1[31], alu_operand1} -
    {alu_operand2[31], alu_operand2};

assign ex_result_subu =
    {1'b0, alu_operand1} - {1'b0, alu_operand2};

assign write_address = alu_operand1 + execute_imm;
assign branch_stall  = wb_branch_nxt_i || wb_branch_i;

// ================================================================
// MULTIPLIER - 3 stage pipeline (FIXED - DO NOT CHANGE)
// Outputs mul_low/mul_high valid 3 cycles after inputs
// ================================================================
wire [31:0] mul_low, mul_high;

optimal_mul_32 MULT_UNIT (
    .clk   (clk),
    .rst   (reset),
    .a     (alu_operand1),
    .b     (alu_operand2),
    .funct3(alu_op),
    .low   (mul_low),
    .high  (mul_high)
);

// ================================================================
// MUL STALL COUNTER - ACCOUNTS FOR 3-CYCLE LATENCY
//
// MUL result (mul_low/mul_high) is valid 3 cycles AFTER input.
// In our 3-stage pipeline:
//   Cycle N:   MUL instruction enters EXECUTE
//   Cycle N+1: MUL in EXECUTE, result not ready yet
//   Cycle N+2: MUL in EXECUTE (or maybe WB), result not ready yet
//   Cycle N+3: Result is ready (available at mul_low/mul_high outputs)
//
// So we need to STALL the pipeline for 3 cycles when MUL enters.
// mul_stall_count = 3 → stall for 3 more cycles
// mul_stall_count = 0 → no stall
// ================================================================
reg [2:0] mul_stall_count;

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        mul_stall_count <= 3'd0;
    end
    else if (is_mul && mul_stall_count == 3'd0 && !div_busy) begin
        // New MUL instruction entering EXECUTE - start 3-cycle stall
        mul_stall_count <= 3'd3;
    end
    else if (mul_stall_count > 3'd0) begin
        mul_stall_count <= mul_stall_count - 3'd1;
    end
end

assign mul_busy = (mul_stall_count > 3'd0);

// ================================================================
// DIVIDER - 34 cycle FSM
// ================================================================
wire [31:0] div_q, div_r;

// Only start divider when:
// - This is a div/rem instruction
// - Divider is not already running
// - Multiplier is not stalling (can't have both in flight)
assign div_start = is_div && !div_busy && !mul_busy;

optimal_div_32 DIV_UNIT (
    .clk        (clk),
    .rst        (reset),
    .start      (div_start),
    .funct3     (alu_op),
    .dividend_i (alu_operand1),
    .divisor_i  (alu_operand2),
    .quotient_o (div_q),
    .remainder_o(div_r),
    .busy_o     (div_busy)
);

// ================================================================
// COMBINED STALL - either MUL or DIV is busy
// ================================================================
assign cpu_stall_out = mul_busy | div_busy;

// ================================================================
// MULTIPLIER RESULT SELECTION
// mul_low/mul_high are valid when mul_stall_count reaches 0
// ================================================================
wire [31:0] mul_result = (alu_op[1:0] != 2'b00) ? mul_high : mul_low;

// ================================================================
// NEXT PC LOGIC
// ================================================================
always @(*) begin
    next_pc      = fetch_pc + 4;
    branch_taken = !branch_stall;

    case (1'b1)
        jal  : next_pc = pc + execute_imm;
        jalr : next_pc = alu_operand1 + execute_imm;

        branch: begin
            case (alu_op)
                `BEQ: begin
                    next_pc = (ex_result_subs == 0)
                              ? pc + execute_imm : fetch_pc + 4;
                    if (ex_result_subs != 0) branch_taken = 1'b0;
                end
                `BNE: begin
                    next_pc = (ex_result_subs != 0)
                              ? pc + execute_imm : fetch_pc + 4;
                    if (ex_result_subs == 0) branch_taken = 1'b0;
                end
                `BLT: begin
                    next_pc = ex_result_subs[32]
                              ? pc + execute_imm : fetch_pc + 4;
                    if (!ex_result_subs[32]) branch_taken = 1'b0;
                end
                `BGE: begin
                    next_pc = (!ex_result_subs[32])
                              ? pc + execute_imm : fetch_pc + 4;
                    if (ex_result_subs[32]) branch_taken = 1'b0;
                end
                `BLTU: begin
                    next_pc = ex_result_subu[32]
                              ? pc + execute_imm : fetch_pc + 4;
                    if (!ex_result_subu[32]) branch_taken = 1'b0;
                end
                `BGEU: begin
                    next_pc = (!ex_result_subu[32])
                              ? pc + execute_imm : fetch_pc + 4;
                    if (ex_result_subu[32]) branch_taken = 1'b0;
                end
                default: next_pc = fetch_pc;
            endcase
        end

        default: begin
            next_pc      = fetch_pc + 4;
            branch_taken = 1'b0;
        end
    endcase
end

// ================================================================
// ALU + MATH RESULT MUX
//
// CRITICAL: is_mul and is_div checked FIRST to prevent jal/alu stealing result
// This is the fix for the "result=24" bug
// ================================================================
always @(*) begin
    case (1'b1)

        // MUL operations - checked FIRST
        is_mul: begin
            case (alu_op)
                3'b000,          // MUL
                3'b001,          // MULH
                3'b010,          // MULHSU
                3'b011:          // MULHU
                    ex_result = mul_result;
                default:
                    ex_result = 32'h0;
            endcase
        end

        // DIV operations - checked SECOND
        is_div: begin
            case (alu_op)
                3'b100,          // DIV
                3'b101:          // DIVU
                    ex_result = div_busy ? 32'h0 : div_q;
                3'b110,          // REM
                3'b111:          // REMU
                    ex_result = div_busy ? 32'h0 : div_r;
                default:
                    ex_result = 32'h0;
            endcase
        end

        mem_write : ex_result = alu_operand2;
        jal, jalr : ex_result = pc + 4;
        lui       : ex_result = execute_imm;

        alu: begin
            case (alu_op)
                `ADD : ex_result = arithsubtype
                                  ? alu_operand1 - alu_operand2
                                  : alu_operand1 + alu_operand2;
                `SLL : ex_result = alu_operand1 << alu_operand2[4:0];
                `SLT : ex_result = ex_result_subs[32];
                `SLTU: ex_result = {31'b0, ex_result_subu[32]};
                `XOR : ex_result = alu_operand1 ^ alu_operand2;
                `SR  : ex_result = arithsubtype
                                  ? $signed(alu_operand1) >>> alu_operand2[4:0]
                                  : alu_operand1 >> alu_operand2[4:0];
                `OR  : ex_result = alu_operand1 | alu_operand2;
                `AND : ex_result = alu_operand1 & alu_operand2;
                default: ex_result = 32'h0;
            endcase
        end

        default: ex_result = 32'h0;
    endcase
end

// ================================================================
// EXECUTE-STAGE RESULT FORWARDING
// ================================================================
// Make ex_result available for immediate forwarding
// This allows next instruction to use result without stalling
assign ex_result_forward = ex_result;

// ================================================================
// EX → WB/MEM PIPELINE REGISTER
// ================================================================
ex_mem_wb_reg u_ex_mem_wb (
    .clk          (clk),
    .reset_n      (reset),
    .stall_n      (~(stall_read | cpu_stall_out)),

    .ex_result    (ex_result),
    .mem_write    (mem_write && !branch_stall && !cpu_stall_out),
    .alu_to_reg   (alu | lui | jal | jalr | mem_to_reg | is_mul | is_div),
    .dest_reg_sel (dest_reg_sel),
    .branch_taken (branch_taken),
    .mem_to_reg   (mem_to_reg),
    .read_address (dmem_raddr),
    .alu_operation(alu_op),

    .ex_mem_result      (wb_result),
    .ex_mem_mem_write   (wb_mem_write),
    .ex_mem_alu_to_reg  (wb_alu_to_reg),
    .ex_mem_dest_reg_sel(wb_dest_reg_sel),
    .ex_mem_branch      (wb_branch),
    .ex_mem_branch_nxt  (wb_branch_nxt),
    .ex_mem_mem_to_reg  (wb_mem_to_reg),
    .ex_mem_read_address(wb_read_address),
    .ex_mem_alu_operation(mem_alu_operation)
);

endmodule


// ================================================================
// EX_MEM_WB_REG PIPELINE REGISTER
// ================================================================
module ex_mem_wb_reg (
    input         clk,
    input         reset_n,
    input         stall_n,

    input  [31:0] ex_result,
    input         mem_write,
    input         alu_to_reg,
    input  [4:0]  dest_reg_sel,
    input         branch_taken,
    input         mem_to_reg,
    input  [1:0]  read_address,
    input  [2:0]  alu_operation,
    
    output reg [31:0] ex_mem_result,
    output reg        ex_mem_mem_write,
    output reg        ex_mem_alu_to_reg,
    output reg [4:0]  ex_mem_dest_reg_sel,
    output reg        ex_mem_branch,
    output reg        ex_mem_branch_nxt,
    output reg        ex_mem_mem_to_reg,
    output reg [1:0]  ex_mem_read_address,
    output reg [2:0]  ex_mem_alu_operation
);

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        ex_mem_result        <= 32'h0;
        ex_mem_mem_write     <= 1'b0;
        ex_mem_alu_to_reg    <= 1'b0;
        ex_mem_dest_reg_sel  <= 5'h0;
        ex_mem_branch        <= 1'b0;
        ex_mem_branch_nxt    <= 1'b0;
        ex_mem_mem_to_reg    <= 1'b0;
        ex_mem_read_address  <= 2'h0;
        ex_mem_alu_operation <= 3'h0;
    end
    else if (stall_n) begin
        ex_mem_result        <= ex_result;
        ex_mem_mem_write     <= mem_write;
        ex_mem_alu_to_reg    <= alu_to_reg;
        ex_mem_dest_reg_sel  <= dest_reg_sel;
        ex_mem_branch        <= branch_taken;
        ex_mem_branch_nxt    <= ex_mem_branch;
        ex_mem_mem_to_reg    <= mem_to_reg;
        ex_mem_read_address  <= read_address;
        ex_mem_alu_operation <= alu_operation;
    end
end

endmodule
