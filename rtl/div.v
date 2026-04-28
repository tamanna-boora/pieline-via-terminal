`timescale 1ns / 1ps

module optimal_div_32 (
    input clk,
    input rst,
    input start,                // Trigger from Execute stage
    input [2:0] funct3,         // DIV, DIVU, REM, REMU
    input [31:0] dividend_i,    // rs1
    input [31:0] divisor_i,     // rs2
    output reg [31:0] quotient_o,
    output reg [31:0] remainder_o,
    output reg busy_o             
);

    // --- State Definitions for FSM ---
    localparam IDLE = 2'b00, CALC = 2'b01, DONE = 2'b10;
    reg [1:0] state;

    reg [5:0]  count;
    reg [31:0] Q, M, A;
    reg        sign_q, sign_r;

    wire is_signed = ~funct3[0];

    always @(posedge clk) begin
        if (!rst) begin
            state <= IDLE;
            busy_o <= 0;
            {quotient_o, remainder_o} <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Handle Divide-by-Zero Exception immediately
                        if (divisor_i == 32'b0) begin
                            quotient_o  <= 32'hFFFF_FFFF;
                            remainder_o <= dividend_i;
                            state <= IDLE; // No stall needed for error
                        end else begin
                            busy_o <= 1;
                            count  <= 6'd32;
                            state  <= CALC;
                            
                            // Pre-processing signs
                            sign_q <= is_signed ? (dividend_i[31] ^ divisor_i[31]) : 0;
                            sign_r <= is_signed ? dividend_i[31] : 0;
                            
                            Q <= (is_signed && dividend_i[31]) ? -dividend_i : dividend_i;
                            M <= (is_signed && divisor_i[31])  ? -divisor_i  : divisor_i;
                            A <= 32'b0;
                        end
                    end
                end

                CALC: begin
                    if (count > 0) begin
                        // The Shift-Subtract Step
                        if ({A[30:0], Q[31]} >= M) begin
                            A <= {A[30:0], Q[31]} - M;
                            Q <= {Q[30:0], 1'b1};
                        end else begin
                            A <= {A[30:0], Q[31]};
                            Q <= {Q[30:0], 1'b0};
                        end
                        count <= count - 1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Post-processing signs and output
                    quotient_o  <= sign_q ? -Q : Q;
                    remainder_o <= sign_r ? -A : A;
                    busy_o      <= 0;
                    state       <= IDLE;
                end
            endcase
        end
    end
endmodule