`timescale 1ns / 1ps

module memory (
    input  wire        clk,
    
    // Standard Processor Interface
    input  wire        re,          // Read Enable
    input  wire        we,          // Write Enable
    input  wire [31:0] addr,        // Memory Address
    input  wire [31:0] wdata,       // Data to Write
    input  wire [ 3:0] wstrb,       // Byte Enable Strobe
    output reg  [31:0] rdata,       // Data Read Output
    
    // Memory-Mapped I/O (MMIO) Interface for Peripheral Integration
    // Ravleen will connect her UART/LED modules to these ports in the top level
    input  wire [31:0] uart_rx_data,  // Incoming image data from PC
    input  wire        uart_rx_valid, // 1 if new UART data is ready to be read
    output reg  [31:0] peripheral_tx_data, // Data going out to LEDs or UART TX
    output reg         peripheral_tx_en    // Trigger to send the output
);

    // MMIO Address Boundaries
    localparam BASE_RAM_ADDR = 32'h0000_0000;
    localparam UART_RX_ADDR  = 32'h1000_0000; // Address to read incoming image data
    localparam UART_STAT_ADDR= 32'h1000_0004; // Address to check if RX data is ready
    localparam LED_TX_ADDR   = 32'h2000_0000; // Address to write final classification

    // 16KB Standard Block RAM (BRAM) Data Memory
    reg [31:0] ram [0:4095];

    // =========================================================
    // READ LOGIC (Multiplexing RAM vs. Peripherals)
    // =========================================================
    always @(posedge clk) begin
        if (re) begin
            case (addr & 32'hF000_0000) // Mask to check the top nibble for routing
                
                4'h0: begin // Accesses 0x0000_xxxx (Standard RAM)
                    rdata <= ram[addr[13:2]]; 
                end
                
                4'h1: begin // Accesses 0x1000_xxxx (MMIO Inputs)
                    if (addr == UART_RX_ADDR)
                        rdata <= uart_rx_data;       // Read the incoming pixel
                    else if (addr == UART_STAT_ADDR)
                        rdata <= {31'd0, uart_rx_valid}; // Read the ready-status flag
                    else
                        rdata <= 32'd0;
                end
                
                default: rdata <= 32'd0; // Unmapped addresses return 0
            endcase
        end
    end

    // =========================================================
    // WRITE LOGIC (Routing RAM vs. Peripherals)
    // =========================================================
    always @(posedge clk) begin
        // Default peripheral write state
        peripheral_tx_en <= 1'b0;
        
        if (we) begin
            if ((addr & 32'hF000_0000) == 4'h0) begin 
                // Write to Standard RAM
                if (wstrb[0]) ram[addr[13:2]][7:0]   <= wdata[7:0];
                if (wstrb[1]) ram[addr[13:2]][15:8]  <= wdata[15:8];
                if (wstrb[2]) ram[addr[13:2]][23:16] <= wdata[23:16];
                if (wstrb[3]) ram[addr[13:2]][31:24] <= wdata[31:24];
            end 
            else if (addr == LED_TX_ADDR) begin
                // Write to the Output Peripherals (LEDs / UART TX)
                peripheral_tx_data <= wdata;
                peripheral_tx_en   <= 1'b1; // Pulses high for one clock cycle to trigger Ravleen's TX logic
            end
        end
    end

endmodule
