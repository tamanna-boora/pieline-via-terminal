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

    (* ram_style = "block" *)
    (* INIT_FILE = "mnist_weights_packed.mem" *)
    reg signed [31:0] weight_rom [0:9][0:195];
    
    initial begin
        $readmemh("mnist_weights_packed.mem", weight_rom);
    end
    
    wire [7:0] pix0 = pixels[7:0];
    wire [7:0] pix1 = pixels[15:8];
    wire [7:0] pix2 = pixels[23:16];
    wire [7:0] pix3 = pixels[31:24];
    
    reg signed [7:0] w0_s1, w1_s1, w2_s1, w3_s1;
    reg [7:0] p0_s1, p1_s1, p2_s1, p3_s1;
    reg [3:0] neuron_s1;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            w0_s1 <= 8'sd0;
            w1_s1 <= 8'sd0;
            w2_s1 <= 8'sd0;
            w3_s1 <= 8'sd0;
            p0_s1 <= 8'd0;
            p1_s1 <= 8'd0;
            p2_s1 <= 8'd0;
            p3_s1 <= 8'd0;
            neuron_s1 <= 4'd0;
        end else if (mac_enable) begin
            {w3_s1, w2_s1, w1_s1, w0_s1} <= weight_rom[neuron_id][weight_addr];
            p0_s1 <= pix0;
            p1_s1 <= pix1;
            p2_s1 <= pix2;
            p3_s1 <= pix3;
            neuron_s1 <= neuron_id;
        end
    end
    
    wire signed [15:0] p0_ext = {8'b0, p0_s1};
    wire signed [15:0] p1_ext = {8'b0, p1_s1};
    wire signed [15:0] p2_ext = {8'b0, p2_s1};
    wire signed [15:0] p3_ext = {8'b0, p3_s1};
    
    reg signed [23:0] prod0_s2, prod1_s2, prod2_s2, prod3_s2;
    reg [3:0] neuron_s2;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prod0_s2 <= 24'sd0;
            prod1_s2 <= 24'sd0;
            prod2_s2 <= 24'sd0;
            prod3_s2 <= 24'sd0;
            neuron_s2 <= 4'd0;
        end else if (mac_enable) begin
            prod0_s2 <= w0_s1 * p0_ext;
            prod1_s2 <= w1_s1 * p1_ext;
            prod2_s2 <= w2_s1 * p2_ext;
            prod3_s2 <= w3_s1 * p3_ext;
            neuron_s2 <= neuron_s1;
        end
    end
    
    wire signed [24:0] sum_low = {prod0_s2[23], prod0_s2} + {prod1_s2[23], prod1_s2};
    wire signed [24:0] sum_high = {prod2_s2[23], prod2_s2} + {prod3_s2[23], prod3_s2};
    wire signed [25:0] sum_all = {sum_low[24], sum_low} + {sum_high[24], sum_high};
    
    reg signed [25:0] sum_s3;
    reg [3:0] neuron_s3;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            sum_s3 <= 26'sd0;
            neuron_s3 <= 4'd0;
        end else if (mac_enable) begin
            sum_s3 <= sum_all;
            neuron_s3 <= neuron_s2;
        end
    end
    
    reg signed [31:0] accumulator [0:9];
    integer i;
    
    initial begin
        for (i = 0; i < 10; i = i + 1) begin
            accumulator[i] = 32'sd0;
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n || mac_reset) begin
            for (i = 0; i < 10; i = i + 1) begin
                accumulator[i] <= 32'sd0;
            end
        end else if (mac_enable) begin
            accumulator[neuron_s3] <= accumulator[neuron_s3] + {{6{sum_s3[25]}}, sum_s3};
        end
    end
    
    reg [3:0] max_neuron_comb;
    reg signed [31:0] max_activation_comb;
    
    always @(*) begin
        max_neuron_comb = 4'd0;
        max_activation_comb = accumulator[0];
        
        if (accumulator[1] > max_activation_comb) begin
            max_neuron_comb = 4'd1;
            max_activation_comb = accumulator[1];
        end
        if (accumulator[2] > max_activation_comb) begin
            max_neuron_comb = 4'd2;
            max_activation_comb = accumulator[2];
        end
        if (accumulator[3] > max_activation_comb) begin
            max_neuron_comb = 4'd3;
            max_activation_comb = accumulator[3];
        end
        if (accumulator[4] > max_activation_comb) begin
            max_neuron_comb = 4'd4;
            max_activation_comb = accumulator[4];
        end
        if (accumulator[5] > max_activation_comb) begin
            max_neuron_comb = 4'd5;
            max_activation_comb = accumulator[5];
        end
        if (accumulator[6] > max_activation_comb) begin
            max_neuron_comb = 4'd6;
            max_activation_comb = accumulator[6];
        end
        if (accumulator[7] > max_activation_comb) begin
            max_neuron_comb = 4'd7;
            max_activation_comb = accumulator[7];
        end
        if (accumulator[8] > max_activation_comb) begin
            max_neuron_comb = 4'd8;
            max_activation_comb = accumulator[8];
        end
        if (accumulator[9] > max_activation_comb) begin
            max_neuron_comb = 4'd9;
            max_activation_comb = accumulator[9];
        end
    end
    
    reg [3:0] digit_out_reg;
    reg valid_out_reg;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            digit_out_reg <= 4'd0;
            valid_out_reg <= 1'b0;
        end else if (classify) begin
            digit_out_reg <= max_neuron_comb;
            valid_out_reg <= 1'b1;
        end else begin
            valid_out_reg <= 1'b0;
        end
    end
    
    assign digit_out = digit_out_reg;
    assign valid_out = valid_out_reg;

endmodule
