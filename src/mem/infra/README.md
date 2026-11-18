# Mem Infra

Buffered memory-interface muxes and word aggregation. The base [`mem`](../README.md)
library is used by low-level components such as FIFOs. Infrastructure that
itself needs FIFOs lives here to avoid circular dependencies. `mem.infra.rtl`
depends on `mem.rtl`, `fifo.rtl`, and `std.rtl`.

## Contents

| Module | Description |
|--------|-------------|
| `mem_wr_aggregate` | Splits each wide write across narrower memory slices and combines their acknowledgements |
| `mem_rd_aggregate` | Replicates read requests across slices and aligns their returned data into a wide response |
| `mem_wr_mux` | Selects one of several write controllers and routes acknowledgements back to the originating controller |
| `mem_rd_mux` | Selects one of several read controllers and routes acknowledgements back to the originating controller |

All modules use the separate `mem_wr_intf` or `mem_rd_intf` interfaces from
`mem.rtl`. Controllers issue requests when ready; peripherals acknowledge
completion. Read data is valid with its acknowledgement. Responses have no
backpressure.

## Aggregation

The aggregate modules connect one wide `from_controller` interface to an
array of `N` narrow `to_peripheral` interfaces.

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `N` | `2` | Number of memory slices |
| `ALIGNMENT_DEPTH` | `8` | Response FIFO depth per slice |

The controller data width must equal `N` times the peripheral data width;
address widths must match. Every slice receives the same word address.
Slice 0 holds the least significant portion of the wide word, slice 1 the
next portion, and so on. Writes require both `en` and `req`.

Each slice has a buffered request path and can accept its request at a
different time. Response FIFOs preserve ordering and wait for a response
from every slice before acknowledging the wide transaction. Read responses
concatenate the aligned slice data; write responses combine completion
acknowledgements. With `N=1`, the modules use direct interface connectors.

Use a common clock across each aggregate and its connected interfaces.
Separate write and read aggregates can operate in different clock domains
when the attached memories support independent write/read clocks. Reset
comes from `from_controller.rst` and propagates to the slice interfaces.

Each aggregate exposes four status arrays indexed by slice:

| Output | Meaning |
|--------|---------|
| `req_oflow` | Request buffer overflow indication |
| `req_pending` | Request available on the slice interface |
| `resp_oflow` | Response alignment FIFO overflow indication |
| `resp_pending` | Response available in the alignment FIFO |

Size `ALIGNMENT_DEPTH` for the maximum response skew between slices.
Response FIFOs cannot backpressure the memories. The status outputs are
zero in the single-slice bypass configuration.

## Controller muxes

The mux modules connect an array of `N` `from_controller` interfaces to one
`to_peripheral` interface. An external `sel` chooses the request source;
the modules do not arbitrate between controllers.

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `N` | `2` | Number of input controllers |
| `NUM_TRANSACTIONS` | `8` | Context FIFO depth for outstanding transactions |
| `SEL_WID` | Derived from `N`, at least `1` | Selection width; do not override |

The selected controller receives peripheral readiness. Each accepted request
records its controller index in a context FIFO, so later acknowledgements
return to the original controller even if `sel` changes. Read data is
broadcast to the controllers and qualified by the routed acknowledgement.
Use in-order peripheral responses and keep accepted outstanding requests
within `NUM_TRANSACTIONS`; readiness is not gated by context FIFO capacity.

Connect the interfaces within one clock domain. Clock and reset come from
controller 0. Use matching data widths; the write mux requires matching
address widths, while the read mux allows narrower controller addresses.

## Verification

The SVUnit suite exercises memory aggregation through paired write/read
aggregates connected to RAM models. It checks reset and randomized data
readback with shared and independent memory clocks, including single-slice
bypass and reset-FSM initialization.

The current suite focuses on basic aggregation behavior. Controller muxes,
response-skew limits, overflow reporting, and sustained traffic are outside
its coverage.

```sh
# Single testbench
make -C tests/mem_aggregate/

# All tests
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
