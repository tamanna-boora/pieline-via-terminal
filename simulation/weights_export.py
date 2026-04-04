import numpy as np

weights = np.random.rand(10, 196) * 2 - 1
quantized_weights = np.clip(np.round(weights * 127), -128, 127).astype(np.int8)

with open("weights.vh", "w") as f:
    for class_idx in range(10):
        for pixel_idx in range(196):
            val = quantized_weights[class_idx, pixel_idx]
            hex_val = f"{(val & 0xFF):02X}\n"
            f.write(hex_val)
