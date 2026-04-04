module data_ram (
    input wire clk,
    input wire we,          // Write Enable
    input wire [9:0] addr,  // 10-bit address (1024 depth)
    input wire [31:0] din,  // 32-bit Data Input
    output reg [31:0] dout  // 32-bit Data Output
);

    // Memory array: 1024 entries, each 32-bit wide
    reg [31:0] ram [0:1023];

    // Synchronous Write and Read
    // This matches the "Safe & Best" 1-cycle latency we discussed
    always @(posedge clk) begin
        if (we) begin
            ram[addr] <= din;
        end
        dout <= ram[addr]; // Registered output for timing stability
    end

    // Optional: Initialize with zeros so the CPU doesn't read "junk"
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            ram[i] = 32'h0;
        end
    end

endmodule