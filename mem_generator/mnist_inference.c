#include <stdint.h>

// Peripheral Register Addresses
#define UART_STATUS_REG (*(volatile uint32_t*)0x40000004) 
#define UART_TX_DATA    (*(volatile uint32_t*)0x40000008)
#define UART_TX_READY   (*(volatile uint32_t*)0x4000000C)
#define SEVEN_SEG_OUT   (*(volatile uint32_t*)0x40000010)

// Memory Bank Base Addresses
#define BANK_A_BASE     0x00000000
#define BANK_B_BASE     0x00002000

#define NUM_PIXELS      784
#define NUM_CLASSES     10

// External weights array (Packed 4-per-word in ROM)
extern const int8_t model_weights[NUM_CLASSES * NUM_PIXELS];

// Bias values from training
const int32_t model_biases[10] = {
    -60, 121, -6, -53, 20, 106, -12, 74, -159, -20
};

// --- UART TX Helper ---
void send_uart_byte(uint8_t data) {
    while (UART_TX_READY == 0);
    UART_TX_DATA = data;
}

static inline int32_t custom_mac(int32_t accumulator, uint32_t packed_pixels, uint32_t packed_weights) {
    int32_t result;
    asm volatile (
        ".insn r 0x0B, 0, 0, %0, %1, %2" 
        : "=r" (result) 
        : "r" (packed_pixels), "r" (packed_weights)
    );
    return result;
}

int main() {
    while (1) {
        while ((UART_STATUS_REG & 0x01) == 0);

      
        uint32_t current_hw_bank = (UART_STATUS_REG & 0x02) >> 1;
        
      
        volatile uint32_t* img_ptr = (current_hw_bank == 1) ? 
                                     (volatile uint32_t*)BANK_B_BASE : 
                                     (volatile uint32_t*)BANK_A_BASE;

        int32_t max_score = -2147483648;
        uint8_t predicted_digit = 0;
        uint32_t* weight_ptr = (uint32_t*)model_weights;

     
        for (int class_idx = 0; class_idx < NUM_CLASSES; class_idx++) {
            int32_t current_score = model_biases[class_idx];
            
            for (int w_idx = 0; w_idx < (NUM_PIXELS / 4); w_idx++) {
                int weight_idx = (class_idx * (NUM_PIXELS / 4)) + w_idx;
                
                current_score = custom_mac(current_score, img_ptr[w_idx], weight_ptr[weight_idx]);
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
