`timescale 1ns / 1ps

module uart_rx #(

    parameter CLK_FREQ      = 100000000,

    parameter BAUD_RATE     = 9600,

    parameter TICKS_PER_BIT = CLK_FREQ / BAUD_RATE,

    parameter HALF_TICKS    = TICKS_PER_BIT / 2

)(

    input  wire       clk,

    input  wire       rst_n,

    input  wire       rx_wire,

    output reg  [7:0] rx_data,

    output reg        rx_done

);

    localparam IDLE  = 2'b00;

    localparam START = 2'b01;

    localparam DATA  = 2'b10;

    localparam STOP  = 2'b11;



    reg [1:0]  state;

    reg [15:0] timer;      // widened to 16 bits for lower baud rates

    reg [2:0]  bit_index;



    // Anti-metastability double flop

    reg rx_sync1, rx_sync2;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            rx_sync1 <= 1'b1; rx_sync2 <= 1'b1;

        end else begin

            rx_sync1 <= rx_wire; rx_sync2 <= rx_sync1;

        end

    end



    // Main FSM

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state     <= IDLE;

            timer     <= 0;

            bit_index <= 0;

            rx_done   <= 0;

            rx_data   <= 0;

        end else begin

            rx_done <= 1'b0;

            case (state)

                IDLE: begin

                    timer     <= 0;

                    bit_index <= 0;

                    if (rx_sync2 == 1'b0) state <= START;

                end



                START: begin

                    // FIX: sample at HALF_TICKS-1 so DATA bit 0

                    // is sampled at exactly HALF_TICKS after transition

                    if (timer == HALF_TICKS - 1) begin

                        if (rx_sync2 != 1'b0) begin

                            state <= IDLE;

                            timer <= 0;     // explicit cleanup

                        end else begin

                            state <= DATA;

                            timer <= 0;

                        end

                    end else begin

                        timer <= timer + 1'b1;

                    end

                end



                DATA: begin

                    if (timer == TICKS_PER_BIT - 1) begin

                        timer <= 0;

                        if (bit_index == 7) state <= STOP;

                        else bit_index <= bit_index + 1'b1;

                    end else begin

                        if (timer == HALF_TICKS)        // dead center of bit

                            rx_data[bit_index] <= rx_sync2;

                        timer <= timer + 1'b1;

                    end

                end



                STOP: begin

                    if (timer == TICKS_PER_BIT - 1) begin

                        timer <= 0;

                        state <= IDLE;

                        if (rx_sync2 == 1'b1) rx_done <= 1'b1;

                    end else begin

                        timer <= timer + 1'b1;

                    end

                end



                default: begin

                    state <= IDLE;

                    timer <= 0;

                end

            endcase

        end

    end

endmodule
