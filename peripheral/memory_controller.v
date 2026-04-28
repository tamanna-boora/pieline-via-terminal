
`timescale 1ns / 1ps

module memory_controller (
    input wire clk,
    input wire rst_n,

    input wire [7:0] uart_rx_data,
    input wire       rx_done,
    input wire       uart_tx_busy,
    output reg [7:0] uart_tx_data_out,
    output reg       uart_tx_start_out,

    input wire [31:0] cpu_addr,
    input wire [31:0] cpu_wdata,
    input wire        cpu_we,
    input wire [3:0]  cpu_wstrb,
    output reg [31:0] cpu_rdata,

    // Bank A — ALL signals now combinational wires
    output wire        ram_we_a,
    output wire [31:0] ram_addr_a,   
    output wire [31:0] ram_wdata_a,
    output wire [3:0]  ram_wstrb_a,
    input  wire [31:0] ram_data_a_out,

    // Bank B — ALL signals now combinational wires
    output wire        ram_we_b,
    output wire [31:0] ram_addr_b,   
    output wire [31:0] ram_wdata_b,
    output wire [3:0]  ram_wstrb_b,
    input  wire [31:0] ram_data_b_out,

    output reg        bank_sel,
    output reg        uart_data_ready,
    output reg [3:0]  seven_seg_val,

    input wire        mac_done_in
);

    reg [9:0]  pixel_count;
    reg [31:0] cpu_addr_reg;
    reg [31:0] pixel_packer;
    reg        uart_ready_latch;
    reg        bank_sel_prev;

    // =========================================================
    // 1. MANAGEMENT LOGIC (Registers & Counters)
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count       <= 10'd0;
            bank_sel          <= 1'b0;
            bank_sel_prev     <= 1'b0;
            uart_ready_latch  <= 1'b0;
            uart_data_ready   <= 1'b0;
            uart_tx_start_out <= 1'b0;
            uart_tx_data_out  <= 8'd0;
            cpu_addr_reg      <= 32'd0;
            pixel_packer      <= 32'd0;
            seven_seg_val     <= 4'd0;
        end else begin
            cpu_addr_reg      <= cpu_addr;
            uart_tx_start_out <= 1'b0;

            bank_sel_prev <= bank_sel;

            if (cpu_we && cpu_addr == 32'h40000010)
                seven_seg_val <= cpu_wdata[3:0];

            if (cpu_we && cpu_addr == 32'h40000008) begin
                uart_tx_data_out  <= cpu_wdata[7:0];
                uart_tx_start_out <= 1'b1;
            end

            if (bank_sel != bank_sel_prev)
                uart_ready_latch <= 1'b1;
            else if (cpu_we && cpu_addr == 32'h40000004) // Removed the '!'
                uart_ready_latch <= 1'b0;

            uart_data_ready <= uart_ready_latch;

            if (rx_done) begin
                case (pixel_count[1:0])
                    2'b00: pixel_packer[7:0]   <= uart_rx_data;
                    2'b01: pixel_packer[15:8]  <= uart_rx_data;
                    2'b10: pixel_packer[23:16] <= uart_rx_data;
                    2'b11: pixel_packer[31:24] <= uart_rx_data;
                endcase

                if (pixel_count == 10'd783) begin
                    pixel_count <= 10'd0;
                    bank_sel    <= ~bank_sel;
                end else begin
                    pixel_count <= pixel_count + 10'd1;
                end
            end
        end
    end

    // =========================================================
    // 2. COMBINATIONAL BRAM DRIVING
    // Aligns Address, Data, Strobe, and WE to the exact same cycle
    // =========================================================
    wire [31:0] uart_write_addr = {22'b0, pixel_count[9:2], 2'b00};
    wire [31:0] uart_wdata      = {uart_rx_data, pixel_packer[23:0]};

    // 1 if UART is trying to write a complete 4-byte word to the bank this cycle
    wire uart_writing_a = (bank_sel == 1'b1) && rx_done && (pixel_count[1:0] == 2'b11);
    wire uart_writing_b = (bank_sel == 1'b0) && rx_done && (pixel_count[1:0] == 2'b11);

    // 1 if CPU is targeting the bank
    wire cpu_access_a = (bank_sel == 1'b0) && (cpu_addr < 32'h2000);
    wire cpu_access_b = (bank_sel == 1'b1) && (cpu_addr < 32'h2000);

    // Bank A Routing
    assign ram_we_a    = uart_writing_a ? 1'b1            : (cpu_access_a ? cpu_we    : 1'b0);
    assign ram_addr_a  = uart_writing_a ? uart_write_addr : cpu_addr;
    assign ram_wdata_a = uart_writing_a ? uart_wdata      : cpu_wdata;
    assign ram_wstrb_a = uart_writing_a ? 4'b1111         : (cpu_access_a ? cpu_wstrb : 4'd0);

    // Bank B Routing
    assign ram_we_b    = uart_writing_b ? 1'b1            : (cpu_access_b ? cpu_we    : 1'b0);
    assign ram_addr_b  = uart_writing_b ? uart_write_addr : cpu_addr;
    assign ram_wdata_b = uart_writing_b ? uart_wdata      : cpu_wdata;
    assign ram_wstrb_b = uart_writing_b ? 4'b1111         : (cpu_access_b ? cpu_wstrb : 4'd0);

    // =========================================================
    // 3. READ MUX (Instantaneous Combinational Return)
    // =========================================================
    always @(*) begin
        cpu_rdata = 32'h0;

        if (cpu_addr == 32'h40000004)
            cpu_rdata = {30'b0, bank_sel, uart_ready_latch};

        else if (cpu_addr == 32'h4000000C)
            cpu_rdata = {31'b0, ~uart_tx_busy};

        else if (cpu_addr == 32'h40000014)
            cpu_rdata = {31'b0, mac_done_in};

        else if (cpu_addr < 32'h2000)
            cpu_rdata = (bank_sel == 1'b0) ? ram_data_a_out : ram_data_b_out;

        else if (cpu_addr >= 32'h2000 && cpu_addr < 32'h4000)
            cpu_rdata = (bank_sel == 1'b0) ? ram_data_b_out : ram_data_a_out;
    end

    // =========================================================
    // SYSTEM DEBUG TRAPS
    // =========================================================
    always @(posedge clk) begin
        if (rx_done && pixel_count == 10'd783)
            $display("FPGA DEBUG: Memory Controller received all 784 pixels! bank_sel toggled.");

        // CHANGED: Use cpu_addr to match the instant CPU request
        if (!cpu_we && cpu_addr == 32'h40000004) begin
            if (uart_ready_latch)
                $display("FPGA DEBUG: CPU read STATUS REG and saw a 1! It should break the loop now!");
        end
    end
endmodule
