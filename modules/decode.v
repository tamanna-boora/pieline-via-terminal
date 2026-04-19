`timescale 1ns / 1ps
`include "opcode.vh"

module decode (
    input  wire [31:0] instr,
    
    // Outputs to the MAC unit
    output reg         mac_enable,
    output reg         mac_reset,
    output reg         classify
);

    wire [6:0] opcode = instr[6:0];
    wire [6:0] funct7 = instr[31:25];

    always @(*) begin
        // Default control signal states (prevents latches)
        mac_enable = 1'b0;
        mac_reset  = 1'b0;
        classify   = 1'b0;

        // Custom Instruction Intercept
        if (opcode == `OPCODE_CUSTOM) begin
            case(funct7)
                `MAC_EN:  mac_enable = 1'b1;
                `MAC_RST: mac_reset  = 1'b1;
                `MAC_CLS: classify   = 1'b1;
                default: ; // Unassigned funct3 codes do nothing
            endcase
        end
    end
endmodule
