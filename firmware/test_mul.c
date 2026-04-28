 #include <stdint.h>

// We use 'volatile' so the C compiler is forced to send the math to  hardware instead of just calculating the answer in software beforehand.
volatile int32_t test1_pos;
volatile int32_t test2_neg;
volatile int32_t test3_zero;

int main() {
    int32_t a = 25;
    int32_t b = 4;
    int32_t c = -5;
    int32_t d = 0;

    // Triggers the MUL instruction
    test1_pos  = a * b; // Expected: 100  (0x00000064)
    test2_neg  = a * c; // Expected: -125 (0xFFFFFF83)
    test3_zero = a * d; // Expected: 0    (0x00000000)

    // Infinite loop to halt the processor at the end of the test
    while(1) {} 
    return 0;
}
