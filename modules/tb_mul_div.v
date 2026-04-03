`timescale 1ns / 1ps

module tb_mul_div;

    // ----------------------------------------------------------------
    // 1. SIGNAL DECLARATIONS
    // ----------------------------------------------------------------
    reg        clk;
    reg        rst;

    reg        div_start;
    reg  [2:0] div_funct3;
    reg [31:0] dividend, divisor;
    wire[31:0] quotient, remainder;
    wire       div_busy;

    reg [31:0] mul_a, mul_b;
    reg  [2:0] mul_funct3;
    wire[31:0] mul_low, mul_high;

    integer pass_count, fail_count;

    // ----------------------------------------------------------------
    // 2. DUT INSTANTIATION
    // ----------------------------------------------------------------
    optimal_div_32 DUT_DIV (
        .clk        (clk),
        .rst        (rst),
        .start      (div_start),
        .funct3     (div_funct3),
        .dividend_i (dividend),
        .divisor_i  (divisor),
        .quotient_o (quotient),
        .remainder_o(remainder),
        .busy_o     (div_busy)
    );

    optimal_mul_32 DUT_MUL (
        .clk   (clk),
        .rst   (rst),
        .a     (mul_a),
        .b     (mul_b),
        .funct3(mul_funct3),
        .low   (mul_low),
        .high  (mul_high)
    );

    // ----------------------------------------------------------------
    // 3. CLOCK
    // ----------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // 4. TASKS  ← ADD ALL TASKS HERE, before initial begin
    // ----------------------------------------------------------------

    // --- Multiplier Task ---
    task mul_test;
        input [31:0] a, b;
        input  [2:0] funct3;
        input [31:0] exp_low, exp_high;
        input [127:0] label;
        begin
            @(negedge clk);
            mul_a      = a;
            mul_b      = b;
            mul_funct3 = funct3;

            repeat(3) @(posedge clk);
            #1;

            if (mul_low === exp_low) begin
                $display("PASS | %s | low=%0h", label, mul_low);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL | %s | low: expected=%0h got=%0h",
                          label, exp_low, mul_low);
                fail_count = fail_count + 1;
            end

            if (funct3 != 3'b000) begin
                if (mul_high === exp_high) begin
                    $display("PASS | %s | high=%0h", label, mul_high);
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL | %s | high: expected=%0h got=%0h",
                              label, exp_high, mul_high);
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask

    // --- Normal Division Task (with timeout watchdog) ---
    task div_test;
        input [31:0] dvd, dvs;
        input  [2:0] funct3;
        input [31:0] exp_q, exp_r;
        input [127:0] label;

        integer timeout;   // ← watchdog counter
        begin
            @(negedge clk);
            dividend   = dvd;
            divisor    = dvs;
            div_funct3 = funct3;
            div_start  = 1;

            @(negedge clk);
            div_start = 0;

            // Wait for busy to rise (with 10-cycle timeout)
            timeout = 0;
            while (!div_busy && timeout < 10) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 10) begin
                $display("FAIL | %s | TIMEOUT — div_busy never asserted!", label);
                fail_count = fail_count + 1;
            end else begin
                // Wait for busy to fall (with 50-cycle timeout)
                timeout = 0;
                while (div_busy && timeout < 50) begin
                    @(posedge clk);
                    timeout = timeout + 1;
                end

                if (timeout >= 50) begin
                    $display("FAIL | %s | TIMEOUT — div_busy never released!", label);
                    fail_count = fail_count + 1;
                end else begin
                    @(posedge clk); #1;

                    if (quotient === exp_q && remainder === exp_r) begin
                        $display("PASS | %s | Q=%0d R=%0d",
                                  label, quotient, remainder);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("FAIL | %s | Expected Q=%0d R=%0d | Got Q=%0d R=%0d",
                                  label, exp_q, exp_r, quotient, remainder);
                        fail_count = fail_count + 1;
                    end
                end
            end
        end
    endtask

    // --- Divide-by-Zero Task ---
    task div_zero_test;
        input [31:0] dvd;
        input  [2:0] funct3;
        input [127:0] label;
        begin
            @(negedge clk);
            dividend   = dvd;
            divisor    = 32'd0;
            div_funct3 = funct3;
            div_start  = 1;

            @(posedge clk); #1;
            div_start = 0;

            if (quotient === 32'hFFFFFFFF && remainder === dvd) begin
                $display("PASS | %s | Q=%0h R=%0d", label, quotient, remainder);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL | %s | Expected Q=FFFFFFFF R=%0d | Got Q=%0h R=%0d",
                          label, dvd, quotient, remainder);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // 5. MAIN STIMULUS  ← initial begin starts here
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("tb_mul_div.vcd");
        $dumpvars(0, tb_mul_div);

        pass_count = 0;
        fail_count = 0;

        // Reset
        rst       = 0;
        div_start = 0;
        mul_a = 0; mul_b = 0; mul_funct3 = 0;
        dividend = 0; divisor = 0; div_funct3 = 0;

        repeat(4) @(posedge clk);
        @(negedge clk); rst = 1;
        repeat(2) @(posedge clk);

        // ---- Multiplier Tests ----
        $display("\n===== MULTIPLIER TESTS =====");
        mul_test(32'd10, 32'd5, 3'b000, 32'd50, 32'd0, "MUL 10*5");
        mul_test(-32'd10, 32'd4, 3'b000, 32'hFFFFFFD8, 32'd0, "MUL -10*4");
        mul_test(32'd0, 32'hDEADBEEF, 3'b000, 32'd0, 32'd0, "MUL 0*X");
        mul_test(32'hFFFFFFFF, 32'hFFFFFFFF, 3'b000, 32'h00000001, 32'd0, "MUL 0xFFFFFFFF*0xFFFFFFFF");
        mul_test(32'h80000000, 32'h80000000, 3'b001, 32'h00000000, 32'h40000000, "MULH 0x80000000^2");
        mul_test(32'hFFFFFFFF, 32'hFFFFFFFF, 3'b011, 32'h00000001, 32'hFFFFFFFE, "MULHU 0xFFFFFFFF^2");
        mul_test(32'hFFFFFFFF, 32'hFFFFFFFF, 3'b010, 32'h00000001, 32'hFFFFFFFF, "MULHSU (-1)*(2^32-1)");

        $display("\n--- Pipeline throughput test ---");
        @(negedge clk); mul_a=32'd3; mul_b=32'd3; mul_funct3=3'b000;
        @(negedge clk); mul_a=32'd7; mul_b=32'd7; mul_funct3=3'b000;
        repeat(3) @(posedge clk); #1;
        if (mul_low === 32'd49) begin
            $display("PASS | Pipeline throughput | 7*7=49 got %0d", mul_low);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL | Pipeline throughput | expected 49 got %0d", mul_low);
            fail_count = fail_count + 1;
        end

        // ---- Divider Tests ----
        $display("\n===== DIVIDER TESTS =====");
        div_test(32'd100, 32'd7, 3'b101, 32'd14, 32'd2, "DIVU 100/7");
        div_test(32'hFFFFFF9C, 32'd7, 3'b100, 32'hFFFFFFF2, 32'hFFFFFFFE, "DIV (signed) -100/7");
        div_test(32'hFFFFFF9C, 32'hFFFFFFF9, 3'b100, 32'd14, 32'hFFFFFFFE, "DIV (signed) -100/-7");
        div_test(32'd3, 32'd100, 3'b101, 32'd0, 32'd3, "DIVU 3/100");
        div_test(32'd1, 32'd1, 3'b101, 32'd1, 32'd0, "DIVU 1/1");
        div_test(32'hFFFFFFFF, 32'd2, 3'b101, 32'd2147483647, 32'd1, "DIVU 0xFFFFFFFF/2");
        div_test(32'd1000, 32'd7, 3'b111, 32'd142, 32'd6, "REMU 1000/7");
        div_test(32'h80000000, 32'hFFFFFFFF, 3'b100, 32'h80000000, 32'd0, "DIV overflow");

        // ---- Divide-by-Zero Tests ----
        $display("\n===== DIVIDE-BY-ZERO TESTS =====");
        div_zero_test(32'd50, 3'b101, "DIVU 50/0");
        div_zero_test(32'd50, 3'b100, "DIV  50/0");
        div_zero_test(32'd0,  3'b101, "DIVU 0/0");

        // ---- Summary ----
        $display("\n========================================");
        $display("  TOTAL: %0d PASSED  |  %0d FAILED", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

endmodule
