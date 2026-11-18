# Xilinx RAM

SystemVerilog RAM inference templates for Xilinx distributed RAM (LUTRAM),
block RAM (BRAM), and UltraRAM. The library has no dependencies on other RTL
libraries and uses inferred arrays rather than vendor simulation primitives.

## Contents

| Component | Description |
|-----------|-------------|
| `xilinx_ram_pkg` | RAM-style selection, optimization modes, and latency helpers |
| `xilinx_ram_sp` | Single read/write port with automatic RAM-style selection and acknowledgements |
| `xilinx_ram_sdp` | Separate write and read ports, with automatic RAM-style selection and acknowledgements |
| `xilinx_ram_tdp` | Two read/write ports, with automatic RAM-style selection and acknowledgements |
| `xilinx_ram_sp_lutram`, `xilinx_ram_sdp_lutram`, `xilinx_ram_tdp_lutram` | Distributed RAM inference templates |
| `xilinx_ram_sp_bram`, `xilinx_ram_sdp_bram`, `xilinx_ram_tdp_bram` | Block RAM inference templates with optional output registers |
| `xilinx_ram_sp_uram`, `xilinx_ram_sdp_uram`, `xilinx_ram_tdp_uram` | Single-clock UltraRAM inference templates with read pipelines |

## Automatic wrappers

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ADDR_WID` | `8` | Address width; depth is `2**ADDR_WID` words |
| `DATA_WID` | `32` | Word width in bits |
| `OPT_MODE` | `xilinx_ram_pkg::OPT_MODE_TIMING` | Timing-optimized or latency-optimized RAM configuration |
| `ASYNC` | `0` | SDP/TDP only: enable selection for independent port clocks |

`ASYNC` describes the relationship between the port clocks, not an
asynchronous-read interface. All wrappers have clocked read responses.
For `ASYNC=0`, connect both port clocks to the same signal; UltraRAM uses a
single clock internally. Writes replace complete words; there are no byte
write enables.

### `xilinx_ram_sp`

Uses `clk`, `en`, `wr`, `addr`, and `wr_data`. A rising edge with `en=1`
accepts a write when `wr=1` or a read when `wr=0`. Completion appears on
`wr_ack` or `rd_ack`; sample `rd_data` with `rd_ack`.

### `xilinx_ram_sdp`

Uses independent write and read interfaces. A write is accepted on `wr_clk`
when `wr_en && wr_req`. A read is accepted on `rd_clk` when `rd_en`.
Responses are `wr_ack` and `rd_ack`/`rd_data`, each in its respective domain.

### `xilinx_ram_tdp`

Ports A and B each have `clk_*`, `en_*`, `wr_*`, `addr_*`, `wr_data_*`,
`wr_ack_*`, `rd_ack_*`, and `rd_data_*`, with the same per-port transaction
convention as `xilinx_ram_sp`.

The wrappers have no ready output or response backpressure. The application
must coordinate concurrent accesses; independent clocks and dual ports do not
make same-address read/write or write/write collisions safe.

## RAM-style selection (`xilinx_ram_pkg`)

`ram_style_t` defines `RAM_STYLE_DISTRIBUTED`, `RAM_STYLE_BLOCK`, and
`RAM_STYLE_ULTRA`. `opt_mode_t` defines `OPT_MODE_TIMING` and
`OPT_MODE_LATENCY`.

For single-clock operation, the automatic wrappers apply these rules in order:

| Condition | Selected style |
|-----------|----------------|
| `ADDR_WID <= 8` | Distributed RAM |
| `ADDR_WID <= 9` | Block RAM |
| `DATA_WID <= 16` | Block RAM |
| Total capacity `<= 65536` bits | Block RAM |
| `OPT_MODE == OPT_MODE_LATENCY` | Block RAM |
| Otherwise | UltraRAM |

For independent clocks, address widths up to 8 select distributed RAM and
larger memories select block RAM. UltraRAM is not selected for this case.
The underlying RTL arrays carry the corresponding `ram_style` attributes;
actual inference and resource mapping are performed by Vivado synthesis.

## Latency and explicit implementations

`get_wr_latency(ADDR_WID, DATA_WID, ASYNC, OPT_MODE)` and
`get_rd_latency(...)` return the automatic wrapper's write and read latencies.
The wrapper also exposes derived `WR_LATENCY` and `RD_LATENCY` localparams,
and pipelines acknowledgements to match the selected RAM configuration.

| Selected RAM | Write latency | Read latency |
|--------------|---------------|--------------|
| LUTRAM | 1 clock | 1 clock |
| BRAM, timing mode | 1 clock | 2 clocks |
| BRAM, latency mode | 1 clock | 1 clock |
| UltraRAM, `ADDR_WID <= 14` | 1 clock | 3 clocks |
| UltraRAM, `ADDR_WID == 15` | 1 clock | 4 clocks |
| UltraRAM, `ADDR_WID > 15` | 1 clock | 5 clocks |

Latencies are measured in the relevant port's clock domain. The explicit
`*_lutram`, `*_bram`, and `*_uram` modules can be instantiated when the RAM
style must be fixed rather than selected automatically. These templates
provide data paths without the wrappers' acknowledgement outputs. BRAM
variants expose output-register enable/reset controls; the automatic wrappers
keep the output-register enables asserted.

The BRAM templates fix `cascade_height=4` to preserve output-register
inference for independent clocks. UltraRAM read-pipeline depth depends on
address width; its current pipeline-depth helper does not reduce that depth
for `OPT_MODE_LATENCY`.

## Reset and initialization

The automatic wrappers provide `srst` (SP), `wr_srst` (SDP), or `srst_A`
(TDP) only when `SYNTHESIS` is not defined. These inputs accelerate simulation
initialization by clearing the array; they are not hardware memory-clear
ports. Without initialization, memory contents are unspecified.

For reset-driven initialization in hardware, use the wrappers and reset FSM
in [`mem`](../../mem/README.md), which write the required reset value through
the memory interface.

## Synthesis constraints

`build/xilinx_ram_sdp_lutram/synth.xdc` constrains the crossing from the
write-clock domain to the read-data registers with a false path. The standard
Vivado build flow applies it automatically to synthesis jobs through the
generated `synth/constraints.tcl`, using
`read_xdc -ref xilinx_ram_sdp_lutram`. The constraint is scoped to instances
of that module, including those instantiated inside memory wrappers.

This timing exception does not establish data coherence. The application
must ensure that the selected memory data is stable before sampling it in
the read domain, for example through FIFO pointer synchronization. The
`timing_ooc.xdc` files under `build/` supply example clocks for standalone
builds and are separate from the automatically applied CDC constraint.

## Verification and build examples

This sub-library has no standalone `tests/` directory or regression target.
The [`mem` test suite](../../mem/README.md#verification) exercises the automatic
SP, SDP, and TDP wrappers through the memory interfaces, including inferred
LUTRAM, BRAM, UltraRAM, and selected independent-clock configurations.

Build examples under `build/` provide synthesis wrappers and timing
constraints for resource and timing evaluation. They include automatic SDP
selection, synchronous and independent-clock BRAM, latency-optimized SDP,
LUTRAM, and UltraRAM configurations.
