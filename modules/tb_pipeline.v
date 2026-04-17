`timescale 1ns / 1ps

module riscv_top #(
    // Set to 1 for Simulation (fast), Set to 0 for FPGA (slow)
    parameter SIM_MODE = 0 
)(
    input  wire        clk,        // Matches XDC: get_ports clk
    input  wire        reset_btn,  // Matches XDC: get_ports reset_btn
    
    // Outputs to physical pins (LEDs)
    output wire [15:0] led         // Matches XDC: get_ports {led[0]} ...
);

    // =========================================================================
    // 1. Clock Divider (Slow down for human eyes)
    // =========================================================================
    reg [26:0] clk_counter = 0;
    reg slow_clk_reg = 0;

    always @(posedge clk) begin
        clk_counter <= clk_counter + 1;
        slow_clk_reg <= clk_counter[24]; // Approx 3 instructions per second
    end

    wire slow_clk = (SIM_MODE == 1) ? clk : slow_clk_reg;

    // =========================================================================
    // 2. Reset Synchronizer & Inverter
    // =========================================================================
    // The physical button is Active-HIGH (1 when pressed).
    // The pipeline needs Active-LOW (0 to reset). 
    // We invert it using ~reset_btn so it defaults to 1 (running) and drops to 0 (reset).
    reg [1:0] reset_sync;
    always @(posedge slow_clk) begin
        reset_sync <= {reset_sync[0], ~reset_btn}; // <--- INVERTED HERE
    end
    wire sys_reset_n = reset_sync[1];

    // =========================================================================
    // 3. Interconnect Wires
    // =========================================================================
    wire [31:0] pc_out;
    wire        exception;
    
    // I-Mem wires
    wire [31:0] inst_mem_address;
    wire [31:0] inst_mem_read_data;
    wire        inst_mem_is_valid;
    
    // D-Mem wires
    wire [31:0] dmem_read_address;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire [31:0] dmem_read_data_temp;
    
    wire        dmem_read_ready;
    wire        dmem_write_ready;
    wire        dmem_read_valid;
    wire        dmem_write_valid;

    // CPU Status wires
    wire        is_mul;
    wire        is_div;
    wire        mul_busy_o;
    wire        div_busy_o;
    wire [31:0] result_o;

        // =========================================================================
    // 4. CPU Core Instantiation (Using slow_clk!)
    // =========================================================================
    // Tie the valid signals HIGH since your memory is always ready
    assign inst_mem_is_valid = 1'b1;
    assign dmem_read_valid   = 1'b1;
    assign dmem_write_valid  = 1'b1;

    pipe #(
        .RESET(32'h0000_0000)
    ) cpu_core (
        .clk                    (slow_clk), 
        .reset                  (sys_reset_n),
        .stall                  (1'b0), 
        
        .exception              (exception),
        .pc_out                 (pc_out),

        .inst_mem_is_valid      (inst_mem_is_valid),
        .inst_mem_read_data     (inst_mem_read_data),
        .inst_mem_address       (inst_mem_address),

        .dmem_read_data_temp    (dmem_read_data_temp),
        .dmem_write_valid       (dmem_write_valid),
        .dmem_read_valid        (dmem_read_valid),
        
        .is_mul                 (is_mul),
        .is_div                 (is_div),
        .mul_busy_o             (mul_busy_o),
        .div_busy_o             (div_busy_o),
        .result_o               (result_o),
        
        .dmem_read_ready        (dmem_read_ready),
        .dmem_read_address      (dmem_read_address),
        .dmem_write_ready       (dmem_write_ready),
        .dmem_write_address     (dmem_write_address),
        .dmem_write_data        (dmem_write_data),
        .dmem_write_byte        (dmem_write_byte)
    );

    // =========================================================================
    // 5. Instruction Memory
    // =========================================================================
    instr_mem imem (
        .clk        (slow_clk),
        .pc         (inst_mem_address),     // Changed to match 'pc'
        .instr      (inst_mem_read_data)    // Changed to match 'instr'
    );

    // =========================================================================
    // 6. Data Memory
    // =========================================================================
    data_mem dmem (
        .clk        (slow_clk),
        .re         (dmem_read_ready),      // Changed to match 're'
        .raddr      (dmem_read_address),    // Changed to match 'raddr'
        .rdata      (dmem_read_data_temp),  // Changed to match 'rdata'
        .we         (dmem_write_ready),     // Changed to match 'we'
        .waddr      (dmem_write_address),   // Changed to match 'waddr'
        .wdata      (dmem_write_data),      // Changed to match 'wdata'
        .wstrb      (dmem_write_byte)       // Changed to match 'wstrb'
    );

    // =========================================================================
    // 7. Output to LEDs
    // =========================================================================
    assign led = {pc_out[9:2], result_o[7:0]};
endmodule
