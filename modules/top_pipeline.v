`timescale 1ns / 1ps

module top (
    input  wire clk,        // 100MHz Oscillator (Pin E3)
    input  wire btnc,       // Center Button Reset (Pin N17)
    output wire [15:0] led  // LEDs LD15 to LD0
);

    // ================================================================
    // 1. CLOCK DIVIDER (Slowed down for the Demo)
    // ================================================================
    reg [31:0] clk_cnt = 0;
    reg slow_clk_reg = 0;
    
    // CPU runs when button is RELEASED (Active-High Button -> Active-Low Reset)
    wire reset_n = ~btnc; 

    always @(posedge clk) begin
        if (btnc) begin
            clk_cnt <= 0;
            slow_clk_reg <= 0;
        end else if (clk_cnt >= 50000000) begin // 10Hz: PC increments every 0.1s
            clk_cnt <= 0;
            slow_clk_reg <= ~slow_clk_reg;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end

    wire cpu_clk = slow_clk_reg;

    // ================================================================
    // 2. INTERNAL CPU SIGNALS
    // ================================================================
    wire [31:0] imem_data, imem_addr, pc_out;
    wire [31:0] dmem_rdata, dmem_waddr, dmem_raddr, dmem_wdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_re, dmem_we, exception, is_mul, is_div;

    // ================================================================
    // 3. PROCESSOR INSTANTIATION
    // ================================================================
    pipe pipe_u (
        .clk(cpu_clk),
        .reset(reset_n),
        .stall(1'b0),
        .exception(exception),
        .pc_out(pc_out),
        .inst_mem_is_valid(1'b1),
        .inst_mem_read_data(imem_data),
        .inst_mem_address(imem_addr),
        .dmem_read_data_temp(dmem_rdata),
        .dmem_write_valid(1'b1),
        .dmem_read_valid(1'b1),
        .dmem_write_ready(dmem_we),
        .dmem_read_ready(dmem_re),
        .dmem_write_address(dmem_waddr),
        .dmem_read_address(dmem_raddr),
        .dmem_write_data(dmem_wdata),
        .dmem_write_byte(dmem_wstrb),
        .is_mul(is_mul),
        .is_div(is_div),
        .mul_busy_o(),
        .div_busy_o(),
        .result_o()
    );

    // ================================================================
    // 4. AI INSTRUCTION MONITOR (MAC_RST / MAC_EN)
    // ================================================================
    reg mac_fired;
    always @(posedge cpu_clk) begin
        if (!reset_n) begin
            mac_fired <= 1'b0;
        end else if (imem_data[6:0] == 7'b0001011) begin 
            // This matches instructions 13 and 14 in your imem.hex
            mac_fired <= 1'b1;
        end
    end

    // ================================================================
    // 5. LED DIAGNOSTIC MAPPING
    // ================================================================
    assign led[15]    = exception;    // LD15: Illegal Instruction (Red)
    assign led[12]    = cpu_clk;      // LD12: Pulse (Blinks while running)
    assign led[11]    = 1'b1;         // LD11: Power Indicator
    assign led[10]    = mac_fired;    // LD10: AI SUCCESS (MAC Activated)
    assign led[13]    = is_mul;
    assign led[14]    = is_div;
    // PC Mapping: 
    // pc_out[11:2] converts byte address (0, 4, 8...) to word index (0, 1, 2...)
    // This will show your instructions 0-19 on LEDs 0-4
    assign led[9:0]   = pc_out[11:2]; 

    // ================================================================
    // 6. MEMORY SYSTEM
    // ================================================================
    instr_mem IMEM (
        .clk(cpu_clk), 
        .pc(imem_addr[11:2]), 
        .instr(imem_data)
    );

    data_mem DMEM (
        .clk(cpu_clk), 
        .re(dmem_re), 
        .raddr(dmem_raddr), 
        .rdata(dmem_rdata), 
        .we(dmem_we), 
        .waddr(dmem_waddr), 
        .wdata(dmem_wdata), 
        .wstrb(dmem_wstrb)
    );

endmodule
