def read_weights_vh(filename):
    weights = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('//'):
                weights.append(int(line, 16))
    return weights

def pack_weights_to_mem(weights, output_filename):
    if len(weights) != 7840:
        print(f"WARNING: Expected 7840 weights, got {len(weights)}")
    
    with open(output_filename, 'w') as f:
        f.write("// MNIST Quantized Weights - Packed Format\n")
        f.write("// Each line: [W3][W2][W1][W0]\n\n")
        
        for i in range(0, len(weights), 4):
            w0 = weights[i]
            w1 = weights[i+1] if (i+1) < len(weights) else 0
            w2 = weights[i+2] if (i+2) < len(weights) else 0
            w3 = weights[i+3] if (i+3) < len(weights) else 0
            
            packed = ((w3 & 0xFF) << 24) | ((w2 & 0xFF) << 16) | \
                     ((w1 & 0xFF) << 8) | (w0 & 0xFF)
            f.write(f'{packed:08X}\n')

weights = read_weights_vh('weights.vh')
print(f"Read {len(weights)} weights")
pack_weights_to_mem(weights, 'mnist_weights_packed.mem')
print(f"✓ Generated mnist_weights_packed.mem")

