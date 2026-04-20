`timescale 1ns / 1ps

module top (
    input  wire clk,        // 100MHz Basys3 oscillator
    input  wire btnc,       // Center button — active high, used as reset
    input  wire rx_pin,     // UART RX from laptop
    output wire tx_pin,     // UART TX to laptop
    output wire [6:0] seg,  // Seven segment segments
    output wire [3:0] an,   // Seven segment anodes
    output wire [15:0] led  // Diagnostic LEDs
);

    // ================================================================
    // 1. CLOCK AND RESET
    // ================================================================
    wire cpu_clk = clk;
    wire reset_n = ~btnc;

    // ================================================================
    // 2. INSTRUCTION MEMORY SIGNALS
    // ================================================================
    wire [31:0] imem_addr;
    wire [31:0] imem_data;

    // ================================================================
    // 3. PIPE DATA MEMORY INTERFACE
    // pipe.v has separate read/write address outputs
    // ================================================================
    wire [31:0] dmem_read_address;
    wire [31:0] dmem_write_address;
    wire        dmem_read_ready;
    wire        dmem_write_ready;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;

    // ================================================================
    // 4. CPU BUS — single address bus to memory_controller
    // Write address presented when writing, read address otherwise
    // memory_controller uses cpu_we to gate writes
    // ================================================================
    wire [31:0] cpu_addr  = dmem_write_ready ? dmem_write_address
                                              : dmem_read_address;
    wire        cpu_we    = dmem_write_ready;
    wire [31:0] cpu_wdata = dmem_write_data;
    wire [3:0]  cpu_wstrb = dmem_write_byte;
    wire [31:0] cpu_rdata;

    // ================================================================
    // 5. UART SIGNALS
    // ================================================================
    wire [7:0] uart_rx_data;
    wire       rx_done;
    wire [7:0] uart_tx_data;
    wire       uart_tx_start;
    wire       uart_tx_busy;

    // ================================================================
    // 6. MAC DONE + SEVEN SEG + DIAGNOSTICS
    // ================================================================
    wire        mac_done_sig;
    wire [3:0]  seven_seg_val;
    wire        exception;
    wire [31:0] pc_out;
    wire        is_mul;
    wire        is_div;

    // ================================================================
    // 7. BRAM BANK SIGNALS
    // ================================================================
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

    // ================================================================
    // 8. PIPE
    // ================================================================
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
        .result_o           (),

        .mac_done_o         (mac_done_sig)
    );

    // ================================================================
    // 9. INSTRUCTION MEMORY
    // imem_addr[11:2] = 10-bit word index
    // ================================================================
    instr_mem imem_inst (
        .clk   (cpu_clk),
        .pc    (imem_addr[11:2]),
        .instr (imem_data)
    );

    // ================================================================
    // 10. BRAM BANK A — ping-pong bank A
    // 512 words x 4 bytes = 2KB
    // 196 pixel words needed — fits easily
    // ================================================================
    bram_bank bank_a (
        .clk   (cpu_clk),
        .we    (ram_we_a),
        .addr  (ram_addr_a[10:2]),
        .wdata (ram_wdata_a),
        .wstrb (ram_wstrb_a),
        .rdata (ram_data_a_out)
    );

    // ================================================================
    // 11. BRAM BANK B — ping-pong bank B
    // ================================================================
    bram_bank bank_b (
        .clk   (cpu_clk),
        .we    (ram_we_b),
        .addr  (ram_addr_b[10:2]),
        .wdata (ram_wdata_b),
        .wstrb (ram_wstrb_b),
        .rdata (ram_data_b_out)
    );

    // ================================================================
    // 12. MEMORY CONTROLLER
    // Handles: pixel ping-pong, MMIO decode,
    //          UART TX trigger, mac_done MMIO at 0x40000014
    // ================================================================
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

        .bank_sel          (),
        .uart_data_ready   (),
        .seven_seg_val     (seven_seg_val),

        .mac_done_in       (mac_done_sig)
    );

    // ================================================================
    // 13. UART RX
    // Receives 784 pixel bytes from laptop
    // ================================================================
    uart_rx #(
        .CLK_FREQ (100000000),
        .BAUD_RATE(9600)
    ) rx_inst (
        .clk     (cpu_clk),
        .rst_n   (reset_n),
        .rx_wire (rx_pin),
        .rx_data (uart_rx_data),
        .rx_done (rx_done)
    );

    // ================================================================
    // 14. UART TX
    // Sends predicted digit back to laptop
    // ================================================================
    uart_tx #(
        .CLK_FREQ (100000000),
        .BAUD_RATE(9600)
    ) tx_inst (
        .clk     (cpu_clk),
        .rst_n   (reset_n),
        .tx_data (uart_tx_data),
        .tx_start(uart_tx_start),
        .tx_wire (tx_pin),
        .tx_busy (uart_tx_busy),
        .tx_done ()
    );

    // ================================================================
    // 15. SEVEN SEGMENT DECODER
    // Common anode Basys3 — segments active low
    // Rightmost digit shows predicted digit 0-9
    // ================================================================
    reg [6:0] seg_reg;
    always @(*) begin
        case (seven_seg_val)
            4'd0:    seg_reg = 7'b1000000;
            4'd1:    seg_reg = 7'b1111001;
            4'd2:    seg_reg = 7'b0100100;
            4'd3:    seg_reg = 7'b0110000;
            4'd4:    seg_reg = 7'b0011001;
            4'd5:    seg_reg = 7'b0010010;
            4'd6:    seg_reg = 7'b0000010;
            4'd7:    seg_reg = 7'b1111000;
            4'd8:    seg_reg = 7'b0000000;
            4'd9:    seg_reg = 7'b0010000;
            default: seg_reg = 7'b1111111;
        endcase
    end

    assign seg = seg_reg;
    assign an  = 4'b1110;  // rightmost digit enabled

    // ================================================================
    // 16. LED DIAGNOSTICS
    // ================================================================
    assign led[15]  = exception;      // illegal instruction
    assign led[14]  = is_mul;         // MUL executing
    assign led[13]  = is_div;         // DIV executing
    assign led[12]  = mac_done_sig;   // MAC pipeline drained
    assign led[11]  = uart_tx_busy;   // TX transmitting
    assign led[10]  = rx_done;        // RX byte received
    assign led[9:0] = pc_out[11:2];   // PC word index

endmodule

// ================================================================
// BRAM BANK
// Instantiated twice for ping-pong banks A and B
// 512 words x 4 bytes = 2KB per bank
// Byte write strobe supported
// Synchronous read — 1 cycle latency
// ================================================================
module bram_bank (
    input  wire        clk,
    input  wire        we,
    input  wire [8:0]  addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg  [31:0] rdata
);
    reg [31:0] ram [0:511];

    always @(posedge clk) begin
        if (we) begin
            if (wstrb[0]) ram[addr][7:0]   <= wdata[7:0];
            if (wstrb[1]) ram[addr][15:8]  <= wdata[15:8];
            if (wstrb[2]) ram[addr][23:16] <= wdata[23:16];
            if (wstrb[3]) ram[addr][31:24] <= wdata[31:24];
        end
        rdata <= ram[addr];
    end
endmodule
