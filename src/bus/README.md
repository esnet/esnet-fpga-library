# Bus

Ready/valid interfaces, buffered pipelines, width converters, and
transaction-based verification helpers. `bus.rtl` depends on `fifo.rtl`.
`bus.verif` adds the standard verification classes from `std.verif`, and
`bus.tb` provides a shared environment for the unit tests.

## Contents

| Component | Description |
|-----------|-------------|
| `bus_intf` | Data, valid, and ready signals with Tx/Rx modports and a clocking block |
| `bus_intf_connector` | Direct connection between matching-width interfaces |
| `bus_reg` | Registers forward data/valid and reverse ready signals |
| `bus_pipe_tx` | Converts accepted input transfers into pipeline valid pulses |
| `bus_pipe_rx` | Buffers in-flight transfers to accommodate delayed backpressure |
| `bus_pipe` | Fixed-depth pipeline with handshake buffering |
| `bus_pipe_auto` | Pipeline with stages available for automatic allocation by implementation tools |
| `bus_pipe_slr` | SLR-crossing pipeline with optional stages before and after the crossing |
| `bus_width_converter` | Packs narrow words into wider words or splits wide words into narrower words |
| `bus_driver`, `bus_monitor` | Verification agents with selectable transfer modes and optional stalls |
| `tb_env` | Test environment connecting bus agents to a transaction scoreboard |

## Interface and transfers

`bus_intf#(DATA_WID)` takes a clock through its `clk` port. `DATA_WID`
defaults to `1` and must be positive. All payload bits are opaque to the
infrastructure.

| Signal | Driven by | Meaning |
|--------|-----------|---------|
| `valid` | Transmitter | A data word is available |
| `data` | Transmitter | The offered word |
| `ready` | Receiver | The receiver can accept the word |

A transfer completes on a rising clock edge with both `valid` and `ready`
asserted. The transmitter holds `valid` and `data` stable while stalled;
consecutive words can transfer on consecutive edges. There are no packet
boundaries or byte enables. The `tx` and `rx` modports describe the
corresponding signal directions. Reset is supplied separately to connected
modules; the interface itself has no reset signal.
Connect both sides of a component to the same clock; this library does not
provide clock-domain crossing.

The interface has a `cb` clocking block for verification, including sampled
`mon_valid`, `mon_ready`, and `mon_data` views. Transaction sequencing, idle
control, and clock-cycle waits belong to the verification agents, which
operate directly through this clocking block.

`bus_intf_connector` wires data/valid forward and ready backward. Both
interfaces must have the same width.

## Pipelining and backpressure

Registering both directions delays the receiver's backpressure indication.
Words already in flight still need storage after readiness drops. The
pipeline components combine register stages with a prefetch receiver FIFO
to accommodate that traffic.

| Module | Configuration |
|--------|---------------|
| `bus_pipe` | `STAGES=1` by default; requires at least one stage in each direction |
| `bus_pipe_auto` | Fixed register stages plus automatic pipeline allocation, with buffering for the supported handshake slack |
| `bus_pipe_slr` | Fixed SLR-crossing registers with `PRE_PIPE_STAGES=0` and `POST_PIPE_STAGES=0` by default |
| `bus_pipe_rx` | `TOTAL_SLACK=16` by default; include forward and reverse pipeline delays when sizing it |
| `bus_reg` | `STAGES=1` by default; zero stages provides a direct signal path |

These modules derive data width from their connected interfaces and require
matching widths. Buffered pipelines use active-high synchronous `srst`.
`bus_pipe_auto` and `bus_pipe_slr` include implementation attributes for
pipeline allocation and physical placement.

`bus_reg` alone delays the signals without providing handshake storage.
Use `bus_pipe` for a complete pipeline, or combine `bus_pipe_tx`, register
stages, and `bus_pipe_rx` when building a custom pipeline. Within that
internal link, valid pulses represent transfers already accepted at the Tx
boundary. The Rx buffer absorbs them while backpressure propagates.

## Width conversion

`bus_width_converter` derives input and output widths from its interfaces.
For conversion, choose different positive widths with an integer ratio;
use `bus_intf_connector` when widths match. `BIGENDIAN` defaults to `1`.

- Upsizing collects a complete group of narrow input words before offering
  a wide output word.
- Downsizing holds a wide input word and emits its narrow words in order,
  respecting output backpressure.
- With `BIGENDIAN=1`, the first narrow word occupies the most significant
  portion of the wide word. With `BIGENDIAN=0`, it occupies the least
  significant portion.

The converter uses active-high synchronous `srst`. Supply complete groups
when upsizing: the interface has no partial-word mask, packet boundary, or
flush indication.

## Verification agents

`bus_verif_pkg::bus_driver#(DATA_T)` and `bus_monitor#(DATA_T)` use
`std_verif_pkg::raw_transaction#(DATA_T)` objects. The default payload type
is `bit[15:0]`. Assign their `bus_vif` virtual interface before use, matching
its data width to `$bits(DATA_T)`.

The inherited `send(transaction)` and `receive(transaction)` methods
operate on transaction objects. `send_raw(data)` and `receive_raw(data)`
operate directly on payloads. Select behavior with `set_tx_mode()` and
`set_rx_mode()`:

| Transmit mode | Behavior |
|---------------|----------|
| `TX_MODE_SEND` | Offer data and complete on a valid/ready handshake; default |
| `TX_MODE_PUSH` | Send a word without waiting for readiness |
| `TX_MODE_PUSH_WHEN_READY` | Observe readiness before issuing a push |

| Receive mode | Behavior |
|--------------|----------|
| `RX_MODE_RECEIVE` | Assert readiness and complete on a valid/ready handshake; default |
| `RX_MODE_PULL` | Request and sample a word without checking validity |
| `RX_MODE_ACK` | Observe validity before acknowledging and sampling a word |
| `RX_MODE_FETCH` | Request a word and sample it on the following clock |
| `RX_MODE_FETCH_VAL` | Request a word and wait for the valid response |
| `RX_MODE_ACK_FETCH` | Observe validity before requesting a word for the following clock |

Push/pull/fetch modes also support FIFO-style request/response interfaces;
choose the mode that matches the attached peripheral. Push-when-ready and
acknowledge modes observe a fresh clocking-block sample before each request.
Use `idle()` to quiesce outputs. Both agents expose `wait_n(cycles)` for
waits in their attached interface's clock domain. The driver also provides
`wait_ready()` to wait for readiness sampled on a clock edge.

`enable_stalls()` inserts random stalls, or fixed stalls when given a
positive cycle count. `set_max_stall()` controls the random upper bound,
which defaults to four cycles. `disable_stalls()` removes stalls, and reset
also disables them.

## Verification

The SVUnit suite checks ordered data delivery through connectors, fixed
pipelines, automatic pipelines, SLR pipelines, and paired width converters.
It exercises individual words, streams, randomized transmit stalls,
receiver backpressure, and both width-conversion word orders. A scoreboard
compares received transactions against the input stream.

The current configurations use representative data widths and pipeline
depths. They do not exhaustively cover every width ratio or the FIFO-style
push/ack/fetch mode combinations.

```sh
# Single testbench
make -C tests/bus_intf/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
