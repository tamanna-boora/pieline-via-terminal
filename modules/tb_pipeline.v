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

// reset (active low in our CPU)
initial begin
    reset = 0;
    #100;
    reset = 1;
end

initial begin
    $dumpfile("pipeline.vcd");
    $dumpvars(0,tb_pipeline);
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
// INSTRUCTION MEMORY  (matches instr_mem.v)
////////////////////////////////////////////////////////////
instr_mem IMEM (
    .clk(clk),
    .pc(inst_mem_address), 
    .instr(inst_mem_read_data)
);


////////////////////////////////////////////////////////////
// DATA MEMORY  (matches data_mem.v)
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
// MONITOR BLOCK: Tracking Standard + Custom Edge AI Logic
////////////////////////////////////////////////////////////
always @(posedge clk) begin

    
    $display("time: %0d | pc = %h | next_pc = %h | alu_res = %d | mac_en = %b | mac_acc = %d", 
             $time, 
             DUT.pc, 
             DUT.next_pc,
             $signed(DUT.execute.ex_result),     // Standard pipeline result
             DUT.decode_inst.mac_en,             // Custom accelerator wake-up flag
             $signed(DUT.mac_inst.accumulator)   // Pipelined MAC 32-bit result
    );

    // You MUST update 32'h00000124 to the actual final PC value 
    
    if (DUT.pc == 32'h00000124) begin 
        $display("==================================================");
        $display("SUCCESS: MNIST Inference Execution Complete!");
        $display("==================================================");
        $finish; 
    end
end


////////////////////////////////////////////////////////////
// SIMULATION TIME
////////////////////////////////////////////////////////////
initial begin
    // Timeout increased to 200,000 ns to give the MNIST neural network 
    // enough clock cycles to finish computing the dot products.
    #200000;   
    $display("ERROR: Simulation timed out. Neural network did not reach final PC.");
    $finish;
end

endmodule
