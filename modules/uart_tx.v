module uart_tx #(
    parameter CLK_FREQ      = 100000000,
    parameter BAUD_RATE     = 9600,
    parameter TICKS_PER_BIT = CLK_FREQ / BAUD_RATE,
    parameter HALF_TICKS    = TICKS_PER_BIT / 2
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_wire,
    output reg        tx_done,
    output reg        tx_busy
);
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [13:0] timer;
    reg [2:0]  bit_index;
    reg [7:0]  tx_shift;

    // Edge detector for tx_start
    reg tx_start_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) tx_start_prev <= 0;
        else        tx_start_prev <= tx_start;
    end
    wire tx_start_edge = tx_start & ~tx_start_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            timer     <= 0;
            bit_index <= 0;
            tx_wire   <= 1'b1;
            tx_done   <= 1'b0;
            tx_busy   <= 1'b0;
            tx_shift  <= 8'b0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx_wire <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start_edge) begin
                        tx_shift <= tx_data;
                        state    <= START;
                        timer    <= 0;
                    end
                end

                START: begin
                    tx_wire <= 1'b0;
                    tx_busy <= 1'b1;
                    if (timer == TICKS_PER_BIT - 1) begin
                        timer     <= 0;
                        bit_index <= 0;
                        state     <= DATA;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                DATA: begin
                    tx_wire <= tx_shift[bit_index];
                    tx_busy <= 1'b1;
                    if (timer == TICKS_PER_BIT - 1) begin
                        timer <= 0;
                        if (bit_index == 7) begin
                            state     <= STOP;
                            bit_index <= 0;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                STOP: begin
                    tx_wire <= 1'b1;
                    tx_busy <= 1'b1;
                    if (timer == TICKS_PER_BIT - 1) begin
                        timer   <= 0;
                        state   <= IDLE;
                        tx_done <= 1'b1;
                        tx_busy <= 1'b0;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                default: begin
                    state   <= IDLE;
                    tx_wire <= 1'b1;
                    tx_busy <= 1'b0;
                end
            endcase
        end
    end
endmodule