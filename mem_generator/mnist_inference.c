#include <stdint.h>

#define UART_STATUS_REG (*(volatile uint32_t*)0x40000004)
#define UART_TX_DATA    (*(volatile uint32_t*)0x40000008)
#define UART_TX_READY   (*(volatile uint32_t*)0x4000000C)
#define SEVEN_SEG_OUT   (*(volatile uint32_t*)0x40000010)
#define MAC_STATUS_REG  (*(volatile uint32_t*)0x40000014) // ADD: mac_done poll
#define BANK_A_BASE     0x00000000
#define NUM_PIXELS      784
#define NUM_CLASSES     10

void send_uart_byte(uint8_t data) {
    while ((UART_TX_READY & 0x01) == 0);
    UART_TX_DATA = data;
}

static inline void mac_reset_hw(void) {
    asm volatile(".insn r 0x0B, 0, 2, x0, x0, x0");
}

static inline void mac_accumulate(uint32_t packed_pixels,
                                   uint8_t  weight_addr,
                                   uint8_t  neuron_id) {
    uint32_t control = ((uint32_t)(neuron_id & 0xF) << 8) | weight_addr;
    asm volatile(
        ".insn r 0x0B, 0, 0, x0, %0, %1"
        :
        : "r" (packed_pixels), "r" (control)
    );
}

static inline uint32_t mac_classify(void) {
    uint32_t result;
    asm volatile(
        ".insn r 0x0B, 0, 1, %0, x0, x0"
        : "=r" (result)
    );
    return result;
}

int main() {
    while (1) {

        // 1. Wait for new image
        while ((UART_STATUS_REG & 0x01) == 0);

        volatile uint32_t* img_ptr = (volatile uint32_t*)BANK_A_BASE;

        // 2. Reset hardware + flush pipeline
        mac_reset_hw();

        // 3. Inverted loop — fetch each pixel word once, reuse for all 10 neurons
        //    196 BRAM reads total 
        for (int addr = 0; addr < (NUM_PIXELS / 4); addr++) {
            uint32_t pixels = img_ptr[addr];
            for (int neuron = 0; neuron < NUM_CLASSES; neuron++) {
                mac_accumulate(pixels, (uint8_t)addr, (uint8_t)neuron);
            }
        }

        // 4. Hardware handshake — poll mac_done i
        //    Portable: works regardless of pipeline depth or clock speed
        //    Prevents silent failure where CPU reads stale digit_out
        //    from previous image if classify fires before pipeline drains
        while ((MAC_STATUS_REG & 0x01) == 0);

        // 5. Hardware argmax — safe_classify interlock in hardware
        //    provides second layer of protection
        uint8_t predicted_digit = (uint8_t)(mac_classify() & 0xF);

        // 6. Output result
        send_uart_byte(predicted_digit);
        SEVEN_SEG_OUT = predicted_digit;
    }

    return 0;
}
