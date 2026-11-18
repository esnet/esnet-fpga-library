# FIFO

Synchronous and asynchronous FIFOs, small distributed-memory buffers,
context queues, and prefetch buffers. `fifo.rtl` depends on `math.pkg`,
`mem.rtl`, and `sync.rtl`. Register-controlled wrappers and verification
helpers are provided separately.

## Contents

| Component | Description |
|-----------|-------------|
| `fifo_pkg` | Timing/latency optimization modes |
| `fifo_sync` | Single-clock FIFO with standard or first-word fall-through reads |
| `fifo_async` | FIFO with independent write/read clocks and reset synchronization |
| `fifo_core` | Shared memory-backed implementation with monitoring interfaces |
| `fifo_ctrl_fsm` | Pointer, occupancy, protection, and clock-domain control logic |
| `fifo_small` | Low-latency synchronous FIFO using distributed memory |
| `fifo_ctxt`, `fifo_small_ctxt` | First-word fall-through buffers optimized for transaction context |
| `fifo_queue` | First-word fall-through queue with timing-oriented pipelining |
| `fifo_prefetch`, `fifo_small_prefetch` | Buffers that reserve space for in-flight writes |
| `fifo_mon_intf`, `fifo_mon_pipe_auto` | FIFO state monitoring and monitor pipelining |
| `fifo_axil_sync`, `fifo_axil_async`, `fifo_axil_core` | FIFO wrappers with AXI4-Lite reset and monitoring registers |
| `fifo_reg_agent` | Verification access to FIFO control and monitor registers |
| `tb_env` | Shared FIFO test environment using bus drivers, monitors, and a scoreboard |

## Standard FIFOs

`fifo_sync` uses one `clk` and active-high synchronous `srst`.
`fifo_async` exposes separate `wr_clk`/`wr_srst` and `rd_clk`/`rd_srst`
ports. The shared `fifo_core` selects this behavior with `ASYNC`, which
defaults to `1`.

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `DATA_WID` | `1` | Width of each stored word |
| `DEPTH` | `32` | Main FIFO storage depth |
| `FWFT` | `1` | Enable first-word fall-through output buffering |
| `OFLOW_PROT` | `1` | Block writes that would overflow storage |
| `UFLOW_PROT` | `1` | Block reads from empty storage; always enabled internally for FWFT |
| `REPORT_OFLOW` | `0` | Print overflow events during simulation |
| `REPORT_UFLOW` | `0` | Print underflow events during simulation |
| `CNT_WID` | Derived | Counter width; do not override |

Use positive data widths and depths. Non-power-of-two depths are supported;
the underlying memory allocation rounds up to a power of two. `fifo_core`
also exposes `WR_OPT_MODE` and `RD_OPT_MODE`, both defaulting to
`fifo_pkg::OPT_MODE_TIMING`. `OPT_MODE_LATENCY` reduces control-path latency
at the expense of additional combinational logic.

### Write and read behavior

Write data is supplied on `wr_data` with `wr` asserted. Wait for `wr_rdy`
after reset and observe the full indication before writing. Protected
writes attempted while full report overflow without overwriting queued
data. Protection can be disabled for applications that enforce the access
rules externally.

Read behavior depends on `FWFT`:

- With `FWFT=0`, assert `rd` to request a word. `rd_ack` qualifies returned
  `rd_data` after the memory read latency.
- With `FWFT=1`, data is prefetched to the output. `rd_ack` indicates that
  the current `rd_data` is valid, and `rd` consumes that word. The output
  buffer can hold an additional word beyond the main storage depth.

The wrappers expose write/read occupancy, full/empty indications, and
protection event outputs. `fifo_sync` names its status ports `full`,
`empty`, `oflow`, and `uflow`; `fifo_async` uses `wr_full`, `rd_empty`,
`wr_oflow`, and `rd_uflow`. Write counts describe main-storage occupancy;
FWFT read counts also account for the output word.

For asynchronous operation, pointers and resets cross clock domains through
synchronizers. Resetting either side resets the combined FIFO state.
Allow reset/readiness to settle before traffic. Counts and status belong to
their local clock domains and can lag activity in the other domain. This
library uses the RAM wrappers in [`mem`](../mem/README.md) for storage.

## Context queues and small FIFOs

`fifo_small` targets distributed RAM and drives read data directly from its
memory array. Its read path is first-word fall-through: `!empty` qualifies
the current word and `rd` consumes it. It supports simultaneous writes and
reads, exposes `count`, and protects both boundaries. Rounded memory depth
is limited to 256 entries. Use it where read-data fanout is low; otherwise,
prefer the registered output path of `fifo_sync`.

`fifo_ctxt` prioritizes write-to-read latency for tracking outstanding
transactions. Its default `DEPTH` is 32. A depth of one uses a single-entry
register implementation; larger depths use a latency-optimized FIFO core
with headroom for simultaneous writes and reads.

`fifo_small_ctxt` provides the analogous low-fanout distributed-memory
implementation with `DEPTH=4` by default. It allocates an extra storage
entry, so the distributed-memory depth limit also applies to that entry.
`fifo_queue` uses the timing-optimized core and defaults to `DEPTH=32`.

These queue interfaces use `wr_rdy` for write readiness and `rd_vld` to
qualify the current output word. `rd` consumes a valid word. Overflow
reporting defaults to enabled and underflow reporting defaults to disabled
for the context/queue variants.

## Prefetch buffers

`fifo_prefetch` and `fifo_small_prefetch` reserve room for requests that
have already entered a write pipeline. `PIPELINE_DEPTH` defaults to `1`
and specifies how many subsequent writes must be accommodated after
`wr_rdy` deasserts. Unlike a conventional ready/valid queue, a write while
`wr_rdy=0` does not necessarily overflow: previously issued requests can
still complete into the reserved space.

The read interface presents `rd_vld` and `rd_data`, with `rd` consuming a
word. `oflow` reports actual storage exhaustion. Match `PIPELINE_DEPTH` to
the upstream pipeline's maximum in-flight traffic and stop issuing new
requests when readiness deasserts.

`fifo_prefetch` supports timing/latency mode selection and pipeline depths
up to 256, with smaller depths typical. `fifo_small_prefetch` targets
low-latency, low-fanout use and limits pipeline depth to 64. Both default to
overflow reporting enabled and underflow reporting disabled.

## Monitoring and AXI4-Lite control

`fifo_core` exports separate write- and read-domain `fifo_mon_intf`
interfaces. Each carries reset, full/empty state, protection events, count,
and pointer values. The `tx` modport drives these fields and `rx` observes
them on the interface's `clk`; there is no valid/ready handshake. `reset`,
`full`, and `empty` are levels; `oflow` and `uflow` report local protection
events, while 32-bit `count` and `ptr` fields report local occupancy and
pointer state. Write- and read-domain observations need not agree in the
same cycle, particularly for asynchronous FIFOs.

`fifo_mon_pipe_auto` provides registered monitoring paths marked for
automatic pipelining by the implementation tools. It does not synchronize
between clocks.

The `fifo.axil.rtl` sub-library adds `fifo_axil_core` and synchronous/
asynchronous wrappers. These preserve the FIFO data ports and add an
`axil_if` peripheral interface. Register blocks describe FIFO geometry and
mode, request a soft reset, and expose write/read monitoring state.
Control and monitor information crosses between the AXI4-Lite and FIFO
clock domains. Register definitions live under `regio/`.

`fifo.verif` supplies `fifo_verif_pkg::fifo_reg_agent`. Construct it with a
register-agent transport and optional base offset. Its methods query depth,
width, asynchronous mode, pointers, counts, and full/empty state, or request
`soft_reset()`. `fifo.tb` supplies the shared `tb_pkg::tb_env` data-path test
environment built from bus agents and the standard verification classes.

## Verification

The base SVUnit suites exercise reset, ordered data readback, empty/full
boundaries, and overflow protection across standard, FWFT, small, context,
queue, and prefetch implementations. Examples include non-power-of-two
depths and independent clocks with both faster-write and faster-read
traffic. Prefetch tests account for in-flight writes after readiness drops.

The AXI4-Lite suite additionally exercises FIFO information registers,
software reset, and monitored state alongside data transfers. These suites
cover representative configurations rather than every width, optimization
mode, or protection setting.

```sh
# Individual base testbenches (examples)
make -C tests/fifo_sync/
make -C tests/fifo_async/
make -C tests/fifo_ctxt/
make -C tests/fifo_prefetch/

# Base regression
make regression

# AXI4-Lite wrapper regression
make -C axil/tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
