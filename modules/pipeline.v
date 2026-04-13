`timescale 1ns / 1ps

module pipe
#(
    parameter [31:0] RESET = 32'h0000_0000
)
(
    input               clk,
    input               reset,
    input               stall,
    output              exception,
    output [31:0]       pc_out,

    // Instruction memory interface
    input               inst_mem_is_valid,
    input  [31:0]       inst_mem_read_data,
    input  [31:0]       dmem_read_data_temp,
    input               dmem_write_valid,
    input               dmem_read_valid,
      output              is_mul,
    output              is_div,
    output              mul_busy_o,
    output              div_busy_o,
    output [31:0]       result_o,
    output [31:0]       inst_mem_address,
    output              dmem_read_ready,
    output [31:0]       dmem_read_address,
    output              dmem_write_ready,
    output [31:0]       dmem_write_address,
    output [31:0]       dmem_write_data,
    output [3:0]        dmem_write_byte
);

    // ================================================================
    // DATA MEMORY WIRES
    // ================================================================
    wire [31:0] dmem_read_data;
    wire  [1:0] dmem_read_offset;
    wire        inst_mem_is_ready;
    wire        dmem_read_valid_checker;

    // ================================================================
    // IF/ID WIRES
    // ================================================================
    reg  [31:0] immediate;
    wire        immediate_sel;
    wire  [4:0] src1_select;
    wire  [4:0] src2_select;
    wire  [4:0] dest_reg_sel;
    wire  [2:0] alu_operation;
    wire        arithsubtype;
    wire        mem_write;
    wire        mem_to_reg;
    wire        illegal_inst;
    wire [31:0] execute_immediate;
    wire        alu;
    wire        lui;
    wire        jal;
    wire        jalr;
    wire        branch;
    reg         stall_read;
    wire [31:0] instruction;
    wire [31:0] reg_rdata2;
    wire [31:0] reg_rdata1;
    reg  [31:0] regs [31:1];

    // ================================================================
    // PC WIRES
    // ================================================================
    wire [31:0] pc;
    wire [31:0] inst_fetch_pc;
    reg  [31:0] fetch_pc;

    // ================================================================
    // STALL WIRES
    // ================================================================
    wire wb_stall_first;
    wire wb_stall_second;
    wire wb_stall;

    // ================================================================
    // EXECUTE WIRES
    // ================================================================
    wire [31:0] next_pc;
    wire [31:0] write_address;
    wire        branch_taken;
    wire        branch_stall;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;

    // ================================================================
    // WB/MEM WIRES
    // ================================================================
    wire        wb_alu_to_reg;
    wire [31:0] wb_result;
    wire  [2:0] wb_alu_operation;
    wire        wb_mem_write;
    wire        wb_mem_to_reg;
    wire  [4:0] wb_dest_reg_sel;
    wire        wb_branch;
    wire        wb_branch_nxt;
    wire [31:0] wb_write_address;
    wire  [1:0] wb_read_address;
    wire  [3:0] wb_write_byte;
    wire [31:0] wb_write_data;
    wire [31:0] wb_read_data;

        // ================================================================
    // M-EXTENSION WIRES
    // ================================================================
    wire        is_mul;         // HIGH for MUL/MULH/MULHSU/MULHU
    wire        is_div;         // HIGH for DIV/DIVU/REM/REMU
    wire        cpu_stall_out;  // HIGH while MUL (3 cycles) or DIV (34 cycles) busy

    // ================================================================
    // MEMORY ASSIGNMENTS
    // ================================================================
    assign dmem_write_address      = wb_write_address;
    assign dmem_read_address       = alu_operand1 + execute_immediate;
    assign dmem_read_offset        = dmem_read_address[1:0];
    assign dmem_read_ready         = mem_to_reg;
    assign dmem_write_ready        = wb_mem_write;
    assign dmem_write_data         = wb_write_data;
    assign dmem_write_byte         = wb_write_byte;
    assign dmem_read_data          = dmem_read_data_temp;
    assign dmem_read_valid_checker = 1'b1;

    // ================================================================
    // IF_ID INSTANTIATION
    // ================================================================
wire [31:0] id_ex_instruction;  // ← ADD THIS WIRE

IF_ID IF_ID_stage (
    .clk                (clk),
    .reset              (reset),
    .stall              (stall),
    .exception          (exception),

    .inst_mem_is_valid  (inst_mem_is_valid),
    .inst_mem_read_data (inst_mem_read_data),

    .stall_read_i       (stall_read),
    .inst_fetch_pc      (inst_fetch_pc),
    .instruction_i      (instruction),

    .wb_stall           (wb_stall),
    .wb_alu_to_reg      (wb_alu_to_reg),
    .wb_mem_to_reg      (wb_mem_to_reg),
    .wb_dest_reg_sel    (wb_dest_reg_sel),
    .wb_result          (wb_result),
    .wb_read_data       (wb_read_data),

    .inst_mem_offset    (inst_mem_address[1:0]),

    .execute_immediate_w(execute_immediate),
    .immediate_sel_w    (immediate_sel),
    .alu_w              (alu),
    .lui_w              (lui),
    .jal_w              (jal),
    .jalr_w             (jalr),
    .branch_w           (branch),
    .mem_write_w        (mem_write),
    .mem_to_reg_w       (mem_to_reg),
    .arithsubtype_w     (arithsubtype),
    .pc_w               (pc),
    .src1_select_w      (src1_select),
    .src2_select_w      (src2_select),
    .dest_reg_sel_w     (dest_reg_sel),
    .alu_operation_w    (alu_operation),
    .illegal_inst_w     (illegal_inst),
    .instruction_o      (instruction),
    .is_mul_w           (is_mul),
    .is_div_w           (is_div),
    .id_ex_instruction_o(id_ex_instruction)  // ← ADD THIS
);


           // ================================================================
    // REGISTER FILE FORWARDING WITH DATA FORWARDING
    // ================================================================
    // 3-stage pipeline forwarding paths:
    // Priority 1: Forward from WB/MEM stage (most recent committed result)
    // Priority 2: Read from register file
    //
    // This allows:
    //   - LW/ALU result forwarding (WB stage)
    //   - MUL/DIV result forwarding
    //   - Dependent instructions to execute without stalls
    //
    // For LOAD instructions:
    //   - LW enters EXECUTE, address calculated
    //   - Data read from memory in WB stage
    //   - wb_read_data_o available for forwarding
    //   - Next instruction can use loaded value immediately
    // ================================================================

    // For src1 (rs1)
    assign reg_rdata1 =
        (src1_select == 5'd0) ? 32'd0 :
        // Forward from WB/MEM stage (highest priority - most recent data)
        (!wb_stall && wb_alu_to_reg && (wb_dest_reg_sel == src1_select))
        ? (wb_mem_to_reg ? wb_read_data : wb_result)
        // Read from register file (default)
        : regs[src1_select];

    // For src2 (rs2)
    assign reg_rdata2 =
        (src2_select == 5'd0) ? 32'd0 :
        // Forward from WB/MEM stage (highest priority - most recent data)
        (!wb_stall && wb_alu_to_reg && (wb_dest_reg_sel == src2_select))
        ? (wb_mem_to_reg ? wb_read_data : wb_result)
        // Read from register file (default)
        : regs[src2_select];
     // ================================================================
    // REGISTER FILE WRITEBACK (Complete Logic)
    // ================================================================
    // Write-back to register file happens every cycle when:
    // 1. wb_alu_to_reg is HIGH (instruction writes to register)
    // 2. stall_read is LOW (pipeline not stalled)
    // 3. wb_stall is LOW (WB stage not blocking)
    //
    // Select data source:
    // - LOAD (wb_mem_to_reg=1): Use wb_read_data (from memory)
    // - ALU/MUL/DIV (wb_mem_to_reg=0): Use wb_result (from execute)
    //
    // Register x0 is hardwired to 0 and never written
    // ================================================================

    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 1; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end
        else if (wb_alu_to_reg && !stall_read && !wb_stall) begin
            // Only write to non-zero registers
            if (wb_dest_reg_sel != 5'd0) begin
                // Select data source based on instruction type
                if (wb_mem_to_reg)
                    regs[wb_dest_reg_sel] <= wb_read_data;  // LOAD: from memory
                else
                    regs[wb_dest_reg_sel] <= wb_result;     // ALU/MUL/DIV: from execute
            end
        end
    end

    // ================================================================
    // STALL REGISTER — INCLUDES M-EXTENSION STALL
    // ================================================================
    // stall_read controls the entire pipeline
    // Set HIGH when: external stall OR MUL/DIV busy
    always @(posedge clk or negedge reset) begin
        if (!reset)
            stall_read <= 1'b1;
        else
            stall_read <= stall | cpu_stall_out;
    end

    // ================================================================
    // EXECUTE INSTANTIATION
    // ================================================================
    execute execute (
        .clk            (clk),
        .reset          (reset),

        .reg_rdata1     (reg_rdata1),
        .reg_rdata2     (reg_rdata2),
        .execute_imm    (execute_immediate),
        .pc             (pc),
        .fetch_pc       (fetch_pc),
        .immediate_sel  (immediate_sel),
        .stall_read     (stall_read),
        .dmem_raddr     (dmem_read_address[1:0]),
        .alu_op         (alu_operation),
        .arithsubtype   (arithsubtype),
        .alu            (alu),
        .lui            (lui),
        .jal            (jal),
        .jalr           (jalr),
        .branch         (branch),
        .mem_write      (mem_write),
        .mem_to_reg     (mem_to_reg),
        .dest_reg_sel   (dest_reg_sel),

        .wb_branch_i    (wb_branch),
        .wb_branch_nxt_i(wb_branch_nxt),

        .alu_operand1   (alu_operand1),
        .alu_operand2   (alu_operand2),
        .write_address  (write_address),
        .branch_stall   (branch_stall),
        .next_pc        (next_pc),
        .branch_taken   (branch_taken),

        .wb_result      (wb_result),
        .wb_mem_write   (wb_mem_write),
        .wb_alu_to_reg  (wb_alu_to_reg),
        .wb_dest_reg_sel(wb_dest_reg_sel),
        .wb_branch      (wb_branch),
        .wb_branch_nxt  (wb_branch_nxt),
        .wb_mem_to_reg  (wb_mem_to_reg),
        .wb_read_address(wb_read_address),
        .mem_alu_operation(wb_alu_operation),
        .ex_result_forward(ex_result_forward),
                .is_mul         (is_mul),
        .is_div         (is_div),
        .cpu_stall_out  (cpu_stall_out)
    );

    // ================================================================
    // PC UPDATE LOGIC
    // ================================================================
    always @(posedge clk or negedge reset) begin
        if (!reset)
            fetch_pc <= RESET;
        else if (!stall_read)
            fetch_pc <= branch_stall
                        ? fetch_pc + 4
                        : next_pc;
    end

    // ================================================================
    // WB/MEM INSTANTIATION
    // ================================================================
    wb wb_stage (
        .clk                (clk),
        .reset              (reset),
        .stall_read_i       (stall_read),
        .fetch_pc_i         (fetch_pc),
        .wb_branch_i        (wb_branch),
        .wb_mem_to_reg_i    (wb_mem_to_reg),
        .mem_write_i        (mem_write && !branch_stall),
        .write_address_i    (write_address),
        .alu_operand2_i     (alu_operand2),
        .alu_operation_i    (alu_operation),
        .wb_alu_operation_i (wb_alu_operation),
        .wb_read_address_i  (wb_read_address),
        .dmem_read_data_i   (dmem_read_data),
        .dmem_write_valid_i (dmem_write_valid),
        .inst_mem_address_o (inst_mem_address),
        .inst_mem_is_ready_o(inst_mem_is_ready),
        .wb_stall_o         (wb_stall),
        .wb_write_address_o (wb_write_address),
        .wb_write_data_o    (wb_write_data),
        .wb_write_byte_o    (wb_write_byte),
        .wb_read_data_o     (wb_read_data),
        .inst_fetch_pc_o    (inst_fetch_pc),
        .wb_stall_first_o   (wb_stall_first),
        .wb_stall_second_o  (wb_stall_second)
    );

    assign pc_out = fetch_pc;
     assign is_mul = is_mul;           // Already exists as internal wire
    assign is_div = is_div;           // Already exists as internal wire
    assign mul_busy_o = cpu_stall_out; // cpu_stall_out indicates MUL/DIV busy
    assign div_busy_o = cpu_stall_out; // Same stall signal
    assign result_o = wb_result;       // Result from WB stage
endmodule
