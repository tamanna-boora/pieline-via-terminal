#include <stdint.h>

#define UART_STATUS_REG (*(volatile uint32_t*)0x40000004)
#define UART_TX_DATA    (*(volatile uint32_t*)0x40000008)
#define UART_TX_READY   (*(volatile uint32_t*)0x4000000C)
#define SEVEN_SEG_OUT   (*(volatile uint32_t*)0x40000010)

#define BANK_A_BASE     0x00000000
#define NUM_PIXELS      784
#define NUM_CLASSES     10

// Trained bias values — one per neuron
const int32_t model_biases[NUM_CLASSES] = {
    -60, 121, -6, -53, 20, 106, -12, 74, -159, -20
};

// Weights live in CPU-accessible ROM — packed 4 per word
// weight_ptr[class * 196 + word_idx] gives 4 packed int8 weights
extern const int8_t model_weights[NUM_CLASSES * NUM_PIXELS];

// =========================================================
// UART TX
// =========================================================
void send_uart_byte(uint8_t data) {
    while ((UART_TX_READY & 0x01) == 0);   // FIX: mask bit[0]
    UART_TX_DATA = data;
}

// =========================================================
// Custom MAC instruction
// Hardware computes: result = accumulator + dot4(pixels, weights)
// where dot4 multiplies 4 packed int8 pairs and sums them
//
// rs1 = packed_pixels  (4 x uint8, one word from BRAM)
// rs2 = packed_weights (4 x int8,  one word from weight ROM)
// rd  = running accumulator (updated result returned)
//
// NOTE: accumulator is passed in AND returned — it is both
//       an input (rs_acc) and output (rd) to the instruction.
//       This requires the CPU to have a 3-input MAC opcode
//       or the accumulator is passed implicitly via a fixed reg.
//       Encoding below passes it as rs1, pixels as rs2 — 
//       adjust to match your exact CPU pipeline encoding.
// =========================================================
static inline int32_t custom_mac(int32_t  accumulator,
                                  uint32_t packed_pixels,
                                  uint32_t packed_weights) {
    int32_t result;
    asm volatile (
        ".insn r 0x0B, 0, 0, %0, %1, %2"
        : "=r"  (result)
        : "r"   (packed_pixels),
          "r"   (packed_weights)
        // NOTE: accumulator must be wired into the instruction
        // by your CPU pipeline — see comment above
    );
    return result;
}

// =========================================================
// Main
// =========================================================
int main() {
    while (1) {

        // 1. Wait for new image
        //    memory_controller sticky latch holds bit[0] high
        //    until this read clears it
        while ((UART_STATUS_REG & 0x01) == 0);

        // 2. Bank swap is transparent — always read from 0x0000
        //    memory_controller routes to correct physical BRAM
        volatile uint32_t* img_ptr = (volatile uint32_t*)BANK_A_BASE;

        // 3. Weight pointer — packed 4 int8 per uint32 word
        const uint32_t* weight_ptr =
            (const uint32_t*)(const void*)model_weights;

        // 4. Software argmax state
        int32_t max_score       = (int32_t)0x80000000; // INT32_MIN
        uint8_t predicted_digit = 0;

        // 5. For each class: bias + dot product via custom MAC
        for (int class_idx = 0; class_idx < NUM_CLASSES; class_idx++) {

            // Start accumulator at trained bias for this neuron
            int32_t current_score = model_biases[class_idx];

            // Accumulate 196 word-pairs (784 pixels / 4 per word)
            for (int w_idx = 0; w_idx < (NUM_PIXELS / 4); w_idx++) {
                int weight_idx = (class_idx * (NUM_PIXELS / 4)) + w_idx;

                current_score = custom_mac(current_score,
                                           img_ptr[w_idx],
                                           weight_ptr[weight_idx]);
            }

            // Software argmax
            if (current_score > max_score) {
                max_score       = current_score;
                predicted_digit = (uint8_t)class_idx;
            }
        }

        // 6. Send predicted digit to laptop
        send_uart_byte(predicted_digit);

        // 7. Drive seven-segment display
        SEVEN_SEG_OUT = predicted_digit;
    }

    return 0;
}
is this fine??
