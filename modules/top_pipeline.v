`timescale 1ns / 1ps

module riscv_top #(
    parameter SIM_MODE = 1
)(
    input  wire        clk,
    input  wire        reset_btn,
    input  wire        rx_pin,
    output wire        tx_pin,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire [7:0]  an
);

    // =========================================================
    // 1. CLOCK DIVIDER
    // SIM_MODE=1 → full speed clock
    // SIM_MODE=0 → slow clock for FPGA LED visibility
    // =========================================================
    reg [26:0] clk_counter = 0;
    reg        slow_clk_reg = 0;

    always @(posedge clk) begin
        clk_counter  <= clk_counter + 1;
        slow_clk_reg <= clk_counter[24];
    end

    wire cpu_clk = (SIM_MODE == 1) ? clk : slow_clk_reg;

    // =========================================================
    // 2. RESET SYNCHRONIZER
    // Button active high → invert for active low reset
    // =========================================================
    reg [1:0] reset_sync;
    always @(posedge cpu_clk) begin
        reset_sync <= {reset_sync[0], ~reset_btn};
    end
    wire reset_n = reset_sync[1];

    // =========================================================
    // 3. INTERCONNECT WIRES
    // =========================================================
    wire [31:0] imem_addr;
    wire [31:0] imem_data;

    wire [31:0] dmem_read_address;
    wire [31:0] dmem_write_address;
    wire        dmem_read_ready;
    wire        dmem_write_ready;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire [31:0] cpu_rdata;

    wire [31:0] cpu_addr  = dmem_write_ready ? dmem_write_address
                                              : dmem_read_address;
    wire        cpu_we    = dmem_write_ready;
    wire [31:0] cpu_wdata = dmem_write_data;
    wire [3:0]  cpu_wstrb = dmem_write_byte;

    wire [7:0]  uart_rx_data;
    wire        rx_done;
    wire [7:0]  uart_tx_data;
    wire        uart_tx_start;
    wire        uart_tx_busy;

    wire        mac_done_sig;
    wire [3:0]  seven_seg_val;
    wire        exception;
    wire [31:0] pc_out;
    wire        is_mul;
    wire        is_div;
    wire [31:0] result_o;

    wire        ram_we_a;
    wire [31:0] ram_addr_a;
    wire [31:0] ram_wdata_a;
    wire [3:0]  ram_wstrb_a;
    wire [31:0] ram_data_a_out;

    wire        ram_we_b;
    wire [31:0] ram_addr_b;
    wire [31:0] ram_wdata_b;
    wire [3:0]  ram_wstrb_b;
    wire [31:0] ram_data_b_out;

    // =========================================================
    // 4. PIPE
    // =========================================================
    pipe #(.RESET(32'h0000_0000)) pipe_inst (
        .clk                (cpu_clk),
        .reset              (reset_n),
        .stall              (1'b0),
        .exception          (exception),
        .pc_out             (pc_out),
        .inst_mem_is_valid  (1'b1),
        .inst_mem_read_data (imem_data),
        .inst_mem_address   (imem_addr),
        .dmem_read_data_temp(cpu_rdata),
        .dmem_write_valid   (1'b1),
        .dmem_read_valid    (1'b1),
        .dmem_read_ready    (dmem_read_ready),
        .dmem_read_address  (dmem_read_address),
        .dmem_write_ready   (dmem_write_ready),
        .dmem_write_address (dmem_write_address),
        .dmem_write_data    (dmem_write_data),
        .dmem_write_byte    (dmem_write_byte),
        .is_mul             (is_mul),
        .is_div             (is_div),
        .mul_busy_o         (),
        .div_busy_o         (),
        .result_o           (result_o),
        .mac_done_o         (mac_done_sig)
    );

    // =========================================================
    // 5. INSTRUCTION MEMORY
    // =========================================================
    instr_mem imem_inst (
        .clk   (cpu_clk),
        .pc    (imem_addr[11:2]),
        .instr (imem_data)
    );

    // =========================================================
    // 6. BRAM BANKS
    // =========================================================
    bram_bank bank_a (
        .clk   (cpu_clk),
        .we    (ram_we_a),
        .addr  (ram_addr_a[11:2]),
        .wdata (ram_wdata_a),
        .wstrb (ram_wstrb_a),
        .rdata (ram_data_a_out)
    );

    bram_bank bank_b (
        .clk   (cpu_clk),
        .we    (ram_we_b),
        .addr  (ram_addr_b[11:2]),
        .wdata (ram_wdata_b),
        .wstrb (ram_wstrb_b),
        .rdata (ram_data_b_out)
    );
    wire bank_sel_w;
wire uart_data_ready_w;


    // =========================================================
    // 7. MEMORY CONTROLLER
    // =========================================================
    memory_controller mc_inst (
        .clk               (cpu_clk),
        .rst_n             (reset_n),
        .uart_rx_data      (uart_rx_data),
        .rx_done           (rx_done),
        .uart_tx_busy      (uart_tx_busy),
        .uart_tx_data_out  (uart_tx_data),
        .uart_tx_start_out (uart_tx_start),
        .cpu_addr          (cpu_addr),
        .cpu_wdata         (cpu_wdata),
        .cpu_we            (cpu_we),
        .cpu_wstrb         (cpu_wstrb),
        .cpu_rdata         (cpu_rdata),
        .ram_we_a          (ram_we_a),
        .ram_addr_a        (ram_addr_a),
        .ram_wdata_a       (ram_wdata_a),
        .ram_wstrb_a       (ram_wstrb_a),
        .ram_data_a_out    (ram_data_a_out),
        .ram_we_b          (ram_we_b),
        .ram_addr_b        (ram_addr_b),
        .ram_wdata_b       (ram_wdata_b),
        .ram_wstrb_b       (ram_wstrb_b),
        .ram_data_b_out    (ram_data_b_out),
     .bank_sel          (bank_sel_w),
.uart_data_ready   (uart_data_ready_w),
        .seven_seg_val     (seven_seg_val),
        .mac_done_in       (mac_done_sig)
    );

    // =========================================================
    // 8. UART RX
    // =========================================================
    uart_rx #(
        .CLK_FREQ (100000000),
        .BAUD_RATE( 1000000)//9600)
    ) rx_inst (
        .clk     (cpu_clk),
        .rst_n   (reset_n),
        .rx_wire (rx_pin),
        .rx_data (uart_rx_data),
        .rx_done (rx_done)
    );

    // =========================================================
    // 9. UART TX
    // =========================================================
    uart_tx #(
        .CLK_FREQ (100000000),
        .BAUD_RATE( 1000000)//9600)
    ) tx_inst (
        .clk     (cpu_clk),
        .rst_n   (reset_n),
        .tx_data (uart_tx_data),
        .tx_start(uart_tx_start),
        .tx_wire (tx_pin),
        .tx_busy (uart_tx_busy),
        .tx_done ()
    );

    // =========================================================
    // 10. SEVEN SEGMENT
    // =========================================================
    reg [6:0] seg_reg;
    always @(*) begin
        case (seven_seg_val)
            4'd0: seg_reg = 7'b1000000;
            4'd1: seg_reg = 7'b1111001;
            4'd2: seg_reg = 7'b0100100;
            4'd3: seg_reg = 7'b0110000;
            4'd4: seg_reg = 7'b0011001;
            4'd5: seg_reg = 7'b0010010;
            4'd6: seg_reg = 7'b0000010;
            4'd7: seg_reg = 7'b1111000;
            4'd8: seg_reg = 7'b0000000;
            4'd9: seg_reg = 7'b0010000;
            default: seg_reg = 7'b1111111;
        endcase
    end
reg [24:0] led_timer;
reg rx_done_visible, mac_done_visible;

always @(posedge clk) begin
    if (!reset_n) begin
        led_timer <= 0;
        rx_done_visible <= 0;
        mac_done_visible <= 0;
    end else begin
        // If the hardware signal fires, "catch" it
        if (rx_done)      rx_done_visible <= 1'b1;
        if (mac_done_sig) mac_done_visible <= 1'b1;

        // Count to 0.25 seconds then reset the "catch" registers
        if (led_timer == 25_000_000) begin
            led_timer <= 0;
            rx_done_visible <= 0;
            mac_done_visible <= 0;
        end else begin
            led_timer <= led_timer + 1;
        end
    end
end
    assign seg = seg_reg;
    assign an  = 8'b11111110;

    // =========================================================
    // 11. LEDs
    // =========================================================
    assign led[15]  = exception;
    assign led[14]  = is_mul;
    assign led[13]  = is_div;
   assign led[12] = mac_done_visible; // Now stays on for 0.25s
    assign led[11]  = uart_tx_busy;
    assign led[10] = rx_done_visible;  // Now stays on for 0.25s
    assign led[9:0] = pc_out[11:2];

endmodule
// ================================================================
// BRAM BANK
// Instantiated twice for ping-pong banks A and B
// 512 words x 4 bytes = 2KB per bank
// Byte write strobe supported
// Synchronous read - 1 cycle latency
// ================================================================
module bram_bank (
    input  wire        clk,
    input  wire        we,
    input  wire [9:0]  addr,   
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output wire [31:0] rdata  
);
    
    reg [31:0] ram [0:1023]; 

    initial begin
        $readmemh("C:/projvivado/project_5/dmem.hex", ram);
    end

    always @(posedge clk) begin
        if (we) begin
            if (wstrb[0]) ram[addr][7:0]   <= wdata[7:0];
            if (wstrb[1]) ram[addr][15:8]  <= wdata[15:8];
            if (wstrb[2]) ram[addr][23:16] <= wdata[23:16];
            if (wstrb[3]) ram[addr][31:24] <= wdata[31:24];
        end
    end

    // CHANGED: Instant combinational read bypasses the clock cycle delay!
    assign rdata = ram[addr];

endmodule
