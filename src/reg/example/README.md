# Register infrastructure examples

`reg.example` demonstrates how to describe register maps in Regio YAML,
connect generated register blocks to application logic, and route an
AXI4-Lite control interface through a generated address decoder.

## Contents

| Component | Description |
|-----------|-------------|
| `example_component` | Application logic connected to a generated AXI4-Lite register block |
| `example_top` | Generated decoder feeding peripherals in control and datapath clock domains |
| `example_reg_blk__reg_if` | Alternative register-block implementation using `reg_intf` directly |
| [`example.yaml`](regio/example.yaml) | Register fields, access modes, initial values, enums, and arrays |
| [`example_decoder.yaml`](regio/example_decoder.yaml) | Address assignments for the example peripherals |

The examples use the [register primitives](../README.md),
[AXI4-Lite components](../../axi4l/README.md), and
[Regio templates](../regio-templates/README.md).

## Register block integration

`example_component` instantiates `example_reg_intf` and the generated
`example_reg_blk`, connecting its `axil_if` port to the control interface.
Application logic reads typed writable fields and drives read-only
registers through their `_nxt` values and `_nxt_v` update enables.

The example includes structured fields and enum values, full-word storage,
register arrays, write-event data delivery, and a read-event counter.
`input_valid` captures `input_data` for software readback; writes to the
write-event register produce `output_valid` and `output_data`. The
read-event indication lets the application clear a counter after a read.
Access events expose the transaction to application logic; side effects
such as clearing a counter are implemented in that logic.

`example_reg_blk__reg_if` is a separately maintained implementation using
the primitive register request/acknowledge interface. It illustrates an
alternative to the generated AXI4-Lite block and is not an output of the
current templates.

## Decoder and clock domains

`example_top` uses the generated `example_decoder` to route accesses and
translate addresses into each peripheral's local register space.

| Peripheral | Base byte address | Register clock domain |
|------------|-------------------|-----------------------|
| `example_component_0` | `0x0000` | `axil_if.aclk` |
| `example_component_1` | `0x1000` | `axil_if.aclk` |
| `example_component_2` | `0x4000` | `clk`, reached through `axi4l_intf_cdc` |

The control-clock peripherals exchange write-event output data. The
peripheral in the `clk` domain loops its output back to its input. Its
AXI4-Lite interface crosses into that domain before reaching the register
block. Generated application interfaces do not synchronize signals across
clock domains; choose the register clock domain and any additional control
or status synchronization as part of the surrounding design.

## Generating a register map

The [`regio/Makefile`](regio/Makefile) lists block and decoder YAML files
and includes the shared register-generation rules. Generate these example
artifacts from this directory with:

```sh
make -C regio/ reg
```

Consumers declare `reg.example.regio.rtl` or `reg.example.regio.verif` as
component dependencies; dependent builds generate the required artifacts
automatically. Maintain the YAML specifications and templates rather than
editing generated files in the build output tree.

For a new component, define its block YAML and any parent decoder map,
list them in its `regio/Makefile`, and declare the generated component
dependencies. Instantiate the generated block and application interface,
then connect fields, update enables, and events to the application logic.
The [template guide](../regio-templates/README.md) describes the outputs
and regeneration rules.

## Verification

The SVUnit suites use generated typed register agents over an AXI4-Lite
transport. They check register initialization, structured field readback,
and array accesses in the standalone component and through the top-level
decoder, including the asynchronous peripheral path.

These are integration examples rather than exhaustive checks of every
access mode or application side effect. The alternative `reg_intf` block
is outside the suites' coverage.

Run from this directory:

```sh
# Individual testbenches
make -C tests/example_component/
make -C tests/example_top/

# Regression
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
