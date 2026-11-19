# Sync

Clock-domain crossing (CDC) components for signals, events, buses, counters,
and resets. The RTL is self-contained and has no dependencies on other libraries.

## Contents

| Component | Description |
|-----------|-------------|
| `sync_pkg` | Retiming-stage count and handshake-mode enumeration |
| `sync_meta` | Source register followed by a destination synchronizer pipeline |
| `sync_event` | Transfers events using a two-way handshake |
| `sync_level` | Transfers level changes with acknowledgement |
| `sync_bus` | Transfers a stable bus value on request |
| `sync_bus_sampled` | Repeatedly samples a bus using `sync_bus` |
| `sync_ctr` | Transfers a counter using Gray encoding |
| `sync_areset` | Asynchronous reset assertion, synchronous deassertion |
| `sync_reset` | Registers reset deassertion in the source domain before synchronizing it |

## Clock and reset conventions

Data synchronizers use `clk_in`/`rst_in` for the source domain and
`clk_out`/`rst_out` for the destination domain. Their resets are active-high
and synchronous to their respective clocks. Initialize both domains before
transferring data. Reset synchronizers have separately configurable polarities,
as described below.

`sync_pkg::RETIMING_STAGES` is fixed at **3**. `sync_meta` registers its input
on `clk_in`, then passes it through three registers on `clk_out`. End-to-end
latency depends on the relative clock phases; handshake-based components also
include the return acknowledgement path.

## Modules

### `sync_meta` — Basic synchronizer

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WID` | `1` | Signal width in bits |
| `RST_VALUE` | `'x` | Value loaded by either domain's reset |

Transfers `sig_in[DATA_WID-1:0]` to `sig_out[DATA_WID-1:0]`. The source
register prevents combinational glitches from entering the destination
pipeline. There is no handshake: short pulses can be missed, and independently
synchronizing the bits of an arbitrary changing bus does not guarantee a
coherent word. Use the event, bus, or counter components for those transfers.

### `sync_event` — Event handshake

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MODE` | `sync_pkg::HANDSHAKE_MODE_4PHASE` | Four-phase or two-phase handshake |

An event is accepted on a source rising edge when both `evt_in` and `rdy_in`
are high. Each accepted event produces one destination-clock pulse on
`evt_out`. Wait for `rdy_in` before presenting another event; keeping `evt_in`
high requests another transfer whenever the synchronizer becomes ready.

`sync_pkg::handshake_mode_t` defines `HANDSHAKE_MODE_4PHASE` (request assertion,
acknowledgement, request clearance, acknowledgement clearance) and
`HANDSHAKE_MODE_2PHASE` (request and acknowledgement toggle on each transfer).
Two-phase operation avoids the return-to-zero portion of the handshake.

### `sync_level` — Acknowledged level changes

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RST_VALUE` | `1'bx` | Reset level in both domains |

Transfers `lvl_in` to `lvl_out`. While `rdy_in` is high, the source captures
the input level. After a change, it waits for the destination's acknowledgement
before sampling again. A captured transition reaches the destination, but
additional transitions while busy can be missed. Use `rdy_in` to determine
when another level change can be accepted.

### `sync_bus` — Requested bus transfer

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WID` | `1` | Bus width in bits |
| `RST_VALUE` | `'x` | Bus reset value |
| `HANDSHAKE_MODE` | `sync_pkg::HANDSHAKE_MODE_4PHASE` | Event-handshake policy |

Captures `data_in` on a source rising edge with `req_in && rdy_in`. The
captured bus remains stable while the request crosses domains. `ack_out` is
a destination-clock pulse aligned with the new `data_out`; the output retains
that value until another transfer or reset. There is no destination backpressure.

### `sync_bus_sampled` — Repeated bus sampling

Has the same parameters as `sync_bus`, with `data_in` and `data_out` as its
data ports. It permanently asserts the internal request, sampling as quickly
as the two-way handshake allows. Intermediate input values can be skipped;
the destination receives occasional coherent samples rather than every source
cycle. The interface has no ready or acknowledgement output.

### `sync_ctr` — Counter transfer

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CNT_WID` | `1` | Counter width in bits |
| `RST_VALUE` | `'x` | Binary counter reset value |
| `DECODE_OUT` | `1'b1` | Decode the synchronized Gray value to binary |

Converts `cnt_in` to Gray code and transfers it through `sync_meta`. Limit
source changes to one count per source cycle, with stable cycles permitted,
so successive transmitted Gray values differ by at most one bit. The
destination may skip values when the source is faster. With `DECODE_OUT=1`, `cnt_out` is binary and includes an additional
destination register. With `DECODE_OUT=0`, it is the synchronized Gray value;
the reset value is Gray-encoded as well.

### `sync_areset` and `sync_reset` — Reset transfer

| Parameter | Default | Description |
|-----------|---------|-------------|
| `INPUT_ACTIVE_HIGH` | `0` | Input reset is active-low by default |
| `OUTPUT_ACTIVE_LOW` | `0` | Output reset is active-high by default |

Both modules assert `rst_out` asynchronously and deassert it through three
`clk_out` retiming stages. `sync_areset` takes only `rst_in` and `clk_out` as
inputs. `sync_reset` also takes `clk_in` and registers reset release in the
source domain before the destination pipeline. Its source register starts in
the reset state; assertion remains asynchronous.

## Synthesis constraints

The library provides scoped CDC constraints in
`build/<module>/synth.xdc` for `sync_meta`, `sync_bus`, and `sync_areset`.
The standard Vivado build flow applies these automatically to synthesis
jobs; designs using these components do not need to include the XDC files
manually.

`scripts/Makefiles/vivado_compile.mk` generates a `synth/constraints.tcl`
file in the component's output directory. The synthesis job loads this
script, which checks the synthesis source list and reads the corresponding
XDC files with `read_xdc -ref <module>`. Reference scoping applies each
constraint to instances of that module, including those nested inside the
other synchronizers. For example, `sync_ctr` inherits the constraints on
its `sync_meta` instance, and `sync_reset` inherits those on `sync_areset`.
Both project and non-project build flows load the generated script.

| Constraint file | Behavior |
|-----------------|----------|
| `build/sync_meta/synth.xdc` | Limits source-register to first destination-stage delay to one source-clock period, and bus skew to the smaller source/destination period |
| `build/sync_bus/synth.xdc` | Limits bus-transfer delay and skew to the destination-clock period multiplied by the request synchronizer's retiming-stage count |
| `build/sync_areset/synth.xdc` | Applies a false path to the asynchronous clear pins of the reset synchronizer registers |

The delay limits use `set_max_delay -datapath_only`; skew limits use
`set_bus_skew`. Clock periods come from the clocks on the instance ports,
with a 100 ns fallback when a clock is unavailable. Define the design's
clocks in its timing constraints. The `timing_ooc.xdc` files alongside the
module build examples provide example clocks for standalone synthesis;
they are separate from the automatically applied CDC constraints.

## Verification

SVUnit tests cover the RTL modules, including scalar and vector
synchronization, input and output resets, and all reset-polarity combinations.
Event tests exercise both handshake modes. Bus and level tests check transfer
values, sustained requests, and ordered sampling under backpressure. Counter
tests check Gray and binary outputs, wraparound, and equal, faster, and slower
destination clocks. Most testbenches randomize the source and destination
clock periods independently.

Unit tests live under `tests/` and can be run individually or as a regression:

```sh
# Single testbench
make -C tests/sync_bus/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.

OOC synthesis jobs live under `build/` and run through the library's synth
CI matrix. `build/sync_meta__unused` removes one consumer after synthesis
and optimization, then checks that its unused CDC chain is removed while
the live registered Gray-code boundary and three-stage synchronizer remain.
Run it with `make -C build/sync_meta__unused/` using the normal part configuration.
