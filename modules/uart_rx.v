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
    
    // --- STEP 1: Anti-Metastability (The "Double Flop") ---
    // We pass the external rx_wire through two flip-flops to synchronize it.
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
            rx_done <= 1'b0; // Default: No data ready

            case (state)
                IDLE: begin
                    if (rx_sync2 == 1'b0) begin // Start bit detected
                        state <= START;
                        timer <= 0;
                    end
                end

                START: begin
                    if (timer == HALF_TICKS) begin
                        // Double-check: Is it still low? (Glitch Filter)
                        if (rx_sync2 == 1'b0) begin
                            state <= DATA;
                            timer <= 0;
                            bit_index <= 0;
                        end else begin
                            state <= IDLE; // Was just noise
                        end
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                DATA: begin
                    if (timer == TICKS_PER_BIT - 1) begin
                        timer <= 0;
                        if (bit_index == 7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end else begin
                        if (timer == HALF_TICKS)          // Sample at center
                            rx_data[bit_index] <= rx_sync2;
                        timer <= timer + 1'b1;
                    end
                end

                STOP: begin
                    if (timer == TICKS_PER_BIT - 1) begin
                        timer <= 0;
                        state <= IDLE;
                        if (rx_sync2 == 1'b1)   // Valid stop bit
                            rx_done <= 1'b1;
                        // else: could drive a `framing_error` output reg here
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule