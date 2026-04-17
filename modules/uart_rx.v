module uart_rx #(
    parameter CLK_FREQ      = 100000000, // 100 MHz
    parameter BAUD_RATE     = 9600,
    parameter TICKS_PER_BIT = CLK_FREQ / BAUD_RATE,    // 10417
    parameter HALF_TICKS    = TICKS_PER_BIT / 2        // 5208
)(
    input wire clk,           // FPGA Internal Clock
    input wire rst_n,         // Active Low Reset
    input wire rx_wire,       // Physical RX pin from laptop
    output reg [7:0] rx_data, // The finished 8-bit Pixel Byte
    output reg rx_done        // Pulse high for 1 cycle when byte is ready
);

    // FSM States
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [13:0] timer;     
    reg [2:0]  bit_index; 
    
    // --- STEP 1: Anti-Metastability (Double Flop) ---
    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_wire;
            rx_sync2 <= rx_sync1;
        end
    end

    // --- STEP 2: Main UART Receiver FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            timer     <= 0;
            bit_index <= 0;
            rx_done   <= 0;
            rx_data   <= 0;
        end else begin
            rx_done <= 1'b0; // Default pulse low

            case (state)
                IDLE: begin
                    timer <= 0;
                    bit_index <= 0;
                    if (rx_sync2 == 1'b0) begin // Start bit detected
                        state <= START;
                    end
                end

                START: begin
                    if (timer == TICKS_PER_BIT - 1) begin
                        // We have finished the FULL start bit.
                        // Now the timer is perfectly aligned with bit boundaries.
                        state <= DATA;
                        timer <= 0;
                    end else begin
                        // Glitch Filter: Check at center if it's still low
                        if (timer == HALF_TICKS && rx_sync2 != 1'b0) begin
                            state <= IDLE;
                        end
                        timer <= timer + 1'b1;
                    end
                end

                DATA: begin
                    if (timer == TICKS_PER_BIT - 1) begin
                        timer <= 0;
                        if (bit_index == 7) begin
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        // THE GOLDEN RULE: Sample at exactly 50% of the bit duration
                        if (timer == HALF_TICKS) begin
                            rx_data[bit_index] <= rx_sync2;
                        end
                        timer <= timer + 1'b1;
                    end
                end

                STOP: begin
                    if (timer == TICKS_PER_BIT - 1) begin
                        timer <= 0;
                        state <= IDLE;
                        // Only signal done if the STOP bit is high (Valid Frame)
                        if (rx_sync2 == 1'b1) begin
                            rx_done <= 1'b1;
                        end
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
