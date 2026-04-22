import numpy as np
import tensorflow as tf
import serial
import time

COM_PORT = 'COM6'       # Change to your port
BAUD_RATE = 1000000 
BATCH_SIZE = 5          # Number of images to show

print("Loading MNIST dataset...")
(_, _), (x_test, y_test) = tf.keras.datasets.mnist.load_data()

try:
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=2)
    time.sleep(1) # Stabilize
    
    print("\n🐌 Running in SLOW-MOTION mode for human visibility...\n")
    
    for i in range(BATCH_SIZE):
        # 1. Grab one image
        pixels = x_test[i].flatten().tolist()
        byte_data = bytearray(pixels)
        true_label = int(y_test[i])
        
        # 2. Send it to the FPGA
        print(f"Sending Image {i+1} (True Digit: {true_label})...")
        ser.write(byte_data)
        ser.flush()
        
        # 3. Read the answer
        response = ser.read(1)
        
        if response:
            predicted = int.from_bytes(response, byteorder='little')
            match = "✅" if predicted == true_label else "❌"
            print(f"  -> FPGA Predicted: {predicted} {match}")
            
            # 4. THE MAGIC FIX: Pause for 1.5 seconds!
            # This holds the number on the 7-segment display so your eyes can see it.
            print("  -> Holding display for 1.5 seconds...")
            time.sleep(1.5) 
            
        else:
            print("  -> ⚠️ FPGA timed out!")
            break

    ser.close()
    print("\nDemo complete!")
    
except Exception as e:
    print(f"Error: {e}")
