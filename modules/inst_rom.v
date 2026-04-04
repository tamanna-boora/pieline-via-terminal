module inst_rom (
    input wire        clk,
    input wire [9:0]  addr,     // 10-bit address for 1024 instructions
    output reg [31:0] dout      // 32-bit Instruction (Opcode)
);

    // 4KB ROM (1024 words x 32 bits)
    reg [31:0] rom [0:1023];

    // --- The "Magic" Step for ROM ---
    // This loads Tamanna's compiled RISC-V code into the FPGA memory 
    // at the moment the board powers up.
    initial begin
        $readmemh("mnist_inference.mem", rom);
    end

    // Synchronous Read (1-cycle latency to match your RAM)
    always @(posedge clk) begin
        dout <= rom[addr];
    end

endmodule