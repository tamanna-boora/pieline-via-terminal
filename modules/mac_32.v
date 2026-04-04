`timescale 1ns / 1ps

module mac_32 (
    input  wire        clk,
    input  wire        rst,       // Active-low, SYNCHRONOUS (matches mul_32)
    input  wire        clear,     // Synchronous clear — flushes pipeline + acc
    input  wire        enable,    // High when input (a, b) is valid
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  funct3,    // Signed/Unsigned control (same as mul_32)
    output reg  [63:0] acc,       // 64-bit accumulator
    output wire        acc_valid  // High when acc holds a valid accumulated result
);

    // ----------------------------------------------------------------
    // 1. Multiplier Instantiation (3-cycle pipeline)
    // ----------------------------------------------------------------
    wire [31:0] mul_low, mul_high;
    wire [63:0] mul_result = {mul_high, mul_low};

    optimal_mul_32 MULT_UNIT (
        .clk   (clk),
        .rst   (rst),
        .a     (a),
        .b     (b),
        .funct3(funct3),
        .low   (mul_low),
        .high  (mul_high)
    );

    // ----------------------------------------------------------------
    // 2. Pipeline registers — delay enable AND clear by 3 cycles
    //
    //   Cycle 0: a,b driven        → enable asserted
    //   Cycle 1: Stage1 (a_reg)    → enable_pipe[0]
    //   Cycle 2: Stage2 (prod_reg) → enable_pipe[1]
    //   Cycle 3: Stage3 (final_out)→ enable_pipe[2] = valid_product
    //
    //   clear is pipelined identically so it arrives at the accumulator
    //   at the same time as the last in-flight product — wiping acc
    //   AFTER that product is consumed, not before.
    // ----------------------------------------------------------------
    reg [2:0] enable_pipe;
    reg [2:0] clear_pipe;

    always @(posedge clk) begin
        if (!rst) begin
            enable_pipe <= 3'b000;
            clear_pipe  <= 3'b000;
        end else begin
            enable_pipe <= {enable_pipe[1:0], enable};
            clear_pipe  <= {clear_pipe[1:0],  clear};
        end
    end

    wire valid_product  = enable_pipe[2];
    wire delayed_clear  = clear_pipe[2];   // arrives when pipeline is drained

    // ----------------------------------------------------------------
    // 3. Accumulation Logic
    //
    //   For signed funct3 (000, 001, 010): mul_result is a signed 64-bit
    //   value stored in two's complement. Adding it directly to acc works
    //   correctly in 64-bit two's complement arithmetic — no extra casting
    //   needed as long as acc is also treated as signed by the consumer.
    //
    //   Priority: delayed_clear > valid_product
    //   (clear wins so a new dot-product starts clean)
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            acc <= 64'd0;
        end else if (delayed_clear) begin
            // Flush: pipeline is drained, safe to wipe accumulator
            acc <= 64'd0;
        end else if (valid_product) begin
            acc <= acc + mul_result;
        end
    end

    // ----------------------------------------------------------------
    // 4. acc_valid flag
    //   Useful for the layer above (e.g. MNIST inference controller)
    //   to know when acc holds a meaningful result.
    //   Goes high with the first valid product, stays high until clear.
    // ----------------------------------------------------------------
    reg acc_valid_reg;
    always @(posedge clk) begin
        if (!rst || delayed_clear) begin
            acc_valid_reg <= 1'b0;
        end else if (valid_product) begin
            acc_valid_reg <= 1'b1;
        end
    end
    assign acc_valid = acc_valid_reg;

endmodule
