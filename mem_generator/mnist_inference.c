#include <stdint.h>

#define UART_STATUS_REG (*(volatile uint32_t*)0x40000004)
#define UART_TX_DATA    (*(volatile uint32_t*)0x40000008)
#define UART_TX_READY   (*(volatile uint32_t*)0x4000000C)
#define SEVEN_SEG_OUT   (*(volatile uint32_t*)0x40000010)
#define MAC_STATUS_REG  (*(volatile uint32_t*)0x40000014)
#define BANK_A_BASE     0x00000000
#define NUM_PIXELS      784
#define NUM_CLASSES     10

// Forward declaration
int main(void);

// =========================================================
// 1. BOOTLOADER (Must be first!)
// =========================================================
// The "naked" attribute prevents GCC from messing with the stack here.
// Put this at the very top, right after your #includes and #defines!
// We changed section(".init") to section(".text.init")
void __attribute__((naked, section(".text.init"))) _start(void) {
    // Initialize Stack Pointer to the top of the 8KB BRAM (0x2000)
    asm volatile("li sp, 0x2000");
    // Jump safely into the main program
    asm volatile("j main");
}

// =========================================================
// 2. HELPER FUNCTIONS
// =========================================================
void send_uart_byte(uint8_t data) {
    while ((UART_TX_READY & 0x01) == 0);
    UART_TX_DATA = data;
}

static inline void mac_reset_hw(void) {
    asm volatile(".insn r 0x0B, 0, 2, x0, x0, x0");
}

static inline void mac_accumulate(uint32_t packed_pixels, uint8_t weight_addr, uint8_t neuron_id) {
    uint32_t control = ((uint32_t)(neuron_id & 0xF) << 8) | weight_addr;
    asm volatile(".insn r 0x0B, 0, 0, x0, %0, %1" :: "r" (packed_pixels), "r" (control));
}

static inline uint32_t mac_classify(void) {
    uint32_t result;
    asm volatile(".insn r 0x0B, 0, 1, %0, x0, x0" : "=r" (result));
    return result;
}

// =========================================================
// 3. MAIN LOOP
// =========================================================
int main(void) {
    while (1) {
        // Wait for image
        while ((UART_STATUS_REG & 0x01) == 0);
	// ADD THIS LINE: Clear the latch so it waits for the next image!
        UART_STATUS_REG = 0;

        volatile uint32_t* img_ptr = (volatile uint32_t*)BANK_A_BASE;
        mac_reset_hw();

        // 196 BRAM reads total 
        for (int addr = 0; addr < (NUM_PIXELS / 4); addr++) {
            uint32_t pixels = img_ptr[addr];
            for (int neuron = 0; neuron < NUM_CLASSES; neuron++) {
                mac_accumulate(pixels, (uint8_t)addr, (uint8_t)neuron);
            }
        }

        // Wait for MAC unit to finish
        while ((MAC_STATUS_REG & 0x01) == 0);

        uint8_t predicted_digit = (uint8_t)(mac_classify() & 0xF);
        
        send_uart_byte(predicted_digit);
        SEVEN_SEG_OUT = predicted_digit;
    }
    return 0;
}
