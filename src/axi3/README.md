# AXI3

AXI3 interfaces, channel pipelines, and a word-addressed memory adapter.
`axi3.rtl` depends on `bus.rtl`, `mem.rtl`, and `fifo.rtl`. `axi3.verif`
provides a simulation memory model.

## Contents

| Component | Description |
|-----------|-------------|
| `axi3_pkg` | Response, transfer-size, burst, lock, cache, and protection types |
| `axi3_intf` | Parameterized AXI3 channel signals and controller/peripheral modports |
| `axi3_intf_connector` | Direct interface connection |
| `axi3_intf_controller_term`, `axi3_intf_peripheral_term` | Tie-offs for unused endpoints |
| `axi3_intf_from_signals`, `axi3_intf_to_signals` | Flattened-signal interface helpers |
| `axi3_to_bus_adapter`, `axi3_from_bus_adapter` | Pack/unpack AXI3 channels as generic bus payloads |
| `axi3_pipe` | Fixed channel pipelines |
| `axi3_pipe_auto` | Channel pipelines with automatic stage placement |
| `axi3_pipe_slr` | Channel pipelines for SLR crossings |
| `axi3_from_mem_adapter` | Convert memory write/read requests into AXI3 transactions |
| `axi3_mem_bfm` | Sparse, multi-channel simulation memory model |

## Interface and connections

`axi3_intf` provides independent write-address, write-data, write-response,
read-address, and read-data channels. Each uses valid/ready handshaking.
It includes transaction IDs, write strobes, burst length and type, last-beat
indications, and user sidebands. The package exposes encoded and raw views
of protocol fields; `get_word_size()` returns bytes per transfer from an
`axsize_t` value.

A channel transfers on a rising `aclk` edge when its `VALID` and `READY`
signals are both asserted. The source holds `VALID` and the channel payload
stable until acceptance. Channels handshake independently; accepting a
write address does not imply that write data or a response has transferred.

| Channel | Payload | Direction |
|---------|---------|-----------|
| AW | Write address and burst attributes | Controller to peripheral |
| W | Write data, byte strobes, and final-beat indication | Controller to peripheral |
| B | Write response and transaction ID | Peripheral to controller |
| AR | Read address and burst attributes | Controller to peripheral |
| R | Read data, response, transaction ID, and final-beat indication | Peripheral to controller |

Addresses are byte addresses. `AxLEN` encodes the number of beats minus one;
`AxSIZE` encodes the base-two logarithm of bytes per beat. `WSTRB` selects
written byte lanes. An accepted `WLAST` marks the final write-data beat,
while the B response completes the write transaction. An accepted `RLAST`
marks the final read response beat. Supported burst types, outstanding
transactions, and ordering depend on the connected endpoints.

AXI3 includes a write-data transaction ID (`WID`) and a four-bit burst
length field. These differ from AXI4, which omits `WID` and widens length
to eight bits.

| Interface parameter | Default | Meaning |
|---------------------|---------|---------|
| `DATA_BYTE_WID` | `8` | Data width in bytes |
| `ADDR_WID` | `32` | Byte-address width |
| `ID_WID` | `1` | Transaction ID width |
| `USER_WID` | `1` | User sideband width |

The interface takes `aclk` as an input and has no reset signal or
transaction tasks. Connected components receive reset separately. Match
interface widths and connect both sides of the pipeline components to the
same clock; these components do not provide clock-domain crossing.

The connector wires channels directly. The controller terminator suppresses
requests and response readiness. The peripheral terminator deasserts
request readiness and response validity; it does not complete accesses to
an unused endpoint with an error response.

The signal helpers bridge flattened channel ports and interface instances.
`axi3_intf_to_signals` also converts active-high `srst` to an active-low
`aresetn` output, registered by default with `RESET_BUFFER=1`.

## Channel pipelines

The bus adapters pack each AXI3 channel's payload into a separate
[`bus_intf`](../bus/README.md). Address/data channels travel toward the
peripheral; response/read-data channels travel toward the controller.
Payloads preserve IDs, metadata, byte strobes, and last-beat indications.

`axi3_pipe` pipelines all channels using `bus_pipe`, including buffering
for ready/valid slack. `STAGES` defaults to `1` and must be at least one.
`axi3_pipe_auto` uses the corresponding automatic bus pipelines, allowing
the implementation tools to allocate additional registers.
`axi3_pipe_slr` uses SLR-crossing bus pipelines, with optional
`PRE_PIPE_STAGES` and `POST_PIPE_STAGES`, both defaulting to zero.

All pipeline variants take active-high synchronous `srst`. Reset clears
pending channel traffic; reset the surrounding transaction endpoints
consistently so discarded requests or responses do not leave transactions
outstanding.

## Memory adapter

`axi3_from_mem_adapter` accepts separate `mem_wr_intf` and `mem_rd_intf`
interfaces and drives an AXI3 controller interface. Memory addresses select
words; AXI3 addresses are `BASE_ADDR + word_address * bytes_per_word`.
Configure the memory and AXI3 data widths to match `SIZE`, and allow enough
AXI3 address bits for the complete translated address range.

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `SIZE` | `SIZE_64BYTES` | Transfer width, matching the memory and AXI3 data buses |
| `BASE_ADDR` | `0` | Byte offset added to translated memory addresses |
| `BURST_SUPPORT` | `0` | Aggregate consecutive requests into incrementing bursts |
| `WR_ID` | `0` | Write transaction ID |
| `RD_ID` | `0` | Read transaction ID; currently declared as a one-bit parameter |

With burst support disabled, requests produce individual AXI3 transfers.
With it enabled, consecutive addresses can be grouped into incrementing
bursts up to the AXI3 length limit. The adapter uses FIFO buffering for
write data and burst contexts. Observe memory readiness and monitor the
`*_oflow` and `*_pending` outputs for buffering status. Its address slicing
assumes more than one byte per word.

Writes use all byte strobes. A memory write acknowledgement means the AXI3
write-data beat was accepted, rather than that the write response reported
successful completion. Write responses are always accepted; their error
codes are not propagated to the memory interface. Read acknowledgements
and data are registered from accepted AXI3 read beats, with read-response
error codes likewise not propagated.

`init_done` is tied high; the adapter does not initialize or clear the
attached memory. `clk` must match the memory and AXI3 interface clocks.

## Simulation memory model

`axi3_mem_bfm` models a sparse memory behind an array of AXI3 interfaces.
`CHANNELS` defaults to `1`; `WR_LATENCY` and `RD_LATENCY` default to `8`
and control response eligibility delays. `DEBUG` enables transaction logs.
Use a common clock for the channels: response timing uses a timestamp
counter clocked by channel zero.

With `GLOBAL_ADDRESSING=0`, the model substitutes a channel index into the
high address bits, partitioning storage by channel. With it enabled, the
channels share the supplied address space. Reset clears transaction queues
and response state while retaining memory contents. Unwritten locations
read as zero.

This model supports the suite's aligned, full-width traffic. It does not
apply write byte strobes or provide complete narrow, wrapping, interleaved,
or response-backpressure behavior. It returns successful responses and
serves as a functional memory model rather than a protocol compliance
checker.

## Verification

The SVUnit suite drives the memory adapter through the
[`mem.proxy`](../mem/proxy/README.md) register interface and agents, with an
AXI3 SLR pipeline between the adapter and memory model. It checks reset,
readiness, memory information, no-op commands, randomized writes and
readback, and larger transfers split by the proxy. The control and memory
paths use separate clocks.

The current configuration leaves AXI3 burst aggregation disabled. Larger
proxy transfers therefore exercise sequences of individual AXI3 transfers.
Burst aggregation, response errors, and general AXI3 protocol corner cases
are outside the suite's coverage.

```sh
# Individual testbench
make -C tests/axi3_from_mem_adapter/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
