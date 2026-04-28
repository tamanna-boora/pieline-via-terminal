#include <stdint.h>

// Memory Mapped I/O for  UART
#define UART_TX_DATA  (*(volatile uint32_t*)0x40000008)
#define UART_TX_READY (*(volatile uint32_t*)0x4000000C)

void send_uart_byte(uint8_t data) {
    while (UART_TX_READY == 0) {} // Wait for hardware to be ready
    UART_TX_DATA = data;
}

int main() {
    int32_t a = 12;
    int32_t b = 5;

    // Run the hardware math
    int32_t mul_ans = a * b; // 60
    int32_t div_ans = a / b; // 2
    int32_t rem_ans = a % b; // 2

    // Send the answers over the UART cable to your laptop
    // (Sending as raw bytes. On your PC, 60 is the ASCII character '<')
    send_uart_byte((uint8_t)mul_ans);
    send_uart_byte((uint8_t)div_ans);
    send_uart_byte((uint8_t)rem_ans);

    while(1) {}
    return 0;
}
