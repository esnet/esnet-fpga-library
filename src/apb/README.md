# APB

Advanced Peripheral Bus interfaces, register-access adapters, and
verification helpers. `apb.rtl` depends on `reg.rtl`; `apb.verif` adds an
APB register agent using the standard verification infrastructure.

## Contents

| Component | Description |
|-----------|-------------|
| `apb_pkg` | Typed protection attributes and their default value |
| `apb_intf` | APB signals, controller/peripheral modports, and a verification clocking block |
| `apb_intf_connector` | Direct interface connection |
| `apb_intf_controller_term`, `apb_intf_peripheral_term` | Tie-offs for unused endpoints |
| `apb_intf_from_signals`, `apb_intf_to_signals` | Flattened-signal interface helpers |
| `apb_controller` | Convert register requests into APB transfers, with optional timeouts |
| `apb_peripheral` | Convert APB transfers into register requests |
| `apb_reg_agent` | Clocking-block APB reads, writes, byte access, and timeouts |

## Interface and transfer behavior

`apb_intf` defaults to `ADDR_WID=32` and `DATA_BYTE_WID=4`. It carries a
clock (`pclk`), active-low reset (`presetn`), address and protection fields,
write direction/data/byte strobes, and read data/error responses.

A transfer has a setup phase with `psel=1` and `penable=0`, followed by an
access phase with both asserted. The controller keeps the address,
direction, and write payload stable until `pready` completes the access.
Completion occurs on a rising `pclk` edge with `psel && penable && pready`.
If `pready` is low, the access phase continues with the request held stable.
`pslverr` qualifies the response at completion. Write strobes select which
bytes may change; read transfers do not use write strobes. Consecutive
transfers each require a setup phase, even when `psel` remains asserted.

The connector forwards clock/reset and request signals and returns
responses. The signal helpers provide the equivalent wiring through
flattened ports. Match address and data widths at both ends. These helpers
provide no buffering or clock-domain crossing.

The controller terminator holds clock/reset and request outputs low. The
peripheral terminator drives zero read data, asserts the error indication,
and holds readiness low. It therefore leaves accesses uncompleted; use a
controller timeout when accessing a terminated endpoint.

`apb_pkg::pprot_t` provides raw and encoded protection views.
`PPROT_DEFAULT` is zero. The interface's `cb` clocking block uses the
SystemVerilog default skews and exposes sampled select/enable views for
verification. Transaction tasks live in the agent rather than the interface.

## Register adapters

### Controller

`apb_controller` accepts a [`reg_intf`](../reg/README.md) peripheral port
and drives an APB controller port. It forwards the register clock to APB
and registers the active-low APB reset from active-high register reset.
Allow reset to settle before issuing requests.

Write requests supply address, data, and byte enables; reads supply an
address. The controller generates the setup/access sequence and converts
APB completion into a register acknowledgement and error indication. It
handles one request at a time without an input queue, so serialize requests
until completion and keep their context valid through setup. Simultaneous
write/read requests select the write path. Protection is fixed to
`PPROT_DEFAULT`.

`WR_TIMEOUT` and `RD_TIMEOUT` each default to `256` access-phase clock
cycles. Zero disables the corresponding deadline. Both single-cycle limits
and differing read/write limits are supported. A timeout acknowledges the
register request with an error and ends the APB access. Read errors and
timeouts return `reg_pkg::BAD_ACCESS_DATA`; successful reads return `prdata`.

### Peripheral

`apb_peripheral` accepts an APB peripheral port and drives a register
controller port. It forwards the APB clock and derives a registered,
active-high register reset from `presetn`.

The peripheral captures request context during setup, then asserts the
corresponding register request during access until the backend
acknowledges it. Register byte enables come from `pstrb`. Backend
acknowledgement, error, and read data become APB readiness, error, and read
data. The peripheral has no internal timeout; a backend that never responds
can stall the transfer indefinitely.

Connect the adapters and their register backends in the same clock domain
and match interface widths. If a controller aborts a request on timeout,
reset the endpoints before reuse when the peripheral or backend can retain
an outstanding transaction.

## Verification agent

`apb_verif_pkg::apb_reg_agent` extends the generic register transport. Its
`ADDR_WID` and `DATA_BYTE_WID` defaults match the APB interface. Construct
it with a name and optional write/read timeout limits, then attach its
`apb_vif` handle to a matching controller interface. Supply clock and reset
separately; the agent controls transaction signals.

| Method | Capability |
|--------|------------|
| `idle()` | Quiesce controller outputs and wait a clocking-block event |
| `wait_n(cycles)` | Wait APB clock cycles |
| `write(addr, data, strb, error, timeout, WR_TIMEOUT)` | Write with explicit byte strobes and completion status |
| `read(addr, data, error, timeout, RD_TIMEOUT)` | Read data and completion status |
| `write_reg()`, `read_reg()` | Inherited word access with transport error reporting |
| `write_byte()`, `read_byte()` | Align to a bus word and select the requested byte lane |

The agent generates setup and access phases through the interface clocking
block, waiting for a sampled access completion even when readiness was
already high during setup. Transfers use default protection attributes.
Callers of the explicit-strobe API supply word-aligned addresses and data
on the intended byte lanes. Byte helpers perform alignment and lane
selection automatically.

Explicit read/write deadlines default to 256 clock cycles and include the
setup phase. Inherited register methods use the agent's configurable
read/write limits, also initialized to 256 unless overridden. A nonpositive
agent limit waits indefinitely. Timeouts cancel the transfer and clear
select/enable; they do not reset the peripheral.

## Verification

The SVUnit interface suite exercises the connector and flattened-signal
helpers together. It checks setup/access sequencing, stable payloads during
wait states, write strobes, read data, error propagation, byte-lane access,
agent timeout cleanup, and endpoint tie-offs.

The controller suite connects the controller and peripheral adapters to a
small register model. It checks reset, word readback, masked and zero-strobe
writes, delayed responses, backend errors, and timeout/reset recovery.
Examples include single-cycle deadlines and disabled timeouts. Stimulus
and monitoring use clocking blocks, with a local testcase failsafe.

The suites cover representative register-bus geometry and serialized
traffic. They do not exhaustively verify every width or protection
attribute, simultaneous upstream requests, or clock-domain crossings.
AXI4-Lite integration is covered separately by the bridge and proxy suites
under [`axi4l`](../axi4l/README.md).

```sh
# Individual testbenches
make -C tests/apb_intf/
make -C tests/apb_controller/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
