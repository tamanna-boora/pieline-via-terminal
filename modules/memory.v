`timescale 1ns / 1ps
module instr_mem (
	input  wire    	clk,
	input  wire [31:0] pc, 	// byte address
	output reg  [31:0] instr
);

	// 1024 words = 4 KB
	// Declare instruction memory array (word-addressable, 4 KB total)
	(* ram_style = "block" *)
	reg [31:0] imem [0:1023];
    initial begin
		$readmemh("imem.hex", imem);
	end
	// FPGA ROM initialization
	// Initialize instruction memory from hex file (simulation / FPGA)
/*	 integer i;  // ← DECLARE AT TOP OF INITIAL BLOCK
     initial begin
       
        // LOAD instructions
        imem[0]  = 32'h00002083;  // lw x1, 0(x0)
        imem[1]  = 32'h00402103;  // lw x2, 4(x0)
        imem[2]  = 32'h00802183;  // lw x3, 8(x0)
        imem[3]  = 32'h00c02203;  // lw x4, 12(x0)
        
        // MUL operations
        imem[4]  = 32'h02208233;  // mul x4, x4, x2
        imem[5]  = 32'h02210233;  // mulh x4, x4, x2
        imem[6]  = 32'h02211233;  // mulhsu x4, x4, x2
        imem[7]  = 32'h02212233;  // mulhu x4, x4, x2
        
        // DIV operations ← THIS WILL NOW WORK!
        imem[8]  = 32'h0230c633;  // div x12, x6, x2
imem[9]  = 32'h02314633;  // divu x12, x6, x2
imem[10] = 32'h02318633;  // rem x12, x6, x2
imem[11] = 32'h0231c633;  // remu x12, x6, x2

imem[12] = 32'h0231c733;  // div x14, x6, x3
imem[13] = 32'h02320733;  // divu x14, x6, x3
imem[14] = 32'h02324733;  // rem x14, x6, x3
imem[15] = 32'h02328733;  // remu x14, x6, x3
        
        // More MUL
        imem[16] = 32'h02208633;  // mul x12, x4, x2
        imem[17] = 32'h02210633;  // mulh x12, x4, x2
        imem[18] = 32'h02211633;  // mulhsu x12, x4, x2
        imem[19] = 32'h02212633;  // mulhu x12, x4, x2
        
        // ADD IMMEDIATE
        imem[20] = 32'h10000293;  // addi x5, x0, 256
        imem[21] = 32'h10400313;  // addi x6, x0, 260
        imem[22] = 32'h10800393;  // addi x7, x0, 264
        
        // PAD with NOPs
        for (i = 23; i < 256; i = i + 1) begin  // ← FIXED: i = i + 1
            imem[i] = 32'h00000013;  // nop
        end
        
    end  // ← ADDED MISSING END*/

	// Synchronous instruction fetch
	// Use word-aligned PC (pc[11:2]) to index memory
	always @(posedge clk) begin
    	instr <= imem[pc[11:2]];	// word address
	end

endmodule



//====================================
// Data Memory (DMEM) - FPGA-safe
//====================================
module data_mem (
	input     	clk,

	// Read port
	input     	re,
	input  [31:0] raddr,   // byte address
	output reg [31:0] rdata,

	// Write port
	input     	we,
	input  [31:0] waddr,   // byte address
	input  [31:0] wdata,
	input  [3:0]  wstrb
);

	// Declare data memory array (word-addressable, 4 KB total)
	// TODO-DMEM-1: Declare dmem
	(* ram_style = "block" *)
	reg [31:0] dmem [0:1023]; //todo1

	// Decode byte address to word index
	wire [9:0] rindex = raddr[11:2];
	wire [9:0] windex = waddr[11:2];

	// Simulation / FPGA init
	// TODO-DMEM-2: Initialize data memory from dmem.hex file
    initial begin
    	$readmemh("dmem.hex", dmem); //todo2
	end
	// -------------------------
	// WRITE + READ (SYNC)
	// -------------------------

	// Synchronous write and read logic
	// - Support byte-wise writes using wstrb
	// - Provide 1-cycle read latency
	// - Handle same-cycle read-after-write using byte-level forwarding

	always @(posedge clk) begin
    	// ---- WRITE ----
    	if (we) begin
        	if (wstrb[0]) dmem[windex][7:0]   <= wdata[7:0];
        	if (wstrb[1]) dmem[windex][15:8]  <= wdata[15:8];
        	if (wstrb[2]) dmem[windex][23:16] <= wdata[23:16];// TODO-DMEM-3
        	if (wstrb[3]) dmem[windex][31:24] <= wdata[31:24]; // TODO-DMEM-3
    	end

    	// ---- READ (1-cycle latency, RAW-safe) ----
    	if (re) begin
        	if (we && (rindex == windex)) begin
            	// Byte-level forwarding
            	rdata[7:0]   <= wstrb[0] ? wdata[7:0]   : dmem[rindex][7:0];
            	rdata[15:8]  <= wstrb[1] ? wdata[15:8]   : dmem[rindex][15:8];// TODO-DMEM-3
            	rdata[23:16] <= wstrb[2] ? wdata[23:16]   : dmem[rindex][23:16];// TODO-DMEM-3
            	rdata[31:24] <= wstrb[3] ? wdata[31:24]   : dmem[rindex][31:24];// TODO-DMEM-3
        	end
        	else begin
            	rdata <= dmem[rindex];
        	end
    	end
    	// else: rdata holds value (exact match to original)
	end

endmodule
