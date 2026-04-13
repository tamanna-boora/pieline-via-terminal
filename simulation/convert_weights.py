import os

# ============================================================
#  pack_weights.py
#  Converts weights.vh (1 byte per line) into
#  mnist_weights_packed.mem (4 bytes packed per line)
#  ready for Vivado $readmemh
#
#  Usage: python pack_weights.py
#  Input : weights.vh        (in same folder)
#  Output: mnist_weights_packed.mem (in same folder)
# ============================================================

INPUT_FILE  = "weights.vh"
OUTPUT_FILE = "mnist_weights_packed.mem"

# ============================================================
print("--- Packing weights.vh → mnist_weights_packed.mem ---")

# Step 1: Read raw bytes from weights.vh
if not os.path.exists(INPUT_FILE):
    print(f"[Error] {INPUT_FILE} not found in this folder.")
    exit()

with open(INPUT_FILE, "r") as f:
    vh_bytes = [l.strip() for l in f
                if l.strip() and not l.strip().startswith('//')]

print(f"-> Bytes read     : {len(vh_bytes)}")

# Step 2: Validate
if len(vh_bytes) == 7840:
    print(f"-> Format         : 28x28 (10 neurons x 196 words x 4 bytes)")
elif len(vh_bytes) == 1960:
    print(f"-> Format         : 14x14 (10 neurons x 49 words x 4 bytes)")
else:
    print(f"[Warning] Unexpected byte count: {len(vh_bytes)}")
    print(f"  Expected 7840 for 28x28 or 1960 for 14x14")

if len(vh_bytes) % 4 != 0:
    print(f"[Error] Byte count not divisible by 4 — file may be corrupted")
    exit()

# Validate all lines are proper 2-char hex
for i, b in enumerate(vh_bytes):
    if len(b) != 2:
        print(f"[Error] Line {i+1} is not a 2-char hex byte: '{b}'")
        exit()
    try:
        int(b, 16)
    except ValueError:
        print(f"[Error] Line {i+1} is not valid hex: '{b}'")
        exit()

# Step 3: Pack 4 bytes → 1 word as {b3,b2,b1,b0}
# RTL reads: {w3,w2,w1,w0} = weight_rom[neuron][addr]
# So b0=w0=bits[7:0], b1=w1=bits[15:8], b2=w2=bits[23:16], b3=w3=bits[31:24]
words = []
for i in range(0, len(vh_bytes), 4):
    b0, b1, b2, b3 = vh_bytes[i], vh_bytes[i+1], vh_bytes[i+2], vh_bytes[i+3]
    words.append(f"{b3}{b2}{b1}{b0}")

# Step 4: Write output — no comments, Unix LF (required by Vivado $readmemh)
with open(OUTPUT_FILE, "w", newline="\n") as f:
    for w in words:
        f.write(w + "\n")

# Step 5: Verify
print(f"-> Words written  : {len(words)}")
print(f"-> Words/neuron   : {len(words)//10}")
print(f"-> Pixels covered : {(len(words)//10)*4}")
print(f"-> Line endings   : Unix LF (no \\r)")
print(f"-> Comments       : None")
print(f"-> Output file    : {OUTPUT_FILE}")
print(f"")
print(f"Sample (first 5 words):")
for w in words[:5]:
    b0 = int(w[6:8], 16); b0s = b0-256 if b0>127 else b0
    b1 = int(w[4:6], 16); b1s = b1-256 if b1>127 else b1
    b2 = int(w[2:4], 16); b2s = b2-256 if b2>127 else b2
    b3 = int(w[0:2], 16); b3s = b3-256 if b3>127 else b3
    print(f"  {w}  →  w0={b0s:4d}  w1={b1s:4d}  w2={b2s:4d}  w3={b3s:4d}")

print(f"")
print(f"✓ Done — copy {OUTPUT_FILE} to your Vivado xsim folder")


