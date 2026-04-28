import numpy as np
import tensorflow as tf
import serial
import time
import sys

# ============================================================
#  EDIT THIS: Your Nexys A7 COM Port
#  Find this in Windows Device Manager -> Ports (COM & LPT)
#  It usually looks like 'COM3', 'COM4', 'COM5', etc.
# ============================================================
COM_PORT = 'COM6'       
BAUD_RATE = 1000000     # Must match your riscv_top.v parameter!

# ============================================================
#  Get User Input
# ============================================================
try:
    IMAGE_INDEX = int(input("Enter MNIST test image index (0-9999): "))
except ValueError:
    print("Invalid input. Please enter a number.")
    sys.exit(1)

# ============================================================
#  Load MNIST & Format Data
# ============================================================
print("Loading MNIST dataset...")
(_, _), (x_test, y_test) = tf.keras.datasets.mnist.load_data()

# Extract 784 pixels as a list of integers (0-255)
pixels = x_test[IMAGE_INDEX].flatten().tolist()   
true_label = int(y_test[IMAGE_INDEX])

print(f"\n--- MNIST Test Image #{IMAGE_INDEX} ---")
print(f"True label : {true_label}")
print(f"Pixels     : {len(pixels)} (28x28)")

# Convert the integer list into a raw bytearray
# This is exactly what the hardware UART RX pin expects!
byte_data = bytearray(pixels)

# ============================================================
#  Hardware Communication (UART)
# ============================================================
print(f"\nConnecting to FPGA on {COM_PORT} at {BAUD_RATE} baud...")

try:
    # Open Serial Port
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=5)
    time.sleep(1) # Give the port a second to stabilize
    
    # 1. Transmit the 784 pixels
    print("Transmitting 784 pixels to custom RISC-V SoC...")
    ser.write(byte_data)
    ser.flush() # Ensure all bytes are pushed out of the PC buffer
    
    # 2. Wait for the hardware to run the Neural Network and reply
    print("Inference running... waiting for response.")
    
    start_time = time.time()
    response = ser.read(1) # Read exactly 1 byte
    end_time = time.time()
    
    # 3. Display Results
    if response:
        predicted_digit = int.from_bytes(response, byteorder='little')
        inference_time = (end_time - start_time) * 1000 # convert to ms
        
        print(f"\n=====================================")
        print(f"✅ FPGA PREDICTION : {predicted_digit}")
        print(f"✅ TRUE LABEL      : {true_label}")
        print(f"⏱️ Inference Time  : {inference_time:.2f} ms")
        print(f"=====================================\n")
        
        if predicted_digit == true_label:
            print("MATCH! The neural network worked perfectly on hardware.")
        else:
            print("MISMATCH. The hardware predicted a different number.")
            
    else:
        print("\n❌ Error: FPGA timed out. It did not send a byte back.")
        print("Check the following:")
        print("1. Did you press the physical RESET button (BTNC) on the board before running this?")
        print("2. Is SIM_MODE = 1 in your Verilog?")
        print("3. Did the Synthesis 'mem' files load correctly?")
        
    ser.close()
    
except serial.SerialException as e:
    print(f"\n[ERROR] Could not open {COM_PORT}.")
    print(f"Detail: {e}")
    print("Is the board plugged in? Is Vivado Hardware Manager blocking the port?")
