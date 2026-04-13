`timescale 1ns / 1ps
 
// ============================================================
//  tb_mac_32.v  –  testbench for 28x28 mnist_mac_unit
//
//  28x28 = 784 pixels / 4 per word = 196 words per neuron
//  10 neurons x 196 words = 1960 data cycles = ~19.6 us
//  Set Vivado simulation runtime to 50us
//
//  Place fixed (Unix LF) .mem files in:
//    <project>.sim/sim_1/behav/xsim/
// ============================================================
 
module tb_mac_32 ();
 
    reg        clk;
    reg        rst_n;
    reg [31:0] pixels;
    reg [7:0]  weight_addr;      // 8-bit: supports 0-195
    reg [3:0]  neuron_id;
    reg        mac_enable;
    reg        mac_reset;
    reg        classify;
 
    wire [3:0] digit_out;
    wire       valid_out;
 
    // 196 words x 32-bit = 784 pixels
    reg [31:0] image_mem [0:195];
 
    // State machine
    localparam S0_RESET    = 3'd0;
    localparam S1_SETTLE   = 3'd1;
    localparam S2_MACRST   = 3'd2;
    localparam S3_SETTLE2  = 3'd3;
    localparam S4_FEED     = 3'd4;
    localparam S5_DRAIN    = 3'd5;
    localparam S6_CLASSIFY = 3'd6;
    localparam S7_DONE     = 3'd7;
 
    reg [2:0]  state;
    reg [9:0]  cycle_cnt;
    reg [3:0]  n_cnt;       // neuron counter 0-9
    reg [7:0]  k_cnt;       // word counter   0-195
    reg        done_flag;
 
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
 
    initial clk = 1'b0;
    always #5 clk = ~clk;   // 100 MHz
 
    initial $readmemh("random_image.mem", image_mem);
 
    initial begin
        state       = S0_RESET;
        cycle_cnt   = 10'd0;
        n_cnt       = 4'd0;
        k_cnt       = 8'd0;
        done_flag   = 1'b0;
        rst_n       = 1'b0;
        mac_enable  = 1'b0;
        mac_reset   = 1'b0;
        classify    = 1'b0;
        pixels      = 32'h0;
        weight_addr = 8'h0;
        neuron_id   = 4'h0;
    end
 
    always @(posedge clk) begin
        case (state)
 
            S0_RESET: begin
                rst_n      <= 1'b0;
                mac_enable <= 1'b0;
                mac_reset  <= 1'b0;
                classify   <= 1'b0;
                if (cycle_cnt == 10'd3) begin
                    rst_n     <= 1'b1;
                    cycle_cnt <= 10'd0;
                    state     <= S1_SETTLE;
                end else
                    cycle_cnt <= cycle_cnt + 1'b1;
            end
 
            S1_SETTLE: begin
                if (cycle_cnt == 10'd1) begin
                    cycle_cnt <= 10'd0;
                    state     <= S2_MACRST;
                end else
                    cycle_cnt <= cycle_cnt + 1'b1;
            end
 
            S2_MACRST: begin
                mac_reset <= 1'b1;
                state     <= S3_SETTLE2;
            end
 
            S3_SETTLE2: begin
                mac_reset <= 1'b0;
                if (cycle_cnt == 10'd1) begin
                    mac_enable  <= 1'b1;
                    n_cnt       <= 4'd0;
                    k_cnt       <= 8'd0;
                    cycle_cnt   <= 10'd0;
                    neuron_id   <= 4'd0;
                    pixels      <= image_mem[0];
                    weight_addr <= 8'd0;
                    state       <= S4_FEED;
                end else
                    cycle_cnt <= cycle_cnt + 1'b1;
            end
 
            // Feed 10 neurons x 196 words = 1960 cycles
            S4_FEED: begin
                if (k_cnt == 8'd195) begin
                    k_cnt <= 8'd0;
                    if (n_cnt == 4'd9) begin
                        cycle_cnt <= 10'd0;
                        state     <= S5_DRAIN;
                    end else begin
                        n_cnt       <= n_cnt + 1'b1;
                        neuron_id   <= n_cnt + 1'b1;
                        pixels      <= image_mem[0];
                        weight_addr <= 8'd0;
                    end
                end else begin
                    k_cnt       <= k_cnt + 1'b1;
                    neuron_id   <= n_cnt;
                    pixels      <= image_mem[k_cnt + 1'b1];
                    weight_addr <= k_cnt + 1'b1;
                end
            end
 
            S5_DRAIN: begin
                if (cycle_cnt == 10'd2) begin
                    mac_enable <= 1'b0;
                    cycle_cnt  <= 10'd0;
                    state      <= S6_CLASSIFY;
                end else
                    cycle_cnt <= cycle_cnt + 1'b1;
            end
 
            S6_CLASSIFY: begin
                if (cycle_cnt == 10'd0) begin
                    classify  <= 1'b1;
                    cycle_cnt <= 10'd1;
                end else if (cycle_cnt == 10'd1) begin
                    classify  <= 1'b0;
                    cycle_cnt <= 10'd2;
                end else begin
                    state     <= S7_DONE;
                    cycle_cnt <= 10'd0;
                end
            end
 
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
 
    // Watchdog: 1960 data cycles x 10ns + margin = 50us
    initial begin
        #50000;
        $display("WATCHDOG TIMEOUT at 50us");
        $finish;
    end
 
endmodule