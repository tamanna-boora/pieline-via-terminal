#include <stdint.h>

#define UART_RX_DATA  (*(volatile uint32_t*)0x40000000)
#define UART_RX_READY (*(volatile uint32_t*)0x40000004)
#define UART_TX_DATA  (*(volatile uint32_t*)0x40000008)
#define UART_TX_READY (*(volatile uint32_t*)0x4000000C)
#define SEVEN_SEG_OUT (*(volatile uint32_t*)0x40000010)

#define NUM_PIXELS 196
#define NUM_CLASSES 10

uint8_t image_buffer[NUM_PIXELS];

extern const int8_t model_weights[NUM_CLASSES * NUM_PIXELS];
extern const int32_t model_biases[NUM_CLASSES];

uint8_t read_uart_byte() {
    while (UART_RX_READY == 0) {
    }
    return (uint8_t)UART_RX_DATA;
}

void send_uart_byte(uint8_t data) {
    while (UART_TX_READY == 0) {
    }
    UART_TX_DATA = data;
}

static inline int32_t custom_mac(int32_t accumulator, int8_t pixel, int8_t weight) {
    int32_t result;
    asm volatile (
        ".insn r 0x0B, 0, 0, %0, %1, %2" 
        : "=r" (result) 
        : "r" (pixel), "r" (weight)
    );
    return result;
}

int main() {
    while (1) {
        for (int i = 0; i < NUM_PIXELS; i++) {
            image_buffer[i] = read_uart_byte();
        }

        int32_t max_score = -2147483648;
        uint8_t predicted_digit = 0;

        for (int class_idx = 0; class_idx < NUM_CLASSES; class_idx++) {
            
            int32_t current_score = model_biases[class_idx];
            
            for (int p_idx = 0; p_idx < NUM_PIXELS; p_idx++) {
                int weight_index = (class_idx * NUM_PIXELS) + p_idx;
                current_score = custom_mac(current_score, image_buffer[p_idx], model_weights[weight_index]);
            }

            if (current_score > max_score) {
                max_score = current_score;
                predicted_digit = class_idx;
            }
        }

        send_uart_byte(predicted_digit);
        SEVEN_SEG_OUT = predicted_digit;
    }
    return 0;
}
