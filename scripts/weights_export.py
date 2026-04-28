import tensorflow as tf
import numpy as np

print("1. Loading MNIST Dataset...")
mnist = tf.keras.datasets.mnist
(x_train, y_train), (x_test, y_test) = mnist.load_data()

print("2. Preprocessing Data...")
# We are using the full 28x28 resolution now (784 pixels).
# Flatten the images into a 1D array of 784 pixels and normalize (0 to 1)
x_train = x_train.reshape(-1, 784) / 255.0
x_test = x_test.reshape(-1, 784) / 255.0

print("3. Building the Neural Network...")
# A simple 1-layer network that exactly matches our FPGA hardware math
# Input shape is now 784 to match the full resolution image
model = tf.keras.models.Sequential([
    tf.keras.layers.Dense(10, input_shape=(784,), activation='softmax')
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

print("4. Training the AI on the Data...")
# This will take a few seconds on your Mac
model.fit(x_train, y_train, epochs=5, validation_data=(x_test, y_test))

print("5. Extracting and Quantizing Weights...")
# Get the learned floating-point numbers
weights, biases = model.layers[0].get_weights()

# Transpose weights so they are grouped by class (10 classes, 784 weights each)
weights = weights.T 

# Convert floats to 8-bit integers (-128 to 127) for the FPGA MAC unit
SCALE_FACTOR = 127.0
quantized_weights = np.clip(np.round(weights * SCALE_FACTOR), -128, 127).astype(np.int8)
quantized_biases = np.round(biases * SCALE_FACTOR).astype(np.int32)

print("6. Exporting Hardware Files...")
# Export weights for the Verilog Memory (weights.vh)
with open("weights.vh", "w") as f:
    for class_idx in range(10):
        # Loop now goes up to 784 for each class
        for pixel_idx in range(784):
            val = int(quantized_weights[class_idx, pixel_idx])
            hex_val = f"{(val & 0xFF):02X}\n"
            f.write(hex_val)

# Export biases for the C code
with open("biases.txt", "w") as f:
    f.write("// Paste this into your C code or a header file:\n")
    f.write("const int32_t model_biases[10] = {\n    ")
    f.write(", ".join(map(str, quantized_biases)))
    f.write("\n};\n")

print("\nSuccess! Generated 'weights.vh' and 'biases.txt'.")
