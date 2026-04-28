#include <stdint.h>

volatile int32_t normal_quotient;
volatile int32_t normal_remainder;
volatile int32_t div_by_zero_quotient;
volatile int32_t div_by_zero_remainder;

int main() {
    int32_t dividend = 100;
    int32_t divisor  = 3;
    int32_t zero     = 0;

    // Triggers the DIV and REM instructions
    normal_quotient  = dividend / divisor; // Expected: 33 (0x00000021)
    normal_remainder = dividend % divisor; // Expected: 1  (0x00000001)

    // Triggers Aditi's hardware exception block
    div_by_zero_quotient  = dividend / zero; // Expected: -1  (0xFFFFFFFF)
    div_by_zero_remainder = dividend % zero; // Expected: 100 (0x00000064)

    while(1) {}
    return 0;
}
