# Utility pipelines and reset buffering

Small synchronous components for delaying data and distributing reset.
`util.rtl` depends on `std.rtl` for parameter validation.

## Contents

| Component | Description |
|-----------|-------------|
| `util_pipe` | Resettable data pipeline with shift-register extraction disabled |
| `util_delay` | Resettable delay line allowing the synthesis tool to choose its implementation |
| `util_reset_buffer` | Synchronous reset pipeline with complementary output polarities |

## Data pipelines

`util_pipe` and `util_delay` share `clk`, active-high synchronous `srst`,
`data_in`, and `data_out` ports. They sample data on rising clock edges and
accept a new value every cycle; neither provides valid/ready flow control.

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `DATA_WID` | `1` | Data width in bits |
| `PIPE_STAGES` / `DELAY` | `1` | Pipeline depth or delay length |
| `RESET_VAL` | `'0` | Initial and synchronous reset value of every storage stage |

Positive depth creates the selected number of registers. Reset replaces
all stored values with `RESET_VAL` and takes priority over incoming data.
Zero depth connects input directly to output, without clock or reset
behavior. Negative depths are rejected.

`util_pipe` applies `shreg_extract = "no"` to its storage to preserve a
register pipeline. `util_delay` leaves shift-register extraction to the
synthesis tool. Choose between them according to the desired implementation
and timing structure; their simulated data and reset behavior is the same.

## Reset buffer

`util_reset_buffer` delays `srst_in` through a reset tree and provides
active-high `srst_out` and active-low `srstn_out`. Assertion and deassertion
both propagate through `STAGES` registers on rising edges of `clk`.
`STAGES` defaults to `2` and must be at least two.

`ASSERT_ON_INIT` defaults to `1`, initializing the pipeline with reset
asserted (`srst_out = 1`, `srstn_out = 0`). Setting it to `0` initializes
reset deasserted. The outputs are complementary, including at startup.
The intermediate reset pipeline disables shift-register extraction.

This component assumes the input reset is already fully synchronous to
`clk`. Use the [sync library](../sync/README.md) when reset synchronization
or asynchronous assertion is required.

## Verification

The SVUnit suites check exact data latency, zero-depth bypass, reset
priority and pipeline flushing, and randomized data/reset sequences.
Representative cases include single-bit and wider data with zero and
nonzero reset values. Reset-buffer tests check startup behavior before
the first DUT clock edge, both initial reset states, assertion and
deassertion latency, and complementary output polarities.

Stimulus and monitoring use clocking blocks. The tests verify functional
behavior; synthesis attributes and physical reset-tree implementation are
outside their scope.

Run from this directory:

```sh
# Individual testbench
make -C tests/util_pipe/

# All utility suites
make regression
```

Pass `waves=ON` to capture a waveform, or `SEED=N` to fix the random seed.
