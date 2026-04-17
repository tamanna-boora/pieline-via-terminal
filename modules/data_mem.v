`timescale 1ns / 1ps

module data_mem (
    input  wire        clk,
    input  wire        re,
    input  wire [31:0] raddr,
    output reg  [31:0] rdata,
    input  wire        we,
    input  wire [31:0] waddr,
    input  wire [31:0] wdata,
    input  wire [ 3:0] wstrb
);
    // 4KB Data Memory
    reg [31:0] ram [0:1023]; 

    // Read Logic
    always @(posedge clk) begin
        if (re) rdata <= ram[raddr[11:2]];
    end

    // Write Logic with Byte Strobes
    always @(posedge clk) begin
        if (we) begin
            if (wstrb[0]) ram[waddr[11:2]][7:0]   <= wdata[7:0];
            if (wstrb[1]) ram[waddr[11:2]][15:8]  <= wdata[15:8];
            if (wstrb[2]) ram[waddr[11:2]][23:16] <= wdata[23:16];
            if (wstrb[3]) ram[waddr[11:2]][31:24] <= wdata[31:24];
        end
    end
endmodule
