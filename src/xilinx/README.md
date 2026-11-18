# Xilinx components

Xilinx-oriented RAM inference templates and integration helpers for vendor
IP. Simulation requirements depend on the sub-library: inferred memories
use ordinary SystemVerilog arrays, while VitisNetP4 uses generated IP,
vendor simulation libraries, and DPI-C drivers.

## Contents

| Library | Description |
|---------|-------------|
| [`xilinx.ram`](ram/README.md) | LUTRAM, BRAM, and UltraRAM inference templates and automatic SP/SDP/TDP wrappers |
| [`xilinx.vitisnetp4`](vitisnetp4/README.md) | P4 IP generation, DPI control agents, examples, and control-plane tests |

## RAM inference and constraints

`xilinx.ram` provides inferred memory implementations with configurable
width, depth, memory style, and read latency. These components support
simulation without vendor memory primitives and are exercised through the
[mem test suites](../mem/README.md#verification).

Build examples under `ram/build/` provide synthesis wrappers and timing
constraints. The RAM guide describes automatically applied synthesis
constraints and the distinction between simulation initialization and
hardware reset behavior.

## VitisNetP4 integration

`xilinx.vitisnetp4` connects P4 descriptions to the shared Vivado IP build
flow and supplies a verification agent for programming the resulting
control plane. It requires the configured Vivado installation's matching
IP, simulation libraries, DPI package, and driver library.

The forwarding control-plane suite passes with Vivado xsim 2025.2. Use
xsim for this IP: the generated RTL and exported functional netlist contain
encrypted sections, and the clock-waiting DPI exports are unsupported by
Verilator 5.054. See the [VitisNetP4 guide](vitisnetp4/README.md) for the
provided components and current simulation limits.

## Verification

There is no aggregate test suite at the Xilinx library root. RAM
verification runs through `mem`, and the VitisNetP4 forwarding suite has
its own regression entry point. Follow the sub-library guides for test
capabilities and invocation.

Simulation checks functional behavior. Memory resource inference, timing
closure, and physical implementation require the corresponding Vivado
synthesis and implementation flows.
