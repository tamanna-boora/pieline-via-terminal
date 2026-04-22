`timescale 1ns / 1ps
module uart_tx #(
    parameter CLK_FREQ      = 100000000,
    parameter BAUD_RATE     = 9600,
    parameter TICKS_PER_BIT = CLK_FREQ / BAUD_RATE
)(
    input  wire       clk,
    input  wire       rst_n,

    // CPU interface (driven by memory_controller)
    input  wire [7:0] tx_data,    // byte to transmit (from 0x40000008 write)
    input  wire       tx_start,   // pulse high for 1 cycle to begin TX

    // Physical pin
    output reg        tx_wire,    // FPGA TX pin to laptop

    // Status
    output reg        tx_busy,    // 1 while transmitting — fed to memory_controller
    output reg        tx_done     // pulses high 1 cycle when byte fully sent
);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] timer;      // matches uart_rx timer width — safe up to low baud rates
    reg [2:0]  bit_index;
    reg [7:0]  shift_reg;  // holds byte being transmitted

    // Edge detection on tx_start — prevents re-triggering if CPU holds high
    reg tx_start_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) tx_start_q <= 1'b0;
        else        tx_start_q <= tx_start;
    end
    wire start_edge = tx_start & ~tx_start_q;

    // =========================================================
    // Main FSM
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            timer     <= 16'd0;
            bit_index <= 3'd0;
            shift_reg <= 8'd0;
            tx_wire   <= 1'b1;   // idle line is high (UART standard)
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
        end else begin
            tx_done <= 1'b0;     // default pulse low every cycle

            case (state)

                // -------------------------------------------------
                IDLE: begin
                    tx_wire   <= 1'b1;   // hold line high
                    tx_busy   <= 1'b0;
                    timer     <= 16'd0;
                    bit_index <= 3'd0;

                    if (start_edge) begin
                        shift_reg <= tx_data;  // latch byte on start edge
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end

                // -------------------------------------------------
                START: begin
                    tx_wire <= 1'b0;     // start bit — pull line low

                    if (timer == TICKS_PER_BIT - 1) begin
                        timer <= 16'd0;
                        state <= DATA;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                // -------------------------------------------------
                DATA: begin
                    tx_wire <= shift_reg[bit_index];   // LSB first

                    if (timer == TICKS_PER_BIT - 1) begin
                        timer <= 16'd0;
                        if (bit_index == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                // -------------------------------------------------
                STOP: begin
                    tx_wire <= 1'b1;     // stop bit — line high

                    if (timer == TICKS_PER_BIT - 1) begin
                        timer   <= 16'd0;
                        state   <= IDLE;
                        tx_done <= 1'b1;  // 1-cycle pulse — byte fully sent
                        tx_busy <= 1'b0;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                // -------------------------------------------------
                default: begin
                    state   <= IDLE;
                    tx_wire <= 1'b1;
                    timer   <= 16'd0;
                end

            endcase
        end
    end

endmodule
