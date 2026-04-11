import numpy as np

# Assume weights shape is [10, 196] (not [10, 784])
weights = np.random.randint(-128, 128, (10, 196), dtype=np.int8)

with open('mnist_weights_packed.mem', 'w') as f:
    for neuron in range(10):
        for addr in range(0, 196, 4):  # Only 0-48 (49 groups)
            w0 = int(weights[neuron, addr])
            w1 = int(weights[neuron, addr+1])
            w2 = int(weights[neuron, addr+2])
            w3 = int(weights[neuron, addr+3])
            
            packed = ((w3 & 0xFF) << 24) | ((w2 & 0xFF) << 16) | \
                     ((w1 & 0xFF) << 8) | (w0 & 0xFF)
            
            f.write(f'{packed:08X}\n')

print(f"Generated mnist_weights_packed.mem with {10*49} lines (10 neurons × 49 groups)")
