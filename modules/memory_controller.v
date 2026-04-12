module memory_controller (
    input wire clk,
    input wire rst_n,

    // --- UART RX interface ---
    input wire [7:0] uart_rx_data,
    input wire       rx_done,
    
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

    // --- Status ---
    output reg        bank_sel,
    output reg        uart_data_valid
);

    reg [9:0]  pixel_count;
    reg [31:0] cpu_addr_delayed;  // 1-cycle delay for read mux

    // --- STEP 1: Management Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count      <= 10'd0;
            bank_sel         <= 1'b0;
            uart_data_valid  <= 1'b0;
            cpu_addr_delayed <= 32'd0;
        end else begin
            uart_data_valid  <= rx_done;
            cpu_addr_delayed <= cpu_addr;

            if (rx_done) begin
                if (pixel_count == 10'd783) begin
                    pixel_count <= 10'd0;
                    bank_sel    <= ~bank_sel;
                end else begin
                    pixel_count <= pixel_count + 10'd1;
                end
            end
        end
    end

    // --- STEP 2: RAM Driving (Sequential - safe for FPGA) ---
    // UART write enable is registered here to prevent glitches
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_we_a    <= 1'b0;
            ram_we_b    <= 1'b0;
            ram_addr_a  <= 32'd0;
            ram_addr_b  <= 32'd0;
            ram_wdata_a <= 32'd0;
            ram_wdata_b <= 32'd0;
            ram_wstrb_a <= 4'b0000;
            ram_wstrb_b <= 4'b0000;
        end else begin
            // Default: no writes
            ram_we_a <= 1'b0;
            ram_we_b <= 1'b0;

            if (bank_sel == 0) begin
                // CPU owns Bank A
                ram_addr_a  <= cpu_addr;
                ram_wdata_a <= cpu_wdata;
                ram_wstrb_a <= cpu_wstrb;
                ram_we_a    <= (cpu_addr >= 32'h2000 &&
                                cpu_addr <  32'h4000) ? cpu_we : 1'b0;

                // UART owns Bank B
                if (rx_done) begin
                    ram_we_b    <= 1'b1;
                    ram_addr_b  <= 32'h2000 + {22'b0, pixel_count, 2'b00};
                    ram_wdata_b <= {24'b0, uart_rx_data};
                    ram_wstrb_b <= 4'b0001;
                end

            end else begin
                // CPU owns Bank B
                ram_addr_b  <= cpu_addr;
                ram_wdata_b <= cpu_wdata;
                ram_wstrb_b <= cpu_wstrb;
                ram_we_b    <= (cpu_addr >= 32'h2000 &&
                                cpu_addr <  32'h4000) ? cpu_we : 1'b0;

                // UART owns Bank A
                if (rx_done) begin
                    ram_we_a    <= 1'b1;
                    ram_addr_a  <= 32'h2000 + {22'b0, pixel_count, 2'b00};
                    ram_wdata_a <= {24'b0, uart_rx_data};
                    ram_wstrb_a <= 4'b0001;
                end
            end
        end
    end

    // --- STEP 3: Read Mux (Combinational) ---
    // Uses cpu_addr_delayed to sync with 1-cycle RAM output latency
    always @(*) begin
        cpu_rdata = 32'h0;

        // UART Status Register
        if (cpu_addr_delayed == 32'h4000) begin
            cpu_rdata = {22'b0, bank_sel, uart_data_valid, uart_rx_data};

        // Data RAM zone
        end else if (cpu_addr_delayed >= 32'h2000 &&
                     cpu_addr_delayed <  32'h4000) begin
            cpu_rdata = (bank_sel == 0) ? ram_data_a_out : ram_data_b_out;
        end
    end

endmodule