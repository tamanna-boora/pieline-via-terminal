import numpy as np
import tensorflow as tf
import serial
import time

COM_PORT = 'COM6'       # Change to your port
BAUD_RATE = 1000000 
BATCH_SIZE = 5          # Number of images to stream back-to-back

print("Loading MNIST dataset...")
(_, _), (x_test, y_test) = tf.keras.datasets.mnist.load_data()

# 1. Prepare a continuous stream of images
batch_pixels = bytearray()
true_labels = []

print(f"Packing {BATCH_SIZE} images into a continuous stream...")
for i in range(BATCH_SIZE):
    pixels = x_test[i].flatten().tolist()
    batch_pixels.extend(pixels)
    true_labels.append(int(y_test[i]))

print(f"Total payload: {len(batch_pixels)} bytes.")

# 2. Open the Firehose!
try:
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=2)
    time.sleep(1) # Stabilize
    
    start_time = time.time()
    
    # BLAST all images at once. 
    # Python does not wait for an answer between images!
    print("\n🚀 Firing continuous pixel stream at FPGA...")
    ser.write(batch_pixels)
    ser.flush()
    
    # 3. Catch the answers as they pop out
    print("⏳ Waiting for hardware pipeline to catch up...\n")
    
    for i in range(BATCH_SIZE):
        response = ser.read(1)
        if response:
            predicted = int.from_bytes(response, byteorder='little')
            
            # Print the comparison
            match = "✅" if predicted == true_labels[i] else "❌"
            print(f"Image {i+1} | True: {true_labels[i]} | FPGA: {predicted} {match}")
        else:
            print(f"⚠️ Image {i+1} | FPGA dropped the connection or timed out!")
            break

    end_time = time.time()
    print(f"\n⏱️ Total Batch Time: {(end_time - start_time)*1000:.2f} ms")
    
    ser.close()
except Exception as e:
    print(f"Error: {e}")
