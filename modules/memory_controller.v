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
    // DESIGN CHOICE: CPU always uses address window 0x0000–0x1FFF.
    // bank_sel transparently routes to the correct physical BRAM.
    // Firmware must always use BANK_A_BASE (0x0000) — never BANK_B_BASE.
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
    output reg [3:0]  seven_seg_val
);

    reg [9:0]  pixel_count;
    reg [31:0] cpu_addr_reg;
    reg [31:0] pixel_packer;

    //use latch directly in read mux — no extra register delay
    reg uart_ready_latch;

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
        uart_tx_data_out  <= 8'd0;      // ← add this
        cpu_addr_reg      <= 32'd0;
        pixel_packer      <= 32'd0;
        seven_seg_val     <= 4'd0;
    end else begin
        cpu_addr_reg      <= cpu_addr;
        uart_tx_start_out <= 1'b0;      // ← default low every cycle

        // MMIO write: 7-segment display
        if (cpu_we && cpu_addr == 32'h40000010)
            seven_seg_val <= cpu_wdata[3:0];

        // MMIO write: UART TX
        if (cpu_we && cpu_addr == 32'h40000008) begin
            uart_tx_data_out  <= cpu_wdata[7:0];
            uart_tx_start_out <= 1'b1;  // 1-cycle pulse
        end

        // Sticky latch
        if (rx_done && pixel_count == 10'd783)
            uart_ready_latch <= 1'b1;
        else if (!cpu_we && cpu_addr == 32'h40000004)
            uart_ready_latch <= 1'b0;

        uart_data_ready <= uart_ready_latch;

        // Pixel packing + bank swap
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
    // FBoth bank_sel cases use identical cpu_addr window
    //        (< 0x2000). Firmware must always use 0x0000 base.
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_we_a    <= 1'b0;     ram_we_b    <= 1'b0;
            ram_addr_a  <= 32'd0;    ram_addr_b  <= 32'd0;
            ram_wdata_a <= 32'd0;    ram_wdata_b <= 32'd0;
            ram_wstrb_a <= 4'd0;     ram_wstrb_b <= 4'd0;
        end else begin
            // Defaults: mirror CPU bus to both (only we signals gate writes)
            ram_we_a    <= 1'b0;       ram_we_b    <= 1'b0;
            ram_addr_a  <= cpu_addr;   ram_addr_b  <= cpu_addr;
            ram_wdata_a <= cpu_wdata;  ram_wdata_b <= cpu_wdata;
            ram_wstrb_a <= cpu_wstrb;  ram_wstrb_b <= cpu_wstrb;

            if (bank_sel == 1'b0) begin
                // CPU → Bank A | UART → Bank B
                ram_we_a <= (cpu_addr < 32'h2000) ? cpu_we : 1'b0;

                if (rx_done && pixel_count[1:0] == 2'b11) begin
                    ram_we_b    <= 1'b1;
                    ram_addr_b  <= {22'b0, pixel_count[9:2], 2'b00};
                    ram_wdata_b <= {uart_rx_data, pixel_packer[23:0]};
                    ram_wstrb_b <= 4'b1111;
                end

            end else begin
                // CPU → Bank B | UART → Bank A
                // same address window — transparent to firmware
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
    // 3. READ MUX
    // use uart_ready_latch directly (no extra cycle delay)
    // status reg cleared same cycle as read via current addr
    // =========================================================
    always @(*) begin
        cpu_rdata = 32'h0;

        if (cpu_addr_reg == 32'h40000004)
           
            cpu_rdata = {30'b0, bank_sel, uart_ready_latch};

        else if (cpu_addr_reg == 32'h4000000C)
            cpu_rdata = {31'b0, ~uart_tx_busy};

        // read mux: bank_sel swaps which physical output wire is read
        // Both cases use the 0x0000 window — matches STEP 2 addressing
        else if (cpu_addr_reg < 32'h2000)
            cpu_rdata = (bank_sel == 1'b0) ? ram_data_a_out : ram_data_b_out;

        else if (cpu_addr_reg >= 32'h2000 && cpu_addr_reg < 32'h4000)
            cpu_rdata = (bank_sel == 1'b0) ? ram_data_b_out : ram_data_a_out;
    end

endmodule
