`timescale 1ns / 1ps

module memory_controller (
    input wire clk,
    input wire rst_n,

    // --- UART Interface ---
    input wire [7:0] uart_rx_data,
    input wire       rx_done,
    input wire       uart_tx_busy,
    output reg [7:0] uart_tx_data_out,
    output reg       uart_tx_start_out,

    // --- CPU Interface ---
    input wire [31:0] cpu_addr,
    input wire [31:0] cpu_wdata,
    input wire        cpu_we,
    input wire [3:0]  cpu_wstrb,
    output reg [31:0] cpu_rdata,

    // --- Physical RAM Bank A ---
    output reg        ram_we_a,
    output reg [31:0] ram_addr_a,
    output reg [31:0] ram_wdata_a,
    output reg [3:0]  ram_wstrb_a,
    input wire [31:0] ram_data_a_out,

    // --- Physical RAM Bank B ---
    output reg        ram_we_b,
    output reg [31:0] ram_addr_b,
    output reg [31:0] ram_wdata_b,
    output reg [3:0]  ram_wstrb_b,
    input wire [31:0] ram_data_b_out,

    // --- Status & Peripherals ---
    output reg        bank_sel,
    output reg        uart_data_ready,
    output reg [3:0]  seven_seg_val,

    // ADD: mac_done mapped to MMIO 0x40000014
    input wire        mac_done_in
);

    reg [9:0]  pixel_count;
    reg [31:0] cpu_addr_reg;
    reg [31:0] pixel_packer;
    reg        uart_ready_latch;

    // =========================================================
    // 1. MANAGEMENT LOGIC 
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count       <= 10'd0;
            bank_sel          <= 1'b0;
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

            if (cpu_we && cpu_addr == 32'h40000010)
                seven_seg_val <= cpu_wdata[3:0];

            if (cpu_we && cpu_addr == 32'h40000008) begin
                uart_tx_data_out  <= cpu_wdata[7:0];
                uart_tx_start_out <= 1'b1;
            end

            if (rx_done && pixel_count == 10'd783)
                uart_ready_latch <= 1'b1;
            else if (!cpu_we && cpu_addr == 32'h40000004)
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
    // 2. RAM DRIVING 
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_we_a    <= 1'b0;     ram_we_b    <= 1'b0;
            ram_addr_a  <= 32'd0;    ram_addr_b  <= 32'd0;
            ram_wdata_a <= 32'd0;    ram_wdata_b <= 32'd0;
            ram_wstrb_a <= 4'd0;     ram_wstrb_b <= 4'd0;
        end else begin
            ram_we_a    <= 1'b0;       ram_we_b    <= 1'b0;
            ram_addr_a  <= cpu_addr;   ram_addr_b  <= cpu_addr;
            ram_wdata_a <= cpu_wdata;  ram_wdata_b <= cpu_wdata;
            ram_wstrb_a <= cpu_wstrb;  ram_wstrb_b <= cpu_wstrb;

            if (bank_sel == 1'b0) begin
                ram_we_a <= (cpu_addr < 32'h2000) ? cpu_we : 1'b0;

                if (rx_done && pixel_count[1:0] == 2'b11) begin
                    ram_we_b    <= 1'b1;
                    ram_addr_b  <= {22'b0, pixel_count[9:2], 2'b00};
                    ram_wdata_b <= {uart_rx_data, pixel_packer[23:0]};
                    ram_wstrb_b <= 4'b1111;
                end
            end else begin
                ram_we_b <= (cpu_addr < 32'h2000) ? cpu_we : 1'b0;

                if (rx_done && pixel_count[1:0] == 2'b11) begin
                    ram_we_a    <= 1'b1;
                    ram_addr_a  <= {22'b0, pixel_count[9:2], 2'b00};
                    ram_wdata_a <= {uart_rx_data, pixel_packer[23:0]};
                    ram_wstrb_a <= 4'b1111;
                end
            end
        end
    end

    // =========================================================
    // 3. READ MUX — ADD mac_done at 0x40000014
    // =========================================================
    always @(*) begin
        cpu_rdata = 32'h0;

        if (cpu_addr_reg == 32'h40000004)
            cpu_rdata = {30'b0, bank_sel, uart_ready_latch};

        else if (cpu_addr_reg == 32'h4000000C)
            cpu_rdata = {31'b0, ~uart_tx_busy};

        // ADD: mac_done status — CPU polls this before mac_classify
        else if (cpu_addr_reg == 32'h40000014)
            cpu_rdata = {31'b0, mac_done_in};

        else if (cpu_addr_reg < 32'h2000)
            cpu_rdata = (bank_sel == 1'b0) ? ram_data_a_out : ram_data_b_out;

        else if (cpu_addr_reg >= 32'h2000 && cpu_addr_reg < 32'h4000)
            cpu_rdata = (bank_sel == 1'b0) ? ram_data_b_out : ram_data_a_out;
    end

endmodule
