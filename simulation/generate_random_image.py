import numpy as np
import shutil
import os

# ============================================================
#  EDIT THIS: path to your Vivado xsim folder
#  Find it: in Vivado Tcl console type:
#    get_property directory [current_project]
#  Then xsim path is:
#    <that_result>\<project_name>.sim\sim_1\behav\xsim
# ============================================================
XSIM_DIR = r"C:\Users\YourName\your_project\your_project.sim\sim_1\behav\xsim"

# ============================================================
print("--- Generating Random Test Image ---")
pixels = np.random.randint(0, 256, 196)

# FIX 1: newline="\n" forces Unix LF — required by Vivado $readmemh
with open("random_image.mem", "w", newline="\n") as f:
    for i in range(0, 196, 4):
        p0, p1, p2, p3 = pixels[i], pixels[i+1], pixels[i+2], pixels[i+3]
        f.write(f"{p3:02X}{p2:02X}{p1:02X}{p0:02X}\n")

print("-> SUCCESS: Generated 'random_image.mem'")

# FIX 2: auto-copy to xsim folder so Vivado sees the new image
dst = os.path.join(XSIM_DIR, "random_image.mem")
if os.path.exists(XSIM_DIR):
    shutil.copy("random_image.mem", dst)
    print(f"-> Copied to xsim: {dst}")
else:
    print(f"[!] xsim folder not found. Manually copy random_image.mem to:")
    print(f"    {XSIM_DIR}")

# ============================================================
accumulators = [0] * 10
try:
    with open("mnist_weights_packed.mem", "r") as f:
        lines = f.readlines()

    for neuron in range(10):
        start_idx = neuron * 49
        neuron_lines = lines[start_idx : start_idx + 49]

        acc = 0
        pixel_idx = 0
        for line in neuron_lines:
            hex_val = line.strip()

            w0 = int(hex_val[6:8], 16); w0 = w0 - 256 if w0 > 127 else w0
            w1 = int(hex_val[4:6], 16); w1 = w1 - 256 if w1 > 127 else w1
            w2 = int(hex_val[2:4], 16); w2 = w2 - 256 if w2 > 127 else w2
            w3 = int(hex_val[0:2], 16); w3 = w3 - 256 if w3 > 127 else w3

            acc += (
                (w0 * int(pixels[pixel_idx]))   +
                (w1 * int(pixels[pixel_idx+1])) +
                (w2 * int(pixels[pixel_idx+2])) +
                (w3 * int(pixels[pixel_idx+3]))
            )
            pixel_idx += 4
        accumulators[neuron] = acc

    predicted_digit = accumulators.index(max(accumulators))

    print("\n--- GOLDEN OUTPUTS FOR RANDOM IMAGE ---")
    for i in range(10):
        print(f"Neuron {i}: {accumulators[i]}")
    print(f"---------------------------------------")
    print(f"EXPECTED HARDWARE DIGIT_OUT: {predicted_digit}")
    print(f"---------------------------------------")
    print("\nNow in Vivado Tcl console run:")
    print("  restart")
    print("  run 10us")

except FileNotFoundError:
    print("\n[Warning] 'mnist_weights_packed.mem' not found in this folder.")
    print("The 'random_image.mem' was still created.")
