# AXI4

AXI4 channel interfaces, connection helpers, a single-beat register agent,
and a sparse simulation memory model. `axi4.rtl` depends on `axi4.pkg` and
`std.rtl`. `axi4.verif` additionally uses the standard verification and
register-agent infrastructure.

## Contents

| Component | Description |
|-----------|-------------|
| `axi4_pkg` | Response, size, burst, lock, cache, and protection types |
| `axi4_intf` | Parameterized channel signals, modports, and a verification clocking block |
| `axi4_intf_connector` | Direct connection between controller and peripheral interfaces |
| `axi4_intf_controller_term` | Idle tie-offs for an unused controller endpoint |
| `axi4_intf_peripheral_term` | Simple peripheral termination helper with error response signals |
| `axi4_intf_from_signals` | Connect flattened controller signals to an interface |
| `axi4_reg_agent` | Single-beat register-window transactions through a virtual interface |
| `axi4_mem_bfm` | Sparse, multi-channel simulation memory model |

## Interface and connections

`axi4_intf` provides independent write-address, write-data, write-response,
read-address, and read-data channels with valid/ready handshaking. It
includes transaction IDs, byte strobes, last-beat indications, protection
and cache fields, and user sidebands. Burst length fields are eight bits,
lock fields are one bit, and the write-data channel has no transaction ID.

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

| Interface parameter | Default | Meaning |
|---------------------|---------|---------|
| `DATA_BYTE_WID` | `8` | Data width in bytes |
| `ADDR_WID` | `32` | Byte-address width |
| `ID_WID` | `1` | Transaction ID width |
| `USER_WID` | `1` | User sideband width |

The interface takes `aclk` as an input and has no reset signal. Components
that require reset receive it separately. `axi4_pkg` exposes encoded and
raw views of protocol fields; `get_word_size()` converts transfer sizes to
byte counts.

The connector wires all channels and checks matching interface widths.
It provides no buffering or clock-domain crossing; connect both sides to
the same clock. The signal helper maps flattened channel ports to an
interface, whose clock must be connected when it is instantiated.

The controller terminator suppresses requests and response readiness. The
peripheral terminator supplies simple error-response logic, without a
fully buffered responder for independent channels and backpressure. It is
outside the current test coverage.

## Register agent

`axi4_verif_pkg::axi4_reg_agent` implements transactions directly through
`axi4_intf.cb`. The interface supplies sampled handshake views; idle
control, cycle waits, transfers, and timeout handling belong to the agent.
Clocking-block skews use the SystemVerilog defaults.

Construct the agent and attach its `axi4_vif` handle to the controller
interface. Agent parameters must match the interface. The agent defaults
to `DATA_BYTE_WID=64`, `ADDR_WID=64`, `ID_WID=1`, and `USER_WID=1`, so its
default geometry differs from the interface defaults.

| Method | Capability |
|--------|------------|
| `idle()` | Quiesce controller outputs and wait a clocking-block event |
| `wait_n(cycles)` | Wait interface clock cycles |
| `write(addr, data, strb, resp, timeout, WR_TIMEOUT)` | Single-beat write with explicit byte strobes and returned response |
| `read(addr, data, resp, timeout, RD_TIMEOUT)` | Single-beat read returning the bus payload and response |
| `write_reg()`, `read_reg()` | Inherited register transport API with error reporting |
| `write_byte()`, `read_byte()` | Select a byte lane within the data bus |

The transaction helpers target 32-bit register windows: `AxLEN=0`,
`AxSIZE=SIZE_4BYTES`, zero transaction IDs, and normal, incrementing access
metadata. They are not a general burst or arbitrary-width transfer agent.
Write data and strobes span the physical bus; callers of `write()` place
register data on the appropriate lanes and mask other bytes. `read()`
returns the bus payload for caller-side lane selection. The inherited
`write_reg()` enables all strobes; use explicit strobes when only a register
window within a wider bus should be written.

Public `read()` and `write()` timeout arguments default to 256 clock cycles;
a nonpositive limit waits indefinitely. The inherited register methods use
`set_rd_timeout()` and `set_wr_timeout()`, both initialized to 128 cycles
unless overridden in the constructor. A timeout cancels the transfer and
quiesces controller outputs. It cannot retract requests already accepted
by a peripheral; reset both endpoints before reuse when an abandoned
transaction can still produce a response.

## Simulation memory model

`axi4_mem_bfm` connects an array of AXI4 peripheral interfaces to sparse
storage. `CHANNELS` defaults to `1`; `WR_LATENCY` and `RD_LATENCY` default
to `8` and control response eligibility delays. `DEBUG` enables transaction
logging. Use a common clock for all channels, since timing uses a shared
timestamp counter clocked by channel zero.

With `GLOBAL_ADDRESSING=0`, channel indices replace high address bits to
partition storage. With it enabled, channels share the supplied address
space. Reset clears transaction queues and response state while retaining
memory contents. Unwritten memory reads as zero, and writes honor byte
strobes.

The model supports the suite's register-window accesses and incrementing
burst traffic at bus-word strides. It does not model transfer-size-based
narrow burst progression, wrapping accesses, or complete response
backpressure behavior. All responses indicate success; this is a functional
memory model rather than a protocol compliance checker.

## Verification

The SVUnit suite exercises the interface connector between the register
agent and memory model. It checks reset, register-word readback, byte-lane
preservation, randomized write/read sequences, and unwritten memory reads.
Agent checks also cover byte access, timeout cleanup, and successful
transactions after resetting abandoned requests.

The current suite uses a representative wide interface with single-beat
register-window traffic. General burst behavior, the flattened-signal
helper, peripheral termination, and response error injection are outside
its coverage. The AXI4-to-AXI4-Lite adapter is tested separately under
[`axi4l`](../axi4l/README.md).

```sh
# Individual testbench
make -C tests/axi4_intf/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
