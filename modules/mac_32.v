`timescale 1ns / 1ps

(* use_dsp = "yes" *)
module mnist_mac_unit (
    input clk,
    input rst_n,
    
    input [31:0] pixels,
    input [7:0] weight_addr,
    input [3:0] neuron_id,
    input mac_enable,
    input mac_reset,
    input classify,
    
    output [3:0] digit_out,
    output valid_out
);

    // 1. Flattened Weight ROM (10 neurons * 196 weights = 1960)
    // This fixes the 2D array synthesis error
    (* ram_style = "block" *)
    reg [31:0] weight_rom [0:1959]; 
    
    initial begin
        // Ensure this file name matches exactly in your Sources
        $readmemh("mnist_weights_packed.mem", weight_rom);
    end
    
    // 2. Stage 1: Fetch Weights and Pixels
    reg signed [7:0] w0_s1, w1_s1, w2_s1, w3_s1;
    reg [7:0] p0_s1, p1_s1, p2_s1, p3_s1;
    reg [3:0] neuron_s1;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            {w3_s1, w2_s1, w1_s1, w0_s1} <= 32'd0;
            {p3_s1, p2_s1, p1_s1, p0_s1} <= 32'd0;
            neuron_s1 <= 4'd0;
        end else if (mac_enable) begin
            // Calculate flat index: (neuron * 196) + address
            {w3_s1, w2_s1, w1_s1, w0_s1} <= weight_rom[(neuron_id * 196) + weight_addr];
            p0_s1 <= pixels[7:0];
            p1_s1 <= pixels[15:8];
            p2_s1 <= pixels[23:16];
            p3_s1 <= pixels[31:24];
            neuron_s1 <= neuron_id;
        end
    end
    
    // 3. Stage 2: Parallel Multipliers
    reg signed [23:0] prod0_s2, prod1_s2, prod2_s2, prod3_s2;
    reg [3:0] neuron_s2;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prod0_s2 <= 24'sd0; prod1_s2 <= 24'sd0;
            prod2_s2 <= 24'sd0; prod3_s2 <= 24'sd0;
            neuron_s2 <= 4'd0;
        end else if (mac_enable) begin
            prod0_s2 <= w0_s1 * $signed({8'b0, p0_s1});
            prod1_s2 <= w1_s1 * $signed({8'b0, p1_s1});
            prod2_s2 <= w2_s1 * $signed({8'b0, p2_s1});
            prod3_s2 <= w3_s1 * $signed({8'b0, p3_s1});
            neuron_s2 <= neuron_s1;
        end
    end
    
    // 4. Stage 3: Adder Tree
    reg signed [25:0] sum_s3;
    reg [3:0] neuron_s3;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            sum_s3 <= 26'sd0;
            neuron_s3 <= 4'd0;
        end else if (mac_enable) begin
            sum_s3 <= $signed(prod0_s2) + $signed(prod1_s2) + 
                      $signed(prod2_s2) + $signed(prod3_s2);
            neuron_s3 <= neuron_s2;
        end
    end
    
    // 5. Accumulators for 10 Neurons
    reg signed [31:0] accumulator [0:9];
    integer i;
    
    always @(posedge clk) begin
        if (!rst_n || mac_reset) begin
            for (i = 0; i < 10; i = i + 1) accumulator[i] <= 32'sd0;
        end else if (mac_enable) begin
            accumulator[neuron_s3] <= accumulator[neuron_s3] + $signed(sum_s3);
        end
    end
    
    // 6. Classification (Finding the Max)
    reg [3:0] max_neuron;
    reg signed [31:0] max_val;
    integer j;

    always @(*) begin
        max_neuron = 4'd0;
        max_val = accumulator[0];
        for (j = 1; j < 10; j = j + 1) begin
            if (accumulator[j] > max_val) begin
                max_val = accumulator[j];
                max_neuron = j[3:0];
            end
        end
    end
    
    // 7. Output Register
    reg [3:0] digit_out_reg;
    reg valid_out_reg;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            digit_out_reg <= 4'd0;
            valid_out_reg <= 1'b0;
        end else if (classify) begin
            digit_out_reg <= max_neuron;
            valid_out_reg <= 1'b1;
        end else begin
            valid_out_reg <= 1'b0;
        end
    end
    
    assign digit_out = digit_out_reg;
    assign valid_out = valid_out_reg;

endmodule
