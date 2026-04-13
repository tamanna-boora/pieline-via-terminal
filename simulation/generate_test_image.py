import numpy as np
import shutil
import os
import tensorflow as tf
 
# ============================================================
#  EDIT THIS: Vivado xsim folder path
# ============================================================
XSIM_DIR = r"C:\Users\yourName\mac_module_testing\mac_module_testing.sim\sim_1\behav\xsim"
 
# ============================================================
#  Choose which test image to run (0 to 9999)
# ============================================================
IMAGE_INDEX = int(input("Enter MNIST test image index (0-9999): "))
 
# ============================================================
def signed8(val):
    v = int(val)
    return v - 256 if v > 127 else v
 
def is_valid_hex(s):
    s = s.strip().replace('\r','')
    if len(s) != 8:
        return False
    try:
        int(s, 16)
        return True
    except ValueError:
        return False
 
# ============================================================
#  Load MNIST test image via Keras (no manual download needed)
#  First run downloads automatically (~11MB), cached after that
# ============================================================
print("Loading MNIST dataset...")
(_, _), (x_test, y_test) = tf.keras.datasets.mnist.load_data()
 
pixels     = x_test[IMAGE_INDEX].flatten().tolist()   # 784 pixels, 0-255
true_label = int(y_test[IMAGE_INDEX])
 
print(f"\n--- MNIST Test Image #{IMAGE_INDEX} ---")
print(f"True label : {true_label}")
print(f"Pixels     : {len(pixels)} (28x28)")
 
# ============================================================
#  Write random_image.mem  –  196 words, Unix LF
# ============================================================
with open("random_image.mem", "w", newline="\n") as f:
    for i in range(0, 784, 4):
        p0, p1, p2, p3 = pixels[i], pixels[i+1], pixels[i+2], pixels[i+3]
        f.write(f"{p3:02X}{p2:02X}{p1:02X}{p0:02X}\n")
 
print("-> random_image.mem written (196 words)")
 
# Copy to xsim folder
dst = os.path.join(XSIM_DIR, "random_image.mem")
if os.path.exists(XSIM_DIR):
    shutil.copy("random_image.mem", dst)
    print(f"-> Copied to xsim: {dst}")
else:
    print(f"[Warning] xsim folder not found. Copy random_image.mem manually.")
 
# ============================================================
#  Golden reference model  –  10 neurons x 196 words
# ============================================================
try:
    with open("mnist_weights_packed.mem", "r") as f:
        lines = [l.strip().replace('\r','') for l in f if is_valid_hex(l)]
 
    print(f"-> Weights : {len(lines)} lines ({len(lines)//10} words/neuron)")
 
    if len(lines) < 1960:
        print(f"[Warning] Expected 1960 lines for 28x28, got {len(lines)}")
 
    accumulators = [0] * 10
    for neuron in range(10):
        neuron_lines = lines[neuron * 196 : neuron * 196 + 196]
        acc = 0
        pixel_idx = 0
        for line in neuron_lines:
            w0 = signed8(int(line[6:8], 16))
            w1 = signed8(int(line[4:6], 16))
            w2 = signed8(int(line[2:4], 16))
            w3 = signed8(int(line[0:2], 16))
            acc += w0*pixels[pixel_idx]   + w1*pixels[pixel_idx+1] + \
                   w2*pixels[pixel_idx+2] + w3*pixels[pixel_idx+3]
            pixel_idx += 4
        accumulators[neuron] = acc
 
    predicted_digit = accumulators.index(max(accumulators))
 
    print("\n--- EXPECTED OUTPUTS (match these in Vivado) ---")
    for i in range(10):
        marker = " <-- MAX" if i == predicted_digit else ""
        print(f"  neuron[{i}] = {accumulators[i]}{marker}")
    print(f"------------------------------------------------")
    print(f"  True digit          = {true_label}")
    print(f"  EXPECTED digit_out  = {predicted_digit}")
    print(f"  Correct prediction? = {'YES ✓' if predicted_digit == true_label else 'NO ✗'}")
    print(f"------------------------------------------------")
    print("\nNow in Vivado Tcl console run:")
    print("  restart")
    print("  run 50us")
 
except FileNotFoundError:
    print("\n[Error] mnist_weights_packed.mem not found.")
    print("  Keep it in the same folder as this script.")
