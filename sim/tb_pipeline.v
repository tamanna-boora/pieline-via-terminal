`timescale 1ns / 1ps

module tb_riscv_top;

    // =========================================================
    // DUT signals
    // =========================================================
    reg        clk;
    reg        reset_btn;
    reg        rx_pin;
    wire       tx_pin;
    wire [15:0] led;
    wire [6:0]  seg;
    wire [7:0]  an;

    // =========================================================
    // UART parameters - must match design
    // =========================================================
    localparam CLK_FREQ      = 100000000;
    localparam BAUD_RATE     = 1000000; //9600
    localparam TICKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 10416
    localparam CLK_PERIOD    = 10; // 10ns = 100MHz
     reg [31:0] test_image [0:195];
initial begin
    $readmemh("C:/projvivado/project_5/random_image.mem", test_image);
    #1; // Wait 1 timestep for memory to populate
    $display("TB DEBUG: First word of test_image is: %h", test_image[0]);
    $display("TB DEBUG: 100th word of test_image is: %h", test_image[100]);// =========================================================
    end 
    // DUT instantiation - SIM_MODE=1 for full speed clock
    // =========================================================
    riscv_top #(.SIM_MODE(1)) dut (
        .clk       (clk),
        .reset_btn (reset_btn),
        .rx_pin    (rx_pin),
        .tx_pin    (tx_pin),
        .led       (led),
        .seg       (seg),
        .an        (an)
    );

    // =========================================================
    // Clock generation - 100MHz
    // =========================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================
    // UART TX task - sends one byte over rx_pin to FPGA
    // Simulates laptop sending a pixel byte
    // =========================================================
    task uart_send_byte;
        input [7:0] data;
        integer j;
        begin
            // Start bit
            rx_pin = 0;
            #(TICKS_PER_BIT * CLK_PERIOD);

            // Data bits LSB first
            for (j = 0; j < 8; j = j + 1) begin
                rx_pin = data[j];
                #(TICKS_PER_BIT * CLK_PERIOD);
            end

            // Stop bit
            rx_pin = 1;
            #(TICKS_PER_BIT * CLK_PERIOD);
        end
    endtask

    // =========================================================
    // UART RX monitor - captures bytes sent by FPGA
    // =========================================================
    reg [7:0]  received_byte;
    reg        byte_received;
    integer    bit_count;
 

    initial begin
        byte_received = 0;
        received_byte = 0;
    end

    always @(negedge tx_pin) begin
        if (!byte_received) begin
            // Start bit detected - wait half bit to center
            #(TICKS_PER_BIT * CLK_PERIOD / 2);
            #(TICKS_PER_BIT * CLK_PERIOD); // skip start bit

            // Sample 8 data bits
            for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                received_byte[bit_count] = tx_pin;
                #(TICKS_PER_BIT * CLK_PERIOD);
            end

            byte_received = 1;
            $display("TB: FPGA sent digit = %0d", received_byte);
        end
    end

    // =========================================================
    // Main test sequence
    // =========================================================
    integer i;
    integer pixel_val;

    initial begin
        // Initialise
        reset_btn = 1;  // hold in reset
        rx_pin    = 1;  // UART idle high

        // Hold reset for 20 cycles
        repeat(20) @(posedge clk);

        // Release reset
        reset_btn = 0;
        repeat(10) @(posedge clk);

        $display("TB: Reset released - CPU running");

        // =====================================================
        // Send 784 pixel bytes to simulate one MNIST image
        // Using a simple pattern: all pixels = 128 (grey)
        // Real use: send actual MNIST image bytes
        // =====================================================
        $display("TB: Sending 784 pixel bytes...");

        for (i = 0; i < 784; i = i + 1) begin
            pixel_val = 8'd128;  // grey pixel
            uart_send_byte(pixel_val[7:0]);
        end

        $display("TB: All 784 pixels sent - waiting for inference result...");

        // =====================================================
        // Wait for FPGA to send back the predicted digit
        // Maximum wait = ~3000 CPU cycles for inference
        // At 100MHz each cycle = 10ns → 30us max
        // Add margin: wait 1ms
        // =====================================================
        byte_received = 0;
        #(5000000); // 1ms timeout

        if (byte_received)
            $display("TB: PASS - Predicted digit = %0d", received_byte);
        else
            $display("TB: FAIL - No response from FPGA within timeout");

        // =====================================================
        // Check LED outputs
        // =====================================================
        $display("TB: LED status:");
        $display("  exception  = %b", led[15]);
        $display("  is_mul     = %b", led[14]);
        $display("  is_div     = %b", led[13]);
        $display("  mac_done   = %b", led[12]);
        $display("  uart_tx    = %b", led[11]);
        $display("  rx_done    = %b", led[10]);
        $display("  PC[9:0]    = %0d", led[9:0]);
        $display("  seg        = %b", seg);

        // =====================================================
        // Send a second image to verify ping-pong banking
        // =====================================================
        $display("TB: Sending second image to test ping-pong...");
        byte_received = 0;

       

// In your sending loop:
for (i = 0; i < 196; i = i + 1) begin
    // Send the 4 bytes packed in each word (adjust order if needed)
    uart_send_byte(test_image[i][7:0]);
uart_send_byte(test_image[i][15:8]);
uart_send_byte(test_image[i][23:16]);
uart_send_byte(test_image[i][31:24]);
end
        #(5000000);

        if (byte_received)
            $display("TB: PASS - Second image digit = %0d", received_byte);
        else
            $display("TB: FAIL - No response for second image");

        $display("TB: Simulation complete");
        $finish;
    end

    // =========================================================
    // Timeout watchdog - kills sim if hung
    // =========================================================
    initial begin
        #(100000000); // 100ms absolute timeout
        $display("TB: WATCHDOG TIMEOUT - simulation killed");
        $finish;
    end

    // =========================================================
    // Waveform dump
    // =========================================================
    initial begin
        $dumpfile("tb_riscv_top.vcd");
        $dumpvars(0, tb_riscv_top);
    end

endmodule
