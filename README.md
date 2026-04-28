# RISC-V TinyML MNIST Accelerator SoC

This project is a complete, full-stack System-on-Chip (SoC) designed from the ground up for edge AI inference. It features a custom RISC-V CPU pipeline, a hardware-accelerated Multiply-Accumulate (MAC) unit, a cycle-accurate Ping-Pong BRAM memory controller, and a bare-metal C firmware driver.

The system is designed to classify handwritten digits (MNIST) in real-time by receiving raw pixels over UART, computing the neural network layers in hardware, and displaying the prediction on a 7-segment display.

**Target Board:** ARTIX Nexys A7 (100MHz)



## Architecture

* **3-stage pipeline** — IF/ID, EX, WB/MEM
* **RV32I** base integer instruction set
* **RV32M** hardware multiply and divide
* **Custom SIMD MAC unit** — processes 4 pixels per cycle using 8-bit quantized weights, mapped via RISC-V's custom-0x0B opcode space
* **UART interface** — streams image data from host PC at 1000000 baud rate
* **Ping-pong BRAM** — overlaps image loading with active inference
* **100 MHz** clock on Artix-7



## Key Numbers

|Metric|Value|
|-|-|
|Accuracy|97.2%|
|MAC throughput|4 pixels / cycle|
|MUL latency|3 cycles|
|DIV latency|34 cycles|
|LUTs used|5,047|
|DSP slices|11|



## Prerequisites

1. **Hardware Synthesis:** Xilinx Vivado (2020.1 or newer recommended)
2. **Firmware Compilation:** RISC-V GNU Compiler Toolchain (`riscv-none-elf-gcc`)
3. **Host Communication:** Python 3.x

   * Python Packages: `pyserial`, `tensorflow` (for the MNIST dataset), `numpy`, `Pillow`
   * Install via: `python -m pip install pyserial tensorflow numpy Pillow`



## Repository Structure

```
rtl/          → Verilog source files (pipeline, ALU, MUL, DIV, MAC)
peripheral/   → UART RX/TX, memory controller
sim/          → Testbench (tb_pipeline.v)
constraints/  → Nexys A7 XDC pin mapping
mem/          → imem.hex, quantized weights
firmware/     → Bare-metal C inference driver
scripts/      → Python host scripts (send image, export weights)
```



## Step 1: Compile the Firmware

Before synthesizing the hardware, you must compile the C code into machine code so it can be baked into the FPGA's Block RAM (BRAM).

1. Open a terminal and navigate to the firmware/software directory.
2. Run the make command to compile the specific program (e.g., MNIST):

&#x20;   ```bash
    make clean
    make mnist
    ```

3. This will generate `imem.hex` (Instruction Memory) and `dmem.hex` (Data Memory). **Ensure these files are in your Vivado project directory or updated in your `$readmemh` paths.**



## Step 2: Synthesize the FPGA Hardware

1. Open Vivado and create/open your project.
2. **Add Sources:** Add all Verilog (`.v`) files, the constraints (`.xdc`) file, and the `.hex` / `.mem` files (weights and compiled firmware).
3. **Critical Parameter:** Open `riscv_top.v` and ensure the simulation mode parameter is set for physical hardware (enables the 50MHz clock divider and correct UART baud rate math):

&#x20;   ```verilog
    parameter SIM_MODE = 1;
    ```

4. Click **Run Synthesis** -> **Run Implementation** -> **Generate Bitstream**.
5. Open the **Hardware Manager**, connect your Nexys A7 board via USB, and click **Program Device**.



## Step 3: Run AI Inference (Hardware in the Loop)

Once the FPGA is programmed, the RISC-V CPU will boot, initialize its stack pointer, and wait in a polling loop for UART data.

1. **Reset the CPU:** Press the Center Button (`BTNC`) on the Nexys A7 board to firmly reset the system.
2. **Find your COM Port:** Open Windows Device Manager (or run `ls /dev/ttyUSB\*` on Linux) to find your board's serial port (e.g., `COM5`). Update the `COM_PORT` variable in the Python scripts.
3. **Run a Host Script:** Open your Python virtual environment and run one of the provided scripts:

   * **Single Inference:** Sends a single user-selected digit.

```bash
        python send_to_fpga.py
```

   * **Continuous Stress Test (Firehose):** Tests the Ping-Pong buffering by streaming multiple images back-to-back at 1 Mbps with zero delay.

```bash
        python test_ping_pong.py
```

   * **Human-Visible Demo:** Sends images but pauses for 1.5 seconds between each so you can read the 7-segment display.

```bash
        python demo_slowed.py
```



## Physical Dashboard (LED Indicators)

The Nexys A7 LEDs act as a real-time diagnostic dashboard for the SoC pipeline:

|Indicator|Component|Behavior|
|-|-|-|
|**LED\[15]**|CPU Exception|**OFF** = Healthy. **ON** = CPU crashed (illegal instruction/stack error).|
|**LED\[12]**|MAC Accelerator|**Pulses ON** for 0.25s when the hardware MAC finishes processing an image.|
|**LED\[11]**|UART TX Busy|**ON** briefly when the FPGA is transmitting the answer back to the PC.|
|**LED\[10]**|UART RX Done|**Pulses ON** for 0.25s when a full 784-byte image is successfully received.|
|**LED\[9:0]**|Program Counter|Shows the current execution address. Appears as a steady glow during fast loops.|
|**7-Segment**|Final Output|Instantly displays the neural network's final predicted digit (0-9).|



## Team — Group 25, IIT Guwahati

|Name|GitHub ID|Contribution|
|-|-|-|
|Tamanna|tamanna-boora|Pipeline decode, hazard forwarding, I/O mapping|
|Pakhi Debnath|pakhi2307|MAC accelerator, MUL/DIV integration|
|Aditi Malav|aditi-malav|Multiplier, divider, testbench|
|Ravleen Kaur|rkaur161205-sudo|UART, memory controller, 7-segment display|
|Vastu|Vastu-verma|Weights quantization, C firmware, Python scripts|

**Demo**: [Hardware Demo Link](https://drive.google.com/file/d/1vSsldxbJOqpfO85OARW3auFoufT1399b/view?usp=sharing)

**Report:** [Report Link](https://drive.google.com/file/d/1E0w1jG3USOAAl6f7Ml8rW8RyE_TJ82_e/view?usp=drive_link)



*CS224 — Hardware Lab · IIT Guwahati · April 2026*



