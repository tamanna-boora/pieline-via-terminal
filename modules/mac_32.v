`timescale 1ns / 1ps

// =============================================================
// mnist_mac_unit.v — Final verified version
//
// Fixes applied vs v3:
//   FIX 1: Explicit 11-bit rom_index prevents synthesis
//           truncation on the neuron*196 multiply.
//
// Confirmed correct from v3 (not changed):
//   - pipe_active drain logic (no drain counter)
//   - mac_done auto-clear on mac_enable rise
//   - safe_classify hardware interlock
//   - signed arithmetic (sign extension is automatic)
//   - valid_out sticky hold (correct for memory-mapped result)
//   - All stage resets on !rst_n || mac_reset
// =============================================================

(* use_dsp = "yes" *)
module mnist_mac_unit (
    input        clk,
    input        rst_n,

    input [31:0] pixels,       // 4 packed 8-bit pixels per word
    input [7:0]  weight_addr,  // Word address within neuron (0-195)
    input [3:0]  neuron_id,    // Target neuron (0-9)
    input        mac_enable,   // High while streaming pixel/weight words
    input        mac_reset,    // Clears accumulators + pipeline between images
    input        classify,     // Pulse after mac_done to latch result

    output [3:0] digit_out,    // Winning digit (0-9)
    output       valid_out,    // High after classify — sticky until mac_reset
    output       mac_done      // High when pipeline fully drained, safe to classify
);

    // =========================================================
    // 1. WEIGHT ROM
    //    10 neurons × 196 words = 1960 entries (indices 0–1959)
    //    Each word packs 4 × signed 8-bit weights
    // =========================================================
    (* ram_style = "block" *)
    reg [31:0] weight_rom [0:1959];
    initial $readmemh("mnist_weights_packed.mem", weight_rom);

    // Bounds clamping — hard clamp before any arithmetic
    wire [3:0] safe_neuron_id   = (neuron_id   > 4'd9)   ? 4'd9   : neuron_id;
    wire [7:0] safe_weight_addr = (weight_addr > 8'd195) ? 8'd195 : weight_addr;

    // FIX 1: Explicit 11-bit ROM index
    // max = 9*196 + 195 = 1959, requires 11 bits.
    // Zero-padding operands prevents synthesis tools from
    // truncating the intermediate multiply result.
    wire [10:0] rom_index = ({7'b0, safe_neuron_id} * 11'd196)
                          + {3'b0, safe_weight_addr};

    // =========================================================
    // 2. PIPELINE ENABLES + mac_done
    //
    //    en_s1/s2/s3 ripple mac_enable through the 3-stage pipe.
    //    pipe_active is a direct combinatorial OR — no counter.
    //    mac_done_reg asserts the cycle pipe_active falls,
    //    i.e. exactly when the last partial sum has landed in
    //    the accumulator. Auto-clears when mac_enable rises.
    // =========================================================
    reg en_s1, en_s2, en_s3;
    reg mac_done_reg;

    wire pipe_active = en_s1 | en_s2 | en_s3;

    always @(posedge clk) begin
        if (!rst_n || mac_reset) begin
            en_s1        <= 1'b0;
            en_s2        <= 1'b0;
            en_s3        <= 1'b0;
            mac_done_reg <= 1'b0;
        end else begin
            en_s1 <= mac_enable;
            en_s2 <= en_s1;
            en_s3 <= en_s2;

            if (mac_enable)
                mac_done_reg <= 1'b0;   // Clear on new data
            else
                mac_done_reg <= !pipe_active; // Assert when drained
        end
    end

    // =========================================================
    // 3. STAGE 1 — Fetch weights + unpack pixels
    //    Gated by mac_enable (pipeline entry point)
    // =========================================================
    reg signed [7:0] w0_s1, w1_s1, w2_s1, w3_s1;
    reg        [7:0] p0_s1, p1_s1, p2_s1, p3_s1;
    reg        [3:0] neuron_s1;

    always @(posedge clk) begin
        if (!rst_n || mac_reset) begin
            {w3_s1, w2_s1, w1_s1, w0_s1} <= 32'd0;
            {p3_s1, p2_s1, p1_s1, p0_s1} <= 32'd0;
            neuron_s1 <= 4'd0;
        end else if (mac_enable) begin
            {w3_s1, w2_s1, w1_s1, w0_s1} <= weight_rom[rom_index]; // FIX 1
            p0_s1 <= pixels[7:0];
            p1_s1 <= pixels[15:8];
            p2_s1 <= pixels[23:16];
            p3_s1 <= pixels[31:24];
            neuron_s1 <= safe_neuron_id;
        end
    end

    // =========================================================
    // 4. STAGE 2 — Parallel multipliers
    //    signed [7:0] × $signed({1'b0, [7:0]}) = signed [16:0]
    //    8-bit signed × 9-bit unsigned-as-signed = 17-bit result
    //    No overflow possible within declared width.
    // =========================================================
    reg signed [16:0] prod0_s2, prod1_s2, prod2_s2, prod3_s2;
    reg        [3:0]  neuron_s2;

    always @(posedge clk) begin
        if (!rst_n || mac_reset) begin
            prod0_s2 <= 17'sd0; prod1_s2 <= 17'sd0;
            prod2_s2 <= 17'sd0; prod3_s2 <= 17'sd0;
            neuron_s2 <= 4'd0;
        end else if (en_s1) begin
           prod0_s2 <= $signed(w0_s1) * $signed({1'b0, p0_s1});
prod1_s2 <= $signed(w1_s1) * $signed({1'b0, p1_s1});
prod2_s2 <= $signed(w2_s1) * $signed({1'b0, p2_s1});
prod3_s2 <= $signed(w3_s1) * $signed({1'b0, p3_s1});
            neuron_s2 <= neuron_s1;
        end
    end

    // =========================================================
    // 5. STAGE 3 — Adder tree
    //    4 × signed [16:0] summed = signed [18:0]
    //    +2 bits to hold carry from 4-way addition. No overflow.
    // =========================================================
    reg signed [18:0] sum_s3;
    reg        [3:0]  neuron_s3;

    always @(posedge clk) begin
        if (!rst_n || mac_reset) begin
            sum_s3    <= 19'sd0;
            neuron_s3 <= 4'd0;
        end else if (en_s2) begin
            sum_s3    <= $signed(prod0_s2) + $signed(prod1_s2) +
                         $signed(prod2_s2) + $signed(prod3_s2);
            neuron_s3 <= neuron_s2;
        end
    end

    // =========================================================
    // 6. ACCUMULATORS — 32-bit signed, one per neuron
    //
    //    Signed addition: sum_s3 (signed [18:0]) is automatically
    //    sign-extended to 32 bits by Verilog signed arithmetic
    //    rules — no manual bit replication needed.
    //
    //    Overflow check:
    //      Max per-cycle sum = 4 × 127 × 255 = 129,540 (19-bit)
    //      196 accumulations → max = 25,389,840 (~25-bit)
    //      Min = −25,559,040. Both fit in signed 32-bit. Safe.
    //
    //    NOTE: Firmware MUST assert mac_reset between images.
    //    Accumulators are not auto-cleared between classifications.
    // =========================================================
    reg signed [31:0] accumulator [0:9];
    integer i;

    always @(posedge clk) begin
        if (!rst_n || mac_reset) begin
            for (i = 0; i < 10; i = i + 1)
                accumulator[i] <= 32'sd0;
        end else if (en_s3) begin
            accumulator[neuron_s3] <= accumulator[neuron_s3] + $signed(sum_s3);
        end
    end

    // =========================================================
    // 7. ARGMAX — purely combinational
    //    Runs continuously. Result is stable before classify fires
    //    because safe_classify is gated by mac_done_reg, which
    //    only asserts after the pipeline is fully drained.
    // =========================================================
    reg [3:0]         max_neuron_comb;
    reg signed [31:0] max_val_comb;
    integer j;

    always @(*) begin
        max_neuron_comb = 4'd0;
        max_val_comb    = accumulator[0];
        for (j = 1; j < 10; j = j + 1) begin
            if (accumulator[j] > max_val_comb) begin
                max_val_comb    = accumulator[j];
                max_neuron_comb = j[3:0];
            end
        end
    end

    // =========================================================
    // 8. OUTPUT REGISTER
    //
    //    safe_classify: hardware interlock — classify only takes
    //    effect when the pipeline is fully drained (mac_done=1).
    //    Prevents firmware timing bugs from producing silent
    //    wrong results.
    //
    //    valid_out is STICKY — holds high after classify until
    //    mac_reset. This is correct for a memory-mapped result
    //    register: firmware can read at leisure. Clearing it
    //    after one cycle would require cycle-precise firmware
    //    reads and is fragile. The stale-writeback risk belongs
    //    in pipe.v — mac_classify_wb must be a single-cycle
    //    pulse at the WB stage, not a persistent level.
    // =========================================================
    reg [3:0] digit_out_reg;
    reg       valid_out_reg;

    wire safe_classify = classify & mac_done_reg;

    always @(posedge clk) begin
        if (!rst_n || mac_reset) begin
            digit_out_reg <= 4'd0;
            valid_out_reg <= 1'b0;
        end else if (safe_classify) begin
            digit_out_reg <= max_neuron_comb;
            valid_out_reg <= 1'b1;
        end else begin
            valid_out_reg <= valid_out_reg; // Sticky hold
        end
    end

    assign digit_out = digit_out_reg;
    assign valid_out = valid_out_reg;
    assign mac_done  = mac_done_reg;
// Paste this at the bottom of mnist_mac_unit.v
    always @(posedge clk) begin
        if (safe_classify) begin
            $display("--- FPGA ACCUMULATORS ---");
            $display("  neuron[0] = %0d", $signed(accumulator[0]));
            $display("  neuron[1] = %0d", $signed(accumulator[1]));
            $display("  neuron[2] = %0d", $signed(accumulator[2]));
            $display("  neuron[3] = %0d", $signed(accumulator[3]));
            $display("  neuron[4] = %0d", $signed(accumulator[4]));
            $display("  neuron[5] = %0d", $signed(accumulator[5]));
            $display("  neuron[6] = %0d", $signed(accumulator[6]));
            $display("  neuron[7] = %0d", $signed(accumulator[7]));
            $display("  neuron[8] = %0d", $signed(accumulator[8]));
            $display("  neuron[9] = %0d", $signed(accumulator[9]));
        end
    end

 // End of mnist_mac_unit
endmodule
