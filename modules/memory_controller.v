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
    output reg        uart_data_ready // Renamed for clarity: High when image is complete
);

    reg [9:0]  pixel_count;
    reg [31:0] cpu_addr_delayed;
    reg [31:0] pixel_packer; 

    // --- STEP 1: Management Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count      <= 10'd0;
            bank_sel         <= 1'b0;
            uart_data_ready  <= 1'b0;
            cpu_addr_delayed <= 32'd0;
            pixel_packer     <= 32'd0;
        end else begin
            cpu_addr_delayed <= cpu_addr;

            if (rx_done) begin
                // Pack 8-bit UART data into 32-bit buffer
                case (pixel_count[1:0])
                    2'b00: pixel_packer[7:0]   <= uart_rx_data;
                    2'b01: pixel_packer[15:8]  <= uart_rx_data;
                    2'b10: pixel_packer[23:16] <= uart_rx_data;
                    2'b11: pixel_packer[31:24] <= uart_rx_data;
                endcase

                // Check if the full image (784 pixels) has arrived
                if (pixel_count == 10'd783) begin
                    pixel_count     <= 10'd0;
                    bank_sel        <= ~bank_sel;   // Swap banks
                    uart_data_ready <= 1'b1;        // Tell CPU: "New Image is Ready!"
                end else begin
                    pixel_count     <= pixel_count + 10'd1;
                    // Reset ready flag while a new image is being transmitted
                    if (pixel_count == 10'd0) uart_data_ready <= 1'b0; 
                end
            end
        end
    end

    // --- STEP 2: RAM Driving ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_we_a <= 1'b0; ram_we_b <= 1'b0;
            ram_addr_a <= 0;  ram_addr_b <= 0;
        end else begin
            // Default: no writes
            ram_we_a <= 1'b0;
            ram_we_b <= 1'b0;

            if (bank_sel == 0) begin
                // CPU is doing AI math on Bank A
                ram_addr_a  <= cpu_addr;
                ram_wdata_a <= cpu_wdata;
                ram_wstrb_a <= cpu_wstrb;
                ram_we_a    <= (cpu_addr >= 32'h2000 && cpu_addr < 32'h4000) ? cpu_we : 1'b0;

                // UART is filling Bank B
                if (rx_done && (pixel_count[1:0] == 2'b11)) begin
                    ram_we_b    <= 1'b1;
                    ram_addr_b  <= 32'h2000 + {22'b0, pixel_count[9:2], 2'b00};
                    ram_wdata_b <= {uart_rx_data, pixel_packer[23:0]};
                    ram_wstrb_b <= 4'b1111;
                end
            end else begin
                // CPU is doing AI math on Bank B
                ram_addr_b  <= cpu_addr;
                ram_wdata_b <= cpu_wdata;
                ram_wstrb_b <= cpu_wstrb;
                ram_we_b    <= (cpu_addr >= 32'h2000 && cpu_addr < 32'h4000) ? cpu_we : 1'b0;

                // UART is filling Bank A
                if (rx_done && (pixel_count[1:0] == 2'b11)) begin
                    ram_we_a    <= 1'b1;
                    ram_addr_a  <= 32'h2000 + {22'b0, pixel_count[9:2], 2'b00};
                    ram_wdata_a <= {uart_rx_data, pixel_packer[23:0]};
                    ram_wstrb_a <= 4'b1111;
                end
            end
        end
    end

    // --- STEP 3: Read Mux ---
    always @(*) begin
        cpu_rdata = 32'h0;
        if (cpu_addr_delayed == 32'h4000) begin
            // Status Register: [31:2] reserved, [1] bank_sel, [0] data_ready
            cpu_rdata = {30'b0, bank_sel, uart_data_ready};
        end else if (cpu_addr_delayed >= 32'h2000 && cpu_addr_delayed < 32'h4000) begin
            cpu_rdata = (bank_sel == 0) ? ram_data_a_out : ram_data_b_out;
        end
    end

endmodule
