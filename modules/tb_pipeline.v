`timescale 1ns / 1ps

module tb_pipeline;

////////////////////////////////////////////////////////////
// CLOCK & RESET
////////////////////////////////////////////////////////////
reg clk;
reg reset;

// 100 MHz clock
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// reset (active low)
initial begin
    reset = 0;
    #100;
    reset = 1;
end

initial begin
    $dumpfile("pipeline.vcd");
    $dumpvars(0, tb_pipeline);
end


////////////////////////////////////////////////////////////
// PIPE ↔ MEMORY SIGNALS
////////////////////////////////////////////////////////////
wire [31:0] inst_mem_read_data;
wire        inst_mem_is_valid;

wire [31:0] dmem_read_data;
wire        dmem_write_valid;
wire        dmem_read_valid;

assign inst_mem_is_valid = 1'b1;
assign dmem_write_valid  = 1'b1;
assign dmem_read_valid   = 1'b1;

wire exception;
wire [31:0] inst_mem_address;
wire        dmem_read_ready;
wire [31:0] dmem_read_address;
wire        dmem_write_ready;
wire [31:0] dmem_write_address;
wire [31:0] dmem_write_data;
wire [3:0]  dmem_write_byte;
wire [31:0] pc_out;

// Track div_busy state changes
reg div_busy_prev;
reg mul_busy_prev;

////////////////////////////////////////////////////////////
// DUT : PIPELINE CPU
////////////////////////////////////////////////////////////
pipe DUT (
    .clk(clk),
    .reset(reset),
    .stall(1'b0),
    .exception(exception),
    .pc_out(pc_out),

    .inst_mem_is_valid(inst_mem_is_valid),
    .inst_mem_read_data(inst_mem_read_data),
    .inst_mem_address(inst_mem_address),
    .dmem_read_data_temp(dmem_read_data),
    .dmem_write_valid(dmem_write_valid),
    .dmem_read_valid(dmem_read_valid),
    .dmem_read_ready(dmem_read_ready),
    .dmem_read_address(dmem_read_address),
    .dmem_write_ready(dmem_write_ready),
    .dmem_write_address(dmem_write_address),
    .dmem_write_data(dmem_write_data),
    .dmem_write_byte(dmem_write_byte)
);


////////////////////////////////////////////////////////////
// INSTRUCTION MEMORY
////////////////////////////////////////////////////////////
instr_mem IMEM (
    .clk(clk),
    .pc(inst_mem_address),
    .instr(inst_mem_read_data)
);


////////////////////////////////////////////////////////////
// DATA MEMORY
////////////////////////////////////////////////////////////
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


////////////////////////////////////////////////////////////
// MAIN MONITOR BLOCK
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    $display(
        "time=%0d | pc=%h | result=%0d | stall=%b | mul_busy=%b | div_busy=%b | dmem_rdata=%h",
        $time,
        DUT.fetch_pc,
        $signed(DUT.execute.ex_result),
        DUT.cpu_stall_out,
        DUT.execute.mul_busy,
        DUT.execute.div_busy,
        dmem_read_data
    );

    // Print M-Extension DEBUG (check EXECUTE stage)
    if (DUT.execute.mul_busy | DUT.execute.div_busy) begin
        $display("[M-EXT ACTIVE] mul_busy=%b, div_busy=%b, alu_op=%b, result=%h",
                 DUT.execute.mul_busy,
                 DUT.execute.div_busy,
                 DUT.execute.alu_op,
                 $signed(DUT.execute.ex_result));
    end

    // Print when MUL starts (0→1 transition)
    if (!mul_busy_prev && DUT.execute.mul_busy) begin
        $display("[MUL START] operand1=%h, operand2=%h",
                 DUT.execute.alu_operand1,
                 DUT.execute.alu_operand2);
    end

    // Print when MUL completes (1→0 transition)
    if (mul_busy_prev && !DUT.execute.mul_busy) begin
        $display("[MUL COMPLETE] result=%h",
                 $signed(DUT.execute.ex_result));
    end

    // Print when DIV starts (0→1 transition) ← KEY!
    if (!div_busy_prev && DUT.execute.div_busy) begin
        $display("[DIV START] dividend=%h, divisor=%h, alu_op=%b",
                 DUT.execute.alu_operand1,
                 DUT.execute.alu_operand2,
                 DUT.execute.alu_op);
    end

    // Print when DIV completes (1→0 transition) ← KEY!
    if (div_busy_prev && !DUT.execute.div_busy) begin
        $display("[DIV COMPLETE] quotient=%h, alu_op=%b",
                 $signed(DUT.execute.ex_result),
                 DUT.execute.alu_op);
    end

    // Print when LOAD completes
    if (DUT.wb_stage.wb_mem_to_reg_i) begin
        $display("[LOAD DATA] wb_read_data_o=%h, dmem_rdata=%h",
                 DUT.wb_stage.wb_read_data_o,
                 dmem_read_data);
    end

    if (DUT.fetch_pc == 32'h00000124) begin
        $display("[TEST COMPLETE] All instructions executed");
    end

    // Update state variables for next cycle
    div_busy_prev = DUT.execute.div_busy;
    mul_busy_prev = DUT.execute.mul_busy;
end


////////////////////////////////////////////////////////////
// SIMULATION TIME
////////////////////////////////////////////////////////////
initial begin
    #50000;
    $finish;
end

endmodule
