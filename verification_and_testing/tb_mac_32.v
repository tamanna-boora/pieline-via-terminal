`timescale 1ns / 1ps
 
// ============================================================
//  tb_mac_32.v  – v5  STATE MACHINE testbench
//
//  ROOT CAUSE OF ALL PREVIOUS FAILURES:
//  Vivado xsim cannot reliably run nested for-loops that
//  contain @(posedge clk) inside an initial block.
//  It silently exits after ~1-2 outer iterations.
//
//  FIX: Replace the for-loop with a clocked always block
//  state machine using integer counters. This is the only
//  approach that works correctly in Vivado xsim.
//
//  STATE MACHINE:
//   S0_RESET    – hold reset
//   S1_SETTLE   – wait after reset release
//   S2_MACRST   – pulse mac_reset
//   S3_SETTLE2  – wait after mac_reset
//   S4_FEED     – feed 10 neurons x 49 words (490 cycles)
//   S5_DRAIN    – 3 pipeline drain cycles
//   S6_CLASSIFY – pulse classify
//   S7_DONE     – print results and finish
// ============================================================
 
module tb_mac_32 ();
 
    // ---- DUT ports ------------------------------------------
    reg        clk;
    reg        rst_n;
    reg [31:0] pixels;
    reg [5:0]  weight_addr;
    reg [3:0]  neuron_id;
    reg        mac_enable;
    reg        mac_reset;
    reg        classify;
 
    wire [3:0] digit_out;
    wire       valid_out;
 
    // ---- Image memory ---------------------------------------
    reg [31:0] image_mem [0:48];
 
    // ---- State machine --------------------------------------
    localparam S0_RESET    = 3'd0;
    localparam S1_SETTLE   = 3'd1;
    localparam S2_MACRST   = 3'd2;
    localparam S3_SETTLE2  = 3'd3;
    localparam S4_FEED     = 3'd4;
    localparam S5_DRAIN    = 3'd5;
    localparam S6_CLASSIFY = 3'd6;
    localparam S7_DONE     = 3'd7;
 
    reg [2:0]  state;
    reg [9:0]  cycle_cnt;   // general cycle counter per state
    reg [3:0]  n_cnt;       // neuron counter 0-9
    reg [5:0]  k_cnt;       // word counter  0-48
 
    reg done_flag;
 
    // ---- DUT ------------------------------------------------
    mnist_mac_unit uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .pixels     (pixels),
        .weight_addr(weight_addr),
        .neuron_id  (neuron_id),
        .mac_enable (mac_enable),
        .mac_reset  (mac_reset),
        .classify   (classify),
        .digit_out  (digit_out),
        .valid_out  (valid_out)
    );
 
    // ---- Clock ----------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // ---- Load image mem at time 0 ---------------------------
    initial begin
        $readmemh("random_image.mem", image_mem);
    end
 
    // ---- State machine (clocked) ----------------------------
    initial begin
        state       = S0_RESET;
        cycle_cnt   = 10'd0;
        n_cnt       = 4'd0;
        k_cnt       = 6'd0;
        done_flag   = 1'b0;
        rst_n       = 1'b0;
        mac_enable  = 1'b0;
        mac_reset   = 1'b0;
        classify    = 1'b0;
        pixels      = 32'h0;
        weight_addr = 6'h0;
        neuron_id   = 4'h0;
    end
 
    always @(posedge clk) begin
        case (state)
 
            // ---- S0: Hold reset for 4 cycles ----------------
            S0_RESET: begin
                rst_n     <= 1'b0;
                mac_enable <= 1'b0;
                mac_reset  <= 1'b0;
                classify   <= 1'b0;
                if (cycle_cnt == 10'd3) begin
                    rst_n     <= 1'b1;   // release reset
                    cycle_cnt <= 10'd0;
                    state     <= S1_SETTLE;
                end else begin
                    cycle_cnt <= cycle_cnt + 1'b1;
                end
            end
 
            // ---- S1: Settle 2 cycles after reset ------------
            S1_SETTLE: begin
                if (cycle_cnt == 10'd1) begin
                    cycle_cnt <= 10'd0;
                    state     <= S2_MACRST;
                end else begin
                    cycle_cnt <= cycle_cnt + 1'b1;
                end
            end
 
            // ---- S2: mac_reset pulse (1 cycle) --------------
            S2_MACRST: begin
                mac_reset <= 1'b1;
                state     <= S3_SETTLE2;
            end
 
            // ---- S3: Drop mac_reset, settle 2 cycles --------
            S3_SETTLE2: begin
                mac_reset <= 1'b0;
                if (cycle_cnt == 10'd1) begin
                    mac_enable <= 1'b1;
                    n_cnt      <= 4'd0;
                    k_cnt      <= 6'd0;
                    cycle_cnt  <= 10'd0;
                    // Pre-load first word
                    neuron_id   <= 4'd0;
                    pixels      <= image_mem[0];
                    weight_addr <= 6'd0;
                    state       <= S4_FEED;
                end else begin
                    cycle_cnt <= cycle_cnt + 1'b1;
                end
            end
 
            // ---- S4: Feed 10 x 49 = 490 cycles --------------
            // Each cycle: present current (n,k), then advance
            S4_FEED: begin
                // Advance counters and pre-load next word
                if (k_cnt == 6'd48) begin
                    k_cnt <= 6'd0;
                    if (n_cnt == 4'd9) begin
                        // All data sent – move to drain
                        cycle_cnt <= 10'd0;
                        state     <= S5_DRAIN;
                    end else begin
                        n_cnt     <= n_cnt + 1'b1;
                        neuron_id   <= n_cnt + 1'b1;
                        pixels      <= image_mem[0];
                        weight_addr <= 6'd0;
                    end
                end else begin
                    k_cnt       <= k_cnt + 1'b1;
                    neuron_id   <= n_cnt;
                    pixels      <= image_mem[k_cnt + 1'b1];
                    weight_addr <= k_cnt + 1'b1;
                end
            end
 
            // ---- S5: Drain pipeline (3 cycles) --------------
            S5_DRAIN: begin
                if (cycle_cnt == 10'd2) begin
                    mac_enable <= 1'b0;
                    cycle_cnt  <= 10'd0;
                    state      <= S6_CLASSIFY;
                end else begin
                    cycle_cnt <= cycle_cnt + 1'b1;
                end
            end
 
            // ---- S6: Classify pulse -------------------------
            S6_CLASSIFY: begin
                if (cycle_cnt == 10'd0) begin
                    classify  <= 1'b1;
                    cycle_cnt <= 10'd1;
                end else if (cycle_cnt == 10'd1) begin
                    classify  <= 1'b0;
                    cycle_cnt <= 10'd2;
                end else begin
                    // Output has latched – move to done
                    state     <= S7_DONE;
                    cycle_cnt <= 10'd0;
                end
            end
 
            // ---- S7: Print and finish -----------------------
            S7_DONE: begin
                if (!done_flag) begin
                    done_flag <= 1'b1;
                    $display("================================================");
                    $display("  Predicted digit : %0d", digit_out);
                    $display("  valid_out       : %b",  valid_out);
                    $display("------------------------------------------------");
                    $display("  neuron[0] = %0d", $signed(uut.accumulator[0]));
                    $display("  neuron[1] = %0d", $signed(uut.accumulator[1]));
                    $display("  neuron[2] = %0d", $signed(uut.accumulator[2]));
                    $display("  neuron[3] = %0d", $signed(uut.accumulator[3]));
                    $display("  neuron[4] = %0d", $signed(uut.accumulator[4]));
                    $display("  neuron[5] = %0d", $signed(uut.accumulator[5]));
                    $display("  neuron[6] = %0d", $signed(uut.accumulator[6]));
                    $display("  neuron[7] = %0d", $signed(uut.accumulator[7]));
                    $display("  neuron[8] = %0d", $signed(uut.accumulator[8]));
                    $display("  neuron[9] = %0d", $signed(uut.accumulator[9]));
                    $display("================================================");
                    $finish;
                end
            end
 
            default: state <= S0_RESET;
        endcase
    end
 
    // ---- Watchdog -------------------------------------------
    initial begin
        #20000;
        $display("WATCHDOG TIMEOUT at 20 us");
        $finish;
    end
 
endmodule