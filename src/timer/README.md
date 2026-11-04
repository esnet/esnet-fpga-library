# Timer

Tick generation, wrapping counters, and timestamp expiry checking with
AXI4-Lite configuration. `timer.rtl` depends on `axi4l.rtl` and generated
`timer.regio.rtl` register components. `timer.verif` provides a register
agent for the expiry checker.

## Contents

| Component | Description |
|-----------|-------------|
| `timer` | Tick-driven wrapping counter with reset and freeze controls |
| `timer_tick` | Convert sampled timer-clock edges into timer ticks |
| `timer_expiry` | Compare timestamps against a programmable expiry threshold |
| `timer_expiry_reg_agent` | Verification access to expiry configuration and status |

## Timer counter

`timer` increments on each rising `clk` edge where `tick` is asserted and
`freeze` is deasserted. The `TIMER_WID` parameter defaults to `1` and sets
the counter width. Values wrap modulo `2**TIMER_WID`.

Both `srst` and `reset` synchronously clear the counter, taking priority
over freeze and tick. The counter also initializes to zero. The plain
counter has no register interface.

## Tick generation

`timer_tick` samples `tclk` on `clk` and converts detected edges into
registered tick indications.

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `TCLK_PER_TICK` | `1000` | Number of detected events per output tick |
| `TCLK_DDR` | `1` | Count both sampled transitions; `0` counts rising edges only |

With `TCLK_PER_TICK=1`, each detected event generates a tick without
additional division. With `TCLK_PER_TICK=0`, `tclk` is ignored and ticks
are generated continuously after reset. `squelch` suppresses the
registered output without resetting the event counter. `srst` clears the
event pulse and divider state.

The input is sampled rather than passed through an asynchronous clock
synchronizer. Ensure that transitions meet the sampling requirements and
remain observable at the `clk` rate. The output path is registered, so
ticks follow input events with pipeline latency.

## Timestamp expiry

`timer_expiry` maintains a `TIMER_WID`-bit timer, defaulting to `1`, and
accepts a timestamp on `timer_in`. Each clock it registers the threshold
`timer - timeout`; `expired` is asserted when the signed, wrapping
difference `timer_in - threshold` is nonpositive. Equality therefore
counts as expired. The registered `timer_out` is aligned with the timer
value used to calculate that threshold.

This modular comparison supports rollover when the timestamps and
thresholds being compared are within half the timer range. Keep timeout
and relevant timestamp ages below `2**(TIMER_WID-1)` for unambiguous age
comparisons. The timeout register is 32 bits; the current RTL selects its
low `TIMER_WID` bits, so use timer widths up to 32 bits for this component.

The hardware `reset` input clears the counter. `srst` and the software
reset bit feed a registered internal reset. Hardware and software freeze
controls are ORed together to pause counting. Counting also requires the
registered combination of `en` and the software enable bit. Disabling
either pauses the counter without clearing it; ticks while disabled are
discarded. Enable changes take effect through this register, adding one
`clk` cycle of latency. Reset still clears the counter while disabled.
The expiry output continues to compare timestamps against the threshold
while counting is paused.

### Register access

Connect `axil_if` to an AXI4-Lite controller. Its clock can differ from the
timer clock; an `axi4l_intf_cdc` crosses register accesses into `clk`.
Register definitions live under [`regio/`](regio/).

| Register | Capability |
|----------|------------|
| `info_timer_bits` | Counter width |
| `cfg_timeout` | Expiry timeout in ticks |
| `control` | Software reset, counting enable, and freeze |
| `status` | Internal reset, enable, and ready indications |
| `dbg_timer_upper`, `dbg_timer_lower` | Current timer value split into upper/lower words |

Construct `timer_verif_pkg::timer_expiry_reg_agent` with a register-agent
transport and an optional base offset. An AXI4-Lite register agent can
provide the transport. The helper supports `soft_reset()`, `wait_ready()`,
`set_timeout()`, `get_timeout()`, `get_timer_bits()`, and
`get_timer_value()`.

`soft_reset()` asserts and clears the software reset bit, then polls
readiness. Debug timer reads retrieve the upper and lower words
separately; they do not latch an atomic snapshot while the timer runs.

## Verification

The SVUnit suite exercises the expiry checker through its AXI4-Lite
register agent with separate register and timer clocks. It checks hardware
and software reset, configuration readback, debug counter reads, timer
output, hardware/software counting enables, and expiry decisions. Enable
checks cover paused counts, resumption, combined hardware/software
control, and counter reset while disabled. Boundary cases cover threshold
equality, rollover, and transitions around zero and the signed midpoint,
alongside randomized timestamps and timeout values.

The current suite uses a representative counter width and drives ticks
directly. Standalone tick-divider behavior and freeze controls are outside
its coverage.

```sh
# Individual testbench
make -C tests/timer_expiry/

# All tests
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
