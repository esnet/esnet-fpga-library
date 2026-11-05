# Standard components

Common parameter checks, reset and event interfaces, and clock-domain
crossing wrappers for block control and monitoring. The
[`std.verif` library](verif/README.md) provides reusable verification
classes, environments, and scoreboards in a separate component.

## Contents

| Component | Description |
|-----------|-------------|
| `std_pkg` | Integer parameter checks with fatal diagnostics |
| `std_reset_intf` | Reset/ready interface with polarity-aware verification helpers |
| `std_event_intf` | Event indication and associated message data |
| `std_block_control` | Transfer reset and enable levels from the control clock domain to a block |
| `std_block_monitor` | Transfer block status levels and a sampled state byte to the control clock domain |
| [`std_verif_pkg`](verif/README.md) | Transaction types, component lifecycle, workers, reference models, and scoreboards |

The control and monitoring wrappers instantiate components from
[`sync.rtl`](../sync/README.md); include that component when using them.
`std.verif` depends on `std.rtl`.

## Parameter checks

`std_pkg` provides helpers for validating integer parameters, typically
called from an `initial` block:

| Function | Required condition |
|----------|--------------------|
| `param_check(value, expected, name, msg="")` | `value == expected` |
| `param_check_lt(value, maximum, name, msg="")` | `value <= maximum` |
| `param_check_gt(value, minimum, name, msg="")` | `value >= minimum` |

Bounds are inclusive. A failed check issues a fatal diagnostic containing
the parameter name, supplied value, expected value or bound, and optional
message.

## Reset interface

`std_reset_intf` carries `reset` and `ready` signals associated with `clk`.
The `controller` modport drives reset and receives readiness; the
`peripheral` modport receives reset and drives readiness.

`ACTIVE_LOW` defaults to `0` for active-high reset. Set it to `1` for
active-low operation. `INIT_VALUE` specifies the initial reset signal
level and defaults to the asserted level for the selected polarity.
The peripheral supplies `ready`; the interface does not derive readiness
from reset or initialize it.

A rising-edge clocking block and verification tasks support reset control:

| Task | Behavior |
|------|----------|
| `assert_sync()`, `deassert_sync()` | Drive the selected reset level through the clocking block and wait for a clocking event |
| `assert_async()`, `deassert_async()` | Assign the selected reset level immediately |
| `_wait(cycles)` | Wait for interface clocking events |
| `wait_ready(timeout, TIMEOUT=0)` | Wait for sampled readiness, returning a timeout flag; zero disables the limit |
| `pulse(cycles=1)` | Sequence synchronous assertion, a cycle wait, and synchronous deassertion |

These tasks provide simulation stimulus. They do not instantiate reset
synchronization hardware. The [sync library](../sync/README.md) provides
hardware reset synchronizers, and [`util_reset_buffer`](../util/README.md)
provides pipelining for an already synchronous reset.

## Event interface

`std_event_intf` carries an `evt` indication and a `MSG_WID`-bit `msg` on
`clk`; `MSG_WID` defaults to `1`. The `publisher` modport drives both
signals, and the `subscriber` modport receives them. Subscribers use
`evt` to qualify the accompanying message. There is no acknowledgement,
backpressure, or internal event storage.

Each rising edge with `evt=1` reports an event; consecutive asserted cycles
report consecutive events. The message is meaningful only while `evt` is
asserted.

The verification clocking block drives signals on rising edges of `clk`.
`idle()` clears the event and message, and `_wait(cycles)` waits for clocking
events. `notify(msg)` waits for a clocking event, drives the message and
`evt` for a full clock cycle, then clears both. Serialize calls through a
single publisher to avoid competing drives.

## Block control and monitoring

`std_block_control` transfers active-high `ctrl_reset_in` and
`ctrl_enable_in` from `ctrl_clk` to `blk_reset_out` and `blk_enable_out`
in the `blk_clk` domain. Each level uses a separate `sync_level` handshake.
This is level synchronization; it does not provide asynchronous reset
assertion or guarantee capture of closely spaced transitions.

`std_block_monitor` transfers block reset, enable, and ready indications
from `blk_clk` to `ctrl_clk` using separate level synchronizers. It also
transfers the eight-bit `blk_state_mon_in` value through
`sync_bus_sampled`, which captures state snapshots at the handshake rate.
The status levels and state byte cross independently, so their outputs
do not form an atomic snapshot.

Both clocks must run for handshakes to complete. These wrappers do not
expose synchronizer readiness, and their internal reset inputs are tied
inactive. Initial output values are unspecified; allow synchronization
to complete before using status. Keep control levels stable long enough
for the handshake to transfer them. See the [sync guide](../sync/README.md)
for the underlying synchronizers and their timing assumptions.

## Verification

The [`std.verif` suites](verif/README.md#verification) exercise transaction
operations, hierarchical lifecycle management, mailbox dataflow, reference
models, scoreboards, and loopback environments. Environment tests exercise
`std_reset_intf` with active-high and active-low resets.

The RTL suites check event pulse duration, message preservation, repeated
notifications, and default message width. Block control/monitoring tests
use independent clocks to check level and state transfers, including stable
randomized inputs. These are functional CDC checks; they do not model
metastability or replace timing and CDC analysis.

Run the suites from this directory:

```sh
# Individual RTL or verification testbench
make -C tests/std_event_intf/
make -C verif/tests/environments/

# All RTL and verification tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
