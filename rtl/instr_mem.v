(* rom_style = "block" *)
module instr_mem (
    input wire clk,
    input wire [9:0] pc, // Use a smaller index for the 1024-entry ROM
    output reg [31:0] instr
);
    reg [31:0] rom [0:1023];

    initial begin
        // IMPORTANT: Ensure "imem.hex" is added to your Vivado project sources
        $readmemh("imem.hex", rom);
    end

    always @(posedge clk) begin
        instr <= rom[pc];
    end
endmodule
