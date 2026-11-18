# Mem

Memory interfaces, RAM wrappers, and initialization logic. The RAM wrappers
use `xilinx.ram` for inferred storage and depend on `sync.rtl` and `std.rtl`.
They provide a common request/acknowledgement interface across distributed,
block, and UltraRAM implementations.

## Contents

| Component | Description |
|-----------|-------------|
| `mem_pkg` | Memory specification, optimization modes, latency helpers, and command/status types |
| `mem_intf` | Combined read/write interface for a single memory port |
| `mem_wr_intf`, `mem_rd_intf` | Separate write and read interfaces |
| `mem_ram_sp` | Single-port RAM using `mem_intf` |
| `mem_ram_sdp` | Simple dual-port RAM with separate write/read interfaces and optional independent clocks |
| `mem_ram_tdp` | True dual-port RAM with two read/write interfaces and optional independent clocks |
| `mem_reset_fsm` | Initializes memory by writing a reset value to every address |
| `mem_sp_to_sdp_adapter` | Splits a combined port into separate write/read interfaces |
| `mem_sdp_to_sp_adapter` | Arbitrates separate write/read interfaces onto one combined port |
| Interface helpers | Connectors, read/write controller and peripheral terminators, and selected N:1 read/write muxes |

Additional components live in separate sub-libraries:

- [`mem.infra`](infra/README.md) provides muxing and aggregation infrastructure
  with dependencies such as FIFOs that cannot be included in the base library
  without creating dependency cycles.
- [`mem.proxy`](proxy/README.md) provides register-controlled memory access
  and its verification agent.

## Memory configuration (`mem_pkg`)

The RAM wrappers take a `mem_pkg::spec_t` parameter named `SPEC`:

| Field | Default | Meaning |
|-------|---------|---------|
| `ADDR_WID` | `8` | Address width; depth is `2**ADDR_WID` words |
| `DATA_WID` | `32` | Word width in bits; writes replace the entire word |
| `ASYNC` | `0` | Separate port clocks for SDP/TDP; keep zero for SP |
| `RESET_FSM` | `0` | Clear memory after reset before asserting ready |
| `OPT_MODE` | `OPT_MODE_DEFAULT` | Pipeline/latency policy |

`DEFAULT_MEM_SPEC` contains these defaults. The available policies are
`OPT_MODE_DEFAULT`, `OPT_MODE_TIMING`, and `OPT_MODE_LATENCY`. Default and
timing modes both select timing-optimized RAMs in `xilinx.ram`; latency mode
selects its latency-optimized configuration.

`get_ram_wr_latency()` and `get_ram_rd_latency()` describe the underlying
RAM timing. `get_wr_latency()` and `get_rd_latency()` account for the wrapper
configuration, including reset-FSM pipelining. Each function takes `SPEC`.
The package also defines access and memory-type classifications, and
`command_t`/`status_t` types used by memory control components.

## Interfaces and transactions

All three interfaces use rising-edge clocks and active-high synchronous
`rst`. The controller drives requests and the peripheral returns readiness
and completion. Match interface address/data widths to `SPEC`.

| Interface | Request signals | Response signals |
|-----------|-----------------|------------------|
| `mem_intf` | `req`, `wr`, `addr`, `wr_data` | `rdy`, `wr_ack`, `rd_ack`, `rd_data` |
| `mem_wr_intf` | `en`, `req`, `addr`, `data` | `rdy`, `ack` |
| `mem_rd_intf` | `req`, `addr` | `rdy`, `ack`, `data` |

Issue requests only when `rdy` is high. On `mem_intf`, `wr=1` selects a write
and `wr=0` selects a read. A write on `mem_wr_intf` requires both `en` and
`req`. Read data is valid with the corresponding read acknowledgement.
Acknowledgements report completion after the configured pipeline latency;
there is no response backpressure. Addresses select complete memory words,
rather than byte offsets, and writes replace whole words. Present request
fields together at the accepting edge; consecutive accepted request cycles
represent separate operations. The interfaces have no transaction IDs, so
pipelined requests require ordered responses and sufficient capacity in the
connected peripheral.

The interfaces provide `controller` and `peripheral` modports, clocking
blocks, and blocking transaction tasks. `mem_intf` supplies `idle()`,
`send_req()`, `write()`, and `read()`. The separate interfaces provide the
corresponding write/read operations and `wait_resp()` helpers.

## RAM wrappers and reset

| Module | Ports | Clock configuration |
|--------|-------|---------------------|
| `mem_ram_sp` | `mem_if` | One clock |
| `mem_ram_sdp` | `mem_wr_if`, `mem_rd_if` | Shared clock when `ASYNC=0`; independent clocks when `ASYNC=1` |
| `mem_ram_tdp` | `mem_if_0`, `mem_if_1` | Shared clock when `ASYNC=0`; independent clocks when `ASYNC=1` |

For synchronous configurations, connect both port interfaces to the same
clock. Independent clocks do not provide arbitration or collision protection;
the application must coordinate accesses to shared addresses.

All RAM wrappers also accept:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `RESET_VAL` | `'0` | Word written during reset-FSM initialization |
| `SIM__FAST_INIT` | `0` | Accelerates initialization for simulation |
| `SIM__RAM_MODEL` | `0` | Uses an associative-array RAM model for simulation |

With `RESET_FSM=1`, `mem_reset_fsm` takes ownership of the write path after
reset, writes `RESET_VAL` across the address space, and drains initialization
write acknowledgements before making the memory ready. SDP initialization
uses the write port; TDP initialization uses port 0. For independent clocks,
readiness is synchronized into the other port's clock domain. Wait for each
port's `rdy` before using it.

With `RESET_FSM=0`, reset does not clear the memory array. The simulation
options are excluded from synthesis; use the reset FSM when hardware needs
a known initial memory value. The associative-array models include
request/response pipelines and avoid allocating a dense array for every
simulated address.

## Adapters and interface helpers

`mem_sp_to_sdp_adapter` routes each combined-port request to the appropriate
write or read interface. Its combined ready signal requires both downstream
interfaces to be ready.

`mem_sdp_to_sp_adapter` combines separate write and read requests. Its
`WRITE_PRIORITY` parameter defaults to `1`, giving writes strict priority
when both request simultaneously; setting it to `0` gives reads priority.
Use these adapters within one clock domain.

The interface source files also contain back-to-back connector modules,
`mem_wr_intf_*_term` and `mem_rd_intf_*_term` termination helpers, and
`mem_wr_intf_mux`/`mem_rd_intf_mux`. Each mux has `N=2` by default and uses
an external `sel`; it does not arbitrate. The selection also routes response
signals, so retain it through completion of the selected transaction.

## Verification

SVUnit testbenches cover SP, SDP, and TDP wrappers with representative
memory depths and word widths. They exercise inferred LUTRAM, BRAM, and
UltraRAM paths, optional reset initialization, and selected associative-array
model configurations. SDP and TDP include independent-clock LUTRAM and BRAM
cases.

Checks cover reset/setup and randomized single-address write/readback.
TDP checks include writes through each port followed by readback through
both ports. The current suite uses timing-optimized configurations; it does
not exhaustively exercise collisions, sustained traffic, or every
optimization/reset combination.

Unit tests live under `tests/` and can be run individually or as a regression:

```sh
# Single testbench
make -C tests/mem_ram_sp/
make -C tests/mem_ram_sdp/
make -C tests/mem_ram_tdp/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
The `infra` and `proxy` sub-libraries have their own test suites.
