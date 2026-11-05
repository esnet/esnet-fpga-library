# Register access proxy

`reg.proxy` provides indirect access to a downstream register interface
through an AXI4-Lite command register block. Verification and Python
clients can use the proxy as a transport for another register map.

## Contents

| Component | Description |
|-----------|-------------|
| `reg_proxy` | AXI4-Lite command/status registers driving a downstream `reg_intf` |
| `reg_proxy_verif_pkg::reg_proxy_agent` | Register transport layered over another register agent |
| [`reg_proxy.yaml`](regio/reg_proxy.yaml) | Command register map and Regio protocol declaration |
| [`reg_proxy_protocol.py`](regio/reg_proxy_protocol.py) | Python Regio protocol for indirect register access |

The RTL uses its generated `reg.proxy.regio.rtl` register block and the
[AXI4-Lite library](../../axi4l/README.md). The verification agent builds on
the [register agent API](../README.md#verification-agents).

## Hardware interface

`reg_proxy` exposes `axil_if` as an `axi4l_intf.peripheral` and `reg_if` as
a `reg_intf.controller`. The downstream interface uses `axil_if.aclk`;
its active-high synchronous reset is registered from `!axil_if.aresetn`.
The command map carries a 32-bit byte address, 32-bit data, and write
byte enables for the word's four byte lanes.

| Register | Purpose |
|----------|---------|
| `command` | Write-event register; `wr_rd_n` selects write (`1`) or read (`0`) |
| `status` | `ready`, `done`, and `error` indications; reading clears `done` and `error` |
| `address` | Downstream byte address |
| `wr_data` | Data for a downstream write |
| `wr_byte_en` | Per-byte write enables, initially all enabled |
| `rd_data` | Result of a completed downstream read |

Read status to check readiness and clear any prior completion, program the
address and write payload as needed, then write the command. Poll status
until `done` is set and check `error` before consuming read data. Serialize
commands and consume each completion before starting another transaction.
The current RTL leaves `ready` asserted after initialization, so it does
not indicate whether a command is in progress.

Downstream read/write requests are single-cycle strobes followed by a wait
for the corresponding acknowledgement. The peripheral must return its
acknowledgement in the subsequent acknowledgement-wait phase. Error
completions place `reg_pkg::BAD_ACCESS_DATA` in `rd_data`.

There is no downstream timeout in the RTL. A peripheral that never
acknowledges leaves the proxy waiting until reset. Client-side timeouts
limit the client's wait; they do not cancel the hardware transaction.

## Verification and software clients

`reg_proxy_agent` extends `reg_agent` and wraps a supplied register
transport plus an optional `BASE_OFFSET` locating the proxy's command map.
Its word operations program the command registers and poll completion.
Byte operations align the downstream address to a word and select the
appropriate byte lane. Read and write timeout limits default to 256 cycles
of the wrapped transport's `wait_n()` clock and can be configured through
the inherited agent API.

Attach the proxy agent to a generated target block agent's public
`reg_agent` handle. The generated agent's base address locates the target
in the downstream map; the proxy agent's `BASE_OFFSET` independently
locates the proxy in the upstream map. This allows named-register clients
to use the same methods for direct and indirect access.

The Python Regio protocol implements the same command/poll sequence for
word accesses, enables all write byte lanes on startup, and raises
exceptions for timeout or error completions. It translates Regio word
offsets to downstream byte addresses. Its `size` argument does not select
partial-word transfers.

## Verification

The SVUnit suite accesses the register byte-order checker through the
AXI4-Lite proxy wrapper and `reg_proxy_agent`. It checks packed and
unpacked scratchpad readback through the indirect path. This exercises
transport layering with a generated named-register agent; byte accesses,
error recovery, and the Python protocol are outside the suite's coverage.

Run from this directory:

```sh
# Individual testbench
make -C tests/reg_proxy/

# Regression
make -C tests/regression/
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
