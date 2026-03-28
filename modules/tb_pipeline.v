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
wire    	inst_mem_is_valid;

wire [31:0] dmem_read_data;
wire    	dmem_write_valid;
wire    	dmem_read_valid;

assign inst_mem_is_valid = 1'b1;
assign dmem_write_valid  = 1'b1;
assign dmem_read_valid   = 1'b1;

wire exception;
// bug 1- more ports are there -- added here
    wire [31:0] inst_mem_address; //added
    wire        dmem_read_ready;
    wire [31:0] dmem_read_address;
    wire        dmem_write_ready;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire [31:0] pc_out; //there was no wire for output pc_out
    

////////////////////////////////////////////////////////////
// DUT : PIPELINE CPU
////////////////////////////////////////////////////////////
pipe DUT (
	.clk(clk),
	.reset(reset),
	.stall(1'b0),
	.exception(exception),
	.pc_out(pc_out), //bug added

	.inst_mem_is_valid(inst_mem_is_valid),
	.inst_mem_read_data(inst_mem_read_data),
    .inst_mem_address(inst_mem_address), // Added port
	.dmem_read_data_temp(dmem_read_data),
	.dmem_write_valid(dmem_write_valid),
	.dmem_read_valid(dmem_read_valid),
	// TODO: Might have a few more port signals
	.dmem_read_ready(dmem_read_ready),       // Added port
    .dmem_read_address(dmem_read_address),   // Added port
    .dmem_write_ready(dmem_write_ready),     // Added port
    .dmem_write_address(dmem_write_address), // Added port
    .dmem_write_data(dmem_write_data),       // Added port
    .dmem_write_byte(dmem_write_byte)        // Added port

   );


////////////////////////////////////////////////////////////
// INSTRUCTION MEMORY  (matches instr_mem.v)
////////////////////////////////////////////////////////////
instr_mem IMEM (
	.clk(clk),
	.pc(inst_mem_address), //todo
	.instr(inst_mem_read_data)
);


////////////////////////////////////////////////////////////
// DATA MEMORY  (matches data_mem.v)
////////////////////////////////////////////////////////////
data_mem DMEM (
	.clk(clk),

	.re(dmem_read_ready), //todo
	.raddr(dmem_read_address), //todo
	.rdata(dmem_read_data),

	.we(dmem_write_ready), //todo
	.waddr(dmem_write_address), //todo
	.wdata(dmem_write_data), //todo
	.wstrb(dmem_write_byte) //todo
);
////////////////////////////////////////////////////////////
// MONITOR BLOCK: This prints to the Tcl Console
////////////////////////////////////////////////////////////
always @(posedge clk) begin
	$display("time: %0d",$time);
    $display("pc= %h	next_pc = %h	result = %d", DUT.pc,DUT.next_pc, $signed(DUT.execute.ex_result));
	if (DUT.pc == 32'h00000124) 
        $display("All instructions are Executed");
end
////////////////////////////////////////////////////////////
// SIMULATION TIME
////////////////////////////////////////////////////////////
initial begin
	#20000;   // run long enough to see program execute
	$finish;
end

endmodule
