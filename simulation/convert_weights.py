def read_weights_vh(filename):
    weights = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('//'):
                weights.append(int(line, 16))
    return weights

def pack_weights_to_mem(weights, output_filename):
    # Check if already packed (1960 values = 32-bit packed)
    if len(weights) == 1960:
        print(f"✓ Weights already in packed format (1960 × 32-bit values)")
    elif len(weights) == 7840:
        print(f"✓ Weights in unpacked format (7840 × 8-bit values) - repacking...")
    else:
        print(f"WARNING: Unexpected weight count {len(weights)}")
        return False
    
    with open(output_filename, 'w') as f:
        f.write("// MNIST Quantized Weights - 8-bit Signed Packed\n")
        f.write("// Each line: 32-bit = [W3:W2:W1:W0]\n")
        f.write("// 10 neurons × 196 weight groups = 1960 lines\n\n")
        
        for packed_value in weights:
            f.write(f'{packed_value:08X}\n')
    
    print(f"✓ Generated {output_filename} with {len(weights)} 32-bit packed values")
    return True

# Usage
weights = read_weights_vh('weights.vh')
print(f"Read {len(weights)} weights from weights.vh")
pack_weights_to_mem(weights, 'mnist_weights_packed.mem')


