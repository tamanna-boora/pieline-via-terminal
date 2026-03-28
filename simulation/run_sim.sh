#!/bin/bash

# 1. Compile the Verilog files
# We include all modules and the testbench
iverilog -o pipeline_sim.out tb_pipeline.v pipe.v IF_ID.v execute.v wb.v memory.v [cite: 184, 185, 186, 187, 188, 387]

# 2. Run the simulation
# This generates the .vcd file defined in your testbench
vvp pipeline_sim.out [cite: 389]

# 3. Open GTKWave with the generated waveform
if [ -f "pipeline_sim.vcd" ]; then
    gtkwave pipeline_sim.vcd
else
    echo "Error: VCD file not generated."
fi