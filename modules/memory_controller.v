module memory_controller (
    input wire clk,
    input wire rst_n,
    // --- Interface with UART RX (Ravleen) ---
    input wire [7:0] uart_rx_data,
    input wire       rx_done,
    // --- Interface with CPU (Tamanna/Pakhi) ---
    input wire [31:0] cpu_addr,
    input wire [31:0] cpu_wdata,
    input wire        cpu_we,
    output reg [31:0] cpu_rdata,
    // --- Interface with Instruction ROM ---
    output wire [9:0] rom_addr,
    input wire [31:0] rom_data_out,
    // --- Interface with Physical RAM Banks ---
    output reg [9:0]  ram_addr_a,
    output reg [9:0]  ram_addr_b,
    output reg [31:0] ram_wdata_a,
    output reg [31:0] ram_wdata_b,
    output reg        ram_we_a,
    output reg        ram_we_b,
    input wire [31:0] ram_data_a_out,
    input wire [31:0] ram_data_b_out,
    // --- Status ---
    output reg        bank_sel,
    output reg        uart_data_valid
);
    reg [9:0]  pixel_count;
    reg [31:0] cpu_addr_delayed;  // 1-cycle delay (for ROM zone)
    reg [31:0] cpu_addr_delayed2; // 2-cycle delay (for RAM zone)

    // --- STEP 1: Management Logic (Sequential) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count      <= 0;
            bank_sel         <= 0;
            uart_data_valid  <= 0;
            cpu_addr_delayed <= 32'b0;
            cpu_addr_delayed2<= 32'b0;
        end else begin
            uart_data_valid   <= rx_done;
            cpu_addr_delayed  <= cpu_addr;         // 1-cycle delay
            cpu_addr_delayed2 <= cpu_addr_delayed; // 2-cycle delay

            if (rx_done) begin
                if (pixel_count == 783) begin
                    pixel_count <= 0;
                    bank_sel    <= ~bank_sel;
                end else begin
                    pixel_count <= pixel_count + 1'b1;
                end
            end
        end
    end

    // --- STEP 2: ROM Addressing (Continuous) ---
    // ROM has 1-cycle latency (registered output inside inst_rom)
    // so combinational address is correct here
    assign rom_addr = cpu_addr[11:2];

    // --- STEP 3: RAM Driving (Sequential/Safe) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {ram_we_a, ram_we_b} <= 2'b00;
        end else begin
            // Default: Disable writes
            ram_we_a <= 1'b0;
            ram_we_b <= 1'b0;

            if (bank_sel == 0) begin
                // CPU gets Bank A
                ram_addr_a  <= cpu_addr[11:2];
                ram_wdata_a <= cpu_wdata;
                ram_we_a    <= (cpu_addr >= 32'h2000 && cpu_addr < 32'h4000) ? cpu_we : 1'b0;
                // UART gets Bank B
                if (rx_done) begin
                    ram_addr_b  <= pixel_count;
                    ram_wdata_b <= {24'b0, uart_rx_data};
                    ram_we_b    <= 1'b1;
                end
            end else begin
                // CPU gets Bank B
                ram_addr_b  <= cpu_addr[11:2];
                ram_wdata_b <= cpu_wdata;
                ram_we_b    <= (cpu_addr >= 32'h2000 && cpu_addr < 32'h4000) ? cpu_we : 1'b0;
                // UART gets Bank A
                if (rx_done) begin
                    ram_addr_a  <= pixel_count;
                    ram_wdata_a <= {24'b0, uart_rx_data};
                    ram_we_a    <= 1'b1;
                end
            end
        end
    end

    // --- STEP 4: Read Selection (Combinational) ---
    // ROM:  1-cycle latency → use cpu_addr_delayed  (1-cycle old address)
    // RAM:  2-cycle latency → use cpu_addr_delayed2 (2-cycle old address)
    // UART: no memory      → use cpu_addr_delayed
    always @(*) begin
        cpu_rdata = 32'h0;

        // ZONE 1: Instruction ROM (0x0000 - 0x1FFF)
        if (cpu_addr_delayed < 32'h2000) begin
            cpu_rdata = rom_data_out;

        // ZONE 2: Data RAM (0x2000 - 0x3FFF)
        end else if (cpu_addr_delayed2 >= 32'h2000 && cpu_addr_delayed2 < 32'h4000) begin
            cpu_rdata = (bank_sel == 0) ? ram_data_a_out : ram_data_b_out;

        // ZONE 3: UART Status (0x4000)
        end else if (cpu_addr_delayed == 32'h4000) begin
            cpu_rdata = {23'b0, uart_data_valid, uart_rx_data};
        end
    end

endmodule