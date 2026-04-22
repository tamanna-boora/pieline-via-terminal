`timescale 1ns / 1ps
module wb 
#(
    parameter [31:0] RESET = 32'h0000_0000
)
(
    input clk,
    input reset,

    input        stall_read_i,
    input [31:0] fetch_pc_i,

    input        wb_branch_i,
    input        wb_mem_to_reg_i,
    input        mem_write_i,

    input [31:0] write_address_i,
    input [31:0] alu_operand2_i,
    input [2:0]  alu_operation_i,

    input [2:0]  wb_alu_operation_i,
    input [1:0]  wb_read_address_i,

    input [31:0] dmem_read_data_i,
    input        dmem_write_valid_i,

    // Outputs
    output [31:0] inst_mem_address_o,
    output inst_mem_is_ready_o,
    output wb_stall_o,
    output reg [31:0] wb_write_address_o,
    output reg [31:0] wb_write_data_o,
    output reg [3:0]  wb_write_byte_o,
    output reg [31:0] wb_read_data_o,
    output reg [31:0] inst_fetch_pc_o,
    output reg wb_stall_first_o,
    output reg wb_stall_second_o
);

// import "opcode.vh" for OPCODES
`include "opcode.vh"


////////////////////////////////////////////////////////////
// assigning these variables to read from the instruction memory
////////////////////////////////////////////////////////////

assign inst_mem_address_o  = fetch_pc_i;
assign inst_mem_is_ready_o = 1'b1; // Always ready for instruction fetch

////////////////////////////////////////////////////////////
// wb_stall flag for defining the first and second stall in branch instruction
////////////////////////////////////////////////////////////

assign wb_stall_o = wb_stall_first_o || wb_stall_second_o;

////////////////////////////////////////////////////////////
// instruction fetch pc update
////////////////////////////////////////////////////////////

always @(posedge clk or negedge reset) begin
    if (!reset)
        inst_fetch_pc_o <= RESET;
    else if (!stall_read_i)
        inst_fetch_pc_o <= fetch_pc_i;
end

////////////////////////////////////////////////////////////
// Branch stall variable declarations
////////////////////////////////////////////////////////////

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        wb_stall_first_o  <= 1'b0;
        wb_stall_second_o <= 1'b0;
    end
    else if (!stall_read_i &&
            !((wb_mem_to_reg_i && !dmem_write_valid_i))) begin
        wb_stall_first_o  <= wb_branch_i;
        wb_stall_second_o <= wb_stall_first_o;
    end
end

////////////////////////////////////////////////////////////
// Preparing write data for store type instructions
////////////////////////////////////////////////////////////

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        wb_write_address_o <= 32'h0;
        wb_write_byte_o    <= 4'h0;
        wb_write_data_o    <= 32'h0;
    end
    else if (!stall_read_i && mem_write_i) begin
        wb_write_address_o <= write_address_i;
        case (alu_operation_i)
            `SB: begin
                wb_write_data_o <= {4{alu_operand2_i[7:0]}};
                case (write_address_i[1:0])
                    2'b00:  wb_write_byte_o <= 4'b0001;
                    2'b01:  wb_write_byte_o <= 4'b0010;
                    2'b10:  wb_write_byte_o <= 4'b0100;
                    default:wb_write_byte_o <= 4'b1000;
                endcase
            end
            `SH: begin
                wb_write_data_o <= {2{alu_operand2_i[15:0]}};
                wb_write_byte_o <= write_address_i[1] ? 4'b1100 : 4'b0011;
            end
            `SW: begin
                wb_write_data_o <= alu_operand2_i;
                wb_write_byte_o <= 4'b1111;
            end
            default: begin
                wb_write_data_o <= 32'hx;
                wb_write_byte_o <= 4'hx;
            end
        endcase
    end
end

////////////////////////////////////////////////////////////
// Load instruction data formatting (COMBINATIONAL)
// This selects the correct bytes/words from memory data
////////////////////////////////////////////////////////////

wire [31:0] wb_read_data_next;

assign wb_read_data_next = 
    (wb_alu_operation_i == `LB) ? (
        wb_read_address_i == 2'b00 ? {{24{dmem_read_data_i[7]}},  dmem_read_data_i[7:0]} :
        wb_read_address_i == 2'b01 ? {{24{dmem_read_data_i[15]}}, dmem_read_data_i[15:8]} :
        wb_read_address_i == 2'b10 ? {{24{dmem_read_data_i[23]}}, dmem_read_data_i[23:16]} :
        {{24{dmem_read_data_i[31]}}, dmem_read_data_i[31:24]}
    ) : (wb_alu_operation_i == `LH) ? (
        wb_read_address_i[1] ? {{16{dmem_read_data_i[31]}}, dmem_read_data_i[31:16]} :
        {{16{dmem_read_data_i[15]}}, dmem_read_data_i[15:0]}
    ) : (wb_alu_operation_i == `LW) ? (
        dmem_read_data_i
    ) : (wb_alu_operation_i == `LBU) ? (
        wb_read_address_i == 2'b00 ? {24'h0, dmem_read_data_i[7:0]} :
        wb_read_address_i == 2'b01 ? {24'h0, dmem_read_data_i[15:8]} :
        wb_read_address_i == 2'b10 ? {24'h0, dmem_read_data_i[23:16]} :
        {24'h0, dmem_read_data_i[31:24]}
    ) : (wb_alu_operation_i == `LHU) ? (
        wb_read_address_i[1] ? {16'h0, dmem_read_data_i[31:16]} :
        {16'h0, dmem_read_data_i[15:0]}
    ) : 32'h0;

////////////////////////////////////////////////////////////
// Register the load data on clock edge
// This ensures data is stable when used by register file
////////////////////////////////////////////////////////////

always @(posedge clk or negedge reset) begin
    if (!reset)
        wb_read_data_o <= 32'h0;
    else if (!stall_read_i)
        wb_read_data_o <= wb_read_data_next;
end

endmodule
