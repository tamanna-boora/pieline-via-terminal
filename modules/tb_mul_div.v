`timescale 1ns / 1ps

module tb_mul_div;

    // 1. Signal Declarations
    reg clk, rst;
    reg div_start;
    reg [2:0] div_funct3, mul_funct3;
    reg [31:0] dividend, divisor, mul_a, mul_b;
    
    wire [31:0] quotient, remainder, mul_low, mul_high;
    wire div_busy;

    // File I/O and Verification Counters
    integer file_h, status;
    integer pass_count, fail_count;
    reg [31:0] f_a, f_b, f_mul, f_q, f_r;

    // 2. DUT Instantiation
    optimal_div_32 DUT_DIV (
        .clk(clk), .rst(rst), .start(div_start), .funct3(div_funct3),
        .dividend_i(dividend), .divisor_i(divisor),
        .quotient_o(quotient), .remainder_o(remainder), .busy_o(div_busy)
    );

    optimal_mul_32 DUT_MUL (
        .clk(clk), .rst(rst), .a(mul_a), .b(mul_b), .funct3(mul_funct3),
        .low(mul_low), .high(mul_high)
    );

    // 3. Clock Generation (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // 4. Verification Logic
    initial begin
        // --- System Reset Sequence ---
        pass_count = 0; 
        fail_count = 0;
        div_start  = 0;
        rst = 0;             // Assert Reset (Active Low)
        #50;
        rst = 1;             // Release Reset
        #50;

        // --- Open Golden Model ---
        file_h = $fopen("math_gold.txt", "r");
        if (file_h == 0) begin
            $display("ERROR: math_gold.txt not found! Ensure it is in the simulation folder.");
            $finish;
        end

        $display("\n================================================");
        $display("   STARTING GOLDEN MODEL REGRESSION");
        $display("================================================\n");

       while (!$feof(file_h)) begin
            status = $fscanf(file_h, "%h %h %h %h %h\n", f_a, f_b, f_mul, f_q, f_r);
            
            if (status == 5) begin
                // --- Step 1: Multiplier Test ---
                @(negedge clk);
                mul_a = f_a; mul_b = f_b; mul_funct3 = 3'b000;
                repeat(4) @(posedge clk); 
                
                // --- Step 2: Divider Test (With Zero Check) ---
                if (f_b == 0) begin
                    $display("[%0t] SKIP | Division by Zero (A:%h / B:0)", $time, f_a);
                end else begin
                    @(negedge clk);
                    dividend = f_a; divisor = f_b; div_funct3 = 3'b100;
                    div_start = 1;      
                    
                    @(posedge div_busy); // Wait for hardware to acknowledge
                    div_start = 0;       
                    @(negedge div_busy); // Wait for hardware to finish
                    
                    #2; 
                    if (mul_low === f_mul && quotient === f_q && remainder === f_r) begin
                        pass_count = pass_count + 1;
                        $display("[%0t] PASS | A:%h B:%h | Count: %0d", $time, f_a, f_b, pass_count);
                    end else begin
                        $display("[%0t] FAIL | A:%h B:%h", $time, f_a, f_b);
                        fail_count = fail_count + 1;
                    end
                end
            end
        end
        // --- Final Result Summary ---
        $fclose(file_h);
        #100;
        $display("\n================================================");
        $display("   REGRESSION COMPLETE");
        $display("   TOTAL PASSED: %0d", pass_count);
        $display("   TOTAL FAILED: %0d", fail_count);
        $display("================================================\n");
        #100;
        $finish;
    end

endmodule
